// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PoolKey} from "../types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "./PoolId.sol";

type PositionInfo is uint256;

using PositionInfoLibrary for PositionInfo global;
using PoolIdLibrary for PoolKey;

library PositionInfoLibrary {
    PositionInfo internal constant EMPTY_POSITION_INFO = PositionInfo.wrap(0);

    uint256 internal constant MASK_UPPER_200_BITS =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000;
    uint256 internal constant MASK_8_BITS = 0xFF;
    uint24 internal constant MASK_24_BITS = 0xFFFFFF;
    uint256 internal constant SET_UNSUBSCRIBE =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00;
    uint256 internal constant SET_SUBSCRIBE = 0x01;
    uint8 internal constant TICK_LOWER_OFFSET = 8;
    uint8 internal constant TICK_UPPER_OFFSET = 32;

    /// @dev This poolId is NOT compatible with the poolId used in UniswapV4 core. It is truncated to 25 bytes, and just used to lookup PoolKey in the poolKeys mapping.
    function poolId(PositionInfo info)
        internal
        pure
        returns (bytes25 _poolId)
    {
        assembly ("memory-safe") {
            _poolId := and(MASK_UPPER_200_BITS, info)
        }
    }

    function tickLower(PositionInfo info)
        internal
        pure
        returns (int24 _tickLower)
    {
        assembly ("memory-safe") {
            _tickLower := signextend(2, shr(TICK_LOWER_OFFSET, info))
        }
    }

    function tickUpper(PositionInfo info)
        internal
        pure
        returns (int24 _tickUpper)
    {
        assembly ("memory-safe") {
            _tickUpper := signextend(2, shr(TICK_UPPER_OFFSET, info))
        }
    }

    function hasSubscriber(PositionInfo info)
        internal
        pure
        returns (bool _hasSubscriber)
    {
        assembly ("memory-safe") {
            _hasSubscriber := and(MASK_8_BITS, info)
        }
    }

    function setSubscribe(PositionInfo info)
        internal
        pure
        returns (PositionInfo _info)
    {
        assembly ("memory-safe") {
            _info := or(info, SET_SUBSCRIBE)
        }
    }

    function setUnsubscribe(PositionInfo info)
        internal
        pure
        returns (PositionInfo _info)
    {
        assembly ("memory-safe") {
            _info := and(info, SET_UNSUBSCRIBE)
        }
    }

    function initialize(
        PoolKey memory _poolKey,
        int24 _tickLower,
        int24 _tickUpper
    ) internal pure returns (PositionInfo info) {
        bytes25 _poolId = bytes25(PoolId.unwrap(_poolKey.toId()));
        assembly {
            info :=
                or(
                    or(
                        and(MASK_UPPER_200_BITS, _poolId),
                        shl(TICK_UPPER_OFFSET, and(MASK_24_BITS, _tickUpper))
                    ),
                    shl(TICK_LOWER_OFFSET, and(MASK_24_BITS, _tickLower))
                )
        }
    }
}
