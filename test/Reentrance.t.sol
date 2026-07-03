// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Re-entrancy.sol";
import "../src/ReentranceAttack.sol";

contract ReentranceTest is Test {
    Reentrance public target;
    reentrancyattack public attacker;

    function setUp() public {
        // deploy contract target dengan 1 ETH
        target = new Reentrance{value: 1 ether}();
        
        // deploy contract penyerang
        attacker = new reentrancyattack{value: 0.1 ether}(address(target));
    }

function testAttack() public {
    assertGt(address(target).balance, 0);
    
    attacker.donate{value: 0.1 ether}();
    attacker.withdrawAttack(1.1 ether);
    
    assertEq(address(target).balance, 0);
}
}