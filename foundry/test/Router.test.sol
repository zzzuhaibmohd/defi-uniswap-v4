// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {
    POOL_MANAGER,
    POSITION_MANAGER,
    POOLS_SLOT,
    POOL_ID_ETH_USDT,
    POOL_ID_ETH_USDC,
    POOL_ID_ETH_WBTC,
    USDT,
    USDC,
    WBTC
} from "../src/Constants.sol";
import {TestHelper} from "./TestHelper.sol";
import {Router} from "@exercises/Router.sol";

contract RouterTest is Test, TestHelper {
    IERC20 constant usdc = IERC20(USDC);
    IERC20 constant wbtc = IERC20(WBTC);

    TestHelper helper;
    Router router;
    // Pool key for single hop swaps
    PoolKey poolKey;

    receive() external payable {}

    function setUp() public {
        helper = new TestHelper();

        deal(USDC, address(this), 1000 * 1e6);
        deal(WBTC, address(this), 1 * 1e8);
        router = new Router(POOL_MANAGER);

        usdc.approve(address(router), type(uint256).max);
        wbtc.approve(address(router), type(uint256).max);

        poolKey = PoolKey({
            currency0: address(0),
            currency1: USDC,
            fee: 500,
            tickSpacing: 10,
            hooks: address(0)
        });
    }

    // TODO: test unlock cannot be called

    /*
    function test_swapExactInputSingle_ETH_USDC() public {
        // Swap ETH to USDC
        helper.set("Before swap USDC", usdc.balanceOf(address(this)));
        helper.set("Before swap ETH", address(this).balance);

        uint128 amountIn = 1e18;
        uint256 amountOut = router.swapExactInputSingle{value: uint256(amountIn)}(Router.ExactInputSingleParams({
            poolKey: poolKey,
            zeroForOne: true,
            amountIn: amountIn,
            amountOutMin: 1,
            hookData: ""
        }));

        helper.set("After swap USDC", usdc.balanceOf(address(this)));
        helper.set("After swap ETH", address(this).balance);

        int256 d0 = helper.delta("After swap ETH", "Before swap ETH");
        int256 d1 = helper.delta("After swap USDC", "Before swap USDC");

        console.log("ETH delta: %e", d0);
        console.log("USDC delta: %e", d1);

        assertLt(d0, 0, "ETH delta");
        assertGt(d1, 0, "USDC delta");
        assertEq(amountOut, uint256(d1), "amount out");
    }

    function test_swapExactInputSingle_USDC_ETH() public {
        // Swap USDC to ETH
        helper.set("Before swap USDC", usdc.balanceOf(address(this)));
        helper.set("Before swap ETH", address(this).balance);

        uint128 amountIn = 1000 * 1e6;
        uint256 amountOut = router.swapExactInputSingle{value: uint256(amountIn)}(Router.ExactInputSingleParams({
            poolKey: poolKey,
            zeroForOne: false,
            amountIn: amountIn,
            amountOutMin: 1,
            hookData: ""
        }));

        helper.set("After swap USDC", usdc.balanceOf(address(this)));
        helper.set("After swap ETH", address(this).balance);

        int256 d0 = helper.delta("After swap ETH", "Before swap ETH");
        int256 d1 = helper.delta("After swap USDC", "Before swap USDC");

        console.log("ETH delta: %e", d0);
        console.log("USDC delta: %e", d1);

        assertGt(d0, 0, "ETH delta");
        assertLt(d1, 0, "USDC delta");
        assertApproxEqRel(amountOut, uint256(d0), 0.001e18, "amount out");
    }

    function test_swapExactOutputSingle_ETH_USDC() public {
        // Swap ETH to USDC
        helper.set("Before swap USDC", usdc.balanceOf(address(this)));
        helper.set("Before swap ETH", address(this).balance);

        uint128 amountInMax = 1e18;
        uint128 amountOut = 100 * 1e6;
        uint256 amountIn = router.swapExactOutputSingle{value: uint256(amountInMax)}(Router.ExactOutputSingleParams({
            poolKey: poolKey,
            zeroForOne: true,
            amountOut: amountOut,
            amountInMax: amountInMax,
            hookData: ""
        }));

        helper.set("After swap USDC", usdc.balanceOf(address(this)));
        helper.set("After swap ETH", address(this).balance);

        int256 d0 = helper.delta("After swap ETH", "Before swap ETH");
        int256 d1 = helper.delta("After swap USDC", "Before swap USDC");

        console.log("ETH delta: %e", d0);
        console.log("USDC delta: %e", d1);

        assertLt(d0, 0, "ETH delta");
        assertGt(d1, 0, "USDC delta");
        assertApproxEqRel(amountIn, uint256(-d0), 0.001e18, "amount in != delta");
        assertLe(amountIn, amountInMax, "amount in > max");
        assertEq(amountOut, uint256(d1), "amount out");
    }

    function test_swapExactOutputSingle_USDC_ETH() public {
        // Swap USDC to ETH
        helper.set("Before swap USDC", usdc.balanceOf(address(this)));
        helper.set("Before swap ETH", address(this).balance);

        uint128 amountInMax = 1000 * 1e6;
        uint128 amountOut = 0.01e18;
        uint256 amountIn = router.swapExactOutputSingle{value: uint256(amountInMax)}(Router.ExactOutputSingleParams({
            poolKey: poolKey,
            zeroForOne: false,
            amountOut: amountOut,
            amountInMax: amountInMax,
            hookData: ""
        }));

        helper.set("After swap USDC", usdc.balanceOf(address(this)));
        helper.set("After swap ETH", address(this).balance);

        int256 d0 = helper.delta("After swap ETH", "Before swap ETH");
        int256 d1 = helper.delta("After swap USDC", "Before swap USDC");

        console.log("ETH delta: %e", d0);
        console.log("USDC delta: %e", d1);

        assertGt(d0, 0, "ETH delta");
        assertLt(d1, 0, "USDC delta");
        assertEq(amountIn, uint256(-d1), "amount in != delta");
        assertLe(amountIn, amountInMax, "amount in > max");
        assertApproxEqRel(amountOut, uint256(d0), 0.001e18, "amount out");
    }
    */

    function test_swapExactInput_USDC_ETH_WBTC() public {
        // Swap USDC -> ETH -> WBTC
        helper.set("Before swap USDC", usdc.balanceOf(address(this)));
        helper.set("Before swap WBTC", wbtc.balanceOf(address(this)));

        Router.PathKey[] memory path = new Router.PathKey[](2);
        path[0] = Router.PathKey({
            currency: address(0),
            fee: 500,
            tickSpacing: 10,
            hooks: address(0),
            hookData: ""
        });
        path[1] = Router.PathKey({
            currency: WBTC,
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0),
            hookData: ""
        });

        uint128 amountIn = 1000 * 1e6;
        uint256 amountOut = router.swapExactInput(Router.ExactInputParams({
            currencyIn: USDC,
            path: path,
            amountIn: amountIn,
            amountOutMin: 1
        }));

        helper.set("After swap USDC", usdc.balanceOf(address(this)));
        helper.set("After swap WBTC", wbtc.balanceOf(address(this)));

        int256 d0 = helper.delta("After swap USDC", "Before swap USDC");
        int256 d1 = helper.delta("After swap WBTC", "Before swap WBTC");

        console.log("USDC delta: %e", d0);
        console.log("WBTC delta: %e", d1);

        assertLt(d0, 0, "USDC delta");
        assertGt(d1, 0, "WBTC delta");
        assertEq(amountOut, uint256(d1), "amount out");
    }

    function test_swapExactOutput() public {}
}
