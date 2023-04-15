// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import './IGaurdian.sol';

contract Gaurdian is IGaurdian {
  address public admin;
  bool public isRateLimited;
  uint public timeout;
  uint public maxDrawdownPercentage;
  uint public rateDuration;

  struct Token {
    uint256 bootstrapAmount;
    uint256 lockedAmount;
    bool exists;
  }

  struct Inflow {
    uint256 amount;
    uint256 timestamp;  
  }

  mapping(address => Token) public tokens;
  mapping(address => Inflow[]) public inflows;
  
  // recipient => token => amount
  mapping(address => mapping(address => uint256)) public lockedFunds;

  constructor(address _admin, uint _timeout, uint _rateDuration, uint _maxDrawdownPercentage) {
    admin = _admin;
    timeout = _timeout;
    maxDrawdownPercentage = _maxDrawdownPercentage;
    rateDuration = _rateDuration;
  }

  function recordInflow(address _tokenAddress, uint256 _amount) external {
    Token storage token = tokens[_tokenAddress];
    require(token.exists, 'Token does not exist');
    inflows[_tokenAddress].push(Inflow(_amount, block.timestamp));
    // Remove old inflows
    uint256 oldestTimestamp = block.timestamp - rateDuration;
    uint256 oldInflows = 0;
    uint256 i = 0;
    while (inflows[_tokenAddress][i].timestamp < oldestTimestamp) {
      oldInflows += inflows[_tokenAddress][i].amount;
      i++;
    }
    if (i > 0) {
      // There's probably a better way to do this
      inflows[_tokenAddress].pop();
    }
    
    token.lockedAmount += _amount - oldInflows;
  }

  function tryOutflow(address _tokenAddress, uint256 _amount, address _recipient) external {
    Token storage token = tokens[_tokenAddress];
    require(token.exists, 'Token does not exist');
    require(_amount <= token.lockedAmount, 'Insufficient available amount');
    require(!isRateLimited, 'Rate limit exceeded');



    // TODO
}


  function withdrawLockedFunds() external {
    Token storage token = tokens[msg.sender];
    require(token.exists, 'Token does not exist');
    require(token.lockedAmount > 0, 'No locked funds to withdraw');
    require(block.timestamp > timeout, 'Withdrawal not authorized');
    uint256 amount = token.lockedAmount;
    token.lockedAmount = 0;
    (bool success, ) = msg.sender.call{ value: amount }('');
    require(success, 'Transfer failed');
  }

  function registerToken(address _tokenAddress, uint256 _bootstrapAmount) external {
    require(msg.sender == admin, 'Only the current admin can register a new token');
    Token storage token = tokens[_tokenAddress];
    require(!token.exists, 'Token already exists');
    token.exists = true;
    token.bootstrapAmount = _bootstrapAmount;
  }

  function overrideLimit() external {
    require(msg.sender == admin, 'Only the current admin can override the withdrawal limit');
    timeout = block.timestamp - 1;
  }

  function extendTimeout(uint _timeExtension) external {
    require(msg.sender == admin, 'Only the current admin can extend the timeout');
    timeout += _timeExtension;
  }

  function pushAlert() external {
    // Push an alert to an external system
  }

}
