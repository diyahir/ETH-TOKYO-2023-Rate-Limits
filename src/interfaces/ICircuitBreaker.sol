// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {LiqChangeNode} from "../static/Structs.sol";

interface ICircuitBreaker {
    /**
     *
     * State changing functions *
     *
     */

    function registerToken(
        address _token,
        uint256 _minLiquidityThreshold,
        uint256 _minAmount
    ) external;

    function updateTokenRateLimitParams(
        address _token,
        uint256 _minLiquidityThreshold,
        uint256 _minAmount
    ) external;

    function depositHook(address _token, uint256 _amount) external;

    function withdrawalHook(
        address _token,
        uint256 _amount,
        address _recipient,
        bool _revertOnRateLimit
    ) external;

    function claimLockedFunds(address _token, address _recipient) external;

    function clearBackLog(address _token, uint256 _maxIterations) external;

    function setAdmin(address _admin) external;

    function removeRateLimit() external;

    function removeExpiredRateLimit() external;

    function addProtectedContracts(address[] calldata _ProtectedContracts) external;

    function removeProtectedContracts(address[] calldata _ProtectedContracts) external;

    /**
     *
     * Read-only functions *
     *
     */

    function tokenLimiters(
        address token
    )
        external
        view
        returns (
            uint256 minLiqRetainedBps,
            uint256 limitBeginThreshold,
            int256 liqTotal,
            int256 liqInPeriod,
            uint256 listHead,
            uint256 listTail
        );

    function lockedFunds(address recipient, address token) external view returns (uint256 amount);

    function isProtectedContract(address account) external view returns (bool protectionActive);

    function admin() external view returns (address);

    function isRateLimited() external view returns (bool);

    function rateLimitCooldownPeriod() external view returns (uint256);

    function lastRateLimitTimestamp() external view returns (uint256);

    function gracePeriodEndTimestamp() external view returns (uint256);

    function isRateLimitBreeched(address _token) external view returns (bool);

    function isInGracePeriod() external view returns (bool);
}
