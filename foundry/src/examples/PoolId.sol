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
forge test --match-path src/examples/PoolId.sol -vvv
*/
contract Example_PoolId is Test {
    function test() public {
        PoolKey memory key = PoolKey({
            currency0: address(0),
            currency1: WBTC,
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });

        PoolId id = PoolIdLibrary.toId(key);

        console.log("--- Pool id ---");
        console.logBytes32(PoolId.unwrap(id));

        assertEq(POOL_ID_ETH_WBTC, PoolId.unwrap(id));
    }
}
