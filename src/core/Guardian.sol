// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { IGuardian } from "../interfaces/IGuardian.sol";
import { LiqChangeNode, TokenRateLimitInfo } from "../static/Structs.sol";


contract Guardian is IGuardian {
    using SafeERC20 for IERC20;
    
    /*******************************
     * Errors *
     *******************************/
    
    error NotAGuardedContract(); 
    error NotAdmin(); 
    error InvalidAdminAddress();
    error TokenAlreadyExists(); 
    error NoLockedFunds(); 
    error RateLimited(); 
    error NotRateLimited(); 
    error CooldownPeriodNotReached(); 

    /*******************************
     * Events *
     *******************************/

    /*******************************
     * Constants *
     *******************************/

    // Rate limit precision, example 700 = 70% max drawdown per period
    int256 public constant PRECISION = 1000;

    uint64 constant public MAX_INT = 2 ** 64 - 1;

    /*******************************
     * State vars *
     *******************************/

    // liquidity historacle
    mapping(address token => int256 amount) public tokenLiquidityHistoracle;

    // liquidity in window
    mapping(address token => int256 amount) public tokenLiquidityWindowAmount;

    // linked list timestamp head
    mapping(address token => uint256 timestamp) public tokenLiquidityHead;

    // linked list timestamp tail
    mapping(address token => uint256 timestamp) public tokenLiquidityTail;

    // token address -> timestamp -> LiqChangeNode
    mapping(address token => mapping(uint256 timestamp => LiqChangeNode node)) public tokenLiquidityChanges;

    // List of tokens that are rate limited
    address[] public tokensGuarded;

    mapping(address token => TokenRateLimitInfo rateLimitInfo) public tokensRateLimitInfo;

    // Funds locked if rate limited reached
    mapping(address recipient => mapping(address token => uint256 amount)) public lockedFunds;

    // Guarded contracts
    mapping(address account => bool guarded) public isGuarded;

    address public admin;

    bool public isRateLimited;

    uint256 public rateLimitCooldownPeriod;

    uint256 public lastRateLimitTimestamp;

    uint256 public gracePeriod = 3 hours;

    /*******************************
     * Modifiers *
     *******************************/

    modifier onlyGuarded() {
        if(!isGuarded[msg.sender]) revert NotAGuardedContract();
        _;
    }

    modifier onlyAdmin() {
        if(msg.sender != admin) revert NotAdmin();
        _;
    }

    /*******************************
     * Constructor *
     *******************************/

    /**
       gracePeriod refers to the time after a rate limit breech and then overriden where withdrawals are still allowed.
       For example a false positive rate limit breech, then it is overriden, so withdrawals are still 
       allowed for a period of time. 
       Before the rate limit is enforced again, it should be set to be at least your largest withdrawalPeriod length
     */
    constructor(address _admin, uint256 _rateLimitCooldownPeriod, uint256 _gracePeriod) {
        admin = _admin;
        rateLimitCooldownPeriod = _rateLimitCooldownPeriod;
        gracePeriod = _gracePeriod;
    }

    /*******************************
     * Functions *
     *******************************/

    function registerToken(
        address _tokenAddress,
        int256 _withdrawalRateLimitPerPeriod,
        uint256 _withdrawalPeriod,
        uint256 _bootstrapAmount
    ) external onlyAdmin {
        TokenRateLimitInfo storage token = tokensRateLimitInfo[_tokenAddress];
        if(token.exists) revert TokenAlreadyExists();

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

        // create a new inflow
        LiqChangeNode memory newLiqChange;

        // NOTE: Unsafe for huge numbers
        newLiqChange.amount = int(_amount);

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
                _traverseLinkedListUntilInPeriod(_tokenAddress, block.timestamp, MAX_INT);
            }

            // check if tail is the same as block.timestamp (multiple txs in same block)
            if (tokenLiquidityTail[_tokenAddress] == block.timestamp) {
                // add amount
                tokenLiquidityChanges[_tokenAddress][block.timestamp].amount += newLiqChange.amount;
            } else {
                // add to tail
                tokenLiquidityChanges[_tokenAddress][tokenLiquidityTail[_tokenAddress]]
                    .nextTimestamp = block.timestamp;
                tokenLiquidityChanges[_tokenAddress][block.timestamp] = newLiqChange;
                tokenLiquidityTail[_tokenAddress] = block.timestamp;
            }
        }
    }

    // Traverse the linked list from the head until the timestamp is within the period
    function _traverseLinkedListUntilInPeriod(
        address _tokenAddress,
        uint256 _timestamp,
        uint64 _maxIterations
    ) internal {
        int256 totalChange = 0;
        uint256 currentHeadTimestamp = tokenLiquidityHead[_tokenAddress];
        uint64 iterations = 0;

        while (
            currentHeadTimestamp != 0 &&
            _timestamp - currentHeadTimestamp >=
            tokensRateLimitInfo[_tokenAddress].withdrawalPeriod &&
            iterations <= _maxIterations
        ) {
            LiqChangeNode memory node = tokenLiquidityChanges[_tokenAddress][currentHeadTimestamp];
            uint256 nextTimestamp = node.nextTimestamp;
            // Save the nextTimestamp before deleting the node
            totalChange += node.amount;
            // Clear data
            delete tokenLiquidityChanges[_tokenAddress][currentHeadTimestamp];

            currentHeadTimestamp = nextTimestamp;
            iterations++;
        }

        if (currentHeadTimestamp == 0) {
            tokenLiquidityHead[_tokenAddress] = _timestamp;
            tokenLiquidityTail[_tokenAddress] = _timestamp;
        } else {
            tokenLiquidityHead[_tokenAddress] = currentHeadTimestamp;
        }
        // update historacle
        tokenLiquidityHistoracle[_tokenAddress] += totalChange;
        // update window
        tokenLiquidityWindowAmount[_tokenAddress] -= totalChange;
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
            erc20TokenNoLimit.safeTransfer(_recipient, _amount);
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
        erc20Token.safeTransfer(_recipient, _amount);
    }

    function overrideLimit() external onlyAdmin {
        isRateLimited = false;
    }

    function transferAdmin(address _admin) external onlyAdmin {
        if(_admin == address(0)) revert InvalidAdminAddress();
        admin = _admin;
    }

    // Allow users to claim locked funds when rate limit is resolved
    function claimLockedFunds(address _tokenAddress) external {
        if(lockedFunds[msg.sender][_tokenAddress] == 0) revert NoLockedFunds();
        if(isRateLimited) revert RateLimited();
        IERC20 erc20Token = IERC20(_tokenAddress);
        erc20Token.safeTransfer(msg.sender, lockedFunds[msg.sender][_tokenAddress]);
        lockedFunds[msg.sender][_tokenAddress] = 0;
    }

    function overrideExpiredRateLimit() public {
        if(!isRateLimited) revert NotRateLimited();
        if(block.timestamp - lastRateLimitTimestamp < rateLimitCooldownPeriod) revert CooldownPeriodNotReached();
        
        isRateLimited = false;
    }

    function addGuardedContracts(address[] calldata _guardedContracts) public onlyAdmin {
        for (uint256 i = 0; i < _guardedContracts.length; i++) {
            isGuarded[_guardedContracts[i]] = true;
        }
    }

    function removeGuardedContracts(address[] calldata _guardedContracts) public onlyAdmin {
        for (uint256 i = 0; i < _guardedContracts.length; i++) {
            isGuarded[_guardedContracts[i]] = false;
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

    

    // Due to potential inactivity, the linked list may grow to where
    // it is better to clear the backlog in advance to save gas for the users
    // this is a public function so that anyone can call it as it is not user sensitive
    function clearBackLog(address _tokenAddress, uint64 _maxIterations) external {
        _traverseLinkedListUntilInPeriod(_tokenAddress, block.timestamp, _maxIterations);
    }

    function isInGracePeriod() public view returns (bool) {
        return block.timestamp - lastRateLimitTimestamp <= gracePeriod && !isRateLimited;
    }

}
