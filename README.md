# defi-uniswap-v4

# Course intro

- [Course intro](./notes/course_intro.md)
- [Setup](./notes/course_setup.md)

# Foundation

- [V4 vs V3](./notes/v4.md)
- [Repositories](./notes/repos.png)

# Pool manager

- [Currency](https://github.com/Uniswap/v4-core/blob/main/src/types/Currency.sol)
- Pool key and pool id
  - [PoolKey](https://github.com/Uniswap/v4-core/blob/main/src/types/PoolKey.sol)
  - [PoolId](https://github.com/Uniswap/v4-core/blob/main/src/types/PoolId.sol)
  - [Example](./foundry/src/examples/pool_id.sol)
  - [Dune - How to get PoolKey from PoolId](https://dune.com/queries/5671549?category=decoded_project&namespace=uniswap_v4&blockchain=ethereum&contract=PoolManager&blockchains=ethereum&id=uniswap_v4_ethereum.poolmanager_evt_initialize)
- Lock
  - [`Lock`](https://github.com/Uniswap/v4-core/blob/main/src/libraries/Lock.sol)
  - [`unlock`](https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/PoolManager.sol#L104-L114)
  - [`NonzeroDeltaCount`](https://github.com/Uniswap/v4-core/blob/main/src/libraries/NonzeroDeltaCount.sol)
- [Transient storage](./foundry/src/examples/transient_storage.sol)
  - [`NonzeroDeltaCount`](https://github.com/Uniswap/v4-core/blob/main/src/libraries/NonzeroDeltaCount.sol)
  - [`_accountDelta`](https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/PoolManager.sol#L368-L378)
  - [Account delta](./notes/account_delta.png)
- [Currency reserves](https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/PoolManager.sol#L279-L288)
- [Swap contract calls](./notes/swap.png)
  - [ ] [`BalanceDelta`](https://github.com/Uniswap/v4-core/blob/main/src/types/BalanceDelta.sol)
  - [ ] [Swap Foundry example](./foundry/src/examples/swap.sol)
- [ ] Reading data
  - [`extsload`](https://github.com/Uniswap/v4-core/blob/main/src/Extsload.sol)
  - [`exttload`](https://github.com/Uniswap/v4-core/blob/main/src/Exttload.sol)
  - [`StateLibrary`](https://github.com/Uniswap/v4-core/blob/main/src/libraries/StateLibrary.sol)
    - [`StateView`](https://github.com/Uniswap/v4-periphery/blob/main/src/lens/StateView.sol)
  - [`TransientStateLibrary`](https://github.com/Uniswap/v4-core/blob/main/src/libraries/TransientStateLibrary.sol)
    - [`DeltaResolver`](https://github.com/Uniswap/v4-periphery/blob/main/src/base/DeltaResolver.sol)
  - [ ] [Exercise - get currency delta](./foundry/exercises/reader.md)
- [ ] [Application - swap router](./foundry/exercises/swap_router.md)

# Resources

- [Uniswap V4](https://v4.uniswap.org/)
- [Uniswap V4 pools](https://app.uniswap.org/explore/pools)
- [Uniswap V4 docs](https://docs.uniswap.org/contracts/v4/overview)
- [GitHub - v4-core](https://github.com/Uniswap/v4-core)
- [GitHub - v4-periphery](https://github.com/Uniswap/v4-periphery)
- [GitHub - universal-router](https://github.com/Uniswap/universal-router)
- [GitHub - v4-template](https://github.com/uniswapfoundation/v4-template)
- [YouTube - Uniswap v4 on Unichain](https://www.youtube.com/watch?v=ZisqLqbakfM)
- [Cyfrin - Uniswap V4 Swap: Deep Dive Into Execution and Accounting](https://www.cyfrin.io/blog/uniswap-v4-swap-deep-dive-into-execution-and-accounting)
- [PoolManager - storage layout](https://www.evm.codes/contract?address=0x000000000004444c5dc75cb358380d2e3de08a90)
- [Dune - How to get PoolKey from PoolId](https://dune.com/queries/5671549?category=decoded_project&namespace=uniswap_v4&blockchain=ethereum&contract=PoolManager&blockchains=ethereum&id=uniswap_v4_ethereum.poolmanager_evt_initialize)
- [Bunni](https://bunni.xyz/)
