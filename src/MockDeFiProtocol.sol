// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IGuardian} from "./IGuardian.sol";

contract MockDeFi {
    using SafeERC20 for IERC20;
    IGuardian guardian;

    function setGuardian(address _guardian) external {
        guardian = IGuardian(_guardian);
    }

    function deposit(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        guardian.recordInflow(token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        IERC20(token).safeTransfer(address(guardian), amount);
        guardian.withdraw(token, amount, msg.sender);
    }

    function getGuardian() external view returns (address) {
        return address(guardian);
    }
}
