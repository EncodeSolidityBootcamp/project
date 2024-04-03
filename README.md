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


Here is the log of successful tests launch:

```
forge test --fork-url=$RPC_URL --fork-block-number 19554015                                                   
[⠒] Compiling...
[⠒] Compiling 2 files with 0.8.24
[⠑] Solc 0.8.24 finished in 4.01s
Compiler run successful!

Ran 1 test for test/TokenSwap.t.sol:TokenSwapTest
[PASS] test_Swap() (gas: 140190)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 7.81ms (1.05ms CPU time)

Ran 7 tests for test/LimitOrderRouter.t.sol:LimitOrderRouterTest
[PASS] test_Create2Factory_succeeds() (gas: 564419)
[PASS] test_EIP1271_EIP6492_succeeds() (gas: 726504)
[PASS] test_Signature() (gas: 15565)
[PASS] test_swap_reverts_amount() (gas: 182559)
[PASS] test_swap_reverts_cancelled() (gas: 103104)
[PASS] test_swap_reverts_expired() (gas: 70294)
[PASS] test_swap_succeeds() (gas: 182420)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 10.29ms (16.54ms CPU time)

Ran 2 test suites in 371.84ms (18.09ms CPU time): 8 tests passed, 0 failed, 0 skipped (8 total tests)


```
