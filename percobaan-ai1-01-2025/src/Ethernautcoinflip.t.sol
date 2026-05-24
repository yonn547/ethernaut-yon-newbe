// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/CoinFlip.sol";       
import "../src/AttackCoinFlip.sol"; 

interface IEthernaut {
    function createLevelInstance(address _level) external payable; 
    function submitLevelInstance(address _instance) external; 
}

contract EthernautTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);

    function testLevel3_CoinFlip() public {

        vm.deal(address(this), 1 ether);
        address levelFactoryAddress = 0xA62fE5344FE62AdC1F356447B669E9E6D10abaaF;

        vm.recordLogs();
        console.log("Membuat Level 3 (CoinFlip)...");
        ethernaut.createLevelInstance(levelFactoryAddress);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        CoinFlip level = CoinFlip(levelAddr);
        
        AttackCoinFlip attacker = new AttackCoinFlip(levelAddr);

        console.log("Mulai menebak 10x berturut-turut...");

        console.log("Mulai menebak 10x berturut-turut...");

        for(uint i = 0; i < 10; i++) {
            vm.roll(block.number + 1);
            
            vm.store(levelAddr, bytes32(uint256(1)), bytes32(uint256(999999 + i)));

            attacker.cheat();
            
            console.log("Menang ke-", level.consecutiveWins());
        }

        assertEq(level.consecutiveWins(), 10);
        console.log("HACKED! 10x Win Streak.");

        console.log("Submit ke Ethernaut...");
        ethernaut.submitLevelInstance(payable(levelAddr));
    }
}