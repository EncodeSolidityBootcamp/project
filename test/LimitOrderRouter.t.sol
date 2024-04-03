// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LimitOrderRouter.sol";
import "./MockERC20.sol";
import "./Create2Factory.sol";
import {MockSmartContractWallet} from "./MockSmartContractWallet.sol";
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

  address constant SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
  LimitOrderRouter immutable ROUTER = new LimitOrderRouter(address(this), SWAP_ROUTER_02);
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

    console.log("L");
    console.log(signature.length);

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

  function test_swap_reverts_amount() public {
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
    ROUTER.fillLimitOrder(order, signature);

    uint256 usdcBalanceDiff = IERC20(DAI).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 0);
  }

  function test_swap_reverts_expired() public {
    // construct order with default test parameters
    LimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();
    order.expiry = block.timestamp - 1;

    // sign order
    bytes memory signature = getOrderSignature(order);

    vm.prank(WETH_OWNER);
    IERC20(order.input.tokenAddress).transfer(SIGNER_ADDRESS, order.input.tokenAmount);

    vm.prank(SIGNER_ADDRESS);
    IERC20(order.input.tokenAddress).approve(address(ROUTER), order.input.tokenAmount);

    vm.expectRevert(abi.encodeWithSelector(OrderExpired.selector, order.expiry, block.timestamp));
    ROUTER.fillLimitOrder(order, signature);
  }

  function test_swap_reverts_cancelled() public {
    // construct order with default test parameters
    LimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    bytes memory signature = getOrderSignature(order);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);
    vm.prank(SIGNER_ADDRESS);
    ROUTER.cancelLimitOrder(orderHash);

    vm.prank(WETH_OWNER);
    IERC20(order.input.tokenAddress).transfer(SIGNER_ADDRESS, order.input.tokenAmount);

    vm.prank(SIGNER_ADDRESS);
    IERC20(order.input.tokenAddress).approve(address(ROUTER), order.input.tokenAmount);

    vm.expectRevert(abi.encodeWithSelector(OrderAlreadyFilledOrCancelled.selector, orderHash));
    ROUTER.fillLimitOrder(order, signature);
  }


  /// Verifies CREATE2 smart contract wallet arguments via deployment
  function test_Create2Factory_succeeds() public {
    Create2Factory factory = new Create2Factory();
    bytes32 salt = keccak256("SOME_RANDOM_SALT");

    LimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();
    bytes32 orderHash = ROUTER.getLimitOrderHash(order);
    // Prepare the bytecode of SimpleContract with constructor argument
    bytes memory bytecode = type(MockSmartContractWallet).creationCode;
    bytes memory signature = getOrderSignature(order);
    bytes memory bytecodeWithArgs = abi.encodePacked(bytecode, abi.encode(orderHash, signature));

    // Deploy SimpleContract using Create2Factory
    address deployedAddress = factory.deploy(salt, bytecodeWithArgs);

    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 EIP1271_MAGICVALUE = 0x1626ba7e;

    assertTrue(MockSmartContractWallet(deployedAddress).isValidSignature(orderHash, signature) == EIP1271_MAGICVALUE);

    // Optionally, compute and assert the expected address
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecodeWithArgs)));
    address expectedAddress = address(uint160(uint(hash)));
    assertEq(deployedAddress, expectedAddress);
  }

  function prepare_EIP6492_deployment(bytes memory expectedOrderSignature, bytes memory actualOrderSignature)
  public
  returns (bytes memory eip6492sig, address expectedAddress) {
    Create2Factory factory = new Create2Factory();
    bytes32 salt = keccak256("SOME_RANDOM_SALT");

    LimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();
    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // Prepare the bytecode of MockSmartContractWallet with constructor argument
    bytes memory bytecode = type(MockSmartContractWallet).creationCode;
    bytes memory bytecodeWithArgs = abi.encodePacked(bytecode, abi.encode(orderHash, expectedOrderSignature));

    // prepare factory calldata
    bytes memory factoryCalldata = abi.encodeWithSelector(
      factory.deploy.selector,
      salt,
      bytecodeWithArgs
    );

    // Compute the smart contract wallet expected address
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecodeWithArgs)));
    expectedAddress = address(uint160(uint(hash)));

    // As per ERC-6492: create2Factory, factoryCalldata, originalSig
    // The address, bytes, and bytes parameters to be encoded
    bytes memory encodedData = abi.encode(address(factory), factoryCalldata, actualOrderSignature);

    // The magic suffix to be appended
    bytes memory magicSuffix = hex"6492649264926492649264926492649264926492649264926492649264926492";

    // Concatenate the encodedData with the magicSuffix
    eip6492sig = bytes.concat(encodedData, magicSuffix);
  }

  function test_EIP1271_EIP6492_succeeds() public {
    LimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();
    //bytes32 orderHash = ROUTER.getLimitOrderHash(order);
    bytes memory signature = getOrderSignature(order);

    // Actual order signature is equal to expected
    (bytes memory eip6492sig, address expectedSmartWalletAddress) = prepare_EIP6492_deployment(signature, signature);

    console.log(expectedSmartWalletAddress);
    // Prepend the signature with the smart contract wallet address
    bytes memory encodedSignature = abi.encodePacked(expectedSmartWalletAddress, eip6492sig);

    vm.prank(WETH_OWNER);
    IERC20(order.input.tokenAddress).transfer(expectedSmartWalletAddress, order.input.tokenAmount);

    vm.prank(expectedSmartWalletAddress);
    IERC20(order.input.tokenAddress).approve(address(ROUTER), order.input.tokenAmount);

    ROUTER.fillLimitOrder(order, encodedSignature);
  }
}
