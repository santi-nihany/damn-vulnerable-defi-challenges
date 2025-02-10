// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract Approver {
    function approveTokens(ERC20 token, address attacker, uint256 amount) public {
        token.approve(attacker, amount);
    }
}
