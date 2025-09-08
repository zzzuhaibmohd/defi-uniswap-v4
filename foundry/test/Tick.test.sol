// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";

// Tick spacing
int24 constant S = 10;

contract TickLast {
    function getTickRange(int24 tick0, int24 tick1, int24 tickSpacing)
        public
        pure
        returns (int24 lower, int24 upper)
    {
        // Last lower tick
        int24 l0 = getTickLower(tick0, tickSpacing);
        // Current lower tick
        int24 l1 = getTickLower(tick1, tickSpacing);

        if (tick0 <= tick1) {
            lower = l0;
            upper = l1 - tickSpacing;
        } else {
            lower = l1 + tickSpacing;
            upper = l0;
        }
    }

    function getTickLower(int24 tick, int24 tickSpacing)
        private
        pure
        returns (int24)
    {
        int24 compressed = tick / tickSpacing;
        // Round towards negative infinity
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }
}

contract TickLastTest is Test {
    TickLast t;

    function setUp() public {
        t = new TickLast();
    }

    function test() public {
        int24[4][24] memory tests = [
            // tick 0 <= tick 1
            [int24(0), 0, 0, -10],
            [int24(0), 1, 0, -10],
            [int24(0), 10, 0, 0],
            [int24(0), 11, 0, 0],
            [int24(0), 20, 0, 10],
            [int24(0), 21, 0, 10],
            // tick 0 <= tick 1
            [int24(1), 1, 0, -10],
            [int24(1), 2, 0, -10],
            [int24(1), 10, 0, 0],
            [int24(1), 11, 0, 0],
            [int24(1), 20, 0, 10],
            [int24(1), 21, 0, 10],
            // tick 1 > tick 0
            [int24(0), 0, 0, -10],
            [int24(0), -1, 0, 0],
            [int24(0), -10, 0, 0],
            [int24(0), -11, -10, 0],
            [int24(0), -20, -10, 0],
            [int24(0), -21, -20, 0],
            // tick 1 > tick 0
            [int24(-1), -1, -10, -20],
            [int24(-1), -2, 0, -10],
            [int24(-1), -10, 0, -10],
            [int24(-1), -11, -10, -10],
            [int24(-1), -20, -10, -10],
            [int24(-1), -21, -20, -10]
        ];

        for (uint256 i = 0; i < tests.length; i++) {
            int24 tickLast = tests[i][0];
            int24 tick = tests[i][1];
            (int24 lower, int24 upper) = t.getTickRange(tickLast, tick, S);
            // console.log("i", i);
            assertEq(lower, tests[i][2], "lower");
            assertEq(upper, tests[i][3], "upper");
        }
    }

    function test_fuzz(int24 t0, int24 t1) public {
        t0 = int24(bound(t0, -1000, 1000));
        t1 = int24(bound(t1, -1000, 1000));

        (int24 lower, int24 upper) = t.getTickRange(t0, t1, S);

        int24 dt = 0;
        if (t0 <= t1) {
            dt = t1 - t0;
        } else {
            dt = t0 - t1;
        }

        if (dt > S) {
            assertGe(upper - lower, 0);
        }
    }
}
