// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IGuardian} from "./IGuardian.sol";

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

contract Guardian is IGuardian {
    // Rate limit precision, example 700 = 70% max drawdown per period
    int256 public constant PRECISION = 1000;

    // liquidity historacle
    mapping(address => int256) public tokenLiquidityHistoracle;

    // liquidity in window
    mapping(address => int256) public tokenLiquidityWindowAmount;

    // linked list timestamp head
    mapping(address => uint256) public tokenLiquidityHead;

    // linked list timestamp tail
    mapping(address => uint256) public tokenLiquidityTail;

    // token address -> timestamp -> LiqChangeNode
    mapping(address => mapping(uint256 => LiqChangeNode)) public tokenLiquidityChanges;

    // List of tokens that are rate limited
    address[] public tokensGuarded;

    // token address -> token struct
    mapping(address => TokenRateLimitInfo) public tokensRateLimitInfo;

    // Funds locked if rate limited reached
    // recipient => token => amount
    mapping(address => mapping(address => uint256)) public lockedFunds;

    address public admin;

    bool public isRateLimited;

    uint256 public rateLimitCooldownPeriod;

    uint256 public lastRateLimitTimestamp;

    uint256 public gracePeriod = 3 hours;

    // Guarded contracts
    mapping(address => bool) public isGuarded;
    // List of guarded contracts
    address[] public guardedContracts;

    // gracePeriod refers to the time after a rate limit breech and then overriden where withdrawals are still allowed
    // for example a false positive rate limit breech, then it is overrident, so withdrawals are still allowed for a period of time
    // before the rate limit is enforced again, it should be set to be at least your largest withdrawalPeriod length
    constructor(address _admin, uint256 _rateLimitCooldownPeriod, uint256 _gracePeriod) {
        admin = _admin;
        rateLimitCooldownPeriod = _rateLimitCooldownPeriod;
        gracePeriod = _gracePeriod;
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
        tokensGuarded.push(_tokenAddress);
    }

    // give guarded contracts one function to call for convenience
    function recordInflow(address _tokenAddress, uint256 _amount) external onlyGuarded {
        _recordTokenChange(_tokenAddress, _amount, true);
    }

    function withdraw(
        address _tokenAddress,
        uint256 _amount,
        address _recipient
    ) external onlyGuarded {
        TokenRateLimitInfo storage tokenRlInfoInfo = tokensRateLimitInfo[_tokenAddress];

        // Check if the token has enforced rate limited
        if (!tokenRlInfoInfo.exists) {
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

        // Check if rate limit is breeched after withdrawal and not in grace period
        // (grace period allows for withdrawals to be made if rate limit is breeched but overriden)
        if (checkIfRateLimitBreeched(_tokenAddress) && !isInGracePeriod()) {
            // if it is, set rate limited to true
            isRateLimited = true;
            lastRateLimitTimestamp = block.timestamp;
            // add to locked funds claimable when resolved
            lockedFunds[_recipient][_tokenAddress] += _amount;
            return;
        }

        // if everything is good, transfer the tokens
        IERC20 erc20Token = IERC20(_tokenAddress);
        erc20Token.transfer(_recipient, _amount);
    }

    function overrideLimit() external onlyAdmin {
        isRateLimited = false;
    }

    function transferAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    // Allow users to claim locked funds when rate limit is resolved
    function claimLockedFunds(address _tokenAddress) external {
        require(lockedFunds[msg.sender][_tokenAddress] > 0, "No locked funds");
        require(!isRateLimited, "Rate limited");
        IERC20 erc20Token = IERC20(_tokenAddress);
        erc20Token.transfer(msg.sender, lockedFunds[msg.sender][_tokenAddress]);
        lockedFunds[msg.sender][_tokenAddress] = 0;
    }

    function overrideExpiredRateLimit() public {
        require(isRateLimited, "Not rate limited");
        require(
            block.timestamp - lastRateLimitTimestamp >= rateLimitCooldownPeriod,
            "Cooldown period not reached"
        );
        isRateLimited = false;
    }

    function addGuardedContracts(address[] calldata _guardedContracts) public onlyAdmin {
        for (uint256 i = 0; i < _guardedContracts.length; i++) {
            isGuarded[_guardedContracts[i]] = true;
            guardedContracts.push(_guardedContracts[i]);
        }
    }

    function removeGuardedContracts(address[] calldata _guardedContracts) public onlyAdmin {
        for (uint256 i = 0; i < _guardedContracts.length; i++) {
            isGuarded[_guardedContracts[i]] = false;
            for (uint256 j = 0; j < guardedContracts.length; j++) {
                if (guardedContracts[j] == _guardedContracts[i]) {
                    delete guardedContracts[j];
                }
            }
        }
    }

    function checkIfRateLimitBreeched(address _tokenAddress) public view returns (bool) {
        TokenRateLimitInfo memory token = tokensRateLimitInfo[_tokenAddress];
        if (!token.exists) {
            return false;
        }
        int256 currentLiq = tokenLiquidityHistoracle[_tokenAddress];

        // Only enforce rate limit if there is significant liquidity
        if (token.bootstrapAmount > uint(currentLiq)) {
            return false;
        }

        int256 futureLiq = currentLiq + tokenLiquidityWindowAmount[_tokenAddress];
        int256 minLiq = (currentLiq * token.withdrawalRateLimitPerPeriod) / PRECISION;

        return futureLiq < minLiq;
    }

    function _recordTokenChange(
        address _tokenAddress,
        uint256 _amount,
        bool _isPositive
    ) internal onlyGuarded {
        TokenRateLimitInfo storage tokenRlInfo = tokensRateLimitInfo[_tokenAddress];

        // If token does not have a rate limit, do nothing
        if (!tokenRlInfo.exists) {
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
        tokenLiquidityWindowAmount[_tokenAddress] += newLiqChange.amount;

        // if there is no head, set the head to the new inflow
        if (tokenLiquidityHead[_tokenAddress] == 0) {
            tokenLiquidityHead[_tokenAddress] = block.timestamp;
            tokenLiquidityTail[_tokenAddress] = block.timestamp;
            tokenLiquidityChanges[_tokenAddress][block.timestamp] = newLiqChange;
        } else {
            // if there is a head, check if the new inflow is within the period
            // if it is, add it to the head
            // if it is not, add it to the tail
            if (
                block.timestamp - tokenLiquidityHead[_tokenAddress] >= tokenRlInfo.withdrawalPeriod
            ) {
                _traverseLinkedListUntilInPeriod(_tokenAddress, block.timestamp);
            }

            // check if tail is the same as block.timestamp (multiple txs in same block)
            if (tokenLiquidityTail[_tokenAddress] == block.timestamp) {
                // add amount
                tokenLiquidityChanges[_tokenAddress][block.timestamp].amount += newLiqChange.amount;
            } else {
                // add to tail
                LiqChangeNode storage tail = tokenLiquidityChanges[_tokenAddress][
                    tokenLiquidityTail[_tokenAddress]
                ];
                tail.nextTimestamp = block.timestamp;
                tokenLiquidityChanges[_tokenAddress][block.timestamp] = newLiqChange;
                tokenLiquidityTail[_tokenAddress] = block.timestamp;
            }
        }
    }

    // Traverse the linked list from the head until the timestamp is within the period
    function _traverseLinkedListUntilInPeriod(address _tokenAddress, uint256 _timestamp) internal {
        int256 totalChange = 0;
        uint256 currentHeadTimestamp = tokenLiquidityHead[_tokenAddress];
        while (
            currentHeadTimestamp != 0 &&
            _timestamp - currentHeadTimestamp >= tokensRateLimitInfo[_tokenAddress].withdrawalPeriod
        ) {
            LiqChangeNode memory node = tokenLiquidityChanges[_tokenAddress][currentHeadTimestamp];
            totalChange += node.amount;
            // Clear data
            delete tokenLiquidityChanges[_tokenAddress][currentHeadTimestamp];

            currentHeadTimestamp = tokenLiquidityChanges[_tokenAddress][currentHeadTimestamp]
                .nextTimestamp;
        }
        // Set new head, if there is no head, set it to the current timestamp
        if (currentHeadTimestamp == 0) {
            tokenLiquidityHead[_tokenAddress] = _timestamp;
        } else {
            tokenLiquidityHead[_tokenAddress] = currentHeadTimestamp;
        }
        // update historacle
        tokenLiquidityHistoracle[_tokenAddress] += totalChange;
        // update window
        tokenLiquidityWindowAmount[_tokenAddress] -= totalChange;
    }

    function isInGracePeriod() public view returns (bool) {
        return block.timestamp - lastRateLimitTimestamp <= gracePeriod && !isRateLimited;
    }

    function _isGuardedContract(address _input) internal view returns (bool) {
        return isGuarded[_input];
    }

    modifier onlyGuarded() {
        require(_isGuardedContract(msg.sender), "Only guarded contracts");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
}
