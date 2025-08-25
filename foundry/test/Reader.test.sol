// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {POOL_MANAGER, USDC} from "../src/Constants.sol";
import {Reader} from "@exercises/Reader.sol";

/*
forge test --fork-url $FORK_URL --match-path test/Reader.test.sol -vvvv
*/
contract ReaderTest is Test {
    IPoolManager constant poolManager = IPoolManager(POOL_MANAGER);
    IERC20 constant usdc = IERC20(USDC);
    Reader reader;

    function setUp() public {
        reader = new Reader(POOL_MANAGER);
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        int256 d;
        d = reader.getCurrencyDelta(address(this), USDC);
        console.log("Before take: %e", d);
        assertEq(d, 0);

        poolManager.take(USDC, address(this), 100 * 1e6);

        d = reader.getCurrencyDelta(address(this), USDC);
        console.log("After take: %e", d);
        assertLt(d, 0);

        poolManager.sync(USDC);

        usdc.transfer(address(poolManager), 100 * 1e6);
        poolManager.settle();

        d = reader.getCurrencyDelta(address(this), USDC);
        console.log("After settle: %e", d);
        assertEq(d, 0);

        return "";
    }

    function test_read() public {
        poolManager.unlock("");
    }
}
