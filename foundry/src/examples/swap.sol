// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {SwapParams} from "../types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "../types/BalanceDelta.sol";
import {SafeCast} from "../libraries/SafeCast.sol";
import {PoolId, PoolIdLibrary} from "../libraries/PoolId.sol";
import {TransientState} from "../libraries/TransientState.sol";
import {
    POOL_MANAGER,
    POOL_ID_ETH_USDC,
    USDC,
    MIN_SQRT_PRICE,
    MAX_SQRT_PRICE
} from "../Constants.sol";

using BalanceDeltaLibrary for BalanceDelta;

/*
forge test --fork-url $FORK_URL --match-path src/examples/swap.sol -vvvv
*/
contract Example_Swap is Test {
    using SafeCast for int128;

    IPoolManager constant poolManager = IPoolManager(POOL_MANAGER);
    bytes32 constant POOL_ID = POOL_ID_ETH_USDC;
    IERC20 constant usdc = IERC20(USDC);

    function setUp() public {
        vm.label(POOL_MANAGER, "poolManager");
        vm.label(USDC, "USDC");

        deal(address(this), 10 * 1e18);
        deal(USDC, address(this), 1000 * 1e6);
    }

    receive() external payable {}

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

        (
            address currencyIn,
            address currencyOut,
            uint256 amountIn,
            uint256 amountOut
        ) = params.zeroForOne
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
        console.log("-- After take --");
        print(key);

        poolManager.sync(currencyIn);
        console.log("-- After sync --");
        print(key);

        if (currencyIn == address(0)) {
            poolManager.settle{value: amountIn}();
        } else {
            IERC20(currencyIn).transfer(address(poolManager), amountIn);
            poolManager.settle();
        }
        console.log("-- After settle --");
        print(key);

        return "";
    }

    function test_swap() public {
        console.log("USDC balance: %e", usdc.balanceOf(address(this)));
        console.log("ETH balance: %e", address(this).balance);

        uint256 amount = 1000 * 1e6;
        // uint256 amount = 1e18;
        // ETH = address(0) < USDC and USDT
        bool zeroForOne = false;

        PoolKey memory key = PoolKey({
            currency0: address(0),
            currency1: USDC,
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

        console.log("USDC balance: %e", usdc.balanceOf(address(this)));
        console.log("ETH balance: %e", address(this).balance);
    }

    function print(PoolKey memory key) internal view {
        int256 d0 = TransientState.currencyDelta(
            poolManager, address(this), key.currency0
        );
        int256 d1 = TransientState.currencyDelta(
            poolManager, address(this), key.currency1
        );
        console.log("delta 0: %e", d0);
        console.log("delta 1: %e", d1);
    }
}
