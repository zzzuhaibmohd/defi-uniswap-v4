// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {TestHelper} from "./TestHelper.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {SafeCast} from "../src/libraries/SafeCast.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {StateLibrary} from "../src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "../src/types/PoolId.sol";
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
    MIN_SQRT_PRICE,
    MAX_SQRT_PRICE
} from "../src/Constants.sol";
import {LimitOrder} from "@exercises/LimitOrder.sol";

/*
1. Run test/FindHookSalt.test.sol to find salt
2. Set salt
export SALT=
3. Run this test
forge test --fork-url $FORK_URL --match-path test/LimitOrder.test.sol -vvv
*/

contract LimitOrderTest is Test {
    using PoolIdLibrary for PoolKey;
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeCast for int128;
    using SafeCast for uint128;

    TestHelper helper;
    IERC20 constant usdc = IERC20(USDC);
    IPoolManager constant poolManager = IPoolManager(POOL_MANAGER);
    PoolKey key;
    LimitOrder hook;

    int24 constant TICK_SPACING = 10;
    uint128 constant LIQUIDITY = 1e18;
    // Initial tick
    int24 tick0;

    uint256 constant SWAP = 1;
    uint256 constant ADD_LIQUIDITY = 2;
    uint256 action;

    address[2] users = [address(11), address(22)];

    function setUp() public {
        helper = new TestHelper();

        console.log("Deployer", address(this));

        bytes32 salt = vm.envBytes32("SALT");
        console.log("SALT");
        console.logBytes32(salt);
        hook = new LimitOrder{salt: salt}(POOL_MANAGER);

        key = PoolKey({
            currency0: address(0),
            currency1: USDC,
            fee: 500,
            tickSpacing: TICK_SPACING,
            hooks: address(hook)
        });

        // sqrt(token 1 / token 0) x 2**96 = 1 ETH = 3000 USDC
        uint160 sqrtPriceX96 = 4347826086925359274971250;
        poolManager.initialize(key, sqrtPriceX96);

        // Check tick is stored
        tick0 = getTick(key.toId());
        assertEq(hook.ticks(key.toId()), tick0, "initial tick");

        action = ADD_LIQUIDITY;
        poolManager.unlock("");

        for (uint256 i = 0; i < users.length; i++) {
            deal(users[i], 100 * 1e18);
            deal(USDC, users[i], 1e6 * 1e6);
            vm.prank(users[i]);
            usdc.approve(address(hook), type(uint256).max);
        }
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
                    liquidityDelta: int256(uint256(LIQUIDITY)),
                    salt: bytes32(0)
                }),
                hookData: ""
            });
            BalanceDelta delta = BalanceDelta.wrap(d);
            if (delta.amount0() < 0) {
                uint256 amount0 = uint128(-delta.amount0());
                console.log("Add liquidity amount 0: %e", amount0);
                deal(address(this), amount0);
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
        } else if (action == SWAP) {
            (uint256 amt, bool zeroForOne) = abi.decode(data, (uint256, bool));

            if (zeroForOne) {
                deal(address(this), amt);
            } else {
                deal(USDC, address(this), amt);
            }

            int256 d = poolManager.swap({
                key: key,
                params: SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: -(int256(amt)),
                    sqrtPriceLimitX96: zeroForOne
                        ? MIN_SQRT_PRICE + 1
                        : MAX_SQRT_PRICE - 1
                }),
                hookData: ""
            });

            // Take and settle
            BalanceDelta delta = BalanceDelta.wrap(d);
            int128 amount0 = delta.amount0();
            int128 amount1 = delta.amount1();

            console.log("Swap amount0: %e", amount0);
            console.log("Swap amount1: %e", amount1);

            (
                address currencyIn,
                address currencyOut,
                uint256 amountIn,
                uint256 amountOut
            ) = zeroForOne
                ? (
                    key.currency0,
                    key.currency1,
                    (-amount0).toUint256(),
                    amount1.toUint256()
                )
                : (
                    key.currency1,
                    key.currency0,
                    (-amount1).toUint256(),
                    amount0.toUint256()
                );

            poolManager.take({
                currency: currencyOut,
                to: address(this),
                amount: amountOut
            });

            poolManager.sync(currencyIn);
            if (currencyIn == address(0)) {
                poolManager.settle{value: amountIn}();
            } else {
                IERC20(currencyIn).transfer(address(poolManager), amountIn);
                poolManager.settle();
            }

            return "";
        }

        revert("Invalid action");
    }

    // TODO:
    // - test place
    // - test cancel
    // - test take
    // - test after swap
    function test_place_zero_for_one() public {
        int24 tickLower = getTickLower(tick0, TICK_SPACING);
        {
            helper.set("user 0: before place ETH", users[0].balance);
            helper.set("user 0: before place USDC", usdc.balanceOf(users[0]));

            uint128 liq = 1e17;
            vm.prank(users[0]);
            hook.place{value: users[0].balance}(
                key, tickLower + TICK_SPACING, true, liq
            );

            helper.set("user 0: after place ETH", users[0].balance);
            helper.set("user 0: after place USDC", usdc.balanceOf(users[0]));

            console.log(
                "user 0 place ETH delta: %e",
                helper.delta(
                    "user 0: after place ETH", "user 0: before place ETH"
                )
            );
            console.log(
                "user 0 place USDC delta: %e",
                helper.delta(
                    "user 0: after place USDC", "user 0: before place USDC"
                )
            );
        }

        // TODO: assert bucket liquidity, assert pool manager liquidity

        {
            /*
            helper.set("user 1: before place ETH", users[1].balance);
            helper.set("user 1: before place USDC", usdc.balanceOf(users[1]));

            uint128 liq = 1e17;
            vm.prank(users[1]);
            hook.place(key, tickLower - TICK_SPACING, false, liq);

            helper.set("user 1: after place ETH", users[1].balance);
            helper.set("user 1: after place USDC", usdc.balanceOf(users[1]));

            console.log("user 1 ETH delta: %e", helper.delta("user 1: after place ETH", "user 1: before place ETH"));
            console.log("user 1 USDC delta: %e", helper.delta("user 1: after place USDC", "user 1: before place USDC"));
            */
        }

        action = SWAP;
        poolManager.unlock(abi.encode(uint256(1e18), false));

        helper.set("user 0: before take ETH", users[0].balance);
        helper.set("user 0: before take USDC", usdc.balanceOf(users[0]));

        uint256 slot = 0;
        vm.prank(users[0]);
        hook.take(key, tickLower + TICK_SPACING, true, slot);

        helper.set("user 0: after take ETH", users[0].balance);
        helper.set("user 0: after take USDC", usdc.balanceOf(users[0]));

        console.log(
            "user take 0 ETH delta: %e",
            helper.delta("user 0: after take ETH", "user 0: before take ETH")
        );
        console.log(
            "user take 0 USDC delta: %e",
            helper.delta("user 0: after take USDC", "user 0: before take USDC")
        );
        // TODO: check slots
    }

    function getTick(PoolId poolId) private view returns (int24 tick) {
        (, tick,,) = StateLibrary.getSlot0(address(poolManager), poolId);
    }

    function getTickLower(int24 tick, int24 tickSpacing)
        private
        pure
        returns (int24)
    {
        int24 compressed = tick / tickSpacing;
        // Round towards negative infinity
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }
}
