// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

struct LiqChangeNode {
    uint256 nextTimestamp;
    int256 amount;
}

struct TokenRateLimitInfo {
    uint256 bootstrapAmount;
    uint256 withdrawalPeriod;
    int256 withdrawalRateLimitPerPeriod;
    bool exists;
}