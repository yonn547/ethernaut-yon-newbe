// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IForta {
    function setDetectionBot(address detectionBotAddress) external;
    function notify(address user, bytes calldata msgData) external;
    function raiseAlert(address user) external;
}

interface ICryptoVault {
    function sweepToken(address token) external;
}

contract SatpamBot {
    address private cryptoVault;

    constructor(address _cryptoVault) {
        cryptoVault = _cryptoVault;
    }

    function handleTransaction(address user, bytes calldata msgData) external {
        
        
        address origSender;
        assembly {
            origSender := calldataload(add(msgData.offset, 68))
        }

        if (origSender == cryptoVault) {
            IForta(msg.sender).raiseAlert(user);
        }
    }
}

contract DoubleEntryPointTest is Test {
    address levelInstance = 0xcfac150599aA709A1C3CAa112658165E0c87488c; 

    function testLevel26_DoubleEntryPoint() public {

        (bool success, bytes memory data) = levelInstance.call(abi.encodeWithSignature("cryptoVault()"));
        address vaultAddr = abi.decode(data, (address));
        console.log("CryptoVault Address:", vaultAddr);

        (success, data) = levelInstance.call(abi.encodeWithSignature("forta()"));
        address fortaAddr = abi.decode(data, (address));
        console.log("Forta Address:", fortaAddr);

        vm.startPrank(tx.origin); // Gunakan wallet kamu

        SatpamBot bot = new SatpamBot(vaultAddr);
        console.log("SatpamBot Deployed at:", address(bot));

        IForta(fortaAddr).setDetectionBot(address(bot));
        console.log("SatpamBot Registered!");

        vm.stopPrank();
    }
}