// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./Manageable.sol";

abstract contract Presaleable is Manageable {
    bool internal isInPresale;

    function setPreselableEnabled(bool value) external onlyManager {
        isInPresale = value;
    }
}
