// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {POOL_MANAGER} from "../src/Constants.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {HookMiner} from "../src/libraries/HookMiner.sol";
import {CounterHook} from "@exercises/CounterHook.sol";

// TODO: script to find salt for CounterHook and exercise hook?
// NOTE: Only run in fork mode, the test may return an error with RPC rate limit
contract CounterHookAddressTest is Test {
    CounterHook hook;

    function setUp() public {
        (address addr, bytes32 salt) = HookMiner.find({
            deployer: address(this),
            flags: uint160(
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                    | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ),
            creationCode: type(CounterHook).creationCode,
            constructorArgs: abi.encode(POOL_MANAGER)
        });
        console.log("Hook address found:", addr);
        console.log("Hook salt:");
        console.logBytes32(salt);

        hook = new CounterHook{salt: salt}(POOL_MANAGER);
        console.log("Hook deployed address:", address(hook));

        assertEq(address(hook), addr);
    }

    function test_permissions() public {
        Hooks.validateHookPermissions(address(hook), hook.getHookPermissions());
    }
}
