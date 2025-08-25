// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";

/*
Difference between transient storage and storage (state variables)
- Transient storages use lower gas
- Stored value resets after every transaction
- Use cases: re-entrancy lock, storing context for callbacks

forge test --match-path src/examples/transient_storage.sol -vvv
*/

contract StateStorage {
    uint256 val;

    function set(uint256 v) public {
        val = v;
    }

    function get() public view returns (uint256) {
        return val;
    }
}

contract TransientStorage {
    bytes32 constant SLOT = 0;

    function set(uint256 val) public {
        assembly {
            tstore(SLOT, val)
        }
    }

    function get() public view returns (uint256 val) {
        assembly {
            val := tload(SLOT)
        }
    }
}

contract Example_state_storage is Test {
    StateStorage s;

    function setUp() public {
        s = new StateStorage();

        console.log("--- State ---");
        console.log("get:", s.get());
        s.set(1);
        console.log("get:", s.get());
        console.log("--------------");
    }

    function test_again() public {
        console.log("get:", s.get());
        s.set(2);
        console.log("get:", s.get());
    }
}

contract Example_transient_storage is Test {
    TransientStorage t;

    function setUp() public {
        t = new TransientStorage();

        console.log("--- Transient ---");
        console.log("get:", t.get());
        t.set(1);
        console.log("get:", t.get());
        console.log("--------------");
    }

    function test_again() public {
        console.log("get:", t.get());
        t.set(2);
        console.log("get:", t.get());
    }
}
