// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LimitOrderRouter.sol";
import "./MockERC20.sol";
import "forge-std/console.sol";

contract LimitOrderRouterTest is Test {

  LimitOrderRouter immutable ROUTER = new LimitOrderRouter();
  address immutable USDC = address(new MockERC20("USDC"));
  address immutable DAI = address(new MockERC20("DAI"));

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
    address inputToken = DAI;
    uint256 inputAmount = 2001 * 1e18;

    address outputToken = USDC;
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
    console.log("signer_pk", SIGNER_PK);
    console.log("signer_address", SIGNER_ADDRESS);
    console.log("orderHash");
    console.logBytes32(orderHash);
    console.log("signature");
    console.logBytes(abi.encodePacked(r, s, v));

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

  function test_Signature() public {
    // construct order with default test parameters
    LimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    bytes memory signature = getOrderSignature(order);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    address recoveredAddress = ECDSA.recover(orderHash, signature);
    assertTrue(SIGNER_ADDRESS == recoveredAddress);
  }
}
