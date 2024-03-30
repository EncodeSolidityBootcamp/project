// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

error OrderAlreadyFilled(bytes32 orderHash);

contract LimitOrderRouter is EIP712 {

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

  constructor()
  EIP712("LimitOrderRouter", "1")
  {

  }

  function fillLimitOrder(
    LimitOrder calldata order,
    bytes calldata signature
  )
  external
  returns (bytes32 orderHash) {
    // Checks

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
    IERC20(order.input.tokenAddress).safeTransferFrom(orderOwner, order.input.tokenAddress, order.input.tokenAmount);

    // Fill order

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
