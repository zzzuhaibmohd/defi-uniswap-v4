// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {IPositionManager} from "../src/interfaces/IPositionManager.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "../src/libraries/PoolId.sol";
import {
    POOL_MANAGER,
    POSITION_MANAGER,
    POOLS_SLOT,
    POOL_ID_ETH_USDT,
    USDT,
    USDC
} from "../src/Constants.sol";

/*
forge test --fork-url $FORK_URL --match-path test/dev.sol -vvvv
*/
contract Dev is Test {
    IPoolManager constant poolManager = IPoolManager(POOL_MANAGER);
    IPositionManager constant posm = IPositionManager(POSITION_MANAGER);
    bytes32 POOL_ID = POOL_ID_ETH_USDT;

    function setUp() public {}

    function test() public {
       // TODO: swap from pool manager

        /*
       Pool id and Pool key
        PoolKey memory key = PoolKey({
            currency0: address(0),
            currency1: USDT,
            fee: 500,
            tickSpacing: 10,
            hooks: address(0)
        });

        PoolId id = PoolIdLibrary.toId(key);

        console.log("ETH/USDT pool id");
        console.logBytes32(PoolId.unwrap(id));

        assertEq(POOL_ID_ETH_USDT, PoolId.unwrap(id));
        */


        /*
        // TODO: read from Pool.extsload
        // slot of value = keccak256(key, slot where mapping is declared)
        bytes32 slot = keccak256(abi.encode(POOL_ID, POOLS_SLOT));
        bytes32[] memory vals = poolManager.extsload(slot, 3);
        console.logBytes32(vals[0]);
        console.logBytes32(vals[1]);
        */

    }
}
