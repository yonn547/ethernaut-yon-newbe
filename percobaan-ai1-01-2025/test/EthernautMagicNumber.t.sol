// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

interface IMagicNum {
    function setSolver(address _solver) external;
}

contract EthernautMagicNumTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x2132C7bc11De7A90B87375f282d36100a29f97a9;

    function testLevel18_MagicNumber() public {
        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        vm.recordLogs(); 

        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        console.log("Level Address:", levelAddr);

        bytes memory runtimeCode = hex"602a60505260206050f3";

        bytes memory creationCode = hex"600a600c600039600a6000f3";
        
        bytes memory bytecode = abi.encodePacked(creationCode, runtimeCode);

        address solver;
        assembly {
            solver := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        
        require(solver != address(0), "Deploy gagal!");
        console.log("Solver Address:", solver);
        
        IMagicNum(levelAddr).setSolver(solver);
        
        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }        
    
    
}