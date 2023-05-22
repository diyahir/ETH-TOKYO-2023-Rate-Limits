// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract Guardian {
    struct Token {
        uint256 totalAmount;
        uint256 amountWithdrawnSincePeriod;
        uint256 withdrawalPeriod;
        uint256 withdrawalLimitPerPeriod;
        bool exists;
    }

    struct InflowNode {
        uint256 amount;
        uint256 nextTimestamp;
    }

    // linked list timestamp head
    mapping(address => uint256) public tokenInflowHead;

    // linked list timestamp tail
    mapping(address => uint256) public tokenInflowTail;

    // token address -> timestamp -> InflowNode
    mapping(address => mapping(uint256 => InflowNode)) public tokenInflows;

    // token address -> token struct
    mapping(address => Token) public tokens;

    // recipient => token => amount
    mapping(address => mapping(address => uint256)) public lockedFunds;

    address public admin;

    bool public isRateLimited;

    mapping(address => bool) public isGuarded;

    modifier onlyGuarded() {
        require(_isGuardedContract(msg.sender), "Only guarded contracts");
        _;
    }

    constructor(address _admin, address[] memory _guardedContracts) {
        admin = _admin;
        for (uint256 i = 0; i < _guardedContracts.length; i++) {
            isGuarded[_guardedContracts[i]] = true;
        }
    }

    function registerToken(
        address _tokenAddress,
        uint256 _withdrawalLimitPerPeriod,
        uint256 _withdrawalPeriod
    ) external {
        require(msg.sender == admin, "Only Admin");
        Token storage token = tokens[_tokenAddress];
        require(!token.exists, "Token already exists");
        token.exists = true;
        token.withdrawalLimitPerPeriod = _withdrawalLimitPerPeriod;
        token.withdrawalPeriod = _withdrawalPeriod;
    }

    function overrideLimit(
        address _tokenAddress,
        uint256 _withdrawalLimitPerPeriod,
        uint256 _withdrawalPeriod
    ) external {
        require(msg.sender == admin, "Only Admin");
        Token storage token = tokens[_tokenAddress];
        token.withdrawalLimitPerPeriod = _withdrawalLimitPerPeriod;
        token.withdrawalPeriod = _withdrawalPeriod;
    }

    function transferAdmin(address _admin) external {
        require(msg.sender == admin, "Only admin");
        admin = _admin;
    }

    // give guarded contracts one function to call for convenience
    function recordInflow(
        address _tokenAddress,
        uint256 _amount
    ) external onlyGuarded {
        _recordInflow(_tokenAddress, _amount);
    }


    function withdraw(address _tokenAddress, uint256 _amount, address _recipient) external {
        Token storage token = tokens[_tokenAddress];

        require(_recipient != address(0), "need to include recipient");
        require(token.exists, "Token does not exist");
        require(token.totalAmount > 0, "No locked funds to withdraw");
        require(_amount <= token.totalAmount, "Insufficient available amount");

        // go through inflows and remove them from the array, also decrease the amountWithdrawnSincePeriod

        // Inflow[] storage inflowArr = inflows[_tokenAddress];
        // for (uint256 i = 0; i < inflowArr.length; i++) {
        //     if (block.timestamp - inflowArr[i].timestamp > token.withdrawalPeriod) {
        //         token.amountWithdrawnSincePeriod -= inflowArr[i].amount;
        //         inflowArr[i] = inflowArr[inflowArr.length - 1];
        //         inflowArr.pop();
        //     }
        // }

        uint256 userLockedAmount = lockedFunds[_recipient][_tokenAddress];
        require(userLockedAmount >= _amount, "Insufficient user balance");

        // now we need to actually check how many tokens the user can withdraw
        // essentially we need to find out how far we are from max drawdown per period, per token
        uint256 maxDrawdownAmount = token.amountWithdrawnSincePeriod -
            token.withdrawalLimitPerPeriod;

        uint256 userWithdrawAmount;

        if (maxDrawdownAmount > _amount) {
            userWithdrawAmount = _amount;
        } else if (_amount - maxDrawdownAmount > 0) {
            userWithdrawAmount = maxDrawdownAmount;
        } else {
            //this shouldn't happen but better be sure
            /// TODO: Wouldn't this be when maxDrawnAmount == _amount?
            revert("Something went wrong");
        }

        //finally we should decrease the users balance and the total balance, and increase the amount withdrawn since period
        lockedFunds[_recipient][_tokenAddress] -= userWithdrawAmount;
        token.totalAmount -= userWithdrawAmount;
        token.amountWithdrawnSincePeriod += userWithdrawAmount;

        IERC20 erc20Token = IERC20(_tokenAddress);
        erc20Token.transfer(_recipient, userWithdrawAmount);
    }

    function addGuardedContracts(address[] calldata _guardedContracts) public {
        require(msg.sender == admin, "Only admin");
        for (uint256 i = 0; i < _guardedContracts.length; i++) {
            isGuarded[_guardedContracts[i]] = true;
        }
    }

    function removeGuardedContracts(address[] calldata _guardedContracts) public {
        require(msg.sender == admin, "Only admin");
        for (uint256 i = 0; i < _guardedContracts.length; i++) {
            isGuarded[_guardedContracts[i]] = false;
        }
    }

    function getMaxWithdrawal(
        address _tokenAddress,
        uint256 _amount,
        address _recipient
    ) public view returns (uint256) {
        //later make a view function so users can estimate how much they will get
    }


    function _recordInflow(
        address _tokenAddress,
        uint256 _amount
    ) internal onlyGuarded {
        Token storage token = tokens[_tokenAddress];
        require(token.exists, "Token does not exist");
        token.totalAmount += _amount;

        //create a new inflow
        InflowNode memory newInflow;
        newInflow.amount = _amount;
        newInflow.nextTimestamp = 0;

        // if there is no head, set the head to the new inflow
        if (tokenInflowHead[_tokenAddress] == 0) {
            tokenInflowHead[_tokenAddress] = block.timestamp;
            tokenInflowTail[_tokenAddress] = block.timestamp;
            tokenInflows[_tokenAddress][block.timestamp] = newInflow;
        } else {
            // if there is a head, check if the new inflow is within the period
            // if it is, add it to the head
            // if it is not, add it to the tail
            if (block.timestamp - tokenInflowHead[_tokenAddress] <= token.withdrawalPeriod) {
                _traverseLinkedListUntilInPeriod(_tokenAddress, block.timestamp);
            } 

            // check if tail is the same as block.timestamp
            if (tokenInflowTail[_tokenAddress] == block.timestamp) {
                // add amount 
                tokenInflows[_tokenAddress][block.timestamp].amount += _amount;
            } else {
            // add to tail
            InflowNode storage tail = tokenInflows[_tokenAddress][tokenInflowTail[_tokenAddress]];
            tail.nextTimestamp = block.timestamp;
            tokenInflows[_tokenAddress][block.timestamp] = newInflow;
            tokenInflowTail[_tokenAddress] = block.timestamp;
            }

            
        }
    }

    // Traverse the linked list from the head until the timestamp is within the period
    function _traverseLinkedListUntilInPeriod(
        address _tokenAddress,
        uint256 _timestamp
    ) internal returns (uint256) {
        uint256 totalAmount = 0;
        uint256 currentTimestamp = tokenInflowHead[_tokenAddress];
        while (currentTimestamp != 0 || _timestamp - currentTimestamp <= tokens[_tokenAddress].withdrawalPeriod) {

                totalAmount += tokenInflows[_tokenAddress][currentTimestamp].amount;
                delete tokenInflows[_tokenAddress][currentTimestamp];
            currentTimestamp = tokenInflows[_tokenAddress][currentTimestamp].nextTimestamp;
        }
        // Set new head 
        tokenInflowHead[_tokenAddress] = currentTimestamp;

        return totalAmount;
    }

    function _isGuardedContract(address _input) internal view returns (bool) {
        return isGuarded[_input];
    }
}
