// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./Tokenomics.sol";

abstract contract SumOfTokenomics is Tokenomics {
    /**
     * Returns the total sum of tokenomics (in percents / per-mille)
     */
    function _getSumOfTokenomics(uint256, uint256)
        internal
        view
        returns (uint256)
    {
        return sumOfTokenomics;
    }
}