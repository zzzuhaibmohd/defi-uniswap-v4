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

        // Borrow
        poolManager.take({currency: currency, to: address(this), amount: amount});

        // You would write your flash loan logic here
        (bool ok,) = tester.call("");
        require(ok, "test failed");

        // Repay
        poolManager.sync(currency);

        if (currency == address(0)) {
            poolManager.settle{value: amount}();
        } else {
            IERC20(currency).transfer(address(poolManager), amount);
            poolManager.settle();
        }

        return "";
    }

    function flash(address currency, uint256 amount) external {
        poolManager.unlock(abi.encode(currency, amount));

        // Refund
        uint256 bal = currency.balanceOf(address(this));
        if (bal > 0) {
            currency.transferOut(msg.sender, bal);
        }
    }
}
