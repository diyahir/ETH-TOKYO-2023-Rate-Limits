// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {MockDeFiProtocol} from "../mocks/MockDeFiProtocol.sol";
import {CircuitBreaker} from "src/core/CircuitBreaker.sol";
import {LimiterLib} from "src/utils/LimiterLib.sol";

contract GuadianTest is Test {
    MockToken internal token;
    MockToken internal secondToken;
    MockToken internal unlimitedToken;
    CircuitBreaker internal circuitBreaker;
    MockDeFiProtocol internal deFi;

    address internal alice = vm.addr(0x1);
    address internal bob = vm.addr(0x2);
    address internal admin = vm.addr(0x3);

    function setUp() public {
        token = new MockToken("USDC", "USDC");
        circuitBreaker = new CircuitBreaker(admin, 3 days, 4 hours, 5 minutes);
        deFi = new MockDeFiProtocol(address(circuitBreaker));

        address[] memory addresses = new address[](1);
        addresses[0] = address(deFi);

        vm.prank(admin);
        circuitBreaker.addProtectedContracts(addresses);

        vm.prank(admin);
        // Protect USDC with 70% max drawdown per 4 hours
        circuitBreaker.registerToken(address(token), 7000, 1000e18);
        vm.warp(1 hours);
    }

    function testInitialization() public {
        CircuitBreaker newCircuitBreaker = new CircuitBreaker(admin, 3 days, 3 hours, 5 minutes);
        assertEq(newCircuitBreaker.admin(), admin);
        assertEq(newCircuitBreaker.rateLimitCooldownPeriod(), 3 days);
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
        circuitBreaker.registerToken(address(secondToken), 7000, 1000e18);
        (uint256 minLiquidityThreshold, uint256 minAmount, , , , ) = circuitBreaker.tokenLimiters(
            address(secondToken)
        );
        assertEq(minAmount, 1000e18);
        assertEq(minLiquidityThreshold, 7000);

        vm.prank(admin);
        circuitBreaker.updateTokenRateLimitParams(address(secondToken), 8000, 2000e18);
        (minLiquidityThreshold, minAmount, , , , ) = circuitBreaker.tokenLimiters(
            address(secondToken)
        );
        assertEq(minAmount, 2000e18);
        assertEq(minLiquidityThreshold, 8000);
    }

    function testRegisterTokenWhenMinimumLiquidityThresholdIsInvalidShouldFail() public {
        secondToken = new MockToken("DAI", "DAI");
        vm.prank(admin);
        vm.expectRevert(LimiterLib.InvalidMinimumLiquidityThreshold.selector);
        circuitBreaker.registerToken(address(secondToken), 0, 1000e18);

        vm.prank(admin);
        vm.expectRevert(LimiterLib.InvalidMinimumLiquidityThreshold.selector);
        circuitBreaker.registerToken(address(secondToken), 10_001, 1000e18);

        vm.prank(admin);
        vm.expectRevert(LimiterLib.InvalidMinimumLiquidityThreshold.selector);
        circuitBreaker.updateTokenRateLimitParams(address(secondToken), 0, 2000e18);

        vm.prank(admin);
        vm.expectRevert(LimiterLib.InvalidMinimumLiquidityThreshold.selector);
        circuitBreaker.updateTokenRateLimitParams(address(secondToken), 10_001, 2000e18);
    }

    function testRegisterTokenWhenAlreadyRegisteredShouldFail() public {
        secondToken = new MockToken("DAI", "DAI");
        vm.prank(admin);
        circuitBreaker.registerToken(address(secondToken), 7000, 1000e18);
        // Cannot register the same token twice
        vm.expectRevert(LimiterLib.LimiterAlreadyInitialized.selector);
        vm.prank(admin);
        circuitBreaker.registerToken(address(secondToken), 7000, 1000e18);
    }

    function testDepositWithDrawNoLimitToken() public {
        unlimitedToken = new MockToken("DAI", "DAI");
        unlimitedToken.mint(alice, 10000e18);

        vm.prank(alice);
        unlimitedToken.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(unlimitedToken), 10000e18);

        assertEq(circuitBreaker.isRateLimitBreeched(address(unlimitedToken)), false);
        vm.warp(1 hours);
        vm.prank(alice);
        deFi.withdrawal(address(unlimitedToken), 10000e18);
        assertEq(circuitBreaker.isRateLimitBreeched(address(unlimitedToken)), false);
    }

    function testDepositShouldBeSuccessful() public {
        token.mint(alice, 10000e18);

        vm.prank(alice);
        token.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(token), 10e18);

        assertEq(circuitBreaker.isRateLimitBreeched(address(token)), false);

        (, , int256 liqTotal, int256 liqInPeriod, uint256 head, uint256 tail) = circuitBreaker
            .tokenLimiters(address(token));

        assertEq(head, tail);
        assertEq(liqTotal, 0);
        assertEq(liqInPeriod, 10e18);

        (uint256 nextTimestamp, int256 amount) = circuitBreaker.tokenLiquidityChanges(
            address(token),
            head
        );
        assertEq(nextTimestamp, 0);
        assertEq(amount, 10e18);

        vm.warp(1 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 110e18);
        assertEq(circuitBreaker.isRateLimitBreeched(address(token)), false);
        (, , liqTotal, liqInPeriod, , ) = circuitBreaker.tokenLimiters(address(token));
        assertEq(liqTotal, 0);
        assertEq(liqInPeriod, 120e18);

        // All the previous deposits are now out of the window and accounted for in the historacle
        vm.warp(10 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);
        assertEq(circuitBreaker.isRateLimitBreeched(address(token)), false);
        (, , liqTotal, liqInPeriod, head, tail) = circuitBreaker.tokenLimiters(address(token));
        assertEq(liqTotal, 120e18);
        assertEq(liqInPeriod, 10e18);

        assertEq(head, block.timestamp);
        assertEq(tail, block.timestamp);
        assertEq(head % 5 minutes, 0);
        assertEq(tail % 5 minutes, 0);
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
        circuitBreaker.clearBackLog(address(token), 10);

        (, , int256 liqTotal, int256 liqInPeriod, uint256 head, uint256 tail) = circuitBreaker
            .tokenLimiters(address(token));
        // only deposits from 2.5 hours and later should be in the window
        assertEq(liqInPeriod, 3);
        assertEq(liqTotal, 2);

        assertEq(head, 3 hours);
        assertEq(tail, 5 hours);
    }

    function testWithdrawlsShouldBeSuccessful() public {
        token.mint(alice, 10000e18);

        vm.prank(alice);
        token.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(token), 100e18);

        vm.warp(1 hours);
        vm.prank(alice);
        deFi.withdrawal(address(token), 60e18);
        assertEq(circuitBreaker.isRateLimitBreeched(address(token)), false);
        (, , int256 liqTotal, int256 liqInPeriod, , ) = circuitBreaker.tokenLimiters(
            address(token)
        );
        assertEq(liqInPeriod, 40e18);
        assertEq(liqTotal, 0);
        assertEq(token.balanceOf(alice), 9960e18);

        // All the previous deposits are now out of the window and accounted for in the historacle
        vm.warp(10 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);
        assertEq(circuitBreaker.isRateLimitBreeched(address(token)), false);

        uint256 tail;
        uint256 head;
        (, , liqTotal, liqInPeriod, head, tail) = circuitBreaker.tokenLimiters(address(token));
        assertEq(liqInPeriod, 10e18);
        assertEq(liqTotal, 40e18);

        assertEq(head, block.timestamp);
        assertEq(tail, block.timestamp);
    }

    function testAddProtectedContractsShouldBeSuccessful() public {
        MockDeFiProtocol secondDeFi = new MockDeFiProtocol(address(circuitBreaker));

        address[] memory addresses = new address[](1);
        addresses[0] = address(secondDeFi);
        vm.prank(admin);
        circuitBreaker.addProtectedContracts(addresses);

        assertEq(circuitBreaker.isProtectedContract(address(secondDeFi)), true);
    }

    function testRemoveProtectedContractsShouldBeSuccessful() public {
        MockDeFiProtocol secondDeFi = new MockDeFiProtocol(address(circuitBreaker));

        address[] memory addresses = new address[](1);
        addresses[0] = address(secondDeFi);
        vm.prank(admin);
        circuitBreaker.addProtectedContracts(addresses);

        vm.prank(admin);
        circuitBreaker.removeProtectedContracts(addresses);
        assertEq(circuitBreaker.isProtectedContract(address(secondDeFi)), false);
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
        deFi.withdrawal(address(token), uint256(withdrawalAmount));
        assertEq(circuitBreaker.isRateLimitBreeched(address(token)), true);
        (, , int256 liqTotal, int256 liqInPeriod, , ) = circuitBreaker.tokenLimiters(
            address(token)
        );
        assertEq(liqInPeriod, -withdrawalAmount);
        assertEq(liqTotal, 1_000_000e18);

        assertEq(
            circuitBreaker.lockedFunds(address(alice), address(token)),
            uint256(withdrawalAmount)
        );
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(circuitBreaker)), uint256(withdrawalAmount));
        assertEq(token.balanceOf(address(deFi)), 1_000_000e18 - uint256(withdrawalAmount));

        // Attempts to withdraw more than the limit
        vm.warp(6 hours);
        vm.prank(alice);
        int256 secondAmount = 10_000e18;
        deFi.withdrawal(address(token), uint256(secondAmount));
        assertEq(circuitBreaker.isRateLimitBreeched(address(token)), true);
        (, , liqTotal, liqInPeriod, , ) = circuitBreaker.tokenLimiters(address(token));
        assertEq(liqInPeriod, -withdrawalAmount - secondAmount);
        assertEq(liqTotal, 1_000_000e18);

        assertEq(
            circuitBreaker.lockedFunds(address(alice), address(token)),
            uint256(withdrawalAmount + secondAmount)
        );
        assertEq(token.balanceOf(alice), 0);

        // False alarm
        // override the limit and allow claim of funds
        vm.prank(admin);
        circuitBreaker.removeRateLimit();

        vm.warp(7 hours);
        vm.prank(alice);
        circuitBreaker.claimLockedFunds(address(token), address(alice));
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
        deFi.withdrawal(address(token), uint256(withdrawalAmount));
        assertEq(circuitBreaker.isRateLimitBreeched(address(token)), true);
        assertEq(circuitBreaker.isRateLimited(), true);

        vm.warp(4 days);
        vm.prank(alice);
        circuitBreaker.removeExpiredRateLimit();
        assertEq(circuitBreaker.isRateLimited(), false);
    }

    function testSetAdminShouldBeSuccessful() public {
        assertEq(circuitBreaker.admin(), admin);
        vm.prank(admin);
        circuitBreaker.setAdmin(bob);
        assertEq(circuitBreaker.admin(), bob);

        vm.expectRevert();
        vm.prank(admin);
        circuitBreaker.setAdmin(alice);
    }

    function testSetAdminWhenCallerIsNotAdminShouldFail() public {
        vm.expectRevert(CircuitBreaker.NotAdmin.selector);
        circuitBreaker.setAdmin(alice);
    }

    function testDepositsAndWithdrawlsInSameTickLength() public {
        vm.warp(1 days);
        token.mint(alice, 10000e18);

        vm.prank(alice);
        token.approve(address(deFi), 10000e18);

        // 10 USDC deposited
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);

        (, , , , uint256 head, ) = circuitBreaker.tokenLimiters(address(token));
        assertEq(head % 5 minutes, 0);

        // 1 minute later 10 usdc deposited, 1 usdc withdrawn all within the same tick length
        vm.warp(1 days + 1 minutes);
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);

        deFi.withdrawal(address(token), 1e18);

        (uint256 nextTimestamp, int256 amount) = circuitBreaker.tokenLiquidityChanges(
            address(token),
            head
        );
        assertEq(nextTimestamp, 0);
        assertEq(amount, 19e18);

        // Next tick length, 1 usdc withdrawn
        vm.warp(1 days + 6 minutes);
        vm.prank(alice);
        deFi.withdrawal(address(token), 1e18);

        (nextTimestamp, amount) = circuitBreaker.tokenLiquidityChanges(address(token), head);
        assertEq(nextTimestamp, 1 days + 6 minutes - ((1 days + 6 minutes) % 5 minutes));
        assertEq(nextTimestamp % 5 minutes, 0);
        // previous tick length has 19 usdc deposited
        assertEq(amount, 19e18);

        // Next tick values
        (nextTimestamp, amount) = circuitBreaker.tokenLiquidityChanges(
            address(token),
            nextTimestamp
        );
        assertEq(nextTimestamp, 0);
        assertEq(amount, -1e18);
    }

    function testDepositsFuzzed(uint256 amount) public {
        // used to test compare gas costs of deposits
        token.mint(alice, amount);
        vm.prank(alice);
        token.approve(address(deFi), amount);
        vm.prank(alice);
        deFi.depositNoCircuitBreaker(address(token), amount);
    }
}
