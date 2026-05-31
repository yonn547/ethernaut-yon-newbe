dalam fallbanck ini aku mencoba membaca alur logika nya dahulu lalu mendapatkan

owner memiliki 100 ether 
lalu ada modifer yang memeriksa apakah kita owner atau bukan 
kemudian ada 3 function 

1.contribute yang bisa kita panggil untuk menjadi kontribusi dalam contract ini yang hanya bisa mengirim kan 0.001 ether 
dan jika kontribusi kita pada contract ini lebih dari owner asli maka kita yang akan "menjadi owner"

2. getContribution yang membuat kita menjadi contribution

3.withdraw yang hanya bisa di gunakan oleh owner untuk menarik uang yang ada di dalam contract  lalu ada receive yang memerlukan nilai ether kita harus lebih dari 0 dan contribution >0 maka kita menjadi owner


maka aku melihat celah di situ bahwa jika dalam fuction withdraw kita dapat menjadi owner dan dapat withdraw jika kita mengirimkan dan memiliki contribution maka bisa kita eksploit dengan 
mengirim dahulu ke contract tersebut agar menjadi contribute dan lalu mengirimkan lagi tanpa memanggil function apapuun agar kita menjadi owner dan meng withdraw ether yang ada di dalam nya


## Fallback — Level 1

### Alur Logika Contract

dalam fallbanck ini aku mencoba membaca alur logika nya dahulu lalu mendapatkan

owner memiliki 100 ether 
lalu ada modifer yang memeriksa apakah kita owner atau bukan 
kemudian ada 3 function 

1.contribute yang bisa kita panggil untuk menjadi kontribusi dalam contract ini yang hanya bisa mengirim kan 0.001 ether 
dan jika kontribusi kita pada contract ini lebih dari owner asli maka kita yang akan "menjadi owner"

2. getContribution yang membuat kita menjadi contribution

3.withdraw yang hanya bisa di gunakan oleh owner untuk menarik uang yang ada di dalam contract  lalu ada receive yang memerlukan nilai ether kita harus lebih dari 0 dan contribution >0 maka kita menjadi owner




### Vulnerability
Nama: swc 106
Penjelasan: Due to missing or insufficient access controls, malicious parties can self-destruct the contract.

### Impact
penyerang dapat menngambil alih peran owner dan men drain saldo token dalam contract

### Cara Eksploit
maka aku melihat celah di situ bahwa jika dalam fuction withdraw kita dapat menjadi owner dan dapat withdraw jika kita mengirimkan dan memiliki contribution maka bisa kita eksploit dengan 
mengirim dahulu ke contract tersebut agar menjadi contribute dan lalu mengirimkan lagi tanpa memanggil function apapuun agar kita menjadi owner dan meng withdraw ether yang ada di dalam nya

### Rekomendasi Fix
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Fallback {
mapping(address => uint256) public contributions;
address public owner;

constructor() {
    owner = msg.sender;
    contributions[msg.sender] = 100 * (1 ether);
}

modifier onlyOwner() {
    require(msg.sender == owner, "YOU NOT OWNER" );
_;
}

function contribute()public payable {
    require(msg.value < 0.001 ether);
    contributions[msg.sender] += msg.value;
    if (contributions[msg.sender] > contributions[owner]) {
        owner = msg.sender;}
    
}
function getContribution() public view returns (uint256) {
    return contributions[msg.sender];
}

function withdraw() public onlyOwner {
    payable (owner).transfer(address(this).balance);
}
receive() external payable { }
}

Fix: hapus logika pengubahan owner dari receive() karena 
receive() seharusnya hanya menerima ETH, bukan mengubah 
state penting seperti ownership contract.