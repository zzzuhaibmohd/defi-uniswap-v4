// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "../interfaces/IERC20.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {Hooks} from "../libraries/Hooks.sol";
import {SafeCast} from "../libraries/SafeCast.sol";
import {CurrencyLib} from "../libraries/CurrencyLib.sol";
import {StateLibrary} from "../libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "../types/PoolId.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {SwapParams, ModifyLiquidityParams} from "../types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "../types/BalanceDelta.sol";
import {
    BeforeSwapDelta,
    BeforeSwapDeltaLibrary
} from "../types/BeforeSwapDelta.sol";
import {MIN_TICK, MAX_TICK, MIN_SQRT_PRICE} from "../Constants.sol";
import {TStore} from "../TStore.sol";

contract LimitOrder is TStore {
    using PoolIdLibrary for PoolKey;
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeCast for int128;
    using SafeCast for uint128;
    using CurrencyLib for address;

    error NotPoolManager();

    uint256 constant ADD_LIQUIDITY = 1;
    uint256 constant REMOVE_LIQUIDITY = 2;

    // TODO: events
    // Bucket of limit orders
    struct Bucket {
        uint256 amount0;
        uint256 amount1;
        // Total liquidity
        uint128 liquidity;
        // Liquidity provided per user
        mapping(address => uint128) sizes;
    }

    IPoolManager public immutable poolManager;

    // Bucket id => current slot to place limit orders
    mapping(bytes32 => uint256) public slots;
    // Bucket id => slot => Bucket
    mapping(bytes32 => mapping(uint256 => Bucket)) public buckets;
    // Pool id => last lower tick
    mapping(PoolId => int24) public ticks;

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
        Hooks.validateHookPermissions(address(this), getHookPermissions());
    }

    function getHookPermissions()
        public
        pure
        returns (Hooks.Permissions memory)
    {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) external onlyPoolManager returns (bytes4) {
        ticks[key.toId()] = getTickLower(tick, key.tickSpacing);
        return this.afterInitialize.selector;
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    )
        external
        onlyPoolManager
        setAction(REMOVE_LIQUIDITY)
        returns (bytes4, int128)
    {
        PoolId poolId = key.toId();
        // Current tick lower
        int24 tickLower = getTickLower(getTick(poolId), key.tickSpacing);
        int24 tickLowerLast = ticks[poolId];

        (int24 lower, int24 upper) = tickLowerLast < tickLower
            ? (tickLowerLast, tickLower)
            : (tickLower, tickLowerLast);

        bool zeroForOne = !params.zeroForOne;
        while (lower < upper) {
            bytes32 id = getBucketId(poolId, lower, zeroForOne);
            Bucket storage bucket = buckets[id][slots[id]];
            if (bucket.liquidity > 0) {
                slots[id]++;
                // TODO: remove liquidity + mint
            }
            lower += key.tickSpacing;
        }

        ticks[poolId] = tickLower;

        // TODO: params
        return (this.afterSwap.selector, 0);
    }

    function unlockCallback(bytes calldata data)
        external
        onlyPoolManager
        returns (bytes memory)
    {
        uint256 action = _getAction();

        if (action == ADD_LIQUIDITY) {
            (
                address msgSender,
                uint256 msgVal,
                PoolKey memory key,
                int24 tickLower,
                bool zeroForOne,
                uint128 liquidity
            ) = abi.decode(
                data, (address, uint256, PoolKey, int24, bool, uint128)
            );

            (int256 d,) = poolManager.modifyLiquidity({
                key: key,
                params: ModifyLiquidityParams({
                    tickLower: tickLower,
                    tickUpper: tickLower + key.tickSpacing,
                    liquidityDelta: int256(uint256(liquidity)),
                    salt: bytes32(0)
                }),
                hookData: ""
            });

            BalanceDelta delta = BalanceDelta.wrap(d);
            int128 amount0 = delta.amount0();
            int128 amount1 = delta.amount1();

            address currency;
            uint256 amountToPay;
            if (zeroForOne) {
                // TODO: amount1 = 0 includes fees?
                require(amount0 < 0 && amount1 == 0, "Tick crossed");
                currency = key.currency0;
                amountToPay = (-amount0).toUint256();
            } else {
                require(amount0 == 0 && amount1 < 0, "Tick crossed");
                currency = key.currency1;
                amountToPay = (-amount1).toUint256();
            }

            // Sync + pay + settle
            poolManager.sync(currency);
            if (currency == address(0)) {
                require(amountToPay >= msgVal, "Not enough ETH sent");
                sendEth(address(poolManager), amountToPay);
                if (msgVal > amountToPay) {
                    sendEth(msgSender, msgVal - amountToPay);
                }
            } else {
                IERC20(currency).transferFrom(
                    msgSender, address(poolManager), amountToPay
                );
            }
            poolManager.settle();

            return "";
        } else if (action == REMOVE_LIQUIDITY) {
            /*
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
            */
            return "";
        }
        revert("Invalid action");
    }

    function getBucketId(PoolId poolId, int24 tick, bool zeroForOne)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(poolId, tick, zeroForOne));
    }

    function place(
        PoolKey calldata key,
        int24 tickLower,
        bool zeroForOne,
        uint128 liquidity
    ) external payable setAction(ADD_LIQUIDITY) returns (uint256) {
        require(tickLower % key.tickSpacing == 0, "Invalid tick");

        poolManager.unlock(
            abi.encode(msg.sender, msg.value, key, tickLower, liquidity)
        );

        bytes32 id = getBucketId(key.toId(), tickLower, zeroForOne);
        uint256 slot = slots[id];

        Bucket storage bucket = buckets[id][slot];
        bucket.liquidity += liquidity;
        bucket.sizes[msg.sender] += liquidity;

        return slot;
    }

    // Burn + take?
    function take(bytes32 id, uint256 slot) external {
        require(slot < slots[id], "Active slot");
    }

    function cancel(bytes32 id, uint256 slot)
        external
        setAction(REMOVE_LIQUIDITY)
    {
        require(slot == slots[id], "Not active slot");
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

    function sendEth(address to, uint256 amount) private {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Send ETH failed");
    }
}
