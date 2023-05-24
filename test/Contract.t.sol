// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MockToken.sol";
import "../src/Guardian.sol";
import "../src/MockDeFiProtocol.sol";

contract ContractTest is Test {
    MyToken token;
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
    }

    function testRateLimit() public {}

    function testAdmin() public {}

    function testGuarded() public {}

    function testTestLockedFundsWithdrawl() public {}
}
