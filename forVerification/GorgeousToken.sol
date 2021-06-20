// SPDX-License-Identifier: MIT

// GORGEOUS - Gorgeous: BEP20 token contract
// Telegram: https://t.me/gorgeoustoken
// Website: https://www.higorgeous.io/

// TOKENOMICS
// ----------------------------------------------------------------------------
// Symbol: GORGEOUS
// Name: Gorgeous
// Total supply: 100,000,000.000000000000000000
// Decimals: 9
// ----------------------------------------------------------------------------
// Max buy 1% max, hold 4%
// 20% Burnt to dead wallet
// 70% Liquidity & Pre-sale on DxSale
// Ownership renounced
// ----------------------------------------------------------------------------
// Redistribution fee: 15% burn (1% Burn, 4% Back to the Liquidity Pool, 3% To charity wallet, 3% To operating wallet, 4% Redistributed to Holders)
// ----------------------------------------------------------------------------

pragma solidity ^0.8.4;

import "./BaseRfiToken.sol";
import "./Liquifier.sol";
import "./Antiwhale.sol";
import "./SafeMath.sol";

abstract contract GorgeousToken is BaseRfiToken, Liquifier, Antiwhale {
    using SafeMath for uint256;

    constructor(Env _env) {
        initializeLiquiditySwapper(
            _env,
            maxTransactionAmount,
            numberOfTokensToSwapToLiquidity
        );

        // exclude the pair address from rewards - we don't want to redistribute
        // tx fees to these two; redistribution is only for holders.
        _exclude(_pair);
        _exclude(burnAddress);
    }

    function _isV2Pair(address account) internal view override returns (bool) {
        return (account == _pair);
    }

    function _getSumOfFees(address sender, uint256 amount)
        internal
        view
        override
        returns (uint256)
    {
        return _getAntiwhaleFees(balanceOf(sender), amount);
    }

    function _beforeTokenTransfer(
        address sender,
        address,
        uint256,
        bool
    ) internal override {
        if (!isInPresale) {
            uint256 contractTokenBalance = balanceOf(address(this));
            liquify(contractTokenBalance, sender);
        }
    }

    function _takeTransactionFees(uint256 amount, uint256 currentRate)
        internal
        override
    {
        if (isInPresale) {
            return;
        }

        uint256 feesCount = _getFeesCount();
        for (uint256 index = 0; index < feesCount; index++) {
            (FeeType name, uint256 value, address recipient, ) = _getFee(index);
            // no need to check value < 0 as the value is uint (i.e. from 0 to 2^256-1)
            if (value == 0) continue;

            if (name == FeeType.Rfi) {
                _redistribute(amount, currentRate, value, index);
            } else if (name == FeeType.Burn) {
                _burn(amount, currentRate, value, index);
            } else {
                _takeFee(amount, currentRate, value, recipient, index);
            }
        }
    }

    function _burn(
        uint256 amount,
        uint256 currentRate,
        uint256 fee,
        uint256 index
    ) private {
        uint256 tBurn = amount.mul(fee).div(FEES_DIVISOR);
        uint256 rBurn = tBurn.mul(currentRate);

        _burnTokens(address(this), tBurn, rBurn);
        _addFeeCollectedAmount(index, tBurn);
    }

    function _takeFee(
        uint256 amount,
        uint256 currentRate,
        uint256 fee,
        address recipient,
        uint256 index
    ) private {
        uint256 tAmount = amount.mul(fee).div(FEES_DIVISOR);
        uint256 rAmount = tAmount.mul(currentRate);

        _reflectedBalances[recipient] = _reflectedBalances[recipient].add(
            rAmount
        );
        if (_isExcludedFromRewards[recipient])
            _balances[recipient] = _balances[recipient].add(tAmount);

        _addFeeCollectedAmount(index, tAmount);
    }

    function _approveDelegate(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        _approve(owner, spender, amount);
    }
}

contract Gorgeous is GorgeousToken {
    constructor() GorgeousToken(Env.MainnetV2) {
        _approve(owner(), address(_router), ~uint256(0));
    }
}
