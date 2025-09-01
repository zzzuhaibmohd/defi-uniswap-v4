foundry

- [ ] TODO - code: Hooks
  - hook deployment + flags
    - `Hooks.hasPermission`
    - https://docs.uniswap.org/contracts/v4/guides/hooks/hook-deployment

- https://docs.uniswap.org/contracts/v4/guides/read-pool-state
- https://github.com/Uniswap/v4-core/blob/main/src/libraries/StateLibrary.sol
- msg.sender?
- Exercise?

TODO - limit order book
Uni v4
https://medium.com/tokamak-network/uniswap-v4-limit-order-hook-part-1-586233620584

https://github.com/eugenioclrc/limit-order-hooks/blob/main/src/TakeProfitsHook.sol

### Hooks

- Key concepts
  - External contract calls before and after pool operations such as swap and liquidity modifications
    - `beforeInitialize`
    - `afterInitialize`
    - `beforeAddLiquidity`
    - `afterAddLiquidity`
    - `beforeRemoveLiquidity`
    - `afterRemoveLiquidity`
    - `beforeSwap`
    - `afterSwap`
    - `beforeDonate`
    - `afterDonate`
  - hooks part of derivation of PoolKey
    - 1 hook for each pool
    - Can have many pools connected to one hook
  - Hook contract address encodes which hook functions it implements
- Ideas
  - Limit orders
  - Dynamic fees set before or after swaps
  - TODO: Custom AMM curves?
    - https://docs.uniswap.org/contracts/v4/quickstart/hooks/async-swap
  - Auto rebalancing liquidity

- TODO: how is hook flags encoded into the hook address?
