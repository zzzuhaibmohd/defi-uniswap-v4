// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Based off of BaseHook
// https://github.com/Uniswap/v4-periphery/blob/main/src/utils/BaseHook.sol

// See here for explanation of function inputs and ouputs
// https://github.com/Uniswap/v4-core/blob/main/src/interfaces/IHooks.sol

import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {PoolId, PoolIdLibrary} from "../libraries/PoolId.sol";
import {Hooks} from "../libraries/Hooks.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {SwapParams, ModifyLiquidityParams} from "../types/PoolOperation.sol";
import {BalanceDelta} from "../types/BalanceDelta.sol";
import {
    BeforeSwapDelta,
    BeforeSwapDeltaLibrary
} from "../types/BeforeSwapDelta.sol";

contract CounterHook {
    using PoolIdLibrary for PoolKey;

    IPoolManager public immutable poolManager;

    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;
    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeRemoveLiquidityCount;

    error NotPoolManager();
    error HookNotImplemented();

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    function getHookPermissions()
        public
        pure
        returns (Hooks.Permissions memory)
    {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96
    ) external onlyPoolManager returns (bytes4) {
        revert HookNotImplemented();
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) external onlyPoolManager returns (bytes4) {
        revert HookNotImplemented();
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        beforeSwapCount[key.toId()]++;
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4, int128) {
        afterSwapCount[key.toId()]++;
        return (this.afterSwap.selector, 0);
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4) {
        beforeAddLiquidityCount[key.toId()]++;
        return this.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4) {
        beforeRemoveLiquidityCount[key.toId()]++;
        return this.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4) {
        revert HookNotImplemented();
    }

    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4) {
        revert HookNotImplemented();
    }
}
