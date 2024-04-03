## Uniswap Limit Order

LimitOrderRouter offers a possibility to create a limit order, sign it offchain and then execute by the once the price reaches the expected level.
The user can set the order expiration timestamp and the minimum amount of output tokens.
Besides placing such order on behalf of a user with an External Owned Account (EIP-712), the LimitOrderRouter allows placing orders on behalf of a Smart Contract Wallet (EIP-12721) and counterfactual wallets (EIP-6492), which are not yet deployed.

## Usage

### Build

```shell
forge build
```

### Test

```shell
export RPC_URL=
forge test --fork-url=$RPC_URL --fork-block-number 19554015
```

