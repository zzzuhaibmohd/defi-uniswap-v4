import {Script, console} from "forge-std/Script.sol";
import {POOL_MANAGER} from "../src/Constants.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {CounterHook} from "@exercises/CounterHook.sol";

/*
Script to print out creation code and constructor inputs for CounterHook

forge script script/CounterHookCode.s.sol -vvv
*/
contract CounterHookCode is Script {
    function run() public {
        bytes memory code = type(CounterHook).creationCode;
        bytes memory args = abi.encode(POOL_MANAGER);
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        console.log("--- Creation code ---");
        console.logBytes(code);
        console.log("--- Constructor args ---");
        console.logBytes(args);
        console.log("Flags:", flags);
    }
}
