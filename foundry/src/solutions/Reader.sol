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
                32, and(currency, 0xffffffffffffffffffffffffffffffffffffffff)
            )
            slot := keccak256(0, 64)
        }
    }

    function getCurrencyDelta(address target, address currency)
        public
        view
        returns (int256 delta)
    {
        bytes32 slot = computeSlot(target, currency);
        return int256(uint256(poolManager.exttload(slot)));
    }
}
