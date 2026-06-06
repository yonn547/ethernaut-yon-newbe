## Delegation — Level 6

### Alur Logika Contract
pada contract ini aku belajar hal baru yaitu delegatecall yang awal nya rumit namun intinya ini adalah konsep dimana suatu contract dapat memanggil function pada contract namun yang berubah adalah storage nya 
pad contract ini aku membancanya ada 2 sontract pada satu file yang pertama contract delegate dan delegation dimana pada contract delegate memiliki function untuk mengganti owner dengan msg.sender dan contract kedua memiliki function fallback yang bisa di manfaatkan oleh penyerang

### Vulnerability
Nama: swc-112
Penjelasan:Penggunaan delegatecall ke contract eksternal yang 
tidak terpercaya memungkinkan contract target mengeksekusi 
code arbitrary dalam konteks storage contract pemanggil. 
Ini bisa dimanfaatkan untuk mengubah state penting seperti 
owner tanpa otorisasi.

 
### Impact

penyerang dapat menggunakan celah delegatecall untuk memanggil function yang dapat merubah owner dengan data atau storage yang seharus nya tidak memiliki function itu

### Cara Eksploit
pada awal nya aku cukup bingung karena walaupun hanya menggunakan terminal kita harus menggunakan transaksi kosong untuk memancing fallback yang berada  di delegation kurang lebih comand console nya seperti ini:

await contract.sendTransaction({
    data: web3.eth.abi.encodeFunctionSignature("pwn()")
})


### Rekomendasi Fix
Use delegatecall dengan hati-hati dan pastikan untuk tidak pernah memanggil kontrak yang tidak tepercaya. Jika alamat target berasal dari masukan pengguna, pastikan untuk memeriksanya berdasarkan daftar putih kontrak tepercaya.
