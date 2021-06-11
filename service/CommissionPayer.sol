// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPayable {
    function pay(string memory service) external payable;
}

/**
 * @title CommissionPayer
 * @dev Implementation of the CommissionPayer
*/
abstract contract CommissionPayer {
    constructor (address payable receiver, string memory service) payable {
        IPayable(receiver).pay{value: msg.value}(service);
    }
}