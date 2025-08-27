// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {POOL_MANAGER, USDC} from "../src/Constants.sol";
import {TestHelper} from "./TestHelper.sol";
import {Flash} from "@exercises/Flash.sol";

contract Check {
    address immutable coin;
    uint256 public val;

    constructor(address _coin) {
        coin = _coin;
    }

    fallback() external {
        val = IERC20(coin).balanceOf(msg.sender);
    }
}

contract FlashTest is Test, TestHelper {
    IERC20 constant usdc = IERC20(USDC);

    TestHelper helper;
    Check check;
    Flash flash;

    receive() external payable {}

    function setUp() public {
        helper = new TestHelper();
        check = new Check(USDC);
        flash = new Flash(POOL_MANAGER, address(check));
    }

    function test_flash() public {
        flash.flash(USDC, 1000 * 1e6);
        uint256 amount = check.val();
        console.log("Borrowed amount: %e USDC", amount);
        assertEq(amount, 1000 * 1e6);
    }
}
