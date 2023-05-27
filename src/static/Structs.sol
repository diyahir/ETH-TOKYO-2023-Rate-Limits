// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

struct LiqChangeNode {
    uint256 nextTimestamp;
    int256 amount;
}

struct TokenRateLimitInfo {
    // minimum amount to be considered for rate limiting operations
    uint256 minAmount;
    uint256 withdrawalPeriod;
    // Rate limit threshold in basis points.
    // Example 7000 - at least 70% of the liquidity should stay in the contract,
    // withdrawals with more than 30% of the liquidity will trigger the rate limit.
    // This represents the minimum liquidity that should stay in the contract.
    uint256 minLiquidityTreshold;
}
