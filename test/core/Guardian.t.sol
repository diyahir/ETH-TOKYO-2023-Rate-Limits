// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {MockDeFiProtocol} from "../mocks/MockDeFiProtocol.sol";
import {Guardian} from "../../src/core/Guardian.sol";

contract GuadianTest is Test {
    MockToken internal token;
    MockToken internal secondToken;
    MockToken internal unlimitedToken;
    Guardian internal guardian;
    MockDeFiProtocol internal deFi;

    address internal alice = vm.addr(0x1);
    address internal bob = vm.addr(0x2);
    address internal admin = vm.addr(0x3);

    function setUp() public {
        token = new MockToken("USDC", "USDC");
        deFi = new MockDeFiProtocol();
        guardian = new Guardian(admin, 3 days, 3 hours, 5 minutes);

        deFi.setGuardian(address(guardian));

        address[] memory addresses = new address[](1);
        addresses[0] = address(deFi);

        vm.prank(admin);
        guardian.addGuardedContracts(addresses);

        vm.prank(admin);
        // Guard USDC with 70% max drawdown per 4 hours
        guardian.registerToken(address(token), 7000, 4 hours, 1000e18);
        vm.warp(1 hours);
    }

    function testInitialization() public {
        Guardian newGuardian = new Guardian(admin, 3 days, 3 hours, 5 minutes);
        assertEq(newGuardian.admin(), admin);
        assertEq(newGuardian.rateLimitCooldownPeriod(), 3 days);
        assertEq(newGuardian.gracePeriod(), 3 hours);
    }

    function testMint() public {
        token.mint(alice, 2e18);
        assertEq(token.totalSupply(), token.balanceOf(alice));
    }

    function testBurn() public {
        token.mint(alice, 10e18);
        assertEq(token.balanceOf(alice), 10e18);

        token.burn(alice, 8e18);

        assertEq(token.totalSupply(), 2e18);
        assertEq(token.balanceOf(alice), 2e18);
    }

    function testRegisterTokenShouldBeSuccessful() public {
        secondToken = new MockToken("DAI", "DAI");
        vm.prank(admin);
        guardian.registerToken(address(secondToken), 7000, 4 hours, 1000e18);
        (uint256 minAmount, uint256 withdrawalPeriod, uint256 minLiquidityThreshold) = guardian
            .tokenRateLimitInfo(address(secondToken));
        assertEq(minAmount, 1000e18);
        assertEq(withdrawalPeriod, 4 hours);
        assertEq(minLiquidityThreshold, 7000);

        vm.prank(admin);
        guardian.updateTokenRateLimitParams(address(secondToken), 8000, 5 hours, 2000e18);
        (minAmount, withdrawalPeriod, minLiquidityThreshold) = guardian.tokenRateLimitInfo(
            address(secondToken)
        );
        assertEq(minAmount, 2000e18);
        assertEq(withdrawalPeriod, 5 hours);
        assertEq(minLiquidityThreshold, 8000);
    }

    function testRegisterTokenWhenMinimumLiquidityThresholdIsInvalidShouldFail() public {
        secondToken = new MockToken("DAI", "DAI");
        vm.prank(admin);
        vm.expectRevert(Guardian.InvalidMinimumLiquidityThreshold.selector);
        guardian.registerToken(address(secondToken), 0, 4 hours, 1000e18);

        vm.prank(admin);
        vm.expectRevert(Guardian.InvalidMinimumLiquidityThreshold.selector);
        guardian.registerToken(address(secondToken), 10_001, 4 hours, 1000e18);

        vm.prank(admin);
        vm.expectRevert(Guardian.InvalidMinimumLiquidityThreshold.selector);
        guardian.updateTokenRateLimitParams(address(secondToken), 0, 5 hours, 2000e18);

        vm.prank(admin);
        vm.expectRevert(Guardian.InvalidMinimumLiquidityThreshold.selector);
        guardian.updateTokenRateLimitParams(address(secondToken), 10_001, 5 hours, 2000e18);
    }

    function testRegisterTokenWhenAlreadyRegisteredShouldFail() public {
        secondToken = new MockToken("DAI", "DAI");
        vm.prank(admin);
        guardian.registerToken(address(secondToken), 7000, 4 hours, 1000e18);
        // Cannot register the same token twice
        vm.expectRevert(Guardian.TokenAlreadyExists.selector);
        vm.prank(admin);
        guardian.registerToken(address(secondToken), 7000, 4 hours, 1000e18);
    }

    function testDepositWithDrawNoLimitToken() public {
        unlimitedToken = new MockToken("DAI", "DAI");
        unlimitedToken.mint(alice, 10000e18);

        vm.prank(alice);
        unlimitedToken.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(unlimitedToken), 10000e18);

        assertEq(guardian.isRateLimitBreeched(address(unlimitedToken)), false);
        vm.warp(1 hours);
        vm.prank(alice);
        deFi.withdraw(address(unlimitedToken), 10000e18);
        assertEq(guardian.isRateLimitBreeched(address(unlimitedToken)), false);
    }

    function testDepositShouldBeSuccessful() public {
        token.mint(alice, 10000e18);

        vm.prank(alice);
        token.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(token), 10e18);

        assertEq(guardian.isRateLimitBreeched(address(token)), false);

        uint256 head = guardian.tokenLiquidityHead(address(token));
        uint256 tail = guardian.tokenLiquidityTail(address(token));

        assertEq(head, tail);
        assertEq(guardian.tokenLiquidityTotal(address(token)), 0);
        assertEq(guardian.tokenLiquidityInPeriod(address(token)), 10e18);

        (uint256 nextTimestamp, int256 amount) = guardian.tokenLiquidityChanges(
            address(token),
            head
        );
        assertEq(nextTimestamp, 0);
        assertEq(amount, 10e18);

        vm.warp(1 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 110e18);
        assertEq(guardian.isRateLimitBreeched(address(token)), false);
        assertEq(guardian.tokenLiquidityTotal(address(token)), 0);
        assertEq(guardian.tokenLiquidityInPeriod(address(token)), 120e18);

        // All the previous deposits are now out of the window and accounted for in the historacle
        vm.warp(10 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);
        assertEq(guardian.isRateLimitBreeched(address(token)), false);
        assertEq(guardian.tokenLiquidityInPeriod(address(token)), 10e18);
        assertEq(guardian.tokenLiquidityTotal(address(token)), 120e18);

        uint256 tailNext = guardian.tokenLiquidityTail(address(token));
        uint256 headNext = guardian.tokenLiquidityHead(address(token));
        assertEq(headNext, block.timestamp);
        assertEq(tailNext, block.timestamp);
        assertEq(headNext % 5 minutes, 0);
        assertEq(tailNext % 5 minutes, 0);
    }

    function testClearBacklogShouldBeSuccessful() public {
        token.mint(alice, 10000e18);

        vm.prank(alice);
        token.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(token), 1);

        vm.warp(2 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 1);

        vm.warp(3 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 1);

        vm.warp(4 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 1);

        vm.warp(5 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 1);

        vm.warp(6.5 hours);
        guardian.clearBackLog(address(token), 10);

        // only deposits from 2.5 hours and later should be in the window
        assertEq(guardian.tokenLiquidityInPeriod(address(token)), 3);
        assertEq(guardian.tokenLiquidityTotal(address(token)), 2);

        assertEq(guardian.tokenLiquidityHead(address(token)), 3 hours);
        assertEq(guardian.tokenLiquidityTail(address(token)), 5 hours);
    }

    function testWithdrawlsShouldBeSuccessful() public {
        token.mint(alice, 10000e18);

        vm.prank(alice);
        token.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(token), 100e18);

        vm.warp(1 hours);
        vm.prank(alice);
        deFi.withdraw(address(token), 60e18);
        assertEq(guardian.isRateLimitBreeched(address(token)), false);
        assertEq(guardian.tokenLiquidityInPeriod(address(token)), 40e18);
        assertEq(guardian.tokenLiquidityTotal(address(token)), 0);
        assertEq(token.balanceOf(alice), 9960e18);

        // All the previous deposits are now out of the window and accounted for in the historacle
        vm.warp(10 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);
        assertEq(guardian.isRateLimitBreeched(address(token)), false);
        assertEq(guardian.tokenLiquidityInPeriod(address(token)), 10e18);
        assertEq(guardian.tokenLiquidityTotal(address(token)), 40e18);

        uint256 tailNext = guardian.tokenLiquidityTail(address(token));
        uint256 headNext = guardian.tokenLiquidityHead(address(token));
        assertEq(headNext, block.timestamp);
        assertEq(tailNext, block.timestamp);
    }

    function testAddGuardedContractsShouldBeSuccessful() public {
        MockDeFiProtocol secondDeFi = new MockDeFiProtocol();
        secondDeFi.setGuardian(address(guardian));

        address[] memory addresses = new address[](1);
        addresses[0] = address(secondDeFi);
        vm.prank(admin);
        guardian.addGuardedContracts(addresses);

        assertEq(guardian.isGuardedContract(address(secondDeFi)), true);
    }

    function testRemoveGuardedContractsShouldBeSuccessful() public {
        MockDeFiProtocol secondDeFi = new MockDeFiProtocol();
        secondDeFi.setGuardian(address(guardian));

        address[] memory addresses = new address[](1);
        addresses[0] = address(secondDeFi);
        vm.prank(admin);
        guardian.addGuardedContracts(addresses);

        vm.prank(admin);
        guardian.removeGuardedContracts(addresses);
        assertEq(guardian.isGuardedContract(address(secondDeFi)), false);
    }

    function testBreach() public {
        // 1 Million USDC deposited
        token.mint(alice, 1_000_000e18);

        vm.prank(alice);
        token.approve(address(deFi), 1_000_000e18);

        vm.prank(alice);
        deFi.deposit(address(token), 1_000_000e18);

        // HACK
        // 300k USDC withdrawn
        int256 withdrawalAmount = 300_001e18;
        vm.warp(5 hours);
        vm.prank(alice);
        deFi.withdraw(address(token), uint256(withdrawalAmount));
        assertEq(guardian.isRateLimitBreeched(address(token)), true);
        assertEq(guardian.tokenLiquidityInPeriod(address(token)), -withdrawalAmount);
        assertEq(guardian.tokenLiquidityTotal(address(token)), 1_000_000e18);

        assertEq(guardian.lockedFunds(address(alice), address(token)), uint256(withdrawalAmount));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(guardian)), uint256(withdrawalAmount));
        assertEq(token.balanceOf(address(deFi)), 1_000_000e18 - uint256(withdrawalAmount));

        // Attempts to withdraw more than the limit
        vm.warp(6 hours);
        vm.prank(alice);
        int256 secondAmount = 10_000e18;
        deFi.withdraw(address(token), uint256(secondAmount));
        assertEq(guardian.isRateLimitBreeched(address(token)), true);
        assertEq(guardian.tokenLiquidityInPeriod(address(token)), -withdrawalAmount - secondAmount);
        assertEq(guardian.tokenLiquidityTotal(address(token)), 1_000_000e18);

        assertEq(
            guardian.lockedFunds(address(alice), address(token)),
            uint256(withdrawalAmount + secondAmount)
        );
        assertEq(token.balanceOf(alice), 0);

        // False alarm
        // override the limit and allow claim of funds
        vm.prank(admin);
        guardian.removeRateLimit();

        vm.warp(7 hours);
        vm.prank(alice);
        guardian.claimLockedFunds(address(token), address(alice));
        assertEq(token.balanceOf(alice), uint256(withdrawalAmount + secondAmount));
    }

    function testBreachAndLimitExpired() public {
        // 1 Million USDC deposited
        token.mint(alice, 1_000_000e18);

        vm.prank(alice);
        token.approve(address(deFi), 1_000_000e18);

        vm.prank(alice);
        deFi.deposit(address(token), 1_000_000e18);

        // HACK
        // 300k USDC withdrawn
        int256 withdrawalAmount = 300_001e18;
        vm.warp(5 hours);
        vm.prank(alice);
        deFi.withdraw(address(token), uint256(withdrawalAmount));
        assertEq(guardian.isRateLimitBreeched(address(token)), true);
        assertEq(guardian.isRateLimited(), true);

        vm.warp(4 days);
        vm.prank(alice);
        guardian.removeExpiredRateLimit();
        assertEq(guardian.isRateLimited(), false);
    }

    function testSetAdminShouldBeSuccessful() public {
        assertEq(guardian.admin(), admin);
        vm.prank(admin);
        guardian.setAdmin(bob);
        assertEq(guardian.admin(), bob);

        vm.expectRevert();
        vm.prank(admin);
        guardian.setAdmin(alice);
    }

    function testSetAdminWhenCallerIsNotAdminShouldFail() public {
        vm.expectRevert(Guardian.NotAdmin.selector);
        guardian.setAdmin(alice);
    }

    function testDepositsAndWithdrawlsInSameTickLength() public {
        vm.warp(1 days);
        token.mint(alice, 10000e18);

        vm.prank(alice);
        token.approve(address(deFi), 10000e18);

        // 10 USDC deposited
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);

        uint256 head = guardian.tokenLiquidityHead(address(token));
        assertEq(head % 5 minutes, 0);

        // 1 minute later 10 usdc deposited, 1 usdc withdrawn all within the same tick length
        vm.warp(1 days + 1 minutes);
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);

        deFi.withdraw(address(token), 1e18);

        (uint256 nextTimestamp, int256 amount) = guardian.tokenLiquidityChanges(
            address(token),
            head
        );
        assertEq(nextTimestamp, 0);
        assertEq(amount, 19e18);

        // Next tick length, 1 usdc withdrawn
        vm.warp(1 days + 6 minutes);
        vm.prank(alice);
        deFi.withdraw(address(token), 1e18);

        (nextTimestamp, amount) = guardian.tokenLiquidityChanges(address(token), head);
        assertEq(nextTimestamp, 1 days + 6 minutes - ((1 days + 6 minutes) % 5 minutes));
        assertEq(nextTimestamp % 5 minutes, 0);
        // previous tick length has 19 usdc deposited
        assertEq(amount, 19e18);

        // Next tick values
        (nextTimestamp, amount) = guardian.tokenLiquidityChanges(address(token), nextTimestamp);
        assertEq(nextTimestamp, 0);
        assertEq(amount, -1e18);
    }
}
