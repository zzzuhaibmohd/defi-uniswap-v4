// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract TStore {
    bytes32 constant SLOT = 0;

    modifier setAction(uint256 action) {
        // Use as re-entrancy guard
        require(_getAction() == 0, "locked");
        require(action > 0, "action = 0");
        _setAction(action);
        _;
        _setAction(0);
    }

    function _setAction(uint256 action) internal {
        assembly {
            tstore(SLOT, action)
        }
    }

    function _getAction() internal view returns (uint256 action) {
        assembly {
            action := tload(SLOT)
        }
    }
}
