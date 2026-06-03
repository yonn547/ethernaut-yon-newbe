## token — Level 5

### Alur Logika Contract
contract ini sepertinya sangat sederhana hanya memiliki function transfer dan balanceOf untuk mengecek saldo
namun ada yang membuat perhatian ku karena setelah ku coba rewrite tidak dapat di compile karena logika nya keliru pada solidity versi 0.6.0 dapat menyebabkan celah underflow

### Vulnerability
Nama: swc-101
Penjelasan:tx.oInteger Overflow and Underflow
Overflow/underflow terjadi ketika operasi aritmatika mencapai ukuran maksimum atau minimum suatu tipe. Misalnya jika suatu bilangan disimpan dalam tipe uint8, artinya bilangan tersebut disimpan dalam 8 bit bilangan tak bertanda tangan yang berkisar antara 0 hingga 2^8-1. Dalam pemrograman komputer, luapan bilangan bulat terjadi ketika operasi aritmatika mencoba membuat nilai numerik yang berada di luar rentang yang dapat direpresentasikan dengan jumlah bit tertentu – yang lebih besar dari nilai maksimum atau levbih rendah dari nilai minimum yang dapat direpresentasikan.



 
### Impact

dalam contract token kali ini aku mempelajari uint256 pada versi solidity 0.6.0 akan membuka celah underflow yang bisa di manfaatkan penyerang maka ketika hanya memiliki 20 token dan mencoba mengirim 21 ke contract maka contract menginputkan angka yang sangat besar dan saldo penyerang akan sangat banyak

### Cara Eksploit
dalam exploit level ini tidak perlu contracr penyerang terpisah cukup mengirimkan 21 ke conract maka kita akan memiliki saldo yang sangat banyak karena memanfaatkan celah underflow nya dengan command terminal
:
await contract.transfer("0x0000000000000000000000000000000000000000", 21)

dan untuk mengecek saldo kita :
(await contract.balanceOf(player)).toString()


### Rekomendasi Fix
Disarankan untuk menggunakan perpustakaan matematika aman yang telah diperiksa untuk operasi aritmatika secara konsisten di seluruh sistem kontrak pintar.
// Solidity >= 0.8.0 — built-in overflow protection
// Tidak perlu SafeMath lagi karena sudah otomatis revert

// Atau untuk Solidity 0.6.0 — gunakan SafeMath:
using SafeMath for uint256;

function transfer(address _to, uint256 _value) public returns (bool) {
    require(balances[msg.sender] >= _value, "Insufficient balance");
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    return true;
}
Solidity versi 0.8.0 ke atas tidak memerlukan library SafeMath karena fitur pemeriksaan aritmatika (Arithmetic Checking) sudah ditanamkan langsung ke dalam compiler bawaannya .