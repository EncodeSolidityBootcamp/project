// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenSwap} from "../src/TokenSwap.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount)
        external
        returns (bool);
}

contract TokenSwapTest is Test {
    TokenSwap public tokenSwap;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    ISwapRouter02 private constant router = ISwapRouter02(SWAP_ROUTER_02);

    function setUp() public {
        tokenSwap = new TokenSwap();
    }

    function test_Swap() public {
        vm.startPrank(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);

        uint256 amountIn = 1 * 1e18;


        IERC20 weth = IERC20(WETH);
        weth.approve(address(router), amountIn);

        tokenSwap.swapExactInputSingleHop(amountIn, 2000 * 1e18);
    }
}
