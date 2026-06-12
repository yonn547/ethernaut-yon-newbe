## vault — Level 8

### Alur Logika Contract
cara aku membaca seperti membaca kode,terdapat password yang harus di input untuk bisa menguasai contract ini ketika kita mendapatkan password nya maka kita berhasil menaklukan level ini

### Vulnerability
Nama: SWC-136
Penjelasan:Ini adalah kesalahpahaman umum bahwa private variabel tipe tidak dapat dibaca. Bahkan jika kontrak Anda tidak dipublikasikan, penyerang dapat melihat transaksi kontrak untuk menentukan nilai yang tersimpan dalam keadaan kontrak. Oleh karena itu, penting agar data pribadi yang tidak terenkripsi tidak disimpan dalam kode kontrak atau status.

### Impact

Penyerang dapat membaca data sensitif yang disimpan sebagai 
private variable langsung dari storage blockchain, 
memungkinkan akses tidak sah ke credential atau secret 
yang seharusnya terlindungi.

### Cara Eksploit
cara mengeksploit nya cukup menggunakan console dengan meminta data mentah dari variable password dengan command

await web3.eth.getStorageAt(contract.address, INDEX)

-pada index berapa variable itu muncul
lalu membuka nya dengan password yang sudah di dapat 

await contract.unlock("hasil_bytes32_tadi")

### Rekomendasi Fix
Data pribadi apa pun harus disimpan di luar chain, atau dienkripsi dengan cermat.
atau dari ether naut menyaran kan Untuk memastikan bahwa data bersifat pribadi, data tersebut perlu dienkripsi sebelum dimasukkan ke dalam blockchain. Dalam skenario ini, kunci dekripsi tidak boleh dikirim secara on-chain, karena kemudian akan terlihat oleh siapa saja yang mencarinya. zk-SNARKs berikan cara untuk menentukan apakah seseorang memiliki parameter rahasia, tanpa harus mengungkapkan parameter tersebut.
