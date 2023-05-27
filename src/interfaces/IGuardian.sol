// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {LiqChangeNode, TokenRateLimitInfo} from "../static/Structs.sol";

interface IGuardian {
    /**
     *
     * State changing functions *
     *
     */

    function registerToken(
        address _token,
        uint256 _minLiquidityThreshold,
        uint256 _withdrawalPeriod,
        uint256 _minAmount
    ) external;

    function recordInflow(address _token, uint256 _amount) external;

    function withdraw(address _token, uint256 _amount, address _recipient) external;

    function claimLockedFunds(address _token) external;

    function clearBackLog(address _token, uint256 _maxIterations) external;

    function setAdmin(address _admin) external;

    function removeRateLimit() external;

    function removeExpiredRateLimit() external;

    function addGuardedContracts(address[] calldata _guardedContracts) external;

    function removeGuardedContracts(address[] calldata _guardedContracts) external;

    /**
     *
     * Read-only functions *
     *
     */

    function tokenLiquidityTotal(address token) external view returns (int256 amount);

    function tokenLiquidityInPeriod(address token) external view returns (int256 amount);

    function tokenLiquidityChanges(address token, uint256 timestamp)
        external
        view
        returns (uint256 nextTimestamp, int256 withdrawalPeriod);

    function tokenRateLimitInfo(address token)
        external
        view
        returns (uint256 minAmount, uint256 withdrawPeriod, uint256 minLiquidityThreshold);

    function lockedFunds(address recipient, address token) external view returns (uint256 amount);

    function isGuardedContract(address account) external view returns (bool guardActive);

    function tokenRateLimitInfoExists(TokenRateLimitInfo memory tokenRLinfo) external pure returns (bool exists);

    function admin() external view returns (address);

    function isRateLimited() external view returns (bool);

    function rateLimitCooldownPeriod() external view returns (uint256);

    function lastRateLimitTimestamp() external view returns (uint256);

    function gracePeriod() external view returns (uint256);

    function isRateLimitBreeched(address _token) external view returns (bool);

    function isInGracePeriod() external view returns (bool);
}
