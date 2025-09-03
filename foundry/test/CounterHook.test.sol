// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {SafeCast} from "../src/libraries/SafeCast.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "../src/libraries/PoolId.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {
    SwapParams, ModifyLiquidityParams
} from "../src/types/PoolOperation.sol";
import {
    BalanceDelta, BalanceDeltaLibrary
} from "../src/types/BalanceDelta.sol";
import {
    POOL_MANAGER,
    USDC,
    MIN_TICK,
    MAX_TICK,
    MIN_SQRT_PRICE
} from "../src/Constants.sol";
import {CounterHook} from "@exercises/CounterHook.sol";

/*
1. Run script/CounterCode.s.sol to print creation code, constructor args and flags
2. Run test/HookAddr.test.sol to find salt
3. Set salt
export SALT=
4. Run this test
forge test --fork-url $FORK_URL --match-path test/CounterHook.test.sol -vvv
*/

contract CounterHookTest is Test {
    using PoolIdLibrary for PoolKey;
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeCast for int128;
    using SafeCast for uint128;

    IERC20 constant usdc = IERC20(USDC);
    IPoolManager constant poolManager = IPoolManager(POOL_MANAGER);
    PoolKey key;
    CounterHook hook;

    int24 constant TICK_SPACING = 10;
    int256 constant LIQUIDITY_DELTA = 1e12;

    uint256 constant SWAP = 1;
    uint256 constant ADD_LIQUIDITY = 2;
    uint256 constant REMOVE_LIQUIDITY = 3;
    uint256 action;

    function setUp() public {
        bytes32 salt = vm.envBytes32("SALT");
        console.log("SALT");
        console.logBytes32(salt);
        hook = new CounterHook{salt: salt}(POOL_MANAGER);

        key = PoolKey({
            currency0: address(0),
            currency1: USDC,
            fee: 500,
            tickSpacing: TICK_SPACING,
            hooks: address(hook)
        });

        poolManager.initialize(key, 1e6 * (1 << 96));

        deal(USDC, address(this), 1e6 * 1e6);
        deal(address(this), 1e6 * 1e18);
    }

    receive() external payable {}

    function unlockCallback(bytes calldata data)
        external
        returns (bytes memory)
    {
        if (action == ADD_LIQUIDITY) {
            (int256 d,) = poolManager.modifyLiquidity({
                key: key,
                params: ModifyLiquidityParams({
                    tickLower: MIN_TICK / TICK_SPACING * TICK_SPACING,
                    tickUpper: MAX_TICK / TICK_SPACING * TICK_SPACING,
                    liquidityDelta: LIQUIDITY_DELTA,
                    salt: bytes32(0)
                }),
                hookData: ""
            });
            BalanceDelta delta = BalanceDelta.wrap(d);
            if (delta.amount0() < 0) {
                uint256 amount0 = uint128(-delta.amount0());
                console.log("Add liquidity amount 0: %e", amount0);
                poolManager.sync(key.currency0);
                poolManager.settle{value: amount0}();
            }
            if (delta.amount1() < 0) {
                uint256 amount1 = uint128(-delta.amount1());
                console.log("Add liquidity amount 1: %e", amount1);
                deal(USDC, address(this), amount1);
                poolManager.sync(key.currency1);
                usdc.transfer(address(poolManager), amount1);
                poolManager.settle();
            }
            return "";
        } else if (action == REMOVE_LIQUIDITY) {
            (int256 d,) = poolManager.modifyLiquidity({
                key: key,
                params: ModifyLiquidityParams({
                    tickLower: MIN_TICK / TICK_SPACING * TICK_SPACING,
                    tickUpper: MAX_TICK / TICK_SPACING * TICK_SPACING,
                    liquidityDelta: -LIQUIDITY_DELTA,
                    salt: bytes32(0)
                }),
                hookData: ""
            });
            BalanceDelta delta = BalanceDelta.wrap(d);
            if (delta.amount0() > 0) {
                uint256 amount0 = uint128(delta.amount0());
                console.log("Remove liquidity amount 0: %e", amount0);
                poolManager.take(key.currency0, address(this), amount0);
            }
            if (delta.amount1() > 0) {
                uint256 amount1 = uint128(delta.amount1());
                console.log("Remove liquidity amount 1: %e", amount1);
                poolManager.take(key.currency1, address(this), amount1);
            }
            return "";
        } else if (action == SWAP) {
            // Swap ETH -> USDC
            uint256 bal = usdc.balanceOf(address(this));
            int256 d = poolManager.swap({
                key: key,
                params: SwapParams({
                    zeroForOne: true,
                    amountSpecified: -(int256(bal)),
                    sqrtPriceLimitX96: MIN_SQRT_PRICE + 1
                }),
                hookData: ""
            });

            BalanceDelta delta = BalanceDelta.wrap(d);
            int128 amount0 = delta.amount0();
            int128 amount1 = delta.amount1();

            (
                address currencyIn,
                address currencyOut,
                uint256 amountIn,
                uint256 amountOut
            ) = (
                key.currency0,
                key.currency1,
                (-amount0).toUint256(),
                amount1.toUint256()
            );

            poolManager.take({
                currency: currencyOut,
                to: address(this),
                amount: amountOut
            });

            poolManager.sync(currencyIn);
            poolManager.settle{value: amountIn}();
            return "";
        }

        revert("Invalid action");
    }

    function test_permissions() public {
        Hooks.validateHookPermissions(address(hook), hook.getHookPermissions());
    }

    function test_liquidity() public {
        action = ADD_LIQUIDITY;
        poolManager.unlock("");
        assertEq(hook.counts(key.toId(), "beforeAddLiquidity"), 1);
        assertEq(hook.counts(key.toId(), "afterAddLiquidity"), 0);

        action = REMOVE_LIQUIDITY;
        poolManager.unlock("");
        assertEq(hook.counts(key.toId(), "beforeRemoveLiquidity"), 1);
        assertEq(hook.counts(key.toId(), "afterRemoveLiquidity"), 0);
    }

    function test_swap() public {
        action = SWAP;
        deal(USDC, address(this), 100 * 1e6);
        poolManager.unlock("");
        assertEq(hook.counts(key.toId(), "beforeSwap"), 1);
        assertEq(hook.counts(key.toId(), "afterSwap"), 1);
    }
}
