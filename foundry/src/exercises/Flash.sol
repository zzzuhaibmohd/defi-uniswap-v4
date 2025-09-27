// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// import {console} from "forge-std/Test.sol";

import {IERC20} from "../interfaces/IERC20.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {IUnlockCallback} from "../interfaces/IUnlockCallback.sol";
import {CurrencyLib} from "../libraries/CurrencyLib.sol";

contract Flash is IUnlockCallback {
    using CurrencyLib for address;

    IPoolManager public immutable poolManager;
    // Contract address to test flash loan
    address private immutable tester;

    modifier onlyPoolManager() {
        require(msg.sender == address(poolManager), "not pool manager");
        _;
    }

    constructor(address _poolManager, address _tester) {
        poolManager = IPoolManager(_poolManager);
        tester = _tester;
    }

    receive() external payable {}

    function unlockCallback(bytes calldata data)
        external
        onlyPoolManager
        returns (bytes memory)
    {
        (address currency, uint256 amount) =
            abi.decode(data, (address, uint256));
        // 1. Take the currency from the pool manager
        poolManager.take(currency, address(this), amount);
        // 2. Call the tester contract to check if the currency was taken
        (bool ok,) = tester.call("");
        require(ok, "test failed");
        // 3. Sync the currency
        poolManager.sync(currency);
        // 4. Transfer the currency back to the pool manager (Since we are borrowing USDC)
        if (currency == address(0)) {
            poolManager.settle{value: amount}();
        } else {
            IERC20(currency).transfer(address(poolManager), amount);
            poolManager.settle();
        }
        // 5. Settle the currency
        poolManager.settle();
        return "";
    }

    function flash(address currency, uint256 amount) external {
        bytes memory data = abi.encode(currency, amount);
        poolManager.unlock(data);
    }
}

// Run the test
// forge test --fork-url $FORK_URL --match-path test/Flash.test.sol -vvv
