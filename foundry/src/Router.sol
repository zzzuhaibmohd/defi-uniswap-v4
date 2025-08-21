// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "./interfaces/IERC20.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {IUnlockCallback} from "./interfaces/IUnlockCallback.sol";
import {PoolKey} from "./types/PoolKey.sol";
import {SwapParams} from "./types/PoolOperation.sol";
import {
    BalanceDelta, BalanceDeltaLibrary
} from "../src/types/BalanceDelta.sol";
import {SafeCast} from "./libraries/SafeCast.sol";
import {MIN_SQRT_PRICE, MAX_SQRT_PRICE} from "./Constants.sol";

contract TStore {
    bytes32 constant SLOT = 0;

    modifier setAction(uint256 action) {
        // Use as re-entrancy guard
        require(_getAction() == 0, "locked");
        require(action > 0, "action = 0");
        _setAction(action);
        _;
        _setAction(0);
    }

    function _setAction(uint256 action) internal {
        assembly {
            tstore(SLOT, action)
        }
    }

    function _getAction() internal view returns (uint256 action) {
        assembly {
            action := tload(SLOT)
        }
    }
}

library CurrencyLib {
    function transferIn(address currency, address src, uint256 amount)
        internal
    {
        if (currency == address(0)) {
            require(amount == msg.value, "msg.value != amount");
        } else {
            IERC20(currency).transferFrom(src, address(this), amount);
        }
    }

    function transferOut(address currency, address dst, uint256 amount)
        internal
    {
        if (currency == address(0)) {
            (bool ok,) = dst.call{value: amount}("");
        } else {
            IERC20(currency).transfer(dst, amount);
        }
    }

    function balanceOf(address currency, address account)
        internal
        view
        returns (uint256)
    {
        if (currency == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(currency).balanceOf(address(this));
        }
    }
}

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

    struct PathKey {
        address currency;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
        bytes hookData;
    }

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

    struct ExactInputParams {
        address currencyIn;
        PathKey[] path;
        uint128 amountIn;
        uint128 amountOutMin;
    }

    struct ExactOutputParams {
        address currencyOut;
        PathKey[] path;
        uint128 amountOut;
        uint128 amountInMax;
    }

    error UnsupportedAction(uint256 action);

    modifier onlyPoolManager() {
        require(msg.sender != address(poolManager), "not pool manager");
        _;
    }

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    receive() external payable {}

    // TODO: how to get msg.sender
    function unlockCallback(bytes calldata data)
        external
        onlyPoolManager
        returns (bytes memory)
    {
        uint256 action = _getAction();

        if (action == SWAP_EXACT_IN_SINGLE) {
            (address msgSender, ExactInputSingleParams memory params) =
                abi.decode(data, (address, ExactInputSingleParams));
            require(msgSender != address(0), "msg sender = address(0)");

            (int128 amount0, int128 amount1) = _swap(
                params.poolKey,
                params.zeroForOne,
                -(params.amountIn.toInt256()),
                params.hookData
            );

            if (params.zeroForOne) {
                uint256 a1 = amount1.toUint256();
                require(a1 >= params.amountOutMin, "amount1 < min out");
                poolManager.take({
                    currency: params.poolKey.currency1,
                    to: msgSender,
                    amount: a1
                });

                poolManager.sync(params.poolKey.currency0);
                _settle(params.poolKey.currency0, (-amount0).toUint256());
            } else {
                uint256 a0 = amount0.toUint256();
                require(a0 >= params.amountOutMin, "amount0 < min out");
                poolManager.take({
                    currency: params.poolKey.currency0,
                    to: msgSender,
                    amount: a0
                });

                poolManager.sync(params.poolKey.currency1);
                _settle(params.poolKey.currency1, (-amount1).toUint256());
            }
        } else if (action == SWAP_EXACT_OUT_SINGLE) {
            (address msgSender, ExactOutputSingleParams memory params) =
                abi.decode(data, (address, ExactOutputSingleParams));
            require(msgSender != address(0), "msg sender = address(0)");

            (int128 amount0, int128 amount1) = _swap(
                params.poolKey,
                params.zeroForOne,
                params.amountOut.toInt256(),
                params.hookData
            );

            if (params.zeroForOne) {
                require(amount0 <= 0, "amount 0 > 0");
                uint256 a0 = (-amount0).toUint256();
                require(a0 <= params.amountInMax, "amount0 > max in");

                poolManager.take({
                    currency: params.poolKey.currency1,
                    to: msgSender,
                    amount: amount1.toUint256()
                });

                poolManager.sync(params.poolKey.currency0);
                _settle(params.poolKey.currency0, a0);
            } else {
                require(amount1 <= 0, "amount 1 > 0");
                uint256 a1 = (-amount1).toUint256();
                require(a1 <= params.amountInMax, "amount1 > max in");

                poolManager.take({
                    currency: params.poolKey.currency0,
                    to: msgSender,
                    amount: amount0.toUint256()
                });

                poolManager.sync(params.poolKey.currency1);
                _settle(params.poolKey.currency1, a1);
            }
        } else if (action == SWAP_EXACT_IN) {
            ExactInputParams memory params =
                abi.decode(data, (ExactInputParams));
        } else if (action == SWAP_EXACT_OUT) {
            ExactOutputParams memory params =
                abi.decode(data, (ExactOutputParams));
        }

        revert UnsupportedAction(action);
    }

    function swapExactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        setAction(SWAP_EXACT_IN_SINGLE)
    {
        address currencyIn = params.zeroForOne
            ? params.poolKey.currency0
            : params.poolKey.currency1;
        currencyIn.transferIn(msg.sender, params.amountIn);

        poolManager.unlock(abi.encode(msg.sender, params));

        uint256 bal = currencyIn.balanceOf(address(this));
        if (bal > 0) {
            currencyIn.transferOut(msg.sender, bal);
        }
    }

    function swapExactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        setAction(SWAP_EXACT_OUT_SINGLE)
    {
        address currencyIn = params.zeroForOne
            ? params.poolKey.currency0
            : params.poolKey.currency1;
        currencyIn.transferIn(msg.sender, params.amountInMax);

        poolManager.unlock(abi.encode(msg.sender, params));

        uint256 bal = currencyIn.balanceOf(address(this));
        if (bal > 0) {
            currencyIn.transferOut(msg.sender, bal);
        }
    }

    function swapExactInput(ExactInputParams calldata params)
        external
        payable
        setAction(SWAP_EXACT_IN)
    {}

    function swapExactOutput(ExactOutputParams calldata params)
        external
        payable
        setAction(SWAP_EXACT_OUT)
    {}

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
                // amountSpecified < 0 = amount in
                // amountSpecified > 0 = amount out
                amountSpecified: amountSpecified,
                // price = Currency 1 / currency 0
                // 0 for 1 = price decreases
                // 1 for 0 = price increases
                sqrtPriceLimitX96: zeroForOne ? MIN_SQRT_PRICE + 1 : MAX_SQRT_PRICE - 1
            }),
            hookData: hookData
        });
        BalanceDelta delta = BalanceDelta.wrap(d);
        return (delta.amount0(), delta.amount1());
        /*
        if (params.zeroForOne) {
            require(amount1 >= 0, "amount1 < 0");
            poolManager.take({
                currency: key.currency1,
                to: address(this),
                amount: amount1.toUint256()
            });

            poolManager.sync(key.currency0);
            _settle(key.currency0, (-amount0).toUint256());
        } else {
            require(amount0 >= 0, "amount0 < 0");
            poolManager.take({
                currency: key.currency0,
                to: address(this),
                amount: amount0.toUint256()
            });

            poolManager.sync(key.currency1);
            _settle(key.currency1, (-amount1).toUint256());
        }
        */
    }

    function _settle(address currency, uint256 amount) private {
        if (currency == address(0)) {
            poolManager.settle{value: amount}();
        } else {
            IERC20(currency).transfer(address(poolManager), amount);
            poolManager.settle();
        }
    }
}
