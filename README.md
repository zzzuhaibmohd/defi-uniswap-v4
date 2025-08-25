# defi-uniswap-v4

# Course intro

- [ ] Prerequisites
  - Solidity
    - Advanced Solidity to understand how to read from Uniswap V4 (`extsload`)
    - User defined types
  - Uniswap V3
- [ ] Project setup
  - v4 template?

# Foundation

- [ ] V4 vs V3
  - Hooks
  - Dynamic fees
  - Singleton
    - PoolManager `mapping(PoolId id => Pool.State) internal _pools`
  - Flash accounting
    - No fee on flash loans
  - ERC6909 TODO: how is it used?
    - traders
    - liquidity providers
- [ ] Repositories
      TODO: excalidraw

  ```
   universal router   ->    v4 router    ->  v4-core
  (universal-router)     (v4-periphery)     (v4-core)
  ```

  ```
    - UniversalRouter.execute
      - dispatch
        - V4Router._executeActions
          - PoolManager.unlock
            - V4Router.unlockCallback
              - _unlockCallback
                  - _executeActionsWithoutUnlock
                      - _handleActions
  ```

# Pool manager

TODO: add Uni v4 links?

- [ ] Goal (PoolManager -> build a swap router contract)
- [ ] Currency = address - (ERC20 token + native token (ETH))
  - currency0 and currency1
  - ETH = address 0
  - ERC20 = token address
- [ ] [Pool key and pool id](./foundry/src/examples/pool_id.sol)
  - User defined value types
  - [ ] How to get Pool key from Uniswap V4 UI and Dune
- [ ] Lock
  - `swap` -> `onlyWhenUnlocked`, `Lock`, `unlock`, `unlockCallback`, `NonzeroDeltaCount`
    - TODO: excalidraw?
- [ ] [Transient storage](./foundry/src/examples/transient_storage.sol)
  - `unlock`, `Lock`, `NonzeroDeltaCount`
  - Difference from state variables
  - `Lock`, account delta, `CurrencyDelta`, `CurrencyReserve`, `NonzeroDeltaCount`
  - [ ] `NonzeroDeltaCount`
    - `_accountDelta`
      - `lib/CurrencyDelta.applyDelta`
        - `next`
    - [ ] [Account delta](./notes/account_delta.png)
      - `_accountDelta`
      - `target`
      - take -> + (claim)
      - settle -> - (owe)
      - excalidraw
- [ ] Currency reserves
  - `settle` -> `sync`
- [ ] [Swap contract calls](./notes/swap.png)
  - Example: unlock -> swap -> sync + pay + settle -> take
    - Order of execution
  - [ ] Balance delta
  - [ ] [Swap Foundry example](./foundry/src/examples/swap.sol)
- [ ] Read data
  - [`extsload`](https://github.com/Uniswap/v4-core/blob/main/src/Extsload.sol)
  - [`exttload`](https://github.com/Uniswap/v4-core/blob/main/src/Exttload.sol)
  - [`StateLibrary`](https://github.com/Uniswap/v4-core/blob/main/src/libraries/StateLibrary.sol)
    - [`StateView`](https://github.com/Uniswap/v4-periphery/blob/main/src/lens/StateView.sol)
  - [`TransientStateLibrary`](https://github.com/Uniswap/v4-core/blob/main/src/libraries/TransientStateLibrary.sol)
    - [`DeltaResolver`](https://github.com/Uniswap/v4-periphery/blob/main/src/base/DeltaResolver.sol)
  - [ ] [Exercise - get currency delta](./foundry/exercises/reader.md)
- [ ] [Application - swap router](./foundry/exercises/swap_router.md)

- [ ] TODO - code: Hooks
  - hook deployment + flags
    - `Hooks.hasPermission`
    - https://docs.uniswap.org/contracts/v4/guides/hooks/hook-deployment

# Resources

[Uniswap V4](https://v4.uniswap.org/)
[Uniswap V4 pools](https://app.uniswap.org/explore/pools)
[Uniswap V4 docs](https://docs.uniswap.org/contracts/v4/overview)
[GitHub - v4-core](https://github.com/Uniswap/v4-core)
[GitHub - v4-periphery](https://github.com/Uniswap/v4-periphery)
[GitHub - universal-router](https://github.com/Uniswap/universal-router)
[GitHub - v4-template](https://github.com/uniswapfoundation/v4-template)
[YouTube - Uniswap v4 on Unichain](https://www.youtube.com/watch?v=ZisqLqbakfM)
[Cyfrin - Uniswap V4 Swap: Deep Dive Into Execution and Accounting](https://www.cyfrin.io/blog/uniswap-v4-swap-deep-dive-into-execution-and-accounting)
[PoolManager - storage layout](https://www.evm.codes/contract?address=0x000000000004444c5dc75cb358380d2e3de08a90)
[Dune - How to get PoolKey from PoolId](https://dune.com/queries/5671549?category=decoded_project&namespace=uniswap_v4&blockchain=ethereum&contract=PoolManager&blockchains=ethereum&id=uniswap_v4_ethereum.poolmanager_evt_initialize)
[Bunni](https://bunni.xyz/)
