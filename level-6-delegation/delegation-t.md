## Delegation — Level 6

### Alur Logika Contract
pada contract ini aku belajar hal baru yaitu delegatecall yang awal nya rumit namun intinya ini adalah konsep dimana suatu contract dapat memanggil function pada contract namun yang berubah adalah storage nya 
pad contract ini aku membancanya ada 2 sontract pada satu file yang pertama contract delegate dan delegation dimana pada contract delegate memiliki function untuk mengganti owner dengan msg.sender dan contract kedua memiliki function fallback yang bisa di manfaatkan oleh penyerang

### Vulnerability
Nama: swc-112
Penjelasan:tx.oInteger Overflow and Underflow
Overflow/underflow terjadi ketika operasi aritmatika mencapai ukuran maksimum atau minimum suatu tipe. Misalnya jika suatu bilangan disimpan dalam tipe uint8, artinya bilangan tersebut disimpan dalam 8 bit bilangan tak bertanda tangan yang berkisar antara 0 hingga 2^8-1. Dalam pemrograman komputer, luapan bilangan bulat terjadi ketika operasi aritmatika mencoba membuat nilai numerik yang berada di luar rentang yang dapat direpresentasikan dengan jumlah bit tertentu – yang lebih besar dari nilai maksimum atau levbih rendah dari nilai minimum yang dapat direpresentasikan.



 
### Impact

penyerang dapat menggunakan celah delegatecall untuk memanggil function yang dapat merubah owner dengan data atau storage yang seharus nya tidak memiliki function itu

### Cara Eksploit
pada awal nya aku cukup bingung karena walaupun hanya menggunakan terminal kita harus menggunakan transaksi kosong untuk memancing fallback yang berada  di delegation kurang lebih comand console nya seperti ini:

await contract.sendTransaction({
    data: web3.eth.abi.encodeFunctionSignature("pwn()")
})


### Rekomendasi Fix
Use delegatecall dengan hati-hati dan pastikan untuk tidak pernah memanggil kontrak yang tidak tepercaya. Jika alamat target berasal dari masukan pengguna, pastikan untuk memeriksanya berdasarkan daftar putih kontrak tepercaya.
