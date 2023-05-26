// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IGuardian {
    function registerToken(
        address _tokenAddress,
        int256 _withdrawalRateLimitPerPeriod,
        uint256 _withdrawalPeriod,
        uint256 _bootstrapAmount
    ) external;

    function recordInflow(address _tokenAddress, uint256 _amount) external;

    function withdraw(address _tokenAddress, uint256 _amount, address _recipient) external;

    function addGuardedContracts(address[] calldata _guardedContracts) external;

    function removeGuardedContracts(address[] calldata _guardedContracts) external;

    function overrideExpiredRateLimit() external;

    function claimLockedFunds(address _tokenAddress) external;

    function checkIfRateLimitBreeched(address _tokenAddress) external returns (bool);

    function clearBackLog(address _tokenAddress, uint64 _maxIterations) external;

    function overrideLimit() external;

    function transferAdmin(address _admin) external;
}
