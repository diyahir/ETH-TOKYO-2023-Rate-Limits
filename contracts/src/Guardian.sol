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

  constructor(address _admin, address[] memory _guardedContracts) {
    admin = _admin;
    guardedContracts = _guardedContracts;
  }

  // give guarded contracts one function to call for convenience
  function recordInflowAndWithdrawAvailable(address _tokenAddress, uint256 _amount, address _recipient) external onlyGuarded {
    recordInflow(_tokenAddress, _amount, _recipient);
    withdraw(_tokenAddress, _amount, _recipient);
  }

  function recordInflow(address _tokenAddress, uint256 _amount, address _recipient) external onlyGuarded {
    Token storage token = tokens[_tokenAddress];
    require(token.exists, 'Token does not exist');

    // credit amount to user, credit total amount
    token.totalAmount += _amount;
    lockedFunds[_recipient][_tokenAddress] += _amount;

    //create a new inflow
    Inflow memory newInflow;
    newInflow.amount =_amount;
    newInflow.timestamp = block.timestamp;
    inflows[_tokenAddress].push(newInflow);
  }

  function getMaxWithdrawal(address _tokenAddress, uint256 _amount, address _recipient) public view returns (uint256) {
      //later make a view function so users can estimate how much they will get
  }

  function withdraw(address _tokenAddress, uint256 _amount, address _recipient) external{

    Token storage token = tokens[_tokenAddress];
    
    require(_recipient != address(0), 'need to include recipient');
    require(token.exists, 'Token does not exist');
    require(token.totalAmount > 0, 'No locked funds to withdraw');
    require(_amount <= token.totalAmount, 'Insufficient available amount');

    // go through inflows and remove them from the array, also decrease the amountWithdrawnSincePeriod

    Inflow storage inflowArr = inflows[_tokenAddress];
    for (uint i=0; i<inflowArr.length; i++){
      if (block.timestamp - inflowArr[i].timestamp > token.withdrawalPeriod){
        token.amountWithdrawnSincePeriod -= inflowArr[i].amount;
        inflowArr[i] = inflowArr[inflowArr.length-1];
        inflowArr.pop();
      }
    }

    uint256 userLockedAmount = lockedFunds[_recipient][_tokenAddress];

    // now we need to actually check how many tokens the user can withdraw
    // essentially we need to find out how far we are from max drawdown per period, per token
    uint256 maxDrawdownAmount = token.amountWithdrawnSincePeriod - token.withdrawalLimitPerPeriod;
    
    uint256 userWithdrawAmount;

    if (maxDrawdownAmount > _amount){
      userWithdrawAmount = _amount;
    } else if (_amount - maxDrawdownAmount > 0) {
      userWithdrawAmount = maxDrawdownAmount;
    } else {
      //this shouldn't happen but better be sure
      revert();
    }
    
    //finally we should decrease the users balance and the total balance, and increase the amount withdrawn since period
    lockedFunds[_recipient][_tokenAddress] -= userWithdrawAmount;
    token.totalAmount -= userWithdrawAmount;
    token.amountWithdrawnSincePeriod += userWithdrawAmount;

    IERC20 erc20Token = IERC20(_tokenAddress);
    erc20Token.transfer(_recipient, userWithdrawAmount);
  }

  function transferAdmin(address _admin) external {
    require(msg.sender == admin, 'Only admin');
    admin = _admin;
  }

  function modifyGuardedContracts(address[] _guardedContracts){
    require(msg.sender == admin, 'Only admin');
    guardedContracts = _guardedContracts;
  } 

  function containsGuardian(address _input) internal view returns(bool){
    bool found = false;
    for (uint i=0; i<guardedContracts.length; i++){
      if (guardedContracts[i] == _input){
        found = true;
        break;
      }
    }
    return found;
  }

  modifier onlyGuarded() {
     require(containsGuardian(msg.sender), 'Only guarded contracts');
     _;
  }

  function registerToken(address _tokenAddress, uint256 _withdrawalLimitPerPeriod, uint256 _withdrawalPeriod) external {
    require(msg.sender == admin, 'Only the current admin can register a new token');
    Token storage token = tokens[_tokenAddress];
    require(!token.exists, 'Token already exists');
    token.exists = true;
    token.withdrawalLimitPerPeriod = _withdrawalLimitPerPeriod;
    token.withdrawalPeriod = _withdrawalPeriod;
  }

  function overrideLimit(address _tokenAddress, uint256 _withdrawalLimitPerPeriod, uint256 _withdrawalPeriod) external {
    require(msg.sender == admin, 'Only the current admin can override the withdrawal limit');
    Token storage token = tokens[_tokenAddress];
    token.withdrawalLimitPerPeriod = _withdrawalLimitPerPeriod;
    token.withdrawalPeriod = _withdrawalPeriod;
  }

  function pushAlert() external {
    // Push an alert to an external system
  }

}
