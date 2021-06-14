// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "../utilities/Manageable.sol";

abstract contract Presaleable is Manageable {
    bool internal isInPresale;

    function setPreseableEnabled(bool value) external onlyManager {
        isInPresale = value;
    }
}
