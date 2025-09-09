// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {HookMiner} from "../src/libraries/HookMiner.sol";
import {POOL_MANAGER} from "../src/Constants.sol";
import {CounterHook} from "@exercises/CounterHook.sol";
import {LimitOrder} from "@exercises/LimitOrder.sol";

/*
Script to find valid Hooks address
NOTE: Don't run in fork mode, the test may hit the RPC rate limit and return an error

forge test --match-path test/FindHookSalt.test.sol -vvv
*/
contract FindHookSalt is Test {
    function find(
        address deployer,
        bytes memory code,
        bytes memory args,
        uint160 flags
    ) private returns (address, bytes32) {
        (address addr, bytes32 salt) = HookMiner.find({
            deployer: deployer,
            flags: flags,
            creationCode: code,
            constructorArgs: args
        });

        console.log("Deployer:", deployer);
        console.log("Hook address:", addr);
        console.log("Hook salt:");
        console.logBytes32(salt);

        return (addr, salt);
    }

    function test_counter_hook() public {
        (address addr, bytes32 salt) = find(
            address(this),
            type(CounterHook).creationCode,
            abi.encode(POOL_MANAGER),
            uint160(
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                    | Hooks.AFTER_SWAP_FLAG
            )
        );

        assertEq(addr, address(new CounterHook{salt: salt}(POOL_MANAGER)));
    }

    function test_limit_order() public {
        (address addr, bytes32 salt) = find(
            address(this),
            type(LimitOrder).creationCode,
            abi.encode(POOL_MANAGER),
            uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG)
        );
        assertEq(addr, address(new LimitOrder{salt: salt}(POOL_MANAGER)));
    }
}
