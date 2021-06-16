// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./Presaleable.sol";
import "../libraries/SafeMath.sol";

abstract contract Tokenomics {
    using SafeMath for uint256;

    // --------------------- Token Settings ------------------- //

    string internal constant NAME = "Gorgeous";
    string internal constant SYMBOL = "GORGEOUS";

    uint16 internal constant FEES_DIVISOR = 10**3;
    uint8 internal constant DECIMALS = 9;
    uint256 internal constant ZEROES = 10**DECIMALS;

    uint256 private constant MAX = ~uint256(0);
    uint256 internal constant TOTAL_SUPPLY = 100000000 * ZEROES;
    uint256 internal _reflectedSupply = (MAX - (MAX % TOTAL_SUPPLY));

    /**
     * @dev Set the maximum transaction amount allowed in a transfer.
     */
    uint256 internal constant maxTransactionAmount = TOTAL_SUPPLY / 50; // 2% of the total supply

    /**
     * @dev Set the maximum allowed balance in a wallet.
     */
    uint256 internal constant maxWalletBalance = TOTAL_SUPPLY / 20; // 5% of the total supply

    /**
     * @dev Set the number of tokens to swap and add to liquidity.
     *
     * Whenever the contract's balance reaches this number of tokens, swap & liquify will be
     * executed in the very next transfer (via the `_beforeTokenTransfer`)
     *
     * 1 of each transaction will be first sent to the contract address. Once the contract's balance
     *  reaches `numberOfTokensToSwapToLiquidity` the `swapAndLiquify` of `Liquifier` will be executed.
     *  Half of the tokens will be swapped for ETH (or BNB on BSC) and together with the other
     *  half converted into a Token-ETH/Token-BNB LP Token.
     */
    uint256 internal constant numberOfTokensToSwapToLiquidity =
        TOTAL_SUPPLY / 1000; // 0.1% of the total supply

    // --------------------- Fees Settings ------------------- //

    /**
     * @dev Wallets for feeType.External
     */
    address internal charityAddress =
        0xF5972eE5678b435c6e1ff7EBD5982F2a3247A157;
    address internal marketingAddress =
        0xFe607FaD583BB771AA391613860DF274857B8fc8;

    /**
     * @dev Wallets for feeType.Burn
     */
    address internal burnAddress = 0x000000000000000000000000000000000000dEaD;

    enum FeeType {Antiwhale, Burn, Liquidity, Rfi, External}
    struct Fee {
        FeeType name;
        uint256 value;
        address recipient;
        uint256 total;
    }

    Fee[] internal fees;
    uint256 internal sumOfFees;

    constructor() {
        _addFees();
    }

    function _addFee(
        FeeType name,
        uint256 value,
        address recipient
    ) private {
        fees.push(Fee(name, value, recipient, 0));
        sumOfFees += value;
    }

    function _addFees() private {
        /**
         * The value of fees is given in part per 1000 (based on the value of FEES_DIVISOR),
         * e.g. for 5% use 50, for 3.5% use 35, etc.
         */
        _addFee(FeeType.Rfi, 40, address(this));

        _addFee(FeeType.Burn, 10, burnAddress);
        _addFee(FeeType.Liquidity, 40, address(this));
        _addFee(FeeType.External, 30, charityAddress);
        _addFee(FeeType.External, 30, marketingAddress);
    }

    function _getFeesCount() internal view returns (uint256) {
        return fees.length;
    }

    function _getFeeStruct(uint256 index) private view returns (Fee storage) {
        require(
            index >= 0 && index < fees.length,
            "FeesSettings._getFeeStruct: Fee index out of bounds"
        );
        return fees[index];
    }

    function _getFee(uint256 index)
        internal
        view
        returns (
            FeeType,
            uint256,
            address,
            uint256
        )
    {
        Fee memory fee = _getFeeStruct(index);
        return (fee.name, fee.value, fee.recipient, fee.total);
    }

    function _addFeeCollectedAmount(uint256 index, uint256 amount) internal {
        Fee storage fee = _getFeeStruct(index);
        fee.total = fee.total.add(amount);
    }

    // function getCollectedFeeTotal(uint256 index) external view returns (uint256){
    function getCollectedFeeTotal(uint256 index)
        internal
        view
        returns (uint256)
    {
        Fee memory fee = _getFeeStruct(index);
        return fee.total;
    }
}
