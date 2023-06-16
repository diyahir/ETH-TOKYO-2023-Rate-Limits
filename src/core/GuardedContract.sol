// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";

// The GuardedContract that uses a guardian for enforcing the circuit breaker
contract GuardedContract {
    // Use the SafeERC20 library for the IERC20 interface
    using SafeERC20 for IERC20;

    // The guardian used by this contract
    IGuardian public guardian;

    // Initialize the contract with a guardian
    constructor(address _guardian) {
        guardian = IGuardian(_guardian);
    }

    // Allows to set a new guardian
    function setGuardian(address _guardian) external {
        guardian = IGuardian(_guardian);
    }

    // Internal function to be used when tokens are deposited
    // Transfers the tokens from sender to recipient and then calls the guardian's depositHook
    function _depositHook(
        address _token,
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        // Transfer the tokens safely from sender to recipient
        IERC20(_token).safeTransferFrom(_sender, _recipient, _amount);
        // Call the guardian's depositHook
        guardian.depositHook(_token, _amount);
    }

    // Internal function to be used when tokens are withdrawn
    // Transfers the tokens to the guardian and then calls the guardian's withdrawalHook
    function _withdrawalHook(
        address _token,
        uint256 _amount,
        address _recipient,
        bool _revertOnRateLimit
    ) internal {
        // Transfer the tokens safely to the guardian
        IERC20(_token).safeTransfer(address(guardian), _amount);
        // Call the guardian's withdrawalHook
        guardian.withdrawalHook(_token, _amount, _recipient, _revertOnRateLimit);
    }
}
