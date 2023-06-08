// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {Limiter, LiqChangeNode} from "../static/Structs.sol";
import {LimiterLib, LimitStatus} from "../utils/LimiterLib.sol";

contract Guardian is IGuardian {
    using SafeERC20 for IERC20;
    using LimiterLib for Limiter;

    /**
     *
     * Errors *
     *
     */

    error NotAGuardedContract();
    error NotAdmin();
    error InvalidAdminAddress();
    error NoLockedFunds();
    error RateLimited();
    error NotRateLimited();
    error CooldownPeriodNotReached();

    /**
     *
     * Events *
     *
     */

    /**
     * @notice Emitted when a token is registered
     */
    event TokenRegistered(address indexed token, uint256 minKeepBps, uint256 limitBeginThreshold);
    event TokenInflow(address indexed token, uint256 indexed amount);
    event TokenRateLimitBreached(address indexed token, uint256 timestamp);
    event TokenWithdraw(address indexed token, address indexed recipient, uint256 amount);
    event LockedFundsClaimed(address indexed token, address indexed recipient);
    event TokenBacklogCleaned(address indexed token, uint256 timestamp);
    event AdminSet(address indexed newAdmin);

    /**
     *
     * Constants *
     *
     */

    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public constant MAX_INT = 2 ** 64 - 1;

    /**
     *
     * State vars *
     *
     */

    mapping(address => Limiter limiter) public tokenLimiters;

    /**
     * @notice Funds locked if rate limited reached
     */
    mapping(address recipient => mapping(address token => uint256 amount)) public lockedFunds;

    mapping(address account => bool guardActive) public isGuardedContract;

    address public admin;

    bool public isRateLimited;

    uint256 public rateLimitCooldownPeriod;

    uint256 public lastRateLimitTimestamp;

    uint256 public gracePeriodEndTimestamp;

    uint256 public immutable WITHDRAWAL_PERIOD;

    uint256 public immutable TICK_LENGTH;

    /**
     *
     * Modifiers *
     *
     */

    modifier onlyGuarded() {
        if (!isGuardedContract[msg.sender]) revert NotAGuardedContract();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    /**
     *
     * Constructor *
     *
     */

    /**
     * @notice gracePeriod refers to the time after a rate limit breech and then overriden where withdrawals are
     * still allowed.
     * @dev For example a false positive rate limit breech, then it is overriden, so withdrawals are still
     * allowed for a period of time.
     * Before the rate limit is enforced again, it should be set to be at least your largest
     * withdrawalPeriod length
     */

    constructor(
        address _admin,
        uint256 _rateLimitCooldownPeriod,
        uint256 _withdrawlPeriod,
        uint256 _liquidityTickLength
    ) {
        admin = _admin;
        rateLimitCooldownPeriod = _rateLimitCooldownPeriod;
        WITHDRAWAL_PERIOD = _withdrawlPeriod;
        TICK_LENGTH = _liquidityTickLength;
    }

    ////////////////////////////////////////////////////////////////
    //                         FUNCTIONS                          //
    ////////////////////////////////////////////////////////////////

    function registerToken(address _token, uint256 _minLiqRetainedBps, uint256 _limitBeginThreshold)
        external
        onlyAdmin
    {
        tokenLimiters[_token].init(_minLiqRetainedBps, _limitBeginThreshold);
        emit TokenRegistered(_token, _minLiqRetainedBps, _limitBeginThreshold);
    }

    function updateTokenRateLimitParams(address _token, uint256 _minLiqRetainedBps, uint256 _limitBeginThreshold)
        external
        onlyAdmin
    {
        Limiter storage limiter = tokenLimiters[_token];
        limiter.updateParams(_minLiqRetainedBps, _limitBeginThreshold);
        limiter.sync(WITHDRAWAL_PERIOD);
    }

    /**
     * @dev Give guarded contracts one function to call for convenience
     */
    function recordInflow(address _token, uint256 _amount) external onlyGuarded {
        /// @dev uint256 could overflow into negative
        tokenLimiters[_token].recordChange(int256(_amount), WITHDRAWAL_PERIOD, TICK_LENGTH);
        emit TokenInflow(_token, _amount);
    }

    function withdraw(address _token, uint256 _amount, address _recipient, bool _revertOnRateLimit)
        external
        onlyGuarded
    {
        Limiter storage limiter = tokenLimiters[_token];
        // Check if the token has enforced rate limited
        if (!limiter.initialized()) {
            // if it is not rate limited, just transfer the tokens
            IERC20(_token).safeTransfer(_recipient, _amount);
            return;
        }
        limiter.recordChange(-int256(_amount), WITHDRAWAL_PERIOD, TICK_LENGTH);
        // Check if currently rate limited, if so, add to locked funds claimable when resolved
        if (isRateLimited) {
            if (_revertOnRateLimit) {
                revert RateLimited();
            }
            lockedFunds[_recipient][_token] += _amount;
            return;
        }

        // Check if rate limit is breeched after withdrawal and not in grace period
        // (grace period allows for withdrawals to be made if rate limit is breeched but overriden)
        if (limiter.status() == LimitStatus.Breeched && !isInGracePeriod()) {
            if (_revertOnRateLimit) {
                revert RateLimited();
            }
            // if it is, set rate limited to true
            isRateLimited = true;
            lastRateLimitTimestamp = block.timestamp;
            // add to locked funds claimable when resolved
            lockedFunds[_recipient][_token] += _amount;

            emit TokenRateLimitBreached(_token, block.timestamp);

            return;
        }

        // if everything is good, transfer the tokens
        IERC20(_token).safeTransfer(_recipient, _amount);

        emit TokenWithdraw(_token, _recipient, _amount);
    }

    function isRateLimitBreeched(address _token) public view returns (bool) {
        return tokenLimiters[_token].status() == LimitStatus.Breeched;
    }

    function isInGracePeriod() public view returns (bool) {
        return block.timestamp <= gracePeriodEndTimestamp;
    }

    /**
     * @notice Allow users to claim locked funds when rate limit is resolved
     */
    function claimLockedFunds(address _token, address _recipient) external {
        if (lockedFunds[_recipient][_token] == 0) revert NoLockedFunds();
        if (isRateLimited) revert RateLimited();
        IERC20 erc20Token = IERC20(_token);
        erc20Token.safeTransfer(_recipient, lockedFunds[_recipient][_token]);
        lockedFunds[_recipient][_token] = 0;

        emit LockedFundsClaimed(_token, _recipient);
    }

    /**
     * @dev Due to potential inactivity, the linked list may grow to where
     * it is better to clear the backlog in advance to save gas for the users
     * this is a public function so that anyone can call it as it is not user sensitive
     */
    function clearBackLog(address _token, uint256 _maxIterations) external {
        tokenLimiters[_token].sync(WITHDRAWAL_PERIOD, _maxIterations);
        emit TokenBacklogCleaned(_token, block.timestamp);
    }

    function setAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert InvalidAdminAddress();
        admin = _newAdmin;
        emit AdminSet(_newAdmin);
    }

    function removeRateLimit() external onlyAdmin {
        if (!isRateLimited) revert NotRateLimited();
        isRateLimited = false;
        // Allow the grace period to extend for the full withdrawal period to not trigger rate limit again
        // if the rate limit is removed just before the withdrawal period ends
        gracePeriodEndTimestamp = lastRateLimitTimestamp + WITHDRAWAL_PERIOD;
    }

    function removeExpiredRateLimit() external {
        if (!isRateLimited) revert NotRateLimited();
        if (block.timestamp - lastRateLimitTimestamp < rateLimitCooldownPeriod) {
            revert CooldownPeriodNotReached();
        }

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

    function tokenLiquidityChanges(address _token, uint256 _tickTimestamp)
        external
        view
        returns (uint256 nextTimestamp, int256 amount)
    {
        LiqChangeNode storage node = tokenLimiters[_token].listNodes[_tickTimestamp];
        nextTimestamp = node.nextTimestamp;
        amount = node.amount;
    }
}
