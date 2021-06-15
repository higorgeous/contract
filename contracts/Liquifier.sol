// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "../interfaces/IPancakeV2Factory.sol";
import "../interfaces/IPancakeV2Router.sol";
import "../utilities/Ownable.sol";
import "../utilities/Manageable.sol";

abstract contract Liquifier is Ownable, Manageable {
    uint256 private withdrawableBalance;

    enum Env {Testnet, Mainnet}
    Env private _env;

    // PancakeSwap V2
    address private _mainnetRouterV2Address =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address private _testnetRouterAddress =
        0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    IPancakeV2Router internal _router;
    address internal _pair;

    bool private inSwapAndLiquify;
    bool private swapAndLiquifyEnabled = true;

    uint256 private maxTransactionAmount;
    uint256 private numberOfTokensToSwapToLiquidity;

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    event RouterSet(address indexed router);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event LiquidityAdded(
        uint256 tokenAmountSent,
        uint256 bnbAmountSent,
        uint256 liquidity
    );

    receive() external payable {}

    function initializeLiquiditySwapper(
        Env env,
        uint256 maxTx,
        uint256 liquifyAmount
    ) internal {
        _env = env;
        if (_env == Env.Mainnet) {
            _setRouterAddress(_mainnetRouterV2Address);
        }
        /*(_env == Env.Testnet)*/
        else {
            _setRouterAddress(_testnetRouterAddress);
        }

        maxTransactionAmount = maxTx;
        numberOfTokensToSwapToLiquidity = liquifyAmount;
    }

    function liquify(uint256 contractTokenBalance, address sender) internal {
        if (contractTokenBalance >= maxTransactionAmount)
            contractTokenBalance = maxTransactionAmount;

        bool isOverRequiredTokenBalance =
            (contractTokenBalance >= numberOfTokensToSwapToLiquidity);

        if (
            isOverRequiredTokenBalance &&
            swapAndLiquifyEnabled &&
            !inSwapAndLiquify &&
            (sender != _pair)
        ) {
            _swapAndLiquify(contractTokenBalance);
        }
    }

    /**
     * sets the router address and created the router, factory pair to enable
     * swapping and liquifying (contract) tokens
     */
    function _setRouterAddress(address router) private {
        IPancakeV2Router _newPancakeRouter = IPancakeV2Router(router);
        _pair = IPancakeV2Factory(_newPancakeRouter.factory()).createPair(
            address(this),
            _newPancakeRouter.WETH()
        );
        _router = _newPancakeRouter;
        emit RouterSet(router);
    }

    function _swapAndLiquify(uint256 amount) private lockTheSwap {
        // Split the contract balance into halves
        uint256 half = amount / 2;
        uint256 otherHalf = amount - half;

        // Capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any BNB that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // Swap tokens for BNB
        _swapTokensForBnb(half); // <- this breaks the BNB -> HATE swap when swap+liquify is triggered

        // How much BNB did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // Add liquidity to pancakeswap
        _addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function _swapTokensForBnb(uint256 tokenAmount) private {
        // Generate the pancakeswap pair path of token -> bnb
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WETH();

        _approveDelegate(address(this), address(_router), tokenAmount);

        // Make the swap
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            // The minimum amount of output tokens that must be received for the transaction not to revert.
            // 0 = accept any amount (slippage is inevitable)
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // Approve token transfer to cover all possible scenarios
        _approveDelegate(address(this), address(_router), tokenAmount);

        // Add the liquidity
        (uint256 tokenAmountSent, uint256 ethAmountSent, uint256 liquidity) =
            _router.addLiquidityETH{value: ethAmount}(
                address(this),
                tokenAmount,
                // Bounds the extent to which the BNB/token price can go up before the transaction reverts.
                // Must be <= amountTokenDesired; 0 = accept any amount (slippage is inevitable)
                0,
                // Bounds the extent to which the token/BNB price can go up before the transaction reverts.
                // 0 = accept any amount (slippage is inevitable)
                0,
                // This is a centralized risk if the owner's account is ever compromised.
                owner(),
                block.timestamp
            );

        /**
         * The swapAndLiquify function converts half of the contractTokenBalance SafeMoon tokens to BNB.
         * For every swapAndLiquify function call, a small amount of BNB remains in the contract.
         * This amount grows over time with the swapAndLiquify function being called throughout the life
         * of the contract. The Safemoon contract does not contain a method to withdraw these funds,
         * and the BNB will be locked in the Safemoon contract forever.
         */
        withdrawableBalance = address(this).balance;
        emit LiquidityAdded(tokenAmountSent, ethAmountSent, liquidity);
    }

    /**
     * Sets the pancakeswapV2 pair (router & factory) for swapping and liquifying tokens
     */
    function setRouterAddress(address router) external onlyManager() {
        _setRouterAddress(router);
    }

    /**
     * Sends the swap and liquify flag to the provided value. If set to `false` tokens collected in the contract will
     * NOT be converted into liquidity.
     */
    function setSwapAndLiquifyEnabled(bool enabled) external onlyManager {
        swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(swapAndLiquifyEnabled);
    }

    /**
     * The owner can withdraw BNB collected in the contract from `swapAndLiquify`
     * or if someone (accidentally) sends BNB directly to the contract.
     *
     * Note: This addresses the contract flaw of Safemoon (SSL-03) pointed out in the Certik Audit:
     */
    function withdrawLockedBnb(address payable recipient)
        external
        onlyManager()
    {
        require(
            recipient != address(0),
            "Cannot withdraw the BNB balance to the zero address"
        );
        require(
            withdrawableBalance > 0,
            "The BNB balance must be greater than 0"
        );

        // prevent re-entrancy attacks
        uint256 amount = withdrawableBalance;
        withdrawableBalance = 0;
        recipient.transfer(amount);
    }

    /**
     * Use this delegate instead of having (unnecessarily) extend `BaseRedistributionToken` to gained access
     * to the `_approve` function.
     */
    function _approveDelegate(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual;
}