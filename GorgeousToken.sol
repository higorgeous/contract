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


pragma solidity ^0.8.3;

import "./interface/IPancakeRouter02.sol";
import "./interface/IPancakeFactory.sol";

import "./library/Address.sol";
import "./library/SafeMath.sol";

import "./service/CommissionPayer.sol";

import "./utility/Context.sol";
import "./utility/IERC20.sol";
import "./utility/Ownable.sol";

contract GorgeousToken is Context, IERC20, Ownable, CommissionPayer {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 100 * 10**6; 
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "Gorgeous";
    string private _symbol = "GRGS";
    uint8 private _decimals = 9;
    uint256 private _start_timestamp = block.timestamp;

    // Tax Fees as standard
    uint256 public _charityFee = 5;
    uint256 public _projectFee = 5;
    uint256 public _hodlerFee = 5;
    uint256 public _liquidityFee = 5;
    uint256 public _previousCharityFee = _charityFee;
    uint256 public _previousProjectFee = _projectFee;
    uint256 public _previousHodlerFee = _hodlerFee;
    uint256 public _previousLiquidityFee = _liquidityFee;
    
    uint256 public _maxTaxAmount = 50 * 10**6;
    uint256 public _numTokensSellToAddToLiquidity = 38 * 10**6;
    uint256 public _maxWalletToken = 5 * 10**6;

    bool inSwapAndLiquify;
    IPancakeRouter02 public immutable pcsV2Router;
    address public immutable pcsV2Pair;
    
    // Receive tax only
    address public charityAddress = 0x6ea97adae69Ff80E418Ea78E80Ae9ab2f2254389;
    address public projectAddress = 0x5DDB6ABD2e3A1f23f15a77227d9652c94341AA57;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity,
        uint256 contractTokenBalance
    );

    constructor() public {
        _rOwned[_msgSender()] = _rTotal;
        _isExcluded[owner()] = true;
        _isExcluded[address(this)] = true;

        // Create a uniswap pair for this new token
        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pcsV2Pair = IPancakeFactory(_pancakeswapV2Router.factory()).createPair(address(this), _pancakeswapV2Router.WETH());
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

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
}