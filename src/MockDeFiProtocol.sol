// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Guardian} from "./Guardian.sol";

contract MockDeFi {
    Guardian guardian;

    function setGuardian(address _guardian) external {
        guardian = Guardian(_guardian);
    }

    function deposit(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        guardian.recordInflow(token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        IERC20(token).transfer(address(guardian), amount);
        guardian.withdraw(token, amount, msg.sender);
    }

    function getGuardian() external view returns (address) {
        return address(guardian);
    }
}
