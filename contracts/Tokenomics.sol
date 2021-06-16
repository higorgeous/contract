// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./Presaleable.sol";
import "../libraries/SafeMath.sol";

abstract contract Tokenomics {
    using SafeMath for uint256;

    string internal constant NAME = "Gorgeous Token";
    string internal constant SYMBOL = "GORGEOUS";

    uint16 internal constant FEES_DIVISOR = 10**3;
    uint8 internal constant DECIMALS = 9;
    uint256 internal constant ZEROES = 10**DECIMALS;

    uint256 private constant MAX = ~uint256(0);
    uint256 internal constant TOTAL_SUPPLY = 100 * 10**6 * ZEROES;
    uint256 internal _reflectedSupply = (MAX - (MAX % TOTAL_SUPPLY));

    /**
     * Set the maximum buy to 2%.
     */
    uint256 internal constant maxTransactionAmount = TOTAL_SUPPLY / 50;

    /**
     * Set the maximum hold to 5%.
     */
    uint256 internal constant maxWalletBalance = TOTAL_SUPPLY / 20;

    /**
     * Set the number of tokens to swap and add to liquidity.
     *
     * When the contract's balance reaches 0.1% of tokens, swap & liquify will be
     * executed in the next transfer with function `_beforeTokenTransfer`
     *
     * Once the contract's balance reaches `numberOfTokensToSwapToLiquidity`, `swapAndLiquify`
     * of `Liquifier` will be executed. Half of the tokens will be swapped for BNB and together
     * with the other half converted into a Token-BNB LP Token.
     *
     * See: `Liquifier`
     */
    uint256 internal constant numberOfTokensToSwapToLiquidity =
        TOTAL_SUPPLY / 1000; // 0.1% of the total supply

    /**
     * Contract specific address'
     */
    address internal charityAddress =
        0x13E1B9381f9942a76e13B56D69C6a5DB8e5DaD15;
    address internal operatingAddress =
        0x7286444DD26b990014C59a516fC05471d3ac9458;
    address internal burnAddress = 0x000000000000000000000000000000000000dEaD;

    enum FeeType {Antiwhale, Burn, Liquidity, Rfi, Project}
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
        _addFee(FeeType.Rfi, 40, address(this));

        _addFee(FeeType.Burn, 10, burnAddress);
        _addFee(FeeType.Liquidity, 40, address(this));
        _addFee(FeeType.Project, 30, charityAddress);
        _addFee(FeeType.Project, 30, operatingAddress);
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

    function getCollectedFeeTotal(uint256 index)
        internal
        view
        returns (uint256)
    {
        Fee memory fee = _getFeeStruct(index);
        return fee.total;
    }
}
