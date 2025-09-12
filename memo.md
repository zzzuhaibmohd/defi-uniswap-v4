### Hooks

- [x] Key concepts
  - External contract calls before and after pool operations such as swap and liquidity modifications
    - [`PoolManager`](https://github.com/Uniswap/v4-core/blob/main/src/PoolManager.sol)
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
    - [`Hooks`](https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol)
  - [Hooks are part of the derivation for `PoolId`](./notes/hooks.png)
    - 1 hooks contract for each pool
    - Can have multiple pools connected to one hooks contract
  - Ideas
    - Limit orders
    - Dynamic fees set before or after swaps
    - Auto rebalancing liquidity example

- [x] How are hook flags encoded into the hooks address?
  - Bottom 14 bits
    - [Flags](https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/libraries/Hooks.sol#L27-L47)
    - [`hasPermission`](https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/libraries/Hooks.sol#L337-L339)
  - [`HookMiner`](https://github.com/Uniswap/v4-periphery/blob/main/src/utils/HookMiner.sol)
    - [`FindHookSalt.sol`](https://github.com/Cyfrin/defi-uniswap-v4/blob/dev/foundry/test/FindHookSalt.test.sol)

- [x] [Access msg.sender inside a hooks contract](./notes/hooks_msg_sender.png)
- [x] [Exercise - counter hook](./foundry/exercises/counter.md)
- [Application - limit order](./foundry/exercises/limit_order.md)
  - [x] [What is a limit order](https://app.uniswap.org/limit)
  - [x] [Review ticks and liquidity](https://www.desmos.com/calculator/x31s77joxw)
  - [ ] [Algorithm](./notes/limit_order.png)
    - buckets
    - slots
    - fees

- References
  - [`BaseHook`](https://github.com/Uniswap/v4-periphery/blob/main/src/utils/BaseHook.sol)
  - [`LimitOrder`](https://github.com/Uniswap/v4-periphery/blob/example-contracts/contracts/hooks/examples/LimitOrder.sol)
