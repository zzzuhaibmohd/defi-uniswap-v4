// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// import {console} from "forge-std/Test.sol";

import {IERC20} from "../interfaces/IERC20.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {IUnlockCallback} from "../interfaces/IUnlockCallback.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {SwapParams} from "../types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "../types/BalanceDelta.sol";
import {SafeCast} from "../libraries/SafeCast.sol";
import {CurrencyLib} from "../libraries/CurrencyLib.sol";
import {MIN_SQRT_PRICE, MAX_SQRT_PRICE} from "../Constants.sol";
import {TStore} from "../TStore.sol";

contract Router is TStore, IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeCast for int128;
    using SafeCast for uint128;
    using CurrencyLib for address;

    // Actions
    uint256 private constant SWAP_EXACT_IN_SINGLE = 0x06;
    uint256 private constant SWAP_EXACT_IN = 0x07;
    uint256 private constant SWAP_EXACT_OUT_SINGLE = 0x08;
    uint256 private constant SWAP_EXACT_OUT = 0x09;

    IPoolManager public immutable poolManager;

    struct ExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMin;
        bytes hookData;
    }

    struct ExactOutputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountOut;
        uint128 amountInMax;
        bytes hookData;
    }

    struct PathKey {
        address currency;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
        bytes hookData;
    }

    struct ExactInputParams {
        address currencyIn;
        // First element + currencyIn determines the first pool to swap
        // Last element + previous path element's currency determines the last pool to swap
        PathKey[] path;
        uint128 amountIn;
        uint128 amountOutMin;
    }

    struct ExactOutputParams {
        address currencyOut;
        // Last element + currencyOut determines the last pool to swap
        // First element + second path element's currency determines the first pool to swap
        PathKey[] path;
        uint128 amountOut;
        uint128 amountInMax;
    }

    error UnsupportedAction(uint256 action);

    modifier onlyPoolManager() {
        require(msg.sender == address(poolManager), "not pool manager");
        _;
    }

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    receive() external payable {}

    function unlockCallback(bytes calldata data)
        external
        onlyPoolManager
        returns (bytes memory)
    {
        uint256 action = _getAction();
        if (action == SWAP_EXACT_IN_SINGLE) {
            (address msgSender, ExactInputSingleParams memory params) =
                abi.decode(data, (address, ExactInputSingleParams));

            (int128 amount0, int128 amount1) = _swap(
                params.poolKey,
                params.zeroForOne,
                -(params.amountIn.toInt256()),
                params.hookData
            );

            (
                address currencyIn,
                address currencyOut,
                uint256 amountIn,
                uint256 amountOut
            ) = params.zeroForOne
                ? (
                    params.poolKey.currency0,
                    params.poolKey.currency1,
                    (-amount0).toUint256(),
                    amount1.toUint256()
                )
                : (
                    params.poolKey.currency1,
                    params.poolKey.currency0,
                    (-amount1).toUint256(),
                    amount0.toUint256()
                );

            require(amountOut >= params.amountOutMin, "amount out < min");

            _takeAndSettle({
                dst: msgSender,
                currencyIn: currencyIn,
                currencyOut: currencyOut,
                amountIn: amountIn,
                amountOut: amountOut
            });

            return abi.encode(amountOut);
        } else if (action == SWAP_EXACT_OUT_SINGLE) {
            (address msgSender, ExactOutputSingleParams memory params) =
                abi.decode(data, (address, ExactOutputSingleParams));

            (int128 amount0, int128 amount1) = _swap(
                params.poolKey,
                params.zeroForOne,
                params.amountOut.toInt256(),
                params.hookData
            );

            (
                address currencyIn,
                address currencyOut,
                uint256 amountIn,
                uint256 amountOut
            ) = params.zeroForOne
                ? (
                    params.poolKey.currency0,
                    params.poolKey.currency1,
                    (-amount0).toUint256(),
                    amount1.toUint256()
                )
                : (
                    params.poolKey.currency1,
                    params.poolKey.currency0,
                    (-amount1).toUint256(),
                    amount0.toUint256()
                );

            require(amountIn <= params.amountInMax, "amount in > max");

            _takeAndSettle({
                dst: msgSender,
                currencyIn: currencyIn,
                currencyOut: currencyOut,
                amountIn: amountIn,
                amountOut: amountOut
            });

            return abi.encode(amountIn);
        } else if (action == SWAP_EXACT_IN) {
            (address msgSender, ExactInputParams memory params) =
                abi.decode(data, (address, ExactInputParams));

            uint256 n = params.path.length;
            address currencyIn = params.currencyIn;
            int256 amountIn = params.amountIn.toInt256();
            for (uint256 i = 0; i < n; i++) {
                PathKey memory path = params.path[i];
                (address currency0, address currency1) = path.currency
                        < currencyIn
                    ? (path.currency, currencyIn)
                    : (currencyIn, path.currency);

                PoolKey memory key = PoolKey({
                    currency0: currency0,
                    currency1: currency1,
                    fee: path.fee,
                    tickSpacing: path.tickSpacing,
                    hooks: path.hooks
                });

                bool zeroForOne = currencyIn == currency0;

                (int128 amount0, int128 amount1) =
                    _swap(key, zeroForOne, -amountIn, path.hookData);

                currencyIn = path.currency;
                amountIn = (zeroForOne ? amount1 : amount0).toInt256();
            }

            require(
                uint256(amountIn) >= uint256(params.amountOutMin),
                "amount out < min"
            );

            _takeAndSettle({
                dst: msgSender,
                currencyIn: params.currencyIn,
                currencyOut: currencyIn,
                amountIn: params.amountIn,
                amountOut: uint256(amountIn)
            });

            return abi.encode(uint256(amountIn));
        } else if (action == SWAP_EXACT_OUT) {
            (address msgSender, ExactOutputParams memory params) =
                abi.decode(data, (address, ExactOutputParams));

            uint256 n = params.path.length;
            address currencyOut = params.currencyOut;
            int256 amountOut = params.amountOut.toInt256();
            for (uint256 i = n; i > 0; i--) {
                PathKey memory path = params.path[i - 1];
                (address currency0, address currency1) = path.currency
                        < currencyOut
                    ? (path.currency, currencyOut)
                    : (currencyOut, path.currency);

                PoolKey memory key = PoolKey({
                    currency0: currency0,
                    currency1: currency1,
                    fee: path.fee,
                    tickSpacing: path.tickSpacing,
                    hooks: path.hooks
                });

                bool zeroForOne = currencyOut == currency1;

                (int128 amount0, int128 amount1) =
                    _swap(key, zeroForOne, amountOut, path.hookData);

                currencyOut = path.currency;
                amountOut = (zeroForOne ? -amount0 : -amount1).toInt256();
            }

            require(
                uint256(amountOut) <= uint256(params.amountInMax),
                "amount in > max"
            );

            _takeAndSettle({
                dst: msgSender,
                currencyIn: currencyOut,
                currencyOut: params.currencyOut,
                amountIn: uint256(amountOut),
                amountOut: uint256(params.amountOut)
            });

            return abi.encode(uint256(amountOut));
        }
        revert UnsupportedAction(action);
    }

    function swapExactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        setAction(SWAP_EXACT_IN_SINGLE)
        returns (uint256 amountOut)
    {
        address currencyIn = params.zeroForOne
            ? params.poolKey.currency0
            : params.poolKey.currency1;
        currencyIn.transferIn(msg.sender, params.amountIn);

        bytes memory data = abi.encode(msg.sender, params);
        bytes memory res = poolManager.unlock(data);
        amountOut = abi.decode(res, (uint256));
        _refund(currencyIn, msg.sender);
        return amountOut;
    }

    function swapExactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        setAction(SWAP_EXACT_OUT_SINGLE)
        returns (uint256 amountIn)
    {
        address currencyIn = params.zeroForOne
            ? params.poolKey.currency0
            : params.poolKey.currency1;
        currencyIn.transferIn(msg.sender, params.amountInMax);

        bytes memory data = abi.encode(msg.sender, params);
        poolManager.unlock(data);

        uint256 refunded = _refund(currencyIn, msg.sender);
        if (refunded < params.amountInMax) {
            return params.amountInMax - refunded;
        }
        return 0;
    }

    function swapExactInput(ExactInputParams calldata params)
        external
        payable
        setAction(SWAP_EXACT_IN)
        returns (uint256 amountOut)
    {
        require(params.path.length > 0, "path length = 0");

        params.currencyIn.transferIn(msg.sender, params.amountIn);
        bytes memory res = poolManager.unlock(abi.encode(msg.sender, params));
        amountOut = abi.decode(res, (uint256));
        _refund(params.currencyIn, msg.sender);
    }

    function swapExactOutput(ExactOutputParams calldata params)
        external
        payable
        setAction(SWAP_EXACT_OUT)
        returns (uint256 amountIn)
    {
        require(params.path.length > 0, "path length = 0");

        PathKey memory path = params.path[0];
        address currencyIn = path.currency;

        currencyIn.transferIn(msg.sender, params.amountInMax);
        poolManager.unlock(abi.encode(msg.sender, params));

        uint256 refunded = _refund(currencyIn, msg.sender);
        if (refunded < params.amountInMax) {
            return params.amountInMax - refunded;
        }
        return 0;
    }

    function _refund(address currency, address dst) private returns (uint256) {
        uint256 bal = currency.balanceOf(address(this));
        if (bal > 0) {
            currency.transferOut(dst, bal);
        }
        return bal;
    }

    function _swap(
        PoolKey memory key,
        bool zeroForOne,
        int256 amountSpecified,
        bytes memory hookData
    ) private returns (int128 amount0, int128 amount1) {
        int256 d = poolManager.swap({
            key: key,
            params: SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne
                    ? MIN_SQRT_PRICE + 1
                    : MAX_SQRT_PRICE - 1
            }),
            hookData: hookData
        });
        BalanceDelta delta = BalanceDelta.wrap(d);
        return (delta.amount0(), delta.amount1());
    }

    function _takeAndSettle(
        address dst,
        address currencyIn,
        address currencyOut,
        uint256 amountIn,
        uint256 amountOut
    ) private {
        poolManager.take({currency: currencyOut, to: dst, amount: amountOut});

        poolManager.sync(currencyIn);

        if (currencyIn == address(0)) {
            poolManager.settle{value: amountIn}();
        } else {
            IERC20(currencyIn).transfer(address(poolManager), amountIn);
            poolManager.settle();
        }
    }
}
