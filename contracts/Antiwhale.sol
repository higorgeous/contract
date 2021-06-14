// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./Tokenomics.sol";

abstract contract Antiwhale is Tokenomics {
    /**
     * Returns the total sum of tokenomics (in percents / per-mille)
     */
    function _getAntiwhaleTokenomics(uint256, uint256)
        internal
        view
        returns (uint256)
    {
        return sumOfTokenomics;
    }
}
