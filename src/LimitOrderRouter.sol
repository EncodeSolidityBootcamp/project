// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

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
  {
    // Checks

    // Get order hash

    // Recover the orderOwner and validate signature

    // Get order filled amount

    // Transfer tokens from order owner

    // Fill order
  }
}
