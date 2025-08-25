// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "../libraries/PoolId.sol";
import {
    POOL_ID_ETH_USDT,
    POOL_ID_ETH_USDC,
    POOL_ID_ETH_WBTC,
    USDT,
    USDC,
    WBTC
} from "../Constants.sol";

/*
- PoolId = keccak256(PoolKey)
- User defined value types
  - wrap() to convert value type into user defined value type
  - unwrap() to convert value type into user defined value type

forge test --match-path src/examples/pool_id.sol -vvv
*/
contract Example_PoolId is Test {
    function test() public pure {
        PoolKey memory key = PoolKey({
            currency0: address(0),
            currency1: WBTC,
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });

        PoolId id = PoolIdLibrary.toId(key);

        console.log("--- Pool id ---");

        // unwrap() to convert PoolId into bytes32
        bytes32 i = PoolId.unwrap(id);
        // wrap() to convert bytes32 into PoolId
        PoolId p = PoolId.wrap(i);

        console.logBytes32(i);

        assertEq(POOL_ID_ETH_WBTC, PoolId.unwrap(id));
    }
}
