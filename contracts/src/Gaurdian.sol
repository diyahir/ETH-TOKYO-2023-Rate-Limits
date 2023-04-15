// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import './IGaurdian.sol';

contract Gaurdian is IGaurdian {
    function recordInflow(address _tokenAddress, uint256 _amount) external {
        // TODO
    }

    function tryOutflow(address _tokenAddress, uint256 _amount, address _recipient) external {

    }

    // User functions
    function withdrawLockedFunds() external {}

    // Admin Functions 
    function initialize(address _admin, uint _timeout, uint _maxDrawdownPrcnt) external {}

    function registerToken(address _tokenAddress, uint256 _bootsrapAmount) external {}

    function overrideLimit() external {}

    function extendTimeout(uint _timeExtension) external {}

    function pushAlert() external {}
}
