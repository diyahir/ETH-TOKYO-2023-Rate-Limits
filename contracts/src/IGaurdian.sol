pragma solidity ^0.8.13;

interface IGaurdian {
    function recordInflow(address _tokenAddress, uint256 _amount) external;

    function tryOutflow(address _tokenAddress, uint256 _amount, address _recipient) external;

    // User functions
    function withdrawLockedFunds() external;

    // Admin Functions 
    function registerToken(address _tokenAddress, uint256 _bootsrapAmount) external;

    function overrideLimit() external;

    function extendTimeout(uint _timeExtension) external;

    function pushAlert() external;
}