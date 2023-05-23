// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

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

contract Guardian {
    // Rate limit precision, example 700 = 70% max drawdown per period
    int256 public constant PRECISION = 1000;

    // liquidity historacle
    mapping(address => int256) public tokenLiqHistoracle;

    // liquidity in window
    mapping(address => int256) public tokenLiqWindowAmount;

    // linked list timestamp head
    mapping(address => uint256) public tokenLiqHead;

    // linked list timestamp tail
    mapping(address => uint256) public tokenLiqTail;

    // token address -> timestamp -> LiqChangeNode
    mapping(address => mapping(uint256 => LiqChangeNode)) public tokenLiqChanges;

    // token address -> token struct
    mapping(address => TokenRateLimitInfo) public tokensRateLimitInfo;

    // Funds locked if rate limited reached
    // recipient => token => amount
    mapping(address => mapping(address => uint256)) public lockedFunds;

    address public admin;

    bool public isRateLimited;

    mapping(address => bool) public isGuarded;

    modifier onlyGuarded() {
        require(_isGuardedContract(msg.sender), "Only guarded contracts");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor(address _admin, address _guardedContracts) {
        admin = _admin;
        isGuarded[_guardedContracts] = true;
    }

    function registerToken(
        address _tokenAddress,
        int256 _withdrawalRateLimitPerPeriod,
        uint256 _withdrawalPeriod,
        uint256 _bootstrapAmount
    ) external onlyAdmin {
        TokenRateLimitInfo storage token = tokensRateLimitInfo[_tokenAddress];
        require(!token.exists, "Token already exists");
        token.exists = true;
        token.withdrawalRateLimitPerPeriod = _withdrawalRateLimitPerPeriod;
        token.withdrawalPeriod = _withdrawalPeriod;
        token.bootstrapAmount = _bootstrapAmount;
    }

    function overrideLimit() external onlyAdmin {
        isRateLimited = false;
    }

    function transferAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    // give guarded contracts one function to call for convenience
    function recordInflow(address _tokenAddress, uint256 _amount) external onlyGuarded {
        _recordTokenChange(_tokenAddress, _amount, true);
    }

    // Allow users to claim locked funds when rate limit is resolved
    function claimLockedFunds(address _tokenAddress) external {
        require(lockedFunds[msg.sender][_tokenAddress] > 0, "No locked funds");
        require(!isRateLimited, "Rate limited");
        IERC20 erc20Token = IERC20(_tokenAddress);
        erc20Token.transfer(msg.sender, lockedFunds[msg.sender][_tokenAddress]);
        lockedFunds[msg.sender][_tokenAddress] = 0;
    }

    function withdraw(address _tokenAddress, uint256 _amount, address _recipient) external {
        TokenRateLimitInfo storage token = tokensRateLimitInfo[_tokenAddress];

        // Check if the token has enforced rate limited
        if (!token.exists) {
            // if it is not rate limited, just transfer the tokens
            IERC20 erc20TokenNoLimit = IERC20(_tokenAddress);
            erc20TokenNoLimit.transfer(_recipient, _amount);
            return;
        }

        _recordTokenChange(_tokenAddress, _amount, false);
        // Check if currently rate limited, if so, add to locked funds claimable when resolved
        if (isRateLimited) {
            lockedFunds[_recipient][_tokenAddress] += _amount;
            return;
        }

        // Check if rate limit is breeched after withdrawal
        if (checkIfRateLimitBreeched(_tokenAddress)) {
            // if it is, set rate limited to true
            isRateLimited = true;
            // add to locked funds claimable when resolved
            lockedFunds[_recipient][_tokenAddress] += _amount;
            return;
        }

        // if everything is good, transfer the tokens
        IERC20 erc20Token = IERC20(_tokenAddress);
        erc20Token.transfer(_recipient, _amount);
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

    function checkIfRateLimitBreeched(address _tokenAddress) public view returns (bool) {
        TokenRateLimitInfo memory token = tokensRateLimitInfo[_tokenAddress];
        if (!token.exists) {
            return false;
        }
        int256 currentLiq = tokenLiqHistoracle[_tokenAddress];

        // Only enforce rate limit if there is significant liquidity
        if (token.bootstrapAmount > uint(currentLiq)) {
            return false;
        }

        int256 currentWindow = tokenLiqWindowAmount[_tokenAddress];

        int256 futureLiq = currentLiq + currentWindow;
        int256 minLiq = (currentLiq * token.withdrawalRateLimitPerPeriod) / PRECISION;

        return futureLiq < minLiq;
    }

    function _recordTokenChange(
        address _tokenAddress,
        uint256 _amount,
        bool _isPositive
    ) internal onlyGuarded {
        TokenRateLimitInfo storage tokenRL = tokensRateLimitInfo[_tokenAddress];

        // If token does not have a rate limit, do nothing
        if (!tokenRL.exists) {
            return;
        }

        //create a new inflow
        LiqChangeNode memory newLiqChange;
        newLiqChange.amount = int(_amount);
        newLiqChange.nextTimestamp = 0;

        // add to window
        if (!_isPositive) {
            newLiqChange.amount = -int(_amount);
        }
        tokenLiqWindowAmount[_tokenAddress] += newLiqChange.amount;

        // if there is no head, set the head to the new inflow
        if (tokenLiqHead[_tokenAddress] == 0) {
            tokenLiqHead[_tokenAddress] = block.timestamp;
            tokenLiqTail[_tokenAddress] = block.timestamp;
            tokenLiqChanges[_tokenAddress][block.timestamp] = newLiqChange;
        } else {
            // if there is a head, check if the new inflow is within the period
            // if it is, add it to the head
            // if it is not, add it to the tail
            if (block.timestamp - tokenLiqHead[_tokenAddress] >= tokenRL.withdrawalPeriod) {
                _traverseLinkedListUntilInPeriod(_tokenAddress, block.timestamp);
            }

            // check if tail is the same as block.timestamp (multiple txs in same block)
            if (tokenLiqTail[_tokenAddress] == block.timestamp) {
                // add amount
                tokenLiqChanges[_tokenAddress][block.timestamp].amount += newLiqChange.amount;
            } else {
                // add to tail
                LiqChangeNode storage tail = tokenLiqChanges[_tokenAddress][
                    tokenLiqTail[_tokenAddress]
                ];
                tail.nextTimestamp = block.timestamp;
                tokenLiqChanges[_tokenAddress][block.timestamp] = newLiqChange;
                tokenLiqTail[_tokenAddress] = block.timestamp;
            }
        }
    }

    // Traverse the linked list from the head until the timestamp is within the period
    function _traverseLinkedListUntilInPeriod(address _tokenAddress, uint256 _timestamp) internal {
        int256 totalChange = 0;
        uint256 currentHeadTimestamp = tokenLiqHead[_tokenAddress];
        while (
            currentHeadTimestamp != 0 &&
            _timestamp - currentHeadTimestamp >= tokensRateLimitInfo[_tokenAddress].withdrawalPeriod
        ) {
            LiqChangeNode memory node = tokenLiqChanges[_tokenAddress][currentHeadTimestamp];
            totalChange += node.amount;
            // Clear data
            delete tokenLiqChanges[_tokenAddress][currentHeadTimestamp];

            currentHeadTimestamp = tokenLiqChanges[_tokenAddress][currentHeadTimestamp]
                .nextTimestamp;
        }
        // Set new head, if there is no head, set it to the current timestamp
        if (currentHeadTimestamp == 0) {
            tokenLiqHead[_tokenAddress] = _timestamp;
        } else {
            tokenLiqHead[_tokenAddress] = currentHeadTimestamp;
        }
        // update historacle
        tokenLiqHistoracle[_tokenAddress] += totalChange;
        // update window
        tokenLiqWindowAmount[_tokenAddress] -= totalChange;
    }

    function _isGuardedContract(address _input) internal view returns (bool) {
        return isGuarded[_input];
    }
}
