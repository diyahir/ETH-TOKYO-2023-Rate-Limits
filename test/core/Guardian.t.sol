// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {MockDeFiProtocol} from "../mocks/MockDeFiProtocol.sol";
import {Guardian} from "../../src/core/Guardian.sol";

contract GuadianTest is Test {
    MockToken internal _token;
    MockToken internal _secondToken;
    MockToken internal _unlimitedToken;
    Guardian internal _guardian;
    MockDeFiProtocol internal _deFi;

    // hardhat getSigner() -> vm.addr()
    address internal _alice = vm.addr(0x1);
    address internal _bob = vm.addr(0x2);
    address internal _admin = vm.addr(0x3);

    // hardhat beforeEach -> setUp
    function setUp() public {
        _token = new MockToken("USDC", "USDC");
        _deFi = new MockDeFiProtocol();
        _guardian = new Guardian(_admin, 3 days, 3 hours);

        _deFi.setGuardian(address(_guardian));

        address[] memory addresses = new address[](1);
        addresses[0] = address(_deFi);

        vm.prank(_admin);
        _guardian.addGuardedContracts(addresses);

        vm.prank(_admin);
        // Guard USDC with 70% max drawdown per 4 hours
        _guardian.registerToken(address(_token), 7000, 4 hours, 1000e18);
        vm.warp(1 hours);
    }

    function testInitialization() public {
        Guardian newGuardian = new Guardian(_admin, 3 days, 3 hours);
        assertEq(newGuardian.admin(), _admin);
        assertEq(newGuardian.rateLimitCooldownPeriod(), 3 days);
        assertEq(newGuardian.gracePeriod(), 3 hours);
    }

    function testMint() public {
        _token.mint(_alice, 2e18);
        assertEq(_token.totalSupply(), _token.balanceOf(_alice));
    }

    function testBurn() public {
        _token.mint(_alice, 10e18);
        assertEq(_token.balanceOf(_alice), 10e18);

        _token.burn(_alice, 8e18);

        assertEq(_token.totalSupply(), 2e18);
        assertEq(_token.balanceOf(_alice), 2e18);
    }

    function testRegisterTokenShouldBeSuccessful() public {
        _secondToken = new MockToken("DAI", "DAI");
        vm.prank(_admin);
        _guardian.registerToken(address(_secondToken), 7000, 4 hours, 1000e18);
        (uint256 minAmount, uint256 withdrawalPeriod, uint256 minLiquidityThreshold) =
            _guardian.tokenRateLimitInfo(address(_secondToken));
        assertEq(minAmount, 1000e18);
        assertEq(withdrawalPeriod, 4 hours);
        assertEq(minLiquidityThreshold, 7000);
    }

    function testRegisterTokenWhenMinimumLiquidityThresholdIsInvalidShouldFail() public {
        _secondToken = new MockToken("DAI", "DAI");
        vm.prank(_admin);
        vm.expectRevert(Guardian.InvalidMinimumLiquidityThreshold.selector);
        _guardian.registerToken(address(_secondToken), 0, 4 hours, 1000e18);

        vm.prank(_admin);
        vm.expectRevert(Guardian.InvalidMinimumLiquidityThreshold.selector);
        _guardian.registerToken(address(_secondToken), 10_001, 4 hours, 1000e18);
    }

    function testRegisterTokenWhenAlreadyRegisteredShouldFail() public {
        _secondToken = new MockToken("DAI", "DAI");
        vm.prank(_admin);
        _guardian.registerToken(address(_secondToken), 7000, 4 hours, 1000e18);
        // Cannot register the same _token twice
        vm.expectRevert(Guardian.TokenAlreadyExists.selector);
        vm.prank(_admin);
        _guardian.registerToken(address(_secondToken), 7000, 4 hours, 1000e18);
    }

    function testDepositWithDrawNoLimitToken() public {
        _unlimitedToken = new MockToken("DAI", "DAI");
        _unlimitedToken.mint(_alice, 10000e18);

        vm.prank(_alice);
        _unlimitedToken.approve(address(_deFi), 10000e18);

        vm.prank(_alice);
        _deFi.deposit(address(_unlimitedToken), 10000e18);

        assertEq(_guardian.isRateLimitBreeched(address(_unlimitedToken)), false);
        vm.warp(1 hours);
        vm.prank(_alice);
        _deFi.withdraw(address(_unlimitedToken), 10000e18);
        assertEq(_guardian.isRateLimitBreeched(address(_unlimitedToken)), false);
    }

    function testDepositShouldBeSuccessful() public {
        _token.mint(_alice, 10000e18);

        vm.prank(_alice);
        _token.approve(address(_deFi), 10000e18);

        vm.prank(_alice);
        _deFi.deposit(address(_token), 10e18);

        assertEq(_guardian.isRateLimitBreeched(address(_token)), false);

        uint256 head = _guardian.tokenLiquidityHead(address(_token));
        uint256 tail = _guardian.tokenLiquidityTail(address(_token));

        assertEq(head, tail);
        assertEq(_guardian.tokenLiquidityTotal(address(_token)), 0);
        assertEq(_guardian.tokenLiquidityInPeriod(address(_token)), 10e18);

        (uint256 nextTimestamp, int256 amount) = _guardian.tokenLiquidityChanges(address(_token), head);
        assertEq(nextTimestamp, 0);
        assertEq(amount, 10e18);

        vm.warp(1 hours);
        vm.prank(_alice);
        _deFi.deposit(address(_token), 110e18);
        assertEq(_guardian.isRateLimitBreeched(address(_token)), false);
        assertEq(_guardian.tokenLiquidityTotal(address(_token)), 0);
        assertEq(_guardian.tokenLiquidityInPeriod(address(_token)), 120e18);

        // All the previous deposits are now out of the window and accounted for in the historacle
        vm.warp(10 hours);
        vm.prank(_alice);
        _deFi.deposit(address(_token), 10e18);
        assertEq(_guardian.isRateLimitBreeched(address(_token)), false);
        assertEq(_guardian.tokenLiquidityInPeriod(address(_token)), 10e18);
        assertEq(_guardian.tokenLiquidityTotal(address(_token)), 120e18);

        uint256 tailNext = _guardian.tokenLiquidityTail(address(_token));
        uint256 headNext = _guardian.tokenLiquidityHead(address(_token));
        assertEq(headNext, block.timestamp);
        assertEq(tailNext, block.timestamp);
    }

    function testClearBacklogShouldBeSuccessful() public {
        _token.mint(_alice, 10000e18);

        vm.prank(_alice);
        _token.approve(address(_deFi), 10000e18);

        vm.prank(_alice);
        _deFi.deposit(address(_token), 1);

        vm.warp(2 hours);
        vm.prank(_alice);
        _deFi.deposit(address(_token), 1);

        vm.warp(3 hours);
        vm.prank(_alice);
        _deFi.deposit(address(_token), 1);

        vm.warp(4 hours);
        vm.prank(_alice);
        _deFi.deposit(address(_token), 1);

        vm.warp(5 hours);
        vm.prank(_alice);
        _deFi.deposit(address(_token), 1);

        vm.warp(6.5 hours);
        _guardian.clearBackLog(address(_token), 10);

        // only deposits from 2.5 hours and later should be in the window
        assertEq(_guardian.tokenLiquidityInPeriod(address(_token)), 3);
        assertEq(_guardian.tokenLiquidityTotal(address(_token)), 2);

        assertEq(_guardian.tokenLiquidityHead(address(_token)), 3 hours);
        assertEq(_guardian.tokenLiquidityTail(address(_token)), 5 hours);
    }

    function testWithdrawlsShouldBeSuccessful() public {
        _token.mint(_alice, 10000e18);

        vm.prank(_alice);
        _token.approve(address(_deFi), 10000e18);

        vm.prank(_alice);
        _deFi.deposit(address(_token), 100e18);

        vm.warp(1 hours);
        vm.prank(_alice);
        _deFi.withdraw(address(_token), 60e18);
        assertEq(_guardian.isRateLimitBreeched(address(_token)), false);
        assertEq(_guardian.tokenLiquidityInPeriod(address(_token)), 40e18);
        assertEq(_guardian.tokenLiquidityTotal(address(_token)), 0);
        assertEq(_token.balanceOf(_alice), 9960e18);

        // All the previous deposits are now out of the window and accounted for in the historacle
        vm.warp(10 hours);
        vm.prank(_alice);
        _deFi.deposit(address(_token), 10e18);
        assertEq(_guardian.isRateLimitBreeched(address(_token)), false);
        assertEq(_guardian.tokenLiquidityInPeriod(address(_token)), 10e18);
        assertEq(_guardian.tokenLiquidityTotal(address(_token)), 40e18);

        uint256 tailNext = _guardian.tokenLiquidityTail(address(_token));
        uint256 headNext = _guardian.tokenLiquidityHead(address(_token));
        assertEq(headNext, block.timestamp);
        assertEq(tailNext, block.timestamp);
    }

    function testAddGuardedContractsShouldBeSuccessful() public {
        MockDeFiProtocol secondDeFi = new MockDeFiProtocol();
        secondDeFi.setGuardian(address(_guardian));

        address[] memory addresses = new address[](1);
        addresses[0] = address(secondDeFi);
        vm.prank(_admin);
        _guardian.addGuardedContracts(addresses);

        assertEq(_guardian.isGuardedContract(address(secondDeFi)), true);
    }

    function testRemoveGuardedContractsShouldBeSuccessful() public {
        MockDeFiProtocol secondDeFi = new MockDeFiProtocol();
        secondDeFi.setGuardian(address(_guardian));

        address[] memory addresses = new address[](1);
        addresses[0] = address(secondDeFi);
        vm.prank(_admin);
        _guardian.addGuardedContracts(addresses);

        vm.prank(_admin);
        _guardian.removeGuardedContracts(addresses);
        assertEq(_guardian.isGuardedContract(address(secondDeFi)), false);
    }

    function testBreach() public {
        // 1 Million USDC deposited
        _token.mint(_alice, 1_000_000e18);

        vm.prank(_alice);
        _token.approve(address(_deFi), 1_000_000e18);

        vm.prank(_alice);
        _deFi.deposit(address(_token), 1_000_000e18);

        // HACK
        // 300k USDC withdrawn
        int256 withdrawalAmount = 300_001e18;
        vm.warp(5 hours);
        vm.prank(_alice);
        _deFi.withdraw(address(_token), uint256(withdrawalAmount));
        assertEq(_guardian.isRateLimitBreeched(address(_token)), true);
        assertEq(_guardian.tokenLiquidityInPeriod(address(_token)), -withdrawalAmount);
        assertEq(_guardian.tokenLiquidityTotal(address(_token)), 1_000_000e18);

        assertEq(_guardian.lockedFunds(address(_alice), address(_token)), uint256(withdrawalAmount));
        assertEq(_token.balanceOf(_alice), 0);
        assertEq(_token.balanceOf(address(_guardian)), uint256(withdrawalAmount));
        assertEq(_token.balanceOf(address(_deFi)), 1_000_000e18 - uint256(withdrawalAmount));

        // Attempts to withdraw more than the limit
        vm.warp(6 hours);
        vm.prank(_alice);
        int256 secondAmount = 10_000e18;
        _deFi.withdraw(address(_token), uint256(secondAmount));
        assertEq(_guardian.isRateLimitBreeched(address(_token)), true);
        assertEq(_guardian.tokenLiquidityInPeriod(address(_token)), -withdrawalAmount - secondAmount);
        assertEq(_guardian.tokenLiquidityTotal(address(_token)), 1_000_000e18);

        assertEq(_guardian.lockedFunds(address(_alice), address(_token)), uint256(withdrawalAmount + secondAmount));
        assertEq(_token.balanceOf(_alice), 0);

        // False alarm
        // override the limit and allow claim of funds
        vm.prank(_admin);
        _guardian.removeRateLimit();

        vm.warp(7 hours);
        vm.prank(_alice);
        _guardian.claimLockedFunds(address(_token));
        assertEq(_token.balanceOf(_alice), uint256(withdrawalAmount + secondAmount));
    }

    function testBreachAndLimitExpired() public {
        // 1 Million USDC deposited
        _token.mint(_alice, 1_000_000e18);

        vm.prank(_alice);
        _token.approve(address(_deFi), 1_000_000e18);

        vm.prank(_alice);
        _deFi.deposit(address(_token), 1_000_000e18);

        // HACK
        // 300k USDC withdrawn
        int256 withdrawalAmount = 300_001e18;
        vm.warp(5 hours);
        vm.prank(_alice);
        _deFi.withdraw(address(_token), uint256(withdrawalAmount));
        assertEq(_guardian.isRateLimitBreeched(address(_token)), true);
        assertEq(_guardian.isRateLimited(), true);

        vm.warp(4 days);
        vm.prank(_alice);
        _guardian.removeExpiredRateLimit();
        assertEq(_guardian.isRateLimited(), false);
    }

    function testSetAdminShouldBeSuccessful() public {
        assertEq(_guardian.admin(), _admin);
        vm.prank(_admin);
        _guardian.setAdmin(_bob);
        assertEq(_guardian.admin(), _bob);

        vm.expectRevert();
        vm.prank(_admin);
        _guardian.setAdmin(_alice);
    }

    function testSetAdminWhenCallerIsNotAdminShouldFail() public {
        vm.expectRevert(Guardian.NotAdmin.selector);
        _guardian.setAdmin(_alice);
    }
}
