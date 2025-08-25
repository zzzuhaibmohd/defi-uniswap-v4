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

- [ ] Goal (PoolManager -> RYO router)
- [ ] Currency = address - (ERC20 token + native token (ETH))
  - currency0 and currency1
  - ETH = address 0
  - ERC20 = token address
- [ ] Pool key and pool id
  - Uniswap V4 UI -> Dune

- [ ] Lock
  - `swap` -> `onlyWhenUnlocked`, `Lock`, `unlock`, `unlockCallback`, `NonzeroDeltaCount`
    - TODO: excalidraw
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
- [ ] Balance delta
- [ ] Swap
  - example: swap -> sync -> pay + settle -> take
  - Currency reserves
  - foundry script
- [ ] Read data
  - extsload, exttload
  - state view, transient state lib
  - credits
- [ ] Application - RYO swap router

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
