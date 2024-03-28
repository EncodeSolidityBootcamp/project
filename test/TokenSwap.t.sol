// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/interfaces/ISwapRouter02.sol";
import {Test, console} from "forge-std/Test.sol";
import {TokenSwap} from "../src/TokenSwap.sol";


contract TokenSwapTest is Test {
  TokenSwap public tokenSwap;

  address constant SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  ISwapRouter02 private constant router = ISwapRouter02(SWAP_ROUTER_02);

  function setUp() public {
    tokenSwap = new TokenSwap();
  }

  function test_Swap() public {
    uint256 amountIn = 1 * 1e18;
    IERC20 weth = IERC20(WETH);

    vm.startPrank(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);
    weth.approve(address(tokenSwap), amountIn);

    tokenSwap.swapExactInputSingleHop(amountIn, 2000 * 1e18);
  }
}
