// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LimitOrderRouter.sol";
import "./MockERC20.sol";
import "forge-std/console.sol";

contract LimitOrderRouterTest is Test {

  event LimitOrderFilled(
    bytes32 indexed orderHash,
    address indexed orderOwner,
    address inputToken,
    address outputToken,
    uint256 orderInputAmount,
    uint256 orderOutputAmount
  );

  LimitOrderRouter immutable ROUTER = new LimitOrderRouter();
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address constant WETH_OWNER = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;

  uint256 constant SIGNER_PK = 1;
  address immutable SIGNER_ADDRESS = vm.addr(SIGNER_PK);


  function createDefaultLimitOrder()
  public
  view
  returns (
    LimitOrderRouter.LimitOrder memory order
  )
  {
    // default test parameters
    address inputToken = WETH;
    uint256 inputAmount = 1 * 1e18;

    address outputToken = DAI;
    uint256 outputAmount = 2001 * 1e6;

    // create default limit order
    order = LimitOrderRouter.LimitOrder({
      input: LimitOrderRouter.TokenInfo(inputToken, inputAmount),
      output: LimitOrderRouter.TokenInfo(outputToken, outputAmount),
      expiry: block.timestamp + 86400
    });
  }

  function getOrderSignature(
    LimitOrderRouter.LimitOrder memory order
  )
  public
  view
  returns (
    bytes memory signature
  ) {
    // get order hash
    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // get signature
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, orderHash);

    // combine signature components
    signature = abi.encodePacked(r, s, v);
  }

  function mintToken(address tokenAddress, uint256 tokenAmount) public {
    // mint tokens to account
    MockERC20(tokenAddress).faucet(SIGNER_ADDRESS, tokenAmount);

    // approve spend
    vm.prank(SIGNER_ADDRESS);
    IERC20(tokenAddress).approve(address(ROUTER), tokenAmount);
  }

  function test_Signature() public view {
    // construct order with default test parameters
    LimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    bytes memory signature = getOrderSignature(order);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    address recoveredAddress = ECDSA.recover(orderHash, signature);
    assertTrue(SIGNER_ADDRESS == recoveredAddress);
  }

  function test_swap_succeeds() public {
    // construct order with default test parameters
    LimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    bytes memory signature = getOrderSignature(order);

    vm.prank(WETH_OWNER);
    IERC20(order.input.tokenAddress).transfer(SIGNER_ADDRESS, order.input.tokenAmount);

    vm.prank(SIGNER_ADDRESS);
    IERC20(order.input.tokenAddress).approve(address(ROUTER), order.input.tokenAmount);

    uint256 usdcBalanceBefore = IERC20(DAI).balanceOf(SIGNER_ADDRESS);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      ROUTER.getLimitOrderHash(order),
      SIGNER_ADDRESS,
      WETH,
      DAI,
      order.input.tokenAmount,
      3604079859440036233885
    );

    // run test
    ROUTER.fillLimitOrder(order, signature);

    uint256 usdcBalanceDiff = IERC20(DAI).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 3604079859440036233885);
  }

  function test_swap_reverts() public {
    // construct order with default test parameters
    LimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();
    order.output.tokenAmount = 4000 * 1e18;

    // sign order
    bytes memory signature = getOrderSignature(order);

    vm.prank(WETH_OWNER);
    IERC20(order.input.tokenAddress).transfer(SIGNER_ADDRESS, order.input.tokenAmount);

    vm.prank(SIGNER_ADDRESS);
    IERC20(order.input.tokenAddress).approve(address(ROUTER), order.input.tokenAmount);

    uint256 usdcBalanceBefore = IERC20(DAI).balanceOf(SIGNER_ADDRESS);


    vm.expectRevert("Too little received");
    // run test
    ROUTER.fillLimitOrder(order, signature);

    uint256 usdcBalanceDiff = IERC20(DAI).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 0);
  }
}
