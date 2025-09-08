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

    event Place(
        bytes32 indexed poolId,
        uint256 indexed slot,
        address indexed user,
        int24 tickLower,
        bool zeroForOne,
        uint128 liquidity
    );
    event Cancel(
        bytes32 indexed poolId,
        uint256 indexed slot,
        address indexed user,
        int24 tickLower,
        bool zeroForOne,
        uint128 liquidity
    );
    event Take(
        bytes32 indexed poolId,
        uint256 indexed slot,
        address indexed user,
        int24 tickLower,
        bool zeroForOne,
        uint256 amount0,
        uint256 amount1
    );
    event Fill(
        bytes32 indexed poolId,
        uint256 indexed slot,
        int24 tickLower,
        bool zeroForOne,
        uint256 amount0,
        uint256 amount1
    );

    // Bucket of limit orders
    struct Bucket {
        bool filled;
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
    // Pool id => last tick
    mapping(PoolId => int24) public ticks;

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
        Hooks.validateHookPermissions(address(this), getHookPermissions());
    }

    receive() external payable {}

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
        ticks[key.toId()] = tick;
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
        int24 tick = getTick(poolId);

        (int24 lower, int24 upper) =
            getTickRange(ticks[poolId], tick, key.tickSpacing);

        if (upper < lower) {
            return (this.afterSwap.selector, 0);
        }

        bool zeroForOne = !params.zeroForOne;
        while (lower <= upper) {
            bytes32 id = getBucketId(poolId, lower, zeroForOne);
            uint256 s = slots[id];
            Bucket storage bucket = buckets[id][s];
            if (bucket.liquidity > 0) {
                slots[id] = s + 1;
                (uint256 amount0, uint256 amount1,,) = removeLiquidity(
                    key,
                    lower,
                    // TODO: safe cast
                    -int256(uint256(bucket.liquidity))
                );
                bucket.filled = true;
                bucket.amount0 += amount0;
                bucket.amount1 += amount1;
                emit Fill(
                    PoolId.unwrap(poolId),
                    s,
                    lower,
                    zeroForOne,
                    bucket.amount0,
                    bucket.amount1
                );
            }
            lower += key.tickSpacing;
        }

        ticks[poolId] = tick;

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
            (
                address msgSender,
                PoolKey memory key,
                int24 tickLower,
                uint128 size,
                uint128 liquidityRemaining
            ) = abi.decode(data, (address, PoolKey, int24, uint128, uint128));

            (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) =
                removeLiquidity(key, tickLower, -int256(uint256(size)));

            if (liquidityRemaining > 0) {
                if (amount0 - fee0 > 0) {
                    key.currency0.transferOut(msgSender, amount0 - fee0);
                }
                if (amount1 - fee1 > 0) {
                    key.currency1.transferOut(msgSender, amount1 - fee1);
                }
                return abi.encode(fee0, fee1);
            } else {
                if (amount0 > 0) {
                    key.currency0.transferOut(msgSender, amount0);
                }
                if (amount1 > 0) {
                    key.currency1.transferOut(msgSender, amount1);
                }
                return abi.encode(uint256(0), uint256(0));
            }
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
    ) external payable setAction(ADD_LIQUIDITY) {
        require(tickLower % key.tickSpacing == 0, "Invalid tick");

        poolManager.unlock(
            abi.encode(msg.sender, msg.value, key, tickLower, liquidity)
        );

        PoolId poolId = key.toId();
        bytes32 id = getBucketId(poolId, tickLower, zeroForOne);
        uint256 slot = slots[id];

        Bucket storage bucket = buckets[id][slot];
        bucket.liquidity += liquidity;
        bucket.sizes[msg.sender] += liquidity;

        emit Place(
            PoolId.unwrap(poolId),
            slot,
            msg.sender,
            tickLower,
            zeroForOne,
            liquidity
        );
    }

    function cancel(PoolKey calldata key, int24 tickLower, bool zeroForOne)
        external
        setAction(REMOVE_LIQUIDITY)
    {
        PoolId poolId = key.toId();
        bytes32 id = getBucketId(poolId, tickLower, zeroForOne);
        uint256 slot = slots[id];
        Bucket storage bucket = buckets[id][slot];
        require(!bucket.filled, "bucket filled");

        uint128 size = bucket.sizes[msg.sender];
        require(size > 0, "limit order size = 0");

        bucket.liquidity -= size;
        bucket.sizes[msg.sender] = 0;

        bytes memory res = poolManager.unlock(
            abi.encode(msg.sender, key, tickLower, size, bucket.liquidity)
        );
        (uint256 fee0, uint256 fee1) = abi.decode(res, (uint256, uint256));

        if (bucket.liquidity > 0) {
            bucket.amount0 += fee0;
            bucket.amount1 += fee1;
        }

        emit Cancel(
            PoolId.unwrap(poolId), slot, msg.sender, tickLower, zeroForOne, size
        );
    }

    function take(
        PoolKey calldata key,
        int24 tickLower,
        bool zeroForOne,
        uint256 slot
    ) external {
        PoolId poolId = key.toId();
        bytes32 id = getBucketId(poolId, tickLower, zeroForOne);
        Bucket storage bucket = buckets[id][slot];
        require(bucket.filled, "bucket not filled");

        uint256 liquidity = uint256(bucket.liquidity);
        uint256 size = uint256(bucket.sizes[msg.sender]);
        bucket.sizes[msg.sender] = 0;

        // Note: recommended to use mulDiv here
        uint256 amount0 = bucket.amount0 * size / liquidity;
        uint256 amount1 = bucket.amount1 * size / liquidity;

        if (amount0 > 0) {
            key.currency0.transferOut(msg.sender, amount0);
        }
        if (amount1 > 0) {
            key.currency1.transferOut(msg.sender, amount1);
        }

        emit Take(
            PoolId.unwrap(poolId),
            slot,
            msg.sender,
            tickLower,
            zeroForOne,
            amount0,
            amount1
        );
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

    function getTickRange(int24 tick0, int24 tick1, int24 tickSpacing)
        private
        pure
        returns (int24 lower, int24 upper)
    {
        // Last lower tick
        int24 l0 = getTickLower(tick0, tickSpacing);
        // Current lower tick
        int24 l1 = getTickLower(tick1, tickSpacing);

        if (tick0 <= tick1) {
            lower = l0;
            upper = l1 - tickSpacing;
        } else {
            lower = l1 + tickSpacing;
            upper = l0;
        }
    }

    function removeLiquidity(
        PoolKey memory key,
        int24 tickLower,
        int256 liquidity
    )
        private
        returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1)
    {
        (int256 d, int256 f) = poolManager.modifyLiquidity({
            key: key,
            params: ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickLower + key.tickSpacing,
                liquidityDelta: liquidity,
                salt: bytes32(0)
            }),
            hookData: ""
        });

        // delta includes fee0 and fee1
        BalanceDelta delta = BalanceDelta.wrap(d);
        if (delta.amount0() > 0) {
            amount0 = uint256(uint128(delta.amount0()));
            poolManager.take(key.currency0, address(this), amount0);
        }
        if (delta.amount1() > 0) {
            amount1 = uint256(uint128(delta.amount1()));
            poolManager.take(key.currency1, address(this), amount1);
        }

        BalanceDelta fees = BalanceDelta.wrap(d);
        if (fees.amount0() > 0) {
            fee0 = uint256(uint128(fees.amount0()));
        }
        if (fees.amount1() > 0) {
            fee1 = uint256(uint128(fees.amount1()));
        }
    }

    function sendEth(address to, uint256 amount) private {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Send ETH failed");
    }
}
