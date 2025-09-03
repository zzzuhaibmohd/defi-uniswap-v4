// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {HookMiner} from "../src/libraries/HookMiner.sol";

/*
Script to find valid Hooks address
NOTE: Don't run in fork mode, the test may hit the RPC rate limit and return an error

export CODE=
export ARGS=
export FLAGS=

forge test --match-path test/HookAddr.test.sol
*/
contract HookAddr is Test {
    function test() public {
        address deployer = address(this);
        bytes memory code = vm.envBytes("CODE");
        bytes memory args = vm.envBytes("ARGS");
        uint160 flags = uint160(vm.envUint("FLAGS"));

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
    }
}
