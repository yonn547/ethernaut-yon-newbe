## Privacy — Level 12

### Alur Logika Contract
alur logika contract ini cukup simple karena memiliki 1 function utama yaitu unlock yang juga memiliki 1 constructor namun memiliki bebrapa tipe data yang di pakai yang di simpan dan cara membukanya adalah dengan data yang tersimpadn di contract itu sendiri pada data[2] dan untuk menemukan data [2] kita perlu mencari slot nya di mana 
untuk menemukan data[2] kita perlu memahami storage slot packing:
- Slot 0: locked (bool, 1 byte)
- Slot 1: ID (uint256, 32 bytes)
- Slot 2: flattening + denomination + awkwardness (digabung karena kecil)
- Slot 3: data[0]
- Slot 4: data[1]
- Slot 5: data[2] ← target kita

### Vulnerability
Nama: SWC-136
Penjelasan: :Ini adalah kesalahpahaman umum bahwa private variabel tipe tidak dapat dibaca. Bahkan jika kontrak Anda tidak dipublikasikan, penyerang dapat melihat transaksi kontrak untuk menentukan nilai yang tersimpan dalam keadaan kontrak. Oleh karena itu, penting agar data pribadi yang tidak terenkripsi tidak disimpan dalam kode kontrak atau status.


### Impact
Penyerang dapat membaca data sensitif yang disimpan sebagai 
private variable langsung dari storage blockchain, 
memungkinkan akses tidak sah ke credential atau secret 
yang seharusnya terlindungi.

### Cara Eksploit
hampir sama seperti level vault yaitu membaca data yang berada di dalam sc dengan consol namun dengan hail bytes16 bukan 32 seperti biasanya dengan command

// 1. Simpan nilai hexadecimal utuh yang didapat dari slot 5
let nilaiHex = await web3.eth.getStorageAt(instance, 5);

// 2. Ambil 16 bytes pertama (indeks 0 sampai 34)
let bytes16 = nilaiHex.slice(0, 34);

// 3. Tampilkan hasilnya
bytes16;


### Rekomendasi Fix
Data pribadi apa pun harus disimpan di luar chain, atau dienkripsi dengan cermat.
atau dari ether naut menyaran kan Untuk memastikan bahwa data bersifat pribadi, data tersebut perlu dienkripsi sebelum dimasukkan ke dalam blockchain. Dalam skenario ini, kunci dekripsi tidak boleh dikirim secara on-chain, karena kemudian akan terlihat oleh siapa saja yang mencarinya. zk-SNARKs berikan cara untuk menentukan apakah seseorang memiliki parameter rahasia, tanpa harus mengungkapkan parameter tersebut.
