// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MockToken.sol";
import "../src/Guardian.sol";
import "../src/MockDeFiProtocol.sol";

contract ContractTest is Test {
    MyToken token;
    MyToken secondToken;
    MyToken unlimitedToken;
    Guardian guardian;
    MockDeFi deFi;

    // hardhat getSigner() -> vm.addr()
    address alice = vm.addr(0x1);
    address bob = vm.addr(0x2);
    address admin = vm.addr(0x3);

    // hardhat beforeEach -> setUp
    function setUp() public {
        token = new MyToken("USDC", "USDC");
        deFi = new MockDeFi();
        guardian = new Guardian(admin, 3 days, 3 hours);

        deFi.setGuardian(address(guardian));
        vm.prank(admin);

        address[] memory addresses = new address[](1);
        addresses[0] = address(deFi);
        guardian.addGuardedContracts(addresses);

        vm.prank(admin);
        // Guard USDC with 70% max drawdown per 4 hours
        guardian.registerToken(address(token), 700, 4 hours, 1000e18);
        vm.warp(1 hours);
    }

    function testInitialization() public {
        Guardian newGuardian = new Guardian(admin, 3 days, 3 hours);
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

    function testRegisterNewToken() public {
        secondToken = new MyToken("DAI", "DAI");
        vm.prank(admin);
        guardian.registerToken(address(secondToken), 700, 4 hours, 1000e18);
        (
            uint256 bootstrapAmount,
            uint256 withdrawalPeriod,
            int256 withdrawalRateLimitPerPeriod,
            bool exists
        ) = guardian.tokensRateLimitInfo(address(secondToken));
        assertEq(bootstrapAmount, 1000e18);
        assertEq(withdrawalPeriod, 4 hours);
        assertEq(withdrawalRateLimitPerPeriod, 700);
        assertEq(exists, true);

        // Cannot register the same token twice
        vm.expectRevert();
        vm.prank(admin);
        guardian.registerToken(address(secondToken), 700, 4 hours, 1000e18);
    }

    function testDepositWithDrawNoLimitToken() public {
        unlimitedToken = new MyToken("DAI", "DAI");
        unlimitedToken.mint(alice, 10000e18);

        vm.prank(alice);
        unlimitedToken.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(unlimitedToken), 10000e18);

        assertEq(guardian.checkIfRateLimitBreeched(address(unlimitedToken)), false);
        vm.warp(1 hours);
        vm.prank(alice);
        deFi.withdraw(address(unlimitedToken), 10000e18);
        assertEq(guardian.checkIfRateLimitBreeched(address(unlimitedToken)), false);
    }

    function testDeposit() public {
        token.mint(alice, 10000e18);

        vm.prank(alice);
        token.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(token), 10e18);

        assertEq(guardian.checkIfRateLimitBreeched(address(token)), false);

        uint256 head = guardian.tokenLiquidityHead(address(token));
        uint256 tail = guardian.tokenLiquidityTail(address(token));

        assertEq(head, tail);
        assertEq(guardian.tokenLiquidityHistoracle(address(token)), 0);
        assertEq(guardian.tokenLiquidityWindowAmount(address(token)), 10e18);

        (uint256 nextTimestamp, int256 amount) = guardian.tokenLiquidityChanges(
            address(token),
            head
        );
        assertEq(nextTimestamp, 0);
        assertEq(amount, 10e18);

        vm.warp(1 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 110e18);
        assertEq(guardian.checkIfRateLimitBreeched(address(token)), false);
        assertEq(guardian.tokenLiquidityWindowAmount(address(token)), 120e18);
        assertEq(guardian.tokenLiquidityHistoracle(address(token)), 0);

        // All the previous deposits are now out of the window and accounted for in the historacle
        vm.warp(10 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);
        assertEq(guardian.checkIfRateLimitBreeched(address(token)), false);
        assertEq(guardian.tokenLiquidityWindowAmount(address(token)), 10e18);
        assertEq(guardian.tokenLiquidityHistoracle(address(token)), 120e18);

        uint256 tailNext = guardian.tokenLiquidityTail(address(token));
        uint256 headNext = guardian.tokenLiquidityHead(address(token));
        assertEq(headNext, block.timestamp);
        assertEq(tailNext, block.timestamp);
    }

    function testClearBacklog() public {
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
        assertEq(guardian.tokenLiquidityWindowAmount(address(token)), 3);
        assertEq(guardian.tokenLiquidityHistoracle(address(token)), 2);

        assertEq(guardian.tokenLiquidityHead(address(token)), 3 hours);
        assertEq(guardian.tokenLiquidityTail(address(token)), 5 hours);
    }

    function testWithdrawls() public {
        token.mint(alice, 10000e18);

        vm.prank(alice);
        token.approve(address(deFi), 10000e18);

        vm.prank(alice);
        deFi.deposit(address(token), 100e18);

        vm.warp(1 hours);
        vm.prank(alice);
        deFi.withdraw(address(token), 60e18);
        assertEq(guardian.checkIfRateLimitBreeched(address(token)), false);
        assertEq(guardian.tokenLiquidityWindowAmount(address(token)), 40e18);
        assertEq(guardian.tokenLiquidityHistoracle(address(token)), 0);
        assertEq(token.balanceOf(alice), 9960e18);

        // All the previous deposits are now out of the window and accounted for in the historacle
        vm.warp(10 hours);
        vm.prank(alice);
        deFi.deposit(address(token), 10e18);
        assertEq(guardian.checkIfRateLimitBreeched(address(token)), false);
        assertEq(guardian.tokenLiquidityWindowAmount(address(token)), 10e18);
        assertEq(guardian.tokenLiquidityHistoracle(address(token)), 40e18);

        uint256 tailNext = guardian.tokenLiquidityTail(address(token));
        uint256 headNext = guardian.tokenLiquidityHead(address(token));
        assertEq(headNext, block.timestamp);
        assertEq(tailNext, block.timestamp);
    }

    function testAddAndRemoveGuardedContracts() public {
        MockDeFi secondDeFi = new MockDeFi();
        secondDeFi.setGuardian(address(guardian));

        address[] memory addresses = new address[](1);
        addresses[0] = address(secondDeFi);
        vm.prank(admin);
        guardian.addGuardedContracts(addresses);

        assertEq(guardian.isGuarded(address(secondDeFi)), true);

        vm.prank(admin);
        guardian.removeGuardedContracts(addresses);
        assertEq(guardian.isGuarded(address(secondDeFi)), false);
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
        deFi.withdraw(address(token), uint(withdrawalAmount));
        assertEq(guardian.checkIfRateLimitBreeched(address(token)), true);
        assertEq(guardian.tokenLiquidityWindowAmount(address(token)), -withdrawalAmount);
        assertEq(guardian.tokenLiquidityHistoracle(address(token)), 1_000_000e18);

        assertEq(guardian.lockedFunds(address(alice), address(token)), uint(withdrawalAmount));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(guardian)), uint(withdrawalAmount));
        assertEq(token.balanceOf(address(deFi)), 1_000_000e18 - uint(withdrawalAmount));

        // Attempts to withdraw more than the limit
        vm.warp(6 hours);
        vm.prank(alice);
        int256 secondAmount = 10_000e18;
        deFi.withdraw(address(token), uint(secondAmount));
        assertEq(guardian.checkIfRateLimitBreeched(address(token)), true);
        assertEq(
            guardian.tokenLiquidityWindowAmount(address(token)),
            -withdrawalAmount - secondAmount
        );
        assertEq(guardian.tokenLiquidityHistoracle(address(token)), 1_000_000e18);

        assertEq(
            guardian.lockedFunds(address(alice), address(token)),
            uint(withdrawalAmount + secondAmount)
        );
        assertEq(token.balanceOf(alice), 0);

        // False alarm
        // override the limit and allow claim of funds
        vm.prank(admin);
        guardian.overrideLimit();

        vm.warp(7 hours);
        vm.prank(alice);
        guardian.claimLockedFunds(address(token));
        assertEq(token.balanceOf(alice), uint(withdrawalAmount + secondAmount));
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
        deFi.withdraw(address(token), uint(withdrawalAmount));
        assertEq(guardian.checkIfRateLimitBreeched(address(token)), true);
        assertEq(guardian.isRateLimited(), true);

        vm.warp(4 days);
        vm.prank(alice);
        guardian.overrideExpiredRateLimit();
        assertEq(guardian.isRateLimited(), false);
    }

    function testAdmin() public {
        assertEq(guardian.admin(), admin);
        vm.prank(admin);
        guardian.transferAdmin(bob);
        assertEq(guardian.admin(), bob);

        vm.expectRevert();
        vm.prank(admin);
        guardian.transferAdmin(alice);
    }
}
