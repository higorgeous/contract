// SPDX-License-Identifier: MIT

// GRGS - Gorgeous: BEP20 token contract
// Telegram: https://t.me/gorgeoustoken
// Website: https://www.higorgeous.io/

// TOKENOMICS
// ----------------------------------------------------------------------------
// Symbol: GRGS
// Name: Gorgeous
// Total supply: 100,000,000.000000000000000000
// Decimals: 18
// ----------------------------------------------------------------------------
// Max buy 2% max, hold 5%
// 100% Liquidity burned, Ownership renounced
// ----------------------------------------------------------------------------
// Sell within 1 hour: 40% burn (10% Back to the Liquidity Pool, 10% To charity wallet, 10% To operating wallet, 10% Redistributed to Holders)
// Sell within 2 hours: 32% burn (8% Back to the Liquidity Pool, 8% To charity wallet, 8% To operating wallet, 8% Redistributed to Holders)
// Standard burn: 20% burn (5% Back to the Liquidity Pool, 5% To charity wallet, 5% To operating wallet, 5% Redistributed to Holders)
// ----------------------------------------------------------------------------

pragma solidity ^0.8.0;

import "./interface/IPancakeRouter02.sol";
import "./interface/IPancakeFactory.sol";

import "./library/SafeMath.sol";

import "./utility/Context.sol";
import "./utility/IBEP20.sol";
import "./utility/Ownable.sol";

contract GorgeousToken is Context, IBEP20, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 100 * 10**6 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "Gorgeous";
    string private _symbol = "GRGS";
    uint8 private _decimals = 9;
    uint256 private _start_timestamp = block.timestamp;

    // Tax Fees as standard
    uint256 public _taxFee = 5;
    uint256 public _charityFee = 5;
    uint256 public _projectFee = 5;
    uint256 public _liquidityFee = 5;
    uint256 public _previousTaxFee = _taxFee;
    uint256 public _previousCharityFee = _charityFee;
    uint256 public _previousProjectFee = _projectFee;
    uint256 public _previousLiquidityFee = _liquidityFee;

    uint256 public _maxTaxAmount = 50 * 10**6 * 10**9;
    uint256 public _numTokensSellToAddToLiquidity = 38 * 10**6 * 10**9;
    uint256 public _maxWalletToken = 5 * 10**6 * 10**9;

    bool inSwapAndLiquify;
    IPancakeRouter02 public immutable pcsV2Router;
    address public immutable pcsV2Pair;

    // Receive tax only
    address public _charityAddress = 0x6ea97adae69Ff80E418Ea78E80Ae9ab2f2254389;
    address public _projectAddress = 0x5DDB6ABD2e3A1f23f15a77227d9652c94341AA57;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity,
        uint256 contractTokenBalance
    );

    constructor() {
        _rOwned[_msgSender()] = _rTotal;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        // Create a uniswap pair for this new token
        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        pcsV2Pair = IPancakeFactory(_pancakeswapV2Router.factory()).createPair(
            address(this),
            _pancakeswapV2Router.WETH()
        );

        // set the rest of the contract variables
        pcsV2Router = _pancakeswapV2Router;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "BEP20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "BEP20: decreased allowance below zero"
            )
        );
        return true;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflect(uint256 tAmount) public {
        address sender = _msgSender();
        (uint256 rAmount, , , , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function removeAllFee() private {
        if (
            _taxFee == 0 &&
            _charityFee == 0 &&
            _projectFee == 0 &&
            _liquidityFee == 0
        ) return;
        _previousTaxFee = _taxFee;
        _previousCharityFee = _charityFee;
        _previousProjectFee = _projectFee;
        _previousLiquidityFee = _liquidityFee;

        _taxFee = 0;
        _charityFee = 0;
        _projectFee = 0;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _charityFee = _previousCharityFee;
        _projectFee = _previousProjectFee;
        _liquidityFee = _previousLiquidityFee;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (
            sender != owner() &&
            recipient != owner() &&
            recipient != address(1) &&
            recipient != pcsV2Pair
        ) {
            require(
                amount <= _maxTaxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
            uint256 contractBalanceRecepient = balanceOf(recipient);
            require(
                contractBalanceRecepient + amount <= _maxWalletToken,
                "Exceeds maximum wallet token amount (100,000,000)"
            );
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is pancakeswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        if (contractTokenBalance >= _maxTaxAmount) {
            contractTokenBalance = _maxTaxAmount;
        }

        bool overMinTokenBalance = contractTokenBalance >=
            _numTokensSellToAddToLiquidity;
        if (overMinTokenBalance && !inSwapAndLiquify && sender != pcsV2Pair) {
            contractTokenBalance = _numTokensSellToAddToLiquidity;
            swapAndLiquify(contractTokenBalance);
        }

        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (
            _isExcludedFromFee[sender] ||
            _isExcludedFromFee[recipient] ||
            sender == pcsV2Pair
        ) {
            takeFee = false;
        }

        if (!takeFee) removeAllFee();

        _transferStandard(sender, recipient, amount);

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tCharity,
            uint256 tProject,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeCharity(tCharity);
        _takeProject(tProject);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tCharity,
            uint256 tProject,
            uint256 tLiquidity
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tCharity,
            tProject,
            tLiquidity,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tCharity,
            tProject,
            tLiquidity
        );
    }

    function _getAntiDumpMultiplier() private view returns (uint256) {
        uint256 time_since_start = block.timestamp - _start_timestamp;
        uint256 hour = 60 * 60;

        if (time_since_start < 1 * hour) {
            return (3);
        } else if (time_since_start < 2 * hour) {
            return (2);
        } else {
            return (1);
        }
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 multiplier = _getAntiDumpMultiplier();
        uint256 tFee = tAmount.div(10**2).mul(_taxFee).mul(multiplier);
        uint256 tCharity = tAmount.div(10**2).mul(_charityFee).mul(multiplier);
        uint256 tProject = tAmount.div(10**2).mul(_projectFee).mul(multiplier);
        uint256 tLiquidity = tAmount.div(10**2).mul(_liquidityFee).mul(
            multiplier
        );
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tCharity, tProject, tLiquidity);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tCharity,
        uint256 tProject,
        uint256 tLiquidity,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rCharity = tCharity.mul(currentRate);
        uint256 rProject = tProject.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount
        .sub(rFee)
        .sub(rCharity)
        .sub(rProject)
        .sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeCharity(uint256 tCharity) private {
        uint256 currentRate = _getRate();
        uint256 rCharity = tCharity.mul(currentRate);
        _rOwned[_charityAddress] = _rOwned[_charityAddress].add(rCharity);
        if (_isExcludedFromFee[_charityAddress])
            _tOwned[_charityAddress] = _tOwned[_charityAddress].add(tCharity);
    }

    function _takeProject(uint256 tProject) private {
        uint256 currentRate = _getRate();
        uint256 rProject = tProject.mul(currentRate);
        _rOwned[_projectAddress] = _rOwned[_projectAddress].add(rProject);
        if (_isExcludedFromFee[_projectAddress])
            _tOwned[_projectAddress] = _tOwned[_projectAddress].add(tProject);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if (_isExcludedFromFee[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        swapTokensForBNB(half);

        // how much BNB did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf, contractTokenBalance);
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pcsV2Router.WETH();

        _approve(address(this), address(pcsV2Router), tokenAmount);

        // make the swap
        pcsV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pcsV2Router), tokenAmount);

        // add the liquidity
        pcsV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    receive() external payable {}
}
