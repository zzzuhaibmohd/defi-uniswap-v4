// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPoolManager} from "../interfaces/IPoolManager.sol";

contract Reader {
    IPoolManager public immutable poolManager;

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    function computeSlot(address target, address currency)
        public
        pure
        returns (bytes32 slot)
    {
        assembly ("memory-safe") {
            mstore(0, and(target, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(
                32,
                and(currency, 0xffffffffffffffffffffffffffffffffffffffff)
            )
            slot := keccak256(0, 64)
        }
    }

    function getCurrencyDelta(address target, address currency)
        public
        view
        returns (int256 delta)
    {
        // 1. Compute the slot
        bytes32 slot = computeSlot(target, currency);
        // 2. Load the slot from the pool manager
        return int256(uint256(poolManager.exttload(slot)));
    }
}

// Run the test
// forge test --fork-url $FORK_URL --match-path test/Reader.test.sol -vvv
