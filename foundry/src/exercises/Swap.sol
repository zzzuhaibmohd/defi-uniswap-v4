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

contract Swap is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeCast for int128;
    using SafeCast for uint128;
    using CurrencyLib for address;

    IPoolManager public immutable poolManager;

    struct SwapExactInputSingleHop {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMin;
    }

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
        // 1. Decode the data
        (address msgSender, SwapExactInputSingleHop memory params) =
            abi.decode(data, (address, SwapExactInputSingleHop));

        // 2. Call the swap function
        int256 d = poolManager.swap({
            key: params.poolKey,
            params: SwapParams({
                zeroForOne: params.zeroForOne,
                amountSpecified: -(params.amountIn.toInt256()), // (-) because the user owes the amount, its (+) for the pool manager owes the amount to the user
                sqrtPriceLimitX96: params.zeroForOne
                    ? MIN_SQRT_PRICE + 1
                    : MAX_SQRT_PRICE - 1
            }),
            hookData: ""
        });

        // 3. Calculate the amount of currency in and out
        BalanceDelta delta = BalanceDelta.wrap(d);
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

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

        // 4. Take the currency out from the pool manager
        poolManager.take({
            currency: currencyOut, to: msgSender, amount: amountOut
        });

        // 5. Sync the currency in and settle the pool manager
        poolManager.sync(currencyIn);

        if (currencyIn == address(0)) {
            poolManager.settle{value: amountIn}();
        } else {
            IERC20(currencyIn).transfer(address(poolManager), amountIn);
            poolManager.settle();
        }

        return "";
    }

    function swap(SwapExactInputSingleHop calldata params) external payable {
        // The currency to take from the caller
        address currencyIn = params.zeroForOne
            ? params.poolKey.currency0
            : params.poolKey.currency1;
        currencyIn.transferIn(msg.sender, params.amountIn);
        bytes memory data = abi.encode(msg.sender, params);
        poolManager.unlock(data);

        //If excess, refund the caller
        uint256 bal = currencyIn.balanceOf(address(this));
        if (bal > 0) {
            currencyIn.transferOut(msg.sender, bal);
        }
    }
}

// Run the test
// forge test --fork-url $FORK_URL --match-path test/Swap.test.sol -vvv
