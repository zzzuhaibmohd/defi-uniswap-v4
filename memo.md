### Hooks

- [ ] Key concepts
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
  - [Hooks are part of the derivation for `PoolId`](./notes/hooks.png)
    - 1 hooks contract for each pool
    - Can have many pools connected to one hooks contract
  - Hooks contract address encodes which hook functions it implements
  - Ideas
    - Limit orders
    - Dynamic fees set before or after swaps
    - Auto rebalancing liquidity example

- [ ] How are hook flags encoded into the hooks address?
  - Bottom 14 bits
    - [Flags](https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/libraries/Hooks.sol#L27-L47)
    - [`hasPermission`](https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/libraries/Hooks.sol#L337-L339)
  - [`HookMiner`](https://github.com/Uniswap/v4-periphery/blob/main/src/utils/HookMiner.sol)
    - test - `FindHookAddr`

- [ ] [Access msg.sender inside a hooks contract](./notes/hooks_msg_sender.png)
- [ ] [Exercise - counter hook](./foundry/exercises/counter.md)
- [ ] [Application - limit order](./foundry/exercises/limit_order.md)
  - [ ] [What is a limit order](https://app.uniswap.org/limit)
  - [ ] [Review ticks and liquidity](https://www.desmos.com/calculator/x31s77joxw)
  - [ ] TODO: excalidraw - Application
    - [ ] buckets
    - [ ] slots
    - [ ] fees

- References
  - [`BaseHook`](https://github.com/Uniswap/v4-periphery/blob/main/src/utils/BaseHook.sol)
  - [`LimitOrder`](https://github.com/Uniswap/v4-periphery/blob/example-contracts/contracts/hooks/examples/LimitOrder.sol)
