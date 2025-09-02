foundry

- [ ] TODO - code: Hooks
  - hook deployment + flags
    - `Hooks.hasPermission`
    - https://docs.uniswap.org/contracts/v4/guides/hooks/hook-deployment

- https://docs.uniswap.org/contracts/v4/guides/read-pool-state
- https://github.com/Uniswap/v4-core/blob/main/src/libraries/StateLibrary.sol
- msg.sender?
- Exercise?

TODO: - limit order book
Uni v4
https://medium.com/tokamak-network/uniswap-v4-limit-order-hook-part-1-586233620584

https://github.com/eugenioclrc/limit-order-hooks/blob/main/src/TakeProfitsHook.sol

### Hooks

- Key concepts
  - External contract calls before and after pool operations such as swap and liquidity modifications
    - [`IHooks`](https://github.com/Uniswap/v4-core/blob/main/src/interfaces/IHooks.sol)
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
    - [`PoolManager`](https://github.com/Uniswap/v4-core/blob/main/src/PoolManager.sol)
    - [`Hooks`](https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol)
  - Hooks are part of the derivation for `PoolId`
    - 1 hooks contract for each pool
    - Can have many pools connected to one hooks contract
  - Ideas
    - Limit orders
    - Dynamic fees set before or after swaps
    - TODO: Custom AMM curves?
      - https://docs.uniswap.org/contracts/v4/quickstart/hooks/async-swap
    - TODO: Auto rebalancing liquidity example?
  - Hooks contract address encodes which hook functions it implements

- How are hook flags encoded into the hooks address?
  - bottom 14 bits
    - [Flags](https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/libraries/Hooks.sol#L27-L47)
    - [`hasPermission`](https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/libraries/Hooks.sol#L337-L339)
  - [`HookMiner`](https://github.com/Uniswap/v4-periphery/blob/main/src/utils/HookMiner.sol)

- Access msg.sender from inside a hook

- Example
  - HookMiner
  - [`BaseHook`](https://github.com/Uniswap/v4-periphery/blob/main/src/utils/BaseHook.sol)
