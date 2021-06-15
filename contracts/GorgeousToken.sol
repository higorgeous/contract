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
// Max buy 2% max, hold 5%
// 50% Burnt to dead wallet
// 40% Liquidity in pool
// Ownership renounced
// ----------------------------------------------------------------------------
// Redistribution fee: 15% burn (1% Burn, 4% Back to the Liquidity Pool, 3% To charity wallet, 3% To operating wallet, 4% Redistributed to Holders)
// ----------------------------------------------------------------------------

pragma solidity ^0.8.5;

import "./SumOfTokenomics.sol";
import "./BaseRedistribution.sol";
import "./Liquifier.sol";

// import "https://github.com/higorgeous/contract/blob/master/contracts/SumOfTokenomics.sol";
// import "https://github.com/higorgeous/contract/blob/master/contracts/BaseRedistribution.sol";
// import "https://github.com/higorgeous/contract/blob/master/contracts/Liquifier.sol";

abstract contract GorgeousToken is BaseRedistribution, Liquifier, SumOfTokenomics {
    constructor(Env _env) {
        initializeLiquiditySwapper(
            _env,
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
        return _getSumOfTokenomics(balanceOf(sender), amount);
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
            } else if (name == TokenomicType.Project) {
                _project(amount, currentRate, value, recipient, index);
            } else {
                _takeTokenomic(amount, currentRate, value, recipient, index);
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

    function _takeTokenomic(
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

    function _project(uint256 amount, uint256 currentRate, uint256 fee, address recipient, uint256 index) private {
        _takeTokenomic(amount, currentRate, fee, recipient, index);        
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
    constructor() GorgeousToken(Env.Testnet) {
        _approve(owner(), address(_router), ~uint256(0));
    }
}
