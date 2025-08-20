// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PoolKey} from "./types/PoolKey.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {IUnlockCallback} from "./interfaces/IUnlockCallback.sol";

contract Router is IUnlockCallback {
    IPoolManager public immutable poolManager;

    // Actions
    uint256 internal constant SWAP_EXACT_IN_SINGLE = 0x06;
    uint256 internal constant SWAP_EXACT_IN = 0x07;
    uint256 internal constant SWAP_EXACT_OUT_SINGLE = 0x08;
    uint256 internal constant SWAP_EXACT_OUT = 0x09;

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
        uint128 amountOutMinimum;
        bytes hookData;
    }

    struct ExactInputParams {
        address currencyIn;
        PathKey[] path;
        uint128 amountIn;
        uint128 amountOutMinimum;
    }

    struct ExactOutputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountOut;
        uint128 amountInMaximum;
        bytes hookData;
    }

    struct ExactOutputParams {
        address currencyOut;
        PathKey[] path;
        uint128 amountOut;
        uint128 amountInMaximum;
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
        // TODO: transient storage
        uint256 action = 0;

        if (action == SWAP_EXACT_IN_SINGLE) {
            // decode
        } else if (action == SWAP_EXACT_IN) {
            // decode
        } else if (action == SWAP_EXACT_OUT_SINGLE) {
            // decode
        } else if (action == SWAP_EXACT_OUT) {
            // decode
        }

        revert UnsupportedAction(action);
    }

    function swapExactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
    {
        // Transfer token in from msg.sender
        // Unlock
        // Swap
        // Check amount out > min
    }

    function swapExactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
    {
        // Transfer token in from msg.sender
        // Unlock
        // Swap
        // Check amount out > min
    }
    function swapExactInput(ExactInputParams calldata params)
        external
        payable
    {}
    function swapExactOutput(ExactOutputParams calldata params)
        external
        payable
    {}
}
