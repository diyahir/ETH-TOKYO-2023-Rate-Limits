// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IGuardian} from "../interfaces/IGuardian.sol";
import {LiqChangeNode, TokenRateLimitInfo} from "../static/Structs.sol";

contract Guardian is IGuardian {
    using SafeERC20 for IERC20;

    /*******************************
     * Errors *
     *******************************/

    error NotAGuardedContract();
    error NotAdmin();
    error InvalidAdminAddress();
    error InvalidMinimumLiquidityThreshold();
    error TokenAlreadyExists();
    error TokenDoesNotExist();
    error NoLockedFunds();
    error RateLimited();
    error NotRateLimited();
    error CooldownPeriodNotReached();

    /*******************************
     * Events *
     *******************************/

    /**
     * @notice Emitted when a token is registered
     */
    event TokenRegistered(
        address indexed token,
        uint256 withdrawalPeriod,
        uint256 minLiquidityThreshold,
        uint256 minAmount
    );

    event TokenInflow(address indexed token, uint256 indexed amount);
    event TokenRateLimitBreached(address indexed token, uint256 timestamp);
    event TokenWithdraw(address indexed token, address indexed recipient, uint256 amount);
    event LockedFundsClaimed(address indexed token, address indexed recipient);
    event TokenBacklogCleaned(address indexed token, uint256 timestamp);
    event AdminSet(address indexed newAdmin);

    /*******************************
     * Constants *
     *******************************/

    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public constant MAX_INT = 2 ** 64 - 1;

    /*******************************
     * State vars *
     *******************************/

    /**
     * @notice The aggregate amount of total recorded liquidity per token
     * @dev only updated at token inflow and withdraw operations
     */
    mapping(address token => int256 amount) public tokenLiquidityTotal;

    /**
     * @notice The amount of recorded liquidity in the current withdraw period, per token.
     */
    mapping(address token => int256 amount) public tokenLiquidityInPeriod;

    mapping(address token => uint256 timestamp) public tokenLiquidityHead;
    mapping(address token => uint256 timestamp) public tokenLiquidityTail;

    mapping(address token => mapping(uint256 timestamp => LiqChangeNode node))
        public tokenLiquidityChanges;

    mapping(address token => TokenRateLimitInfo info) public tokenRateLimitInfo;

    /**
     * @notice Funds locked if rate limited reached
     */
    mapping(address recipient => mapping(address token => uint256 amount)) public lockedFunds;

    mapping(address account => bool guardActive) public isGuardedContract;

    address public admin;

    bool public isRateLimited;

    uint256 public rateLimitCooldownPeriod;

    uint256 public lastRateLimitTimestamp;

    uint256 public gracePeriod = 3 hours;

    /*******************************
     * Modifiers *
     *******************************/

    modifier onlyGuarded() {
        if (!isGuardedContract[msg.sender]) revert NotAGuardedContract();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    /*******************************
     * Constructor *
     *******************************/

    /**
     * @notice gracePeriod refers to the time after a rate limit breech and then overriden where withdrawals are
     * still allowed.
     * @dev For example a false positive rate limit breech, then it is overriden, so withdrawals are still
     * allowed for a period of time.
     * Before the rate limit is enforced again, it should be set to be at least your largest
     * withdrawalPeriod length
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
        address _token,
        uint256 _minLiquidityThreshold,
        uint256 _withdrawalPeriod,
        uint256 _minAmount
    ) external onlyAdmin {
        if (_minLiquidityThreshold == 0 || _minLiquidityThreshold > BPS_DENOMINATOR) {
            revert InvalidMinimumLiquidityThreshold();
        }
        TokenRateLimitInfo storage token = tokenRateLimitInfo[_token];
        if (token.minLiquidityTreshold > 0) revert TokenAlreadyExists();

        token.minLiquidityTreshold = _minLiquidityThreshold;
        token.withdrawalPeriod = _withdrawalPeriod;
        token.minAmount = _minAmount;
        emit TokenRegistered(_token, _withdrawalPeriod, _minLiquidityThreshold, _minAmount);
    }

    function updateTokenRateLimitParams(
        address _token,
        uint256 _minLiquidityThreshold,
        uint256 _withdrawalPeriod,
        uint256 _minAmount
    ) external onlyAdmin {
        TokenRateLimitInfo storage token = tokenRateLimitInfo[_token];
        if (token.minLiquidityTreshold == 0) revert TokenDoesNotExist();
        token.minLiquidityTreshold = _minLiquidityThreshold;
        token.withdrawalPeriod = _withdrawalPeriod;
        token.minAmount = _minAmount;

        // if the withdrawl period is smaller, clear the backlog
        // if the withdrawal period is larger, this has no effect
        _traverseLinkedListUntilInPeriod(_token, block.timestamp, MAX_INT);
    }

    /**
     * @dev Give guarded contracts one function to call for convenience
     */
    function recordInflow(address _token, uint256 _amount) external onlyGuarded {
        _recordTokenChange(_token, _amount, true);
        emit TokenInflow(_token, _amount);
    }

    function _recordTokenChange(
        address _token,
        uint256 _amount,
        bool _isPositive
    ) internal onlyGuarded {
        TokenRateLimitInfo memory tokenRlInfo = tokenRateLimitInfo[_token];

        // If token does not have a rate limit, do nothing
        if (!tokenRateLimitInfoExists(tokenRlInfo)) {
            return;
        }

        // create a new inflow
        LiqChangeNode memory newLiqChange;

        // NOTE: Might be unsafe for huge numbers
        newLiqChange.amount = int256(_amount);

        // add to period
        if (!_isPositive) {
            newLiqChange.amount = -int256(_amount);
        }
        tokenLiquidityInPeriod[_token] += newLiqChange.amount;

        // if there is no head, set the head to the new inflow
        if (tokenLiquidityHead[_token] == 0) {
            tokenLiquidityHead[_token] = block.timestamp;
            tokenLiquidityTail[_token] = block.timestamp;
            tokenLiquidityChanges[_token][block.timestamp] = newLiqChange;
        } else {
            // if there is a head, check if the new inflow is within the period
            // if it is, add it to the head
            // if it is not, add it to the tail
            if (block.timestamp - tokenLiquidityHead[_token] >= tokenRlInfo.withdrawalPeriod) {
                _traverseLinkedListUntilInPeriod(_token, block.timestamp, MAX_INT);
            }

            // check if tail is the same as block.timestamp (multiple txs in same block)
            if (tokenLiquidityTail[_token] == block.timestamp) {
                // add amount
                tokenLiquidityChanges[_token][block.timestamp].amount += newLiqChange.amount;
            } else {
                // add to tail
                tokenLiquidityChanges[_token][tokenLiquidityTail[_token]].nextTimestamp = block
                    .timestamp;
                tokenLiquidityChanges[_token][block.timestamp] = newLiqChange;
                tokenLiquidityTail[_token] = block.timestamp;
            }
        }
    }

    /**
     * @dev Traverse the linked list from the head until the timestamp is within the period
     */
    function _traverseLinkedListUntilInPeriod(
        address _token,
        uint256 _timestamp,
        uint256 _maxIterations
    ) internal {
        uint256 currentHeadTimestamp = tokenLiquidityHead[_token];
        uint64 iterations = 0;
        int256 totalChange = 0;

        while (
            currentHeadTimestamp != 0 &&
            _timestamp - currentHeadTimestamp >= tokenRateLimitInfo[_token].withdrawalPeriod &&
            iterations <= _maxIterations
        ) {
            LiqChangeNode memory node = tokenLiquidityChanges[_token][currentHeadTimestamp];
            uint256 nextTimestamp = node.nextTimestamp;
            // Save the nextTimestamp before deleting the node
            totalChange += node.amount;
            // Clear data
            delete tokenLiquidityChanges[_token][currentHeadTimestamp];

            currentHeadTimestamp = nextTimestamp;
            iterations++;
        }

        // If the list is empty, set the tail and head to _timestamp
        if (currentHeadTimestamp == 0) {
            tokenLiquidityHead[_token] = _timestamp;
            tokenLiquidityTail[_token] = _timestamp;
        } else {
            tokenLiquidityHead[_token] = currentHeadTimestamp;
        }
        // update total liquidity
        tokenLiquidityTotal[_token] += totalChange;
        // update period
        tokenLiquidityInPeriod[_token] -= totalChange;
    }

    function withdraw(address _token, uint256 _amount, address _recipient) external onlyGuarded {
        TokenRateLimitInfo memory tokenRlInfo = tokenRateLimitInfo[_token];

        // Check if the token has enforced rate limited
        if (!tokenRateLimitInfoExists(tokenRlInfo)) {
            // if it is not rate limited, just transfer the tokens
            IERC20 erc20TokenNoLimit = IERC20(_token);
            erc20TokenNoLimit.safeTransfer(_recipient, _amount);
            return;
        }
        _recordTokenChange(_token, _amount, false);
        // Check if currently rate limited, if so, add to locked funds claimable when resolved
        if (isRateLimited) {
            lockedFunds[_recipient][_token] += _amount;
            return;
        }

        // Check if rate limit is breeched after withdrawal and not in grace period
        // (grace period allows for withdrawals to be made if rate limit is breeched but overriden)
        if (isRateLimitBreeched(_token) && !isInGracePeriod()) {
            // if it is, set rate limited to true
            isRateLimited = true;
            lastRateLimitTimestamp = block.timestamp;
            // add to locked funds claimable when resolved
            lockedFunds[_recipient][_token] += _amount;

            emit TokenRateLimitBreached(_token, block.timestamp);

            return;
        }

        // if everything is good, transfer the tokens
        IERC20 erc20Token = IERC20(_token);
        erc20Token.safeTransfer(_recipient, _amount);

        emit TokenWithdraw(_token, _recipient, _amount);
    }

    function isRateLimitBreeched(address _token) public view returns (bool) {
        TokenRateLimitInfo memory tokenRlInfo = tokenRateLimitInfo[_token];
        if (!tokenRateLimitInfoExists(tokenRlInfo)) {
            return false;
        }
        int256 currentLiq = tokenLiquidityTotal[_token];

        // Only enforce rate limit if there is significant liquidity
        if (tokenRlInfo.minAmount > uint256(currentLiq)) {
            return false;
        }

        int256 futureLiq = currentLiq + tokenLiquidityInPeriod[_token];
        // NOTE: uint256 to int256 conversion here is safe
        int256 minLiq = (currentLiq * int256(tokenRlInfo.minLiquidityTreshold)) /
            int256(BPS_DENOMINATOR);

        return futureLiq < minLiq;
    }

    function isInGracePeriod() public view returns (bool) {
        return block.timestamp - lastRateLimitTimestamp <= gracePeriod && !isRateLimited;
    }

    /**
     * @notice Allow users to claim locked funds when rate limit is resolved
     */
    function claimLockedFunds(address _token) external {
        if (lockedFunds[msg.sender][_token] == 0) revert NoLockedFunds();
        if (isRateLimited) revert RateLimited();
        IERC20 erc20Token = IERC20(_token);
        erc20Token.safeTransfer(msg.sender, lockedFunds[msg.sender][_token]);
        lockedFunds[msg.sender][_token] = 0;

        emit LockedFundsClaimed(_token, msg.sender);
    }

    /**
     * @dev Due to potential inactivity, the linked list may grow to where
     * it is better to clear the backlog in advance to save gas for the users
     * this is a public function so that anyone can call it as it is not user sensitive
     */
    function clearBackLog(address _token, uint256 _maxIterations) external {
        _traverseLinkedListUntilInPeriod(_token, block.timestamp, _maxIterations);
        emit TokenBacklogCleaned(_token, block.timestamp);
    }

    function setAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert InvalidAdminAddress();
        admin = _newAdmin;
        emit AdminSet(_newAdmin);
    }

    function removeRateLimit() external onlyAdmin {
        isRateLimited = false;
    }

    function removeExpiredRateLimit() external {
        if (!isRateLimited) revert NotRateLimited();
        if (block.timestamp - lastRateLimitTimestamp < rateLimitCooldownPeriod)
            revert CooldownPeriodNotReached();

        isRateLimited = false;
    }

    function addGuardedContracts(address[] calldata _guardedContracts) external onlyAdmin {
        for (uint256 i = 0; i < _guardedContracts.length; i++) {
            isGuardedContract[_guardedContracts[i]] = true;
        }
    }

    function removeGuardedContracts(address[] calldata _guardedContracts) external onlyAdmin {
        for (uint256 i = 0; i < _guardedContracts.length; i++) {
            isGuardedContract[_guardedContracts[i]] = false;
        }
    }

    function tokenRateLimitInfoExists(
        TokenRateLimitInfo memory tokenRlInfo
    ) public pure returns (bool exists) {
        exists = tokenRlInfo.minLiquidityTreshold > 0;
    }
}
