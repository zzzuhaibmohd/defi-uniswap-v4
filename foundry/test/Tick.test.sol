// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";

int24 constant TICK_SPACING = 10;

contract TickLast {
    int24 tickLowerLast;

    function swap(int24 tick) public {
        (int24 tickLower, int24 lower, int24 upper) =
            getCrossedTicks(tick, TICK_SPACING, tickLowerLast);

        while (lower <= upper) {
            lower += TICK_SPACING;
        }

        tickLowerLast = tickLower;
    }

    function getCrossedTicks(int24 tick, int24 tickSpacing, int24 tickLowerLast)
        public
        pure
        returns (int24 tickLower, int24 lower, int24 upper)
    {
        tickLower = getTickLower(tick, tickSpacing);

        if (tickLowerLast <= tickLower) {
            lower = tickLowerLast;
            upper = tickLower - tickSpacing;
        } else {
            lower = tickLower + tickSpacing;
            upper = tickLowerLast;
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
        int24[5][10] memory tests = [
            // tick, tickLowerLast, tickLower, lower, upper
            [int24(1), 0, 0, 0, -TICK_SPACING],
            [TICK_SPACING, 0, TICK_SPACING, 0, 0],
            [TICK_SPACING + 1, 0, TICK_SPACING, 0, 0],
            [2 * TICK_SPACING, 0, 2 * TICK_SPACING, 0, TICK_SPACING],
            [2 * TICK_SPACING + 1, 0, 2 * TICK_SPACING, 0, TICK_SPACING],
            // TODO: correct?
            [int24(-1), 0, -TICK_SPACING, 0, 0],
            [-TICK_SPACING, 0, -TICK_SPACING, 0, 0],
            [-(TICK_SPACING + 1), 0, -2 * TICK_SPACING, -TICK_SPACING, 0],
            [-2 * TICK_SPACING, 0, -2 * TICK_SPACING, -TICK_SPACING, 0],
            [-(2 * TICK_SPACING + 1), 0, -3 * TICK_SPACING, -2 * TICK_SPACING, 0]
        ];

        for (uint256 i = 0; i < tests.length; i++) {
            int24 tick = tests[i][0];
            int24 tickLowerLast = tests[i][1];
            (int24 tickLower, int24 lower, int24 upper) =
                t.getCrossedTicks(tick, TICK_SPACING, tickLowerLast);
            assertEq(tickLower, tests[i][2], "tick lower");
            assertEq(lower, tests[i][3], "lower");
            assertEq(upper, tests[i][4], "upper");
        }
    }
}
