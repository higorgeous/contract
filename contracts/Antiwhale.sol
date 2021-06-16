// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./Tokenomics.sol";

abstract contract Antiwhale is Tokenomics {
    /**
     * @dev Returns the total sum of fees (in percents / per-mille - this depends on the FEES_DIVISOR value)
     */
    function _getAntiwhaleFees(uint256, uint256)
        internal
        view
        returns (uint256)
    {
        return sumOfFees;
    }
}
