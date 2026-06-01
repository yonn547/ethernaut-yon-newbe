## Fallout — Level 2

### Alur Logika Contract

dalam contract fallout iniaku membacanya dan mendapatkan seperti level sebelum nya namun ada beberapa kejanggalan seperti constructor nya yang di /*
apa itu constructor? dose yang berjalan hanya 1 kali pada saat deploy

lalu aku juga menemukan typo fada function fal1out maka aku beraasumsi ini janggal dan setelah itu contract ini juga memiliki function yang lain seperti melihat saldo dkk seperti fallback



### Vulnerability
Nama: swc-118
Penjelasan:Incorrect Constructor Name
 dan ternyata aku baru tau kalau jika nama function yang sama dengan contract pada pragma versi < 0.4.0 itu tetap di anggap constructor 
### Impact
penyerang dapat menngambil alih peran owner dan men drain saldo token dalam contract

### Cara Eksploit
maka aku melihat celah di situ bahwa jika dalam fuction fal1out bukan lah constructtor maka dapat dipanggil siapa saja maka akan menjadi owner maka penyerang dapat menjadi owner dan mendrain contrct tersebut

### Rekomendasi Fix
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v0.6.0/contracts/math/SafeMath.sol";

contract Fallout {
    using SafeMath for uint256;

    mapping (address => uint256 ) allocations;
    address payable public owner;

    constructor() public payable {
        owner = msg.sender;
        allocations[owner] = msg.value;
    }}
    fix: mengubah tipo fallout dan memberikan constructor yang jelas agar kode berjalan 1 kali saat mendeploy saja 