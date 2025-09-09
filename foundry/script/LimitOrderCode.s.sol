// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {POOL_MANAGER} from "../src/Constants.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {LimitOrder} from "@exercises/LimitOrder.sol";

/*
Script to print out creation code and constructor inputs for LimitOrder

forge script script/LimitOrderCode.s.sol -vvv
*/
contract LimitOrderCode is Script {
    function run() public {
        bytes memory code = type(LimitOrder).creationCode;
        bytes memory args = abi.encode(POOL_MANAGER);
        uint160 flags =
            uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG);
        console.log("--- Creation code ---");
        console.logBytes(code);
        console.log("--- Constructor args ---");
        console.logBytes(args);
        console.log("Flags:", flags);
    }
}
