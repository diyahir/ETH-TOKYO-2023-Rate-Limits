// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Guardian {
  address public admin;
  address[] public guardedContracts;

  struct Token {
    uint256 totalAmount;
    uint256 amountWithdrawnSincePeriod;
    uint256 withdrawalPeriod;
    uint256 withdrawalLimitPerPeriod;
    bool exists;
  }

  struct Inflow {
    uint256 amount;
    uint256 timestamp;  
  }

  // token address -> token struct
  mapping(address => Token) public tokens;

  // token -> inflows
  mapping(address => Inflow[]) public inflows;
  
  // recipient => token => amount
  mapping(address => mapping(address => uint256)) public lockedFunds;

  constructor(address _admin, address[] _guardedContracts) {
    admin = _admin;
    guardedContracts = _guardedContracts;
  }

  function recordInflowAndWithdrawAvailable(){

  }


  function recordInflow(address _tokenAddress, uint256 _amount) external onlyGuarded {
    Token storage token = tokens[_tokenAddress];
    require(token.exists, 'Token does not exist');

    // credit amount to user, credit total amount



  }
/*
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
  */

  function getMaxWithdrawal(address _tokenAddress, uint256 _amount, address _recipient) pure {

  }

  function withdraw(address _tokenAddress, uint256 _amount, address _recipient) external{
    
    address recipient;

    if (!_recipient){
      recipient = msg.sender;
    } else {
      recipient = _recipient;
    }

    Token storage token = tokens[_tokenAddress];
    require(token.exists, 'Token does not exist');
    require(token.lockedAmount > 0, 'No locked funds to withdraw');
    require(_amount <= token.lockedAmount, 'Insufficient available amount');

    // now we need to actually check how many tokens the user can withdraw
    // essentially we need to find out how far we are from max drawdown percentage per period, per token


    // go through inflows and remove them from the array, also decrement the amountWithdrawnSincePeriod

    //

    IERC20 erc20Token = IERC20(_tokenAddress);
    token.lockedAmount -= _amount;
    erc20Token.transfer(recipient, _amount);
  }

  function transferAdmin(address _admin) external {
    require(msg.sender == admin, 'Only admin');
    admin = _admin;
  }

  function modifyGuardedContracts(address[] _guardedContracts){
    require(msg.sender == admin, 'Only admin');
    guardedContracts = _guardedContracts;
  } 

  function registerToken(address _tokenAddress, uint256 withdrawalLimitPerPeriod, withdrawalPeriod) external {
    require(msg.sender == admin, 'Only the current admin can register a new token');
    Token storage token = tokens[_tokenAddress];
    require(!token.exists, 'Token already exists');
    token.exists = true;
  }

  function overrideLimit(address _tokenAddress) external {
    require(msg.sender == admin, 'Only the current admin can override the withdrawal limit');
    //reimplement this
  }

  function pushAlert() external {
    // Push an alert to an external system
  }

}
