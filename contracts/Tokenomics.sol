// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./Presaleable.sol";

abstract contract Tokenomics is Presaleable {
    string internal constant NAME = "Gorgeous Token";
    string internal constant SYMBOL = "GORGEOUS";

    uint16 internal constant TOKENOMICS_DIVISOR = 10**3;
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
        0x6ea97adae69Ff80E418Ea78E80Ae9ab2f2254389;
    address internal projectAddress =
        0x5DDB6ABD2e3A1f23f15a77227d9652c94341AA57;
    address internal burnAddress = 0x000000000000000000000000000000000000dEaD;

    /**
     * Address to get time token was last received
     */
    mapping(address => uint256) lastReceived;

    enum TokenomicType {
        Burn,
        Liquidity,
        Redistribution,
        External,
        ExternalToBNB
    }
    struct Tokenomic {
        TokenomicType name;
        uint256 value;
        address recipient;
        uint256 total;
    }

    Tokenomic[] internal tokenomics;
    uint256 internal sumOfTokenomics;

    constructor() {
        _addTokenomics();
    }

    function _addTokenomic(
        TokenomicType name,
        uint256 value,
        address recipient
    ) private {
        tokenomics.push(Tokenomic(name, value, recipient, 0));
        sumOfTokenomics += value;
        _updateLastReceived(recipient);
    }

    function getMultiplier(address _sender) internal view returns (uint256) {
        uint256 timeReceived = block.timestamp - lastReceived[_sender];
        if (timeReceived < 1 hours) {
            return 100;
        } else if (timeReceived < 2 hours) {
            return 80;
        }
        return 50;
    }

    function _updateLastReceived(address _receiver) internal {
        lastReceived[_receiver] = block.timestamp;
    }

    function _addTokenomics() private {
        uint256 fee = getMultiplier(msg.sender);

        _addTokenomic(TokenomicType.Redistribution, fee, address(this));

        _addTokenomic(TokenomicType.Burn, 10, burnAddress);
        _addTokenomic(TokenomicType.Liquidity, 50, address(this));
        _addTokenomic(TokenomicType.ExternalToBNB, 50, charityAddress);
        _addTokenomic(TokenomicType.ExternalToBNB, 50, projectAddress);
    }

    function _getTokenomicsCount() internal view returns (uint256) {
        return tokenomics.length;
    }

    function _getTokenomicStruct(uint256 index)
        private
        view
        returns (Tokenomic storage)
    {
        require(
            index >= 0 && index < tokenomics.length,
            "TokenomicSettings._getTokenomicStruct: Tokenomic index out of bounds"
        );
        return tokenomics[index];
    }

    function _getTokenomic(uint256 index)
        internal
        view
        returns (
            TokenomicType,
            uint256,
            address,
            uint256
        )
    {
        Tokenomic memory tokenomic = _getTokenomicStruct(index);
        return (
            tokenomic.name,
            tokenomic.value,
            tokenomic.recipient,
            tokenomic.total
        );
    }

    function _addTokenomicCollectedAmount(uint256 index, uint256 amount)
        internal
    {
        Tokenomic storage tokenomic = _getTokenomicStruct(index);
        tokenomic.total = tokenomic.total + amount;
    }

    function getCollectedTokenomicTotal(uint256 index)
        internal
        view
        returns (uint256)
    {
        Tokenomic memory tokenomic = _getTokenomicStruct(index);
        return tokenomic.total;
    }
}
