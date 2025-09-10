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
        // Write your code here
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
        // Write your code here
        return (this.afterSwap.selector, 0);
    }

    function unlockCallback(bytes calldata data)
        external
        onlyPoolManager
        returns (bytes memory)
    {
        uint256 action = _getAction();

        if (action == ADD_LIQUIDITY) {
            // Write your code here
        } else if (action == REMOVE_LIQUIDITY) {
            // Write your code here
        }

        revert("Invalid action");
    }

    function place(
        PoolKey calldata key,
        int24 tickLower,
        bool zeroForOne,
        uint128 liquidity
    ) external payable setAction(ADD_LIQUIDITY) {
        // Write your code here
    }

    function cancel(PoolKey calldata key, int24 tickLower, bool zeroForOne)
        external
        setAction(REMOVE_LIQUIDITY)
    {
        // Write your code here
    }

    function take(
        PoolKey calldata key,
        int24 tickLower,
        bool zeroForOne,
        uint256 slot
    ) external {
        // Write your code here
    }

    function getBucketId(PoolId poolId, int24 tick, bool zeroForOne)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(PoolId.unwrap(poolId), tick, zeroForOne));
    }

    function getBucket(bytes32 id, uint256 slot)
        public
        view
        returns (
            bool filled,
            uint256 amount0,
            uint256 amount1,
            uint128 liquidity
        )
    {
        Bucket storage bucket = buckets[id][slot];
        return (bucket.filled, bucket.amount0, bucket.amount1, bucket.liquidity);
    }

    function getOrderSize(bytes32 id, uint256 slot, address user)
        public
        view
        returns (uint128)
    {
        return buckets[id][slot].sizes[user];
    }

    function _getTick(PoolId poolId) private view returns (int24 tick) {
        (, tick,,) = StateLibrary.getSlot0(address(poolManager), poolId);
    }

    function _getTickLower(int24 tick, int24 tickSpacing)
        private
        pure
        returns (int24)
    {
        int24 compressed = tick / tickSpacing;
        // Round towards negative infinity
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function _getTickRange(int24 tick0, int24 tick1, int24 tickSpacing)
        private
        pure
        returns (int24 lower, int24 upper)
    {
        // Last lower tick
        int24 l0 = _getTickLower(tick0, tickSpacing);
        // Current lower tick
        int24 l1 = _getTickLower(tick1, tickSpacing);

        if (tick0 <= tick1) {
            lower = l0;
            upper = l1 - tickSpacing;
        } else {
            lower = l1 + tickSpacing;
            upper = l0;
        }
    }
}
