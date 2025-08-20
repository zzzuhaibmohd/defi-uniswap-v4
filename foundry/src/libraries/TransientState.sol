// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPoolManager} from "../interfaces/IPoolManager.sol";

library TransientState {
    function currencyDelta(
        IPoolManager manager,
        address target,
        address currency
    ) internal view returns (int256) {
        bytes32 key;
        assembly ("memory-safe") {
            mstore(0, and(target, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(
                32, and(currency, 0xffffffffffffffffffffffffffffffffffffffff)
            )
            key := keccak256(0, 64)
        }
        return int256(uint256(manager.exttload(key)));
    }
}
