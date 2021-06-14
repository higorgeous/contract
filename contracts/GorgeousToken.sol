// SPDX-License-Identifier: MIT

// GRGS - Gorgeous: BEP20 token contract
// Telegram: https://t.me/gorgeoustoken
// Website: https://www.higorgeous.io/

// TOKENOMICS
// ----------------------------------------------------------------------------
// Symbol: GRGS
// Name: Gorgeous
// Total supply: 100,000,000.000000000000000000
// Decimals: 9
// ----------------------------------------------------------------------------
// Max buy 2% max, hold 5%
// 100% Liquidity burned, Ownership renounced
// ----------------------------------------------------------------------------
// Sell within 1 hour: 41% burn (1% Burn, 10% Back to the Liquidity Pool, 10% To charity wallet, 10% To operating wallet, 10% Redistributed to Holders)
// Sell within 2 hours: 33% burn (1% Burn, 8% Back to the Liquidity Pool, 8% To charity wallet, 8% To operating wallet, 8% Redistributed to Holders)
// Standard burn: 21% burn (1% Burn, 5% Back to the Liquidity Pool, 5% To charity wallet, 5% To operating wallet, 5% Redistributed to Holders)
// ----------------------------------------------------------------------------

pragma solidity ^0.8.5;

import "./BaseRedistribution.sol";
import "./Liquifier.sol";
import "./Antiwhale.sol";

// import "https://github.com/higorgeous/contract/blob/master/contracts/BaseRedistribution.sol";
// import "https://github.com/higorgeous/contract/blob/master/contracts/Liquifier.sol";
// import "https://github.com/higorgeous/contract/blob/master/contracts/Antiwhale.sol";

contract GorgeousToken is BaseRedistribution, Liquifier, Antiwhale {
    constructor() {
        initializeLiquiditySwapper(
            maxTransactionAmount,
            numberOfTokensToSwapToLiquidity
        );

        // exclude the pair address from rewards - we don't want to redistribute
        // tokenomics to these two; redistribution is only for holders!
        _exclude(_pair);
        _exclude(burnAddress);
    }

    function _isV2Pair(address account) internal view override returns (bool) {
        return (account == _pair);
    }

    function _getSumOfTokenomics(address sender, uint256 amount)
        internal
        view
        override
        returns (uint256)
    {
        return _getAntiwhaleTokenomics(balanceOf(sender), amount);
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

    function _takeTransactionTokenomics(uint256 amount, uint256 currentRate)
        internal
        override
    {
        if (isInPresale) {
            return;
        }

        uint256 tokenomicsCount = _getTokenomicsCount();
        for (uint256 index = 0; index < tokenomicsCount; index++) {
            (TokenomicType name, uint256 value, address recipient, ) =
                _getTokenomic(index);
            // no need to check value < 0 as the value is uint (i.e. from 0 to 2^256-1)
            if (value == 0) continue;

            if (name == TokenomicType.Redistribution) {
                _redistribute(amount, currentRate, value, index);
            } else if (name == TokenomicType.Burn) {
                _burn(amount, currentRate, value, index);
            } else if (name == TokenomicType.ExternalToBNB) {
                _takeTokenomicsToBNB(
                    amount,
                    currentRate,
                    value,
                    recipient,
                    index
                );
            } else {
                _takeTokenomics(amount, currentRate, value, recipient, index);
            }
        }
    }

    function _burn(
        uint256 amount,
        uint256 currentRate,
        uint256 tokenomic,
        uint256 index
    ) private {
        uint256 tBurn = (amount * tokenomic) / TOKENOMICS_DIVISOR;
        uint256 rBurn = tBurn * currentRate;

        _burnTokens(address(this), tBurn, rBurn);
        _addTokenomicCollectedAmount(index, tBurn);
    }

    function _takeTokenomics(
        uint256 amount,
        uint256 currentRate,
        uint256 tokenomic,
        address recipient,
        uint256 index
    ) private {
        uint256 tAmount = (amount * tokenomic) / TOKENOMICS_DIVISOR;
        uint256 rAmount = tAmount * currentRate;

        _reflectedBalances[recipient] = _reflectedBalances[recipient] + rAmount;
        if (_isExcludedFromRewards[recipient])
            _balances[recipient] = _balances[recipient] + tAmount;

        _addTokenomicCollectedAmount(index, tAmount);
    }

    /**
     * When implemented this will convert the tokenomic amount of tokens into BNB
     * and send to the recipient's wallet. Note that this reduces liquidity so it
     * might be a good idea to add a % into the liquidity tokenomic for % you take
     * our through this method (just a suggestions)
     */
    function _takeTokenomicsToBNB(
        uint256 amount,
        uint256 currentRate,
        uint256 tokenomic,
        address recipient,
        uint256 index
    ) private {
        _takeTokenomics(amount, currentRate, tokenomic, recipient, index);
        (amount, currentRate, tokenomic, recipient, index);
    }

    function _approveDelegate(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        _approve(owner, spender, amount);
    }
}

contract HellCoin is GorgeousToken{

    constructor() GorgeousToken(Env.Testnet){
        // pre-approve the initial liquidity supply
        _approve(owner(),address(_router), ~uint256(0));
    }
}

/**
 * Tests to pass:
 *
 * - Tokenomics fees can be added/removed/edited
 * - Tokenomics fees are correctly taken from each (qualifying) transaction
 * - The redistribution tokenomics is correctly distributed among holders (which are not excluded from rewards)
 * - `swapAndLiquify` works correctly when the threshold balance is reached
 * - `maxTransactionAmount` works correctly and *unlimited* accounts are not subject to the limit
 * - `maxWalletBalance` works correctly and *unlimited* accounts are not subject to the limit
 * - accounts excluded from fees are not subjecto tx fees
 * - accounts excluded from rewards do not share in rewards
 * - BNB collected/stuck in the contract can be withdrawn (see)
 */
