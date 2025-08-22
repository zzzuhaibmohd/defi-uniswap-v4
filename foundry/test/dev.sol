// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IUnlockCallback} from "../src/interfaces/IUnlockCallback.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {IPositionManager} from "../src/interfaces/IPositionManager.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {SwapParams} from "../src/types/PoolOperation.sol";
import {
    BalanceDelta, BalanceDeltaLibrary
} from "../src/types/BalanceDelta.sol";
import {SafeCast} from "../src/libraries/SafeCast.sol";
import {PoolId, PoolIdLibrary} from "../src/libraries/PoolId.sol";
import {TransientState} from "../src/libraries/TransientState.sol";
import {
    POOL_MANAGER,
    POSITION_MANAGER,
    POOLS_SLOT,
    POOL_ID_ETH_USDT,
    POOL_ID_ETH_USDC,
    POOL_ID_ETH_WBTC,
    USDT,
    USDC,
    WBTC,
    MIN_SQRT_PRICE,
    MAX_SQRT_PRICE
} from "../src/Constants.sol";

using BalanceDeltaLibrary for BalanceDelta;

/*
forge test --fork-url $FORK_URL --match-path test/dev.sol -vvvv
*/
contract Dev is Test {
    IPoolManager constant poolManager = IPoolManager(POOL_MANAGER);
    IPositionManager constant posm = IPositionManager(POSITION_MANAGER);
    bytes32 constant POOL_ID = POOL_ID_ETH_USDC;
    IERC20 constant coin = IERC20(USDC);

    function setUp() public {
        vm.label(POOL_MANAGER, "poolManager");
        vm.label(USDT, "USDT");
        vm.label(USDC, "USDC");
    }

    receive() external payable {}

    function test_pool_key() public {
        PoolKey memory key = PoolKey({
            currency0: address(0),
            currency1: WBTC,
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });

        PoolId id = PoolIdLibrary.toId(key);

        console.logBytes32(PoolId.unwrap(id));

        assertEq(POOL_ID_ETH_WBTC, PoolId.unwrap(id));
    }

    /*
    function settle(address currency, uint256 amount) internal {
        if (currency == address(0)) {
            poolManager.settle{value: amount}();
        } else {
            IERC20(currency).transfer(address(poolManager), amount);
            poolManager.settle();
        }
    }

    function print(PoolKey memory key) internal {
        int256 d0 = TransientState.currencyDelta(
            poolManager, address(this), key.currency0
        );
        int256 d1 = TransientState.currencyDelta(
            poolManager, address(this), key.currency1
        );
        console.log("delta 0: %e", d0);
        console.log("delta 1: %e", d1);
    }

    function unlockCallback(bytes calldata data)
        external
        returns (bytes memory)
    {
        (PoolKey memory key, SwapParams memory params) =
            abi.decode(data, (PoolKey, SwapParams));

        console.log("-- Before swap --");
        print(key);

        int256 d = poolManager.swap({key: key, params: params, hookData: ""});
        console.log("-- After swap --");
        print(key);
        BalanceDelta delta = BalanceDelta.wrap(d);

        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

        // amount > 0 = incoming
        // amount < 0 = outgoing
        console.log("amount0: %e", amount0);
        console.log("amount1: %e", amount1);

        if (params.zeroForOne) {
            require(amount1 >= 0, "amount1 < 0");
            poolManager.take({
                currency: key.currency1,
                to: address(this),
                amount: SafeCast.toUint256(amount1)
            });
            console.log("-- After take --");
            print(key);

            poolManager.sync(key.currency0);
            console.log("-- After sync --");
            print(key);

            settle(key.currency0, SafeCast.toUint256(-amount0));
            console.log("-- After settle --");
            print(key);
        } else {
            require(amount0 >= 0, "amount0 < 0");
            poolManager.take({
                currency: key.currency0,
                to: address(this),
                amount: SafeCast.toUint256(amount0)
            });
            console.log("-- After take --");
            print(key);

            poolManager.sync(key.currency1);
            console.log("-- After sync --");
            print(key);

            settle(key.currency1, SafeCast.toUint256(-amount1));
            console.log("-- After settle --");
            print(key);
        }

        return "";
    }

    function test() public {
        // TODO: multi hop swap from pool manager
        deal(address(this), 10 * 1e18);
        deal(address(coin), address(this), 1000 * 1e6);
        uint256 bal = coin.balanceOf(address(this));
        console.log("coin balance: %e", coin.balanceOf(address(this)));
        console.log("ETH balance: %e", address(this).balance);

        uint256 amount = 1000 * 1e6;
        // uint256 amount = 1e18;
        // ETH = address(0) < USDC and USDT
        bool zeroForOne = false;

        PoolKey memory key = PoolKey({
            currency0: address(0),
            currency1: address(coin),
            fee: 500,
            tickSpacing: 10,
            hooks: address(0)
        });

        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amount),
            // price = Currency 1 / currency 0
            // 0 for 1 = price decreases
            // 1 for 0 = price increases
            sqrtPriceLimitX96: zeroForOne ? MIN_SQRT_PRICE + 1 : MAX_SQRT_PRICE - 1
        });

        bytes memory data = abi.encode(key, params);
        poolManager.unlock(data);

        console.log("coin balance: %e", coin.balanceOf(address(this)));
        console.log("ETH balance: %e", address(this).balance);

       Pool id and Pool key
        PoolKey memory key = PoolKey({
            currency0: address(0),
            currency1: USDT,
            fee: 500,
            tickSpacing: 10,
            hooks: address(0)
        });

        PoolId id = PoolIdLibrary.toId(key);

        console.log("ETH/USDT pool id");
        console.logBytes32(PoolId.unwrap(id));

        assertEq(POOL_ID_ETH_USDT, PoolId.unwrap(id));

        // TODO: read from Pool.extsload
        // slot of value = keccak256(key, slot where mapping is declared)
        bytes32 slot = keccak256(abi.encode(POOL_ID, POOLS_SLOT));
        bytes32[] memory vals = poolManager.extsload(slot, 3);
        console.logBytes32(vals[0]);
        console.logBytes32(vals[1]);
    }
    */
}
