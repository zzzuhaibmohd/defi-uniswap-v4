# defi-uniswap-v4

# Course intro

- [ ] Prerequisites
  - Solidity
    - Advanced Solidity to understand how to read from Uniswap V4 (`extsload`)
    - User defined types
  - Uniswap V3
- [ ] Project setup
  - v4 template?

# Contracts

- [ ] v4-core -> v4 router (BaseActionsRouter) -> universal router

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

- [ ] V4 vs V3
  - Hooks
  - dynamic fees
  - [ ] Singleton
    - PoolManager `mapping(PoolId id => Pool.State) internal _pools`
  - [ ] Flash accounting
  - [ ] ERC6909
  - [ ] Hooks
  - [ ] Subscriber?

- [ ] Transient storage
  - lock, currency delta, currency reserve, `NonzeroDeltaCount`
- [ ] Pool key and pool id
  - [ ] Currency
    - id
      - ETH = address 0
      - ERC20 = token address
- [ ] Currency reserves
- [ ] Lock
- [ ] Account delta
- [ ] Operations
  - [ ] unlock
  - [ ] swap -> sync -> pay + settle -> take
- [ ] Lifecycle
- [ ] Application - RYO swap router
  - v4 template?

- [ ] Hooks
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
