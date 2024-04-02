// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISwapRouter02.sol";

using SafeERC20 for IERC20;

error OrderAlreadyFilled(bytes32 orderHash);
error OrderExpired(uint256 orderExpiry, uint256 currentTimestamp);
error SlippageLimitExceeded(address tokenAddress, uint256 expectedAmount, uint256 actualAmount);

contract LimitOrderRouter is EIP712, Ownable {

  address immutable UNISWAP_ROUTER;

  event LimitOrderFilled(
    bytes32 indexed orderHash,
    address indexed orderOwner,
    address inputToken,
    address outputToken,
    uint256 orderInputAmount,
    uint256 orderOutputAmount
  );

  struct TokenInfo {
    address tokenAddress;
    // Minimum token amount for output
    uint256 tokenAmount;
  }

  struct LimitOrder {
    TokenInfo input;
    TokenInfo output;
    uint256 expiry;
  }

  mapping(address orderOwner => mapping(bytes32 orderHash => uint256 filledAmount)) public limitOrders;

  bytes32 public constant TOKEN_INFO_TYPEHASH = keccak256(
    "TokenInfo("
      "address tokenAddress,"
      "uint256 tokenAmount"
    ")"
  );

  bytes32 public constant LIMIT_ORDER_TYPEHASH = keccak256(
    "LimitOrder("
      "TokenInfo input,"
      "TokenInfo output,"
      "uint256 expiry"
    ")"
    "TokenInfo("
      "address tokenAddress,"
      "uint256 tokenAmount"
    ")"
  );

  constructor(address initialOwner, address uniswapRouter)
  EIP712("LimitOrderRouter", "1")
  Ownable(initialOwner)
  {
    UNISWAP_ROUTER = uniswapRouter;
  }

  function fillLimitOrder(
    LimitOrder calldata order,
    bytes calldata signature
  )
  external
  returns (bytes32 orderHash) {
    // Checks
    if (order.expiry < block.timestamp) {
      revert OrderExpired(order.expiry, block.timestamp);
    }

    // Get order hash
    orderHash = getLimitOrderHash(order);

    // Recover the orderOwner and validate signature
    address orderOwner = ECDSA.recover(orderHash, signature);

    // Get order filled amount
    uint256 filledAmount = limitOrders[orderOwner][orderHash];

    if (filledAmount != 0) {
      revert OrderAlreadyFilled(orderHash);
    }

    // Transfer tokens from order owner
    IERC20(order.input.tokenAddress).safeTransferFrom(orderOwner, address(this), order.input.tokenAmount);
    IERC20(order.input.tokenAddress).approve(address(UNISWAP_ROUTER), order.input.tokenAmount);

    // Fill order
    ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
      .ExactInputSingleParams({
      tokenIn: order.input.tokenAddress,
      tokenOut: order.output.tokenAddress,
      fee: 3000,
      recipient: orderOwner,
      amountIn: order.input.tokenAmount,
      amountOutMinimum: order.output.tokenAmount,
      sqrtPriceLimitX96: 0
    });

    uint256 amountOut = ISwapRouter02(UNISWAP_ROUTER).exactInputSingle(params);

    // Transfer tokens to the order owner - don't need, as Uniswap sends to the orderOwner
    // IERC20(order.output.tokenAddress).safeTransfer(orderOwner, amountOut);

    // emit event
    emit LimitOrderFilled(
      orderHash,
      orderOwner,
      order.input.tokenAddress,
      order.output.tokenAddress,
      order.input.tokenAmount,
      amountOut
    );
  }

  function swapExactInput(TokenInfo calldata input, TokenInfo calldata output)
  internal
  returns (uint256 amountOut)
  {
    //IERC20(input.tokenAddress).transferFrom(msg.sender, address(this), input.tokenAmount);
    //IERC20(input.tokenAddress).approve(address(UNISWAP_ROUTER), input.tokenAmount);

    ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
      .ExactInputSingleParams({
      tokenIn: input.tokenAddress,
      tokenOut: output.tokenAddress,
      fee: 3000,
      recipient: msg.sender,
      amountIn: input.tokenAmount,
      amountOutMinimum: output.tokenAmount,
      sqrtPriceLimitX96: 0
    });

    return ISwapRouter02(UNISWAP_ROUTER).exactInputSingle(params);
  }

  function getLimitOrderHash(LimitOrder calldata order)
  public
  view
  returns (bytes32 hash)
  {
    return _hashTypedDataV4(keccak256(encodeLimitOrder(order)));
  }

  function encodeTokenInfo(
    TokenInfo calldata tokenInfo
  )
  public
  pure
  returns (bytes memory)
  {
    return abi.encode(TOKEN_INFO_TYPEHASH, tokenInfo.tokenAddress, tokenInfo.tokenAmount);
  }

  function encodeLimitOrder(
    LimitOrder calldata order
  )
  public
  pure
  returns (bytes memory)
  {
    return
      abi.encode(
      LIMIT_ORDER_TYPEHASH,
      keccak256(encodeTokenInfo(order.input)),
      keccak256(encodeTokenInfo(order.output)),
      order.expiry
    );
  }
}
