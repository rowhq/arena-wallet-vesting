// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Test.sol";

import {ArenaVestingWallet} from "../src/ArenaVestingWallet.sol";
import {VestingParams, IArenaVestingWallet} from "../src/IArenaVestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockArenaToken is ERC20Mock {
    constructor() ERC20Mock() {}
}

contract MockArenaVestingWalletV2 is ArenaVestingWallet {
    function version() external pure returns (string memory) {
        return "v2";
    }

    function newFeature() external pure returns (string memory) {
        return "new feature";
    }
}

contract ArenaVestingWalletTest is Test {
    ArenaVestingWallet public walletImplementation;
    MockArenaToken public arenaToken;

    address public beneficiary = makeAddr("beneficiary");
    address public depositor = makeAddr("depositor");
    address public user = makeAddr("user");

    uint256 public constant ALLOCATION = 1000e18;
    uint64 public constant CLIFF_DURATION = 30 days;
    uint64 public constant INTERVAL_DURATION = 30 days;
    uint64 public constant INTERVALS = 12;

    event Arena_VestingDeposit(address indexed token, uint256 amount);

    function setUp() public {
        // Deploy mock ARENA token
        arenaToken = new MockArenaToken();

        // Replace ARENA constant in wallet with our mock (for testing)
        vm.etch(0xB8d7710f7d8349A506b75dD184F05777c82dAd0C, address(arenaToken).code);
        arenaToken = MockArenaToken(0xB8d7710f7d8349A506b75dD184F05777c82dAd0C);

        // Deploy implementation
        walletImplementation = new ArenaVestingWallet();

        // Setup tokens
        arenaToken.mint(depositor, ALLOCATION * 10);
        vm.prank(depositor);
        arenaToken.approve(address(this), type(uint256).max);
    }

    // ============ Initialization Tests ============

    function test_Initialize() public {
        VestingParams memory params = _createValidParams();
        ArenaVestingWallet wallet = _createWallet(params);

        assertEq(wallet.owner(), beneficiary);
        assertEq(wallet.start(), params.start);
        assertEq(wallet.cliff(), params.start + params.cliff);
        assertEq(wallet.duration(), params.intervals * params.intervalDuration);
        assertEq(wallet.intervals(), params.intervals);
        assertEq(wallet.allocation(), 0);
        assertFalse(wallet.started());
    }

    function test_InitializeRevertsWithZeroBeneficiary() public {
        VestingParams memory params = _createValidParams();
        params.beneficiary = address(0);

        vm.expectRevert(IArenaVestingWallet.Arena_InvalidParams.selector);
        _createWallet(params);
    }

    function test_InitializeRevertsWithZeroIntervals() public {
        VestingParams memory params = _createValidParams();
        params.intervals = 0;

        vm.expectRevert(IArenaVestingWallet.Arena_InvalidParams.selector);
        _createWallet(params);
    }

    function test_InitializeRevertsWithZeroIntervalDuration() public {
        VestingParams memory params = _createValidParams();
        params.intervalDuration = 0;

        vm.expectRevert(IArenaVestingWallet.Arena_InvalidParams.selector);
        _createWallet(params);
    }

    // ============ Deposit Tests ============

    function test_Deposit() public {
        ArenaVestingWallet wallet = _createWallet(_createValidParams());

        vm.startPrank(depositor);
        arenaToken.approve(address(wallet), ALLOCATION);

        vm.expectEmit(true, false, false, true);
        emit Arena_VestingDeposit(address(arenaToken), ALLOCATION);

        wallet.deposit(ALLOCATION);

        assertEq(wallet.allocation(), ALLOCATION);
        assertTrue(wallet.started());
        assertEq(arenaToken.balanceOf(address(wallet)), ALLOCATION);
        vm.stopPrank();
    }

    function test_DepositRevertsOnSecondDeposit() public {
        ArenaVestingWallet wallet = _createWallet(_createValidParams());

        vm.startPrank(depositor);
        arenaToken.approve(address(wallet), ALLOCATION * 2);

        wallet.deposit(ALLOCATION);

        vm.expectRevert(abi.encodeWithSelector(IArenaVestingWallet.Arena_VestingStarted.selector, true));
        wallet.deposit(ALLOCATION);
        vm.stopPrank();
    }

    function test_DepositRevertsWithZeroAmount() public {
        ArenaVestingWallet wallet = _createWallet(_createValidParams());

        vm.startPrank(depositor);
        vm.expectRevert(IArenaVestingWallet.Arena_InvalidAmount.selector);
        wallet.deposit(0);
        vm.stopPrank();
    }

    // ============ Release Tests Before Vesting ============

    function test_ReleaseRevertsBeforeVestingStarted() public {
        ArenaVestingWallet wallet = _createWallet(_createValidParams());

        vm.expectRevert(abi.encodeWithSelector(IArenaVestingWallet.Arena_VestingStarted.selector, false));
        wallet.release(address(arenaToken));
    }

    // ============ Cliff Tests ============

    function test_NoVestingBeforeCliff() public {
        VestingParams memory params = _createValidParams();
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // Just before cliff
        vm.warp(params.start + params.cliff - 1);

        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), 0);
        assertEq(wallet.releasable(address(arenaToken)), 0);
    }

    function test_VestingStartsAtCliff() public {
        VestingParams memory params = _createValidParams();
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // At cliff
        vm.warp(params.start + params.cliff);

        uint256 expectedVested = ALLOCATION / params.intervals;
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedVested);
        assertEq(wallet.releasable(address(arenaToken)), expectedVested);
    }

    function test_CliffAfterFirstInterval() public {
        VestingParams memory params = _createValidParams();
        params.cliff = INTERVAL_DURATION + 15 days; // Cliff in middle of second interval
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // At cliff (middle of second interval)
        vm.warp(params.start + params.cliff);

        uint256 expectedVested = ALLOCATION / params.intervals; // Still only first interval
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedVested);
    }

    // ============ Interval Vesting Tests ============

    function test_VestingAtEachInterval() public {
        // Use different cliff and interval to make the math clearer
        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            cliff: 0, // No cliff for this test to focus on intervals
            start: uint64(block.timestamp),
            intervals: 12,
            intervalDuration: 30 days
        });

        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        for (uint256 i = 1; i <= params.intervals; i++) {
            // Warp to each interval boundary
            vm.warp(params.start + (i * params.intervalDuration));

            uint256 expectedVested = (ALLOCATION * i) / params.intervals;
            uint256 actualVested = wallet.vestedAmount(address(arenaToken), uint64(block.timestamp));

            assertEq(actualVested, expectedVested, "Vesting mismatch at interval");
        }
    }

    function test_VestingWithCliffAndIntervals() public {
        VestingParams memory params = _createValidParams(); // Has 30-day cliff
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // Test at cliff (should vest based on elapsed intervals from start)
        vm.warp(params.start + params.cliff); // 30 days from start
        uint256 elapsedIntervals = params.cliff / params.intervalDuration; // 30 days / 30 days = 1
        uint256 expectedAtCliff = (ALLOCATION * elapsedIntervals) / params.intervals;
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedAtCliff);

        // Test after cliff + more intervals
        vm.warp(params.start + params.cliff + params.intervalDuration); // 60 days from start
        elapsedIntervals = (params.cliff + params.intervalDuration) / params.intervalDuration; // 60 / 30 = 2
        uint256 expectedAfterCliff = (ALLOCATION * elapsedIntervals) / params.intervals;
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedAfterCliff);
    }

    function test_VestingWithinInterval() public {
        VestingParams memory params = _createValidParams();
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // Halfway through second interval
        vm.warp(params.start + params.cliff + (params.intervalDuration / 2));

        uint256 expectedVested = ALLOCATION / params.intervals; // Still only first interval vested
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedVested);
    }

    function test_FullVestingAfterDuration() public {
        VestingParams memory params = _createValidParams();
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // After full duration
        vm.warp(params.start + (params.intervals * params.intervalDuration) + 1 days);

        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), ALLOCATION);
        assertEq(wallet.releasable(address(arenaToken)), ALLOCATION);
    }

    // ============ Release Tests During Vesting ============

    function test_ReleaseAtFirstInterval() public {
        VestingParams memory params = _createValidParams();
        params.cliff = 0;
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        vm.warp(params.start + params.cliff + params.intervalDuration);

        uint256 expectedRelease = ALLOCATION / params.intervals;
        uint256 balanceBefore = arenaToken.balanceOf(beneficiary);

        vm.prank(beneficiary);
        wallet.release(address(arenaToken));

        assertEq(arenaToken.balanceOf(beneficiary) - balanceBefore, expectedRelease);
        assertEq(wallet.released(address(arenaToken)), expectedRelease);
        assertEq(wallet.releasable(address(arenaToken)), 0);
    }

    function test_MultipleReleases() public {
        VestingParams memory params = _createValidParams();
        params.cliff = 0;
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        uint256 expectedPerInterval = ALLOCATION / params.intervals;
        uint256 totalReleased = 0;

        // Release at intervals 1, 3, and 5
        uint256[] memory releaseIntervals = new uint256[](5);
        releaseIntervals[0] = 1;
        releaseIntervals[1] = 3;
        releaseIntervals[2] = 5;
        releaseIntervals[3] = 9;
        releaseIntervals[4] = 13;

        for (uint256 i = 0; i < releaseIntervals.length; i++) {
            uint256 releaseInterval = releaseIntervals[i] > params.intervals ? params.intervals : releaseIntervals[i];
            vm.warp(params.start + params.cliff + (releaseInterval * params.intervalDuration));

            uint256 expectedReleasable = (expectedPerInterval * releaseInterval) - totalReleased;
            assertApproxEqAbs(wallet.releasable(address(arenaToken)), expectedReleasable, 6);

            vm.prank(beneficiary);
            wallet.release(address(arenaToken));

            totalReleased += expectedReleasable;
            assertApproxEqAbs(wallet.released(address(arenaToken)), totalReleased, 6);
        }

        assertApproxEqAbs(ALLOCATION, totalReleased, 6);
        assertApproxEqAbs(wallet.released(address(arenaToken)), totalReleased, 6);
    }

    function test_ReleaseAfterFullVesting() public {
        VestingParams memory params = _createValidParams();
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // After full vesting period
        vm.warp(params.start + (params.intervals * params.intervalDuration) + 365 days);

        uint256 balanceBefore = arenaToken.balanceOf(beneficiary);

        vm.prank(beneficiary);
        wallet.release(address(arenaToken));

        assertEq(arenaToken.balanceOf(beneficiary) - balanceBefore, ALLOCATION);
        assertEq(wallet.released(address(arenaToken)), ALLOCATION);
        assertEq(wallet.releasable(address(arenaToken)), 0);
    }

    // ============ Token Restriction Tests ============

    function test_VestedAmountRevertsForNonArenaToken() public {
        ArenaVestingWallet wallet = _createWallet(_createValidParams());
        ERC20Mock otherToken = new ERC20Mock();

        vm.expectRevert(abi.encodeWithSelector(IArenaVestingWallet.Arena_InvalidToken.selector, address(otherToken)));
        wallet.vestedAmount(address(otherToken), uint64(block.timestamp));
    }

    function test_ReleaseWorksOnlyForArenaToken() public {
        VestingParams memory params = _createValidParams();
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        ERC20Mock otherToken = new ERC20Mock();
        otherToken.mint(address(wallet), 1000e18);

        vm.warp(params.start + params.cliff + params.intervalDuration);

        // Should work for ARENA
        vm.prank(beneficiary);
        wallet.release(address(arenaToken));

        // Should not release other tokens (they stay in wallet)
        uint256 balanceBefore = otherToken.balanceOf(beneficiary);

        vm.expectRevert(abi.encodeWithSelector(IArenaVestingWallet.Arena_InvalidToken.selector, address(otherToken)));
        vm.prank(beneficiary);
        wallet.release(address(otherToken));
        assertEq(otherToken.balanceOf(beneficiary), balanceBefore); // No change
    }

    // ============ Ownership Tests ============

    function test_CannotTransferOwnership() public {
        ArenaVestingWallet wallet = _createWallet(_createValidParams());

        vm.prank(beneficiary);
        vm.expectRevert(IArenaVestingWallet.Arena_CannotTransferOwnership.selector);
        wallet.transferOwnership(user);
    }

    function test_CannotRenounceOwnership() public {
        ArenaVestingWallet wallet = _createWallet(_createValidParams());

        vm.prank(beneficiary);
        vm.expectRevert(IArenaVestingWallet.Arena_CannotRenounceOwnership.selector);
        wallet.renounceOwnership();
    }

    // ============ Token Deposit Behavior Tests ============

    function test_OnlyDepositedTokensVest() public {
        VestingParams memory params = _createValidParams();
        params.cliff = 0;
        ArenaVestingWallet wallet = _createWallet(params);

        // Step 1: Send tokens directly BEFORE deposit (should be stuck)
        uint256 tokensBeforeDeposit = 200e18;
        arenaToken.mint(depositor, tokensBeforeDeposit + ALLOCATION + 300e18);
        vm.startPrank(depositor);
        arenaToken.transfer(address(wallet), tokensBeforeDeposit);

        // Step 2: Official deposit via deposit() function
        arenaToken.approve(address(wallet), ALLOCATION);
        wallet.deposit(ALLOCATION);

        // Step 3: Send tokens directly AFTER deposit (should be stuck)
        uint256 tokensAfterDeposit = 300e18;
        arenaToken.transfer(address(wallet), tokensAfterDeposit);
        vm.stopPrank();

        // Verify wallet has all tokens
        uint256 totalInWallet = tokensBeforeDeposit + ALLOCATION + tokensAfterDeposit;
        assertEq(arenaToken.balanceOf(address(wallet)), totalInWallet);

        // Verify only ALLOCATION amount is set for vesting
        assertEq(wallet.allocation(), ALLOCATION);

        // Move to middle of vesting period
        vm.warp(params.start + params.cliff + (6 * params.intervalDuration)); // 6 intervals

        // Should only vest based on deposited allocation, not extra tokens
        uint256 expectedVested = (ALLOCATION * 6) / params.intervals;
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedVested);
        assertEq(wallet.releasable(address(arenaToken)), expectedVested);

        // Release vested amount
        vm.prank(beneficiary);
        wallet.release(address(arenaToken));

        assertEq(arenaToken.balanceOf(beneficiary), expectedVested);
        assertEq(wallet.released(address(arenaToken)), expectedVested);

        // Wallet should still have: original allocation - vested + stuck tokens
        uint256 expectedRemainingInWallet = (ALLOCATION - expectedVested) + tokensBeforeDeposit + tokensAfterDeposit;
        assertEq(arenaToken.balanceOf(address(wallet)), expectedRemainingInWallet);

        // Complete full vesting period
        vm.warp(params.start + (params.intervals * params.intervalDuration));

        // Should vest exactly the allocated amount, no more
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), ALLOCATION);

        // Release remaining vested tokens
        vm.prank(beneficiary);
        wallet.release(address(arenaToken));

        // Beneficiary should have received exactly the allocation amount
        assertEq(arenaToken.balanceOf(beneficiary), ALLOCATION);
        assertEq(wallet.released(address(arenaToken)), ALLOCATION);

        // Stuck tokens should remain in wallet forever
        uint256 stuckTokens = tokensBeforeDeposit + tokensAfterDeposit;
        assertEq(arenaToken.balanceOf(address(wallet)), stuckTokens);

        // Additional releases should do nothing
        vm.prank(beneficiary);
        wallet.release(address(arenaToken));
        assertEq(arenaToken.balanceOf(beneficiary), ALLOCATION); // No change
        assertEq(arenaToken.balanceOf(address(wallet)), stuckTokens); // No change
    }

    function test_VestingWithPrimeIntervals() public {
        uint256 primeTestAllocation = 1001e18; // Doesn't divide evenly by 13

        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            cliff: 0,
            start: uint64(block.timestamp),
            intervals: 13, // Prime number for precision testing
            intervalDuration: 30 days
        });

        ArenaVestingWallet wallet = _createWallet(params);

        arenaToken.mint(depositor, primeTestAllocation);
        vm.startPrank(depositor);
        arenaToken.approve(address(wallet), primeTestAllocation);
        wallet.deposit(primeTestAllocation);
        vm.stopPrank();

        uint256 totalReleased = 0;

        // Test vesting at prime interval positions
        uint256[] memory testIntervals = new uint256[](4);
        testIntervals[0] = 3;
        testIntervals[1] = 7;
        testIntervals[2] = 11;
        testIntervals[3] = 13; // Full vesting

        for (uint256 i = 0; i < testIntervals.length; i++) {
            vm.warp(params.start + (testIntervals[i] * params.intervalDuration));

            uint256 expectedVested = (primeTestAllocation * testIntervals[i]) / params.intervals;
            uint256 releasable = expectedVested - totalReleased;

            assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedVested);
            assertEq(wallet.releasable(address(arenaToken)), releasable);

            if (releasable > 0) {
                vm.prank(beneficiary);
                wallet.release(address(arenaToken));
                totalReleased += releasable;
            }
        }

        // At final interval, should have released close to full allocation
        // Account for precision loss (max loss is intervals - 1 wei)
        assertGe(totalReleased, primeTestAllocation - (params.intervals - 1));
        assertEq(wallet.released(address(arenaToken)), totalReleased);
        assertEq(arenaToken.balanceOf(beneficiary), totalReleased);
    }

    // ============ Client Specific Vesting Requirements ============

    function test_QuarterlyVestingWithoutCliff() public {
        // Client requirement: Quarterly vesting (91 days) for 1 year, no cliff
        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            cliff: 0, // No cliff
            start: uint64(block.timestamp),
            intervals: 4, // 4 quarters
            intervalDuration: 91 days // Quarterly intervals
        });

        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // Quarter 1: 25% vests immediately
        vm.warp(params.start + (1 * params.intervalDuration)); // 91 days
        uint256 expectedQ1 = (ALLOCATION * 1) / params.intervals;
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedQ1);
        assertEq(wallet.releasable(address(arenaToken)), expectedQ1);

        vm.prank(beneficiary);
        wallet.release(address(arenaToken));
        assertEq(arenaToken.balanceOf(beneficiary), expectedQ1);

        // Quarter 2: 50% total vested
        vm.warp(params.start + (2 * params.intervalDuration)); // 182 days
        uint256 expectedQ2 = (ALLOCATION * 2) / params.intervals;
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedQ2);
        assertEq(wallet.releasable(address(arenaToken)), expectedQ2 - expectedQ1);

        vm.prank(beneficiary);
        wallet.release(address(arenaToken));
        assertEq(arenaToken.balanceOf(beneficiary), expectedQ2);

        // Quarter 3: 75% total vested
        vm.warp(params.start + (3 * params.intervalDuration)); // 273 days
        uint256 expectedQ3 = (ALLOCATION * 3) / params.intervals;
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedQ3);

        vm.prank(beneficiary);
        wallet.release(address(arenaToken));
        assertEq(arenaToken.balanceOf(beneficiary), expectedQ3);

        // Quarter 4: 100% vested (full year = 364 days)
        vm.warp(params.start + (4 * params.intervalDuration)); // 364 days
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), ALLOCATION);

        vm.prank(beneficiary);
        wallet.release(address(arenaToken));
        assertEq(arenaToken.balanceOf(beneficiary), ALLOCATION);
        assertEq(wallet.released(address(arenaToken)), ALLOCATION);
        assertEq(wallet.releasable(address(arenaToken)), 0);
    }

    function test_QuarterlyVestingWithCliff() public {
        // Client requirement: Quarterly vesting with 6-month cliff
        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            cliff: 182 days, // 6-month cliff (2 quarters)
            start: uint64(block.timestamp),
            intervals: 4, // 4 quarters
            intervalDuration: 91 days // Quarterly intervals
        });

        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // Before cliff: Nothing should vest
        vm.warp(params.start + 91 days); // Q1 completed, but before cliff
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), 0);
        assertEq(wallet.releasable(address(arenaToken)), 0);

        vm.warp(params.start + 181 days); // Just before cliff
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), 0);
        assertEq(wallet.releasable(address(arenaToken)), 0);

        // At cliff (6 months): Should vest 2 quarters worth (50%)
        vm.warp(params.start + params.cliff); // 182 days = 2 quarters elapsed
        uint256 elapsedIntervals = params.cliff / params.intervalDuration; // 182 / 91 = 2
        uint256 expectedAtCliff = (ALLOCATION * elapsedIntervals) / params.intervals; // 50%
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedAtCliff);
        assertEq(wallet.releasable(address(arenaToken)), expectedAtCliff);

        vm.prank(beneficiary);
        wallet.release(address(arenaToken));
        assertEq(arenaToken.balanceOf(beneficiary), expectedAtCliff);

        // Quarter 3: 75% total vested
        vm.warp(params.start + (3 * params.intervalDuration)); // 273 days
        uint256 expectedQ3 = (ALLOCATION * 3) / params.intervals;
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), expectedQ3);
        assertEq(wallet.releasable(address(arenaToken)), expectedQ3 - expectedAtCliff);

        vm.prank(beneficiary);
        wallet.release(address(arenaToken));
        assertEq(arenaToken.balanceOf(beneficiary), expectedQ3);

        // Quarter 4: 100% vested (full year)
        vm.warp(params.start + (4 * params.intervalDuration)); // 364 days
        assertEq(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)), ALLOCATION);
        assertEq(wallet.releasable(address(arenaToken)), ALLOCATION - expectedQ3);

        vm.prank(beneficiary);
        wallet.release(address(arenaToken));
        assertEq(arenaToken.balanceOf(beneficiary), ALLOCATION);
        assertEq(wallet.released(address(arenaToken)), ALLOCATION);
    }

    // ============ Edge Cases & Error Conditions ============

    function test_VestingScheduleHandlesMaxValues() public {
        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            cliff: 365 days,
            start: uint64(block.timestamp),
            intervals: type(uint64).max / (365 days), // Large but safe intervals
            intervalDuration: 365 days
        });

        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // Should handle large values without overflow
        vm.warp(params.start + params.cliff + params.intervalDuration);
        assertTrue(wallet.vestedAmount(address(arenaToken), uint64(block.timestamp)) > 0);
    }

    function test_ReleaseMoreThanAllocated() public {
        VestingParams memory params = _createValidParams();
        ArenaVestingWallet wallet = _createWallet(params);
        _depositTokens(wallet, ALLOCATION);

        // After full vesting
        vm.warp(params.start + (params.intervals * params.intervalDuration) + 1);

        // Release all
        vm.prank(beneficiary);
        wallet.release(address(arenaToken));

        // Try to release again
        vm.prank(beneficiary);
        wallet.release(address(arenaToken)); // Should not revert, but release 0

        assertEq(wallet.releasable(address(arenaToken)), 0);
    }

    // ============ Fuzz Tests ============

    function testFuzz_VestingSchedule(
        uint256 _allocation,
        uint64 _intervals,
        uint64 _intervalDuration,
        uint64 _timeElapsed
    ) public {
        vm.assume(_allocation > 0 && _allocation < type(uint128).max);
        vm.assume(_intervals > 0 && _intervals <= 1000);
        vm.assume(_intervalDuration > 0 && _intervalDuration <= 365 days);
        vm.assume(_intervals * _intervalDuration > 30 days);
        _timeElapsed = uint64(bound(_timeElapsed, 0, _intervals * _intervalDuration + 365 days));

        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            cliff: 30 days,
            start: uint64(block.timestamp),
            intervals: _intervals,
            intervalDuration: _intervalDuration
        });

        ArenaVestingWallet wallet = _createWallet(params);

        arenaToken.mint(depositor, _allocation);
        vm.startPrank(depositor);
        arenaToken.approve(address(wallet), _allocation);
        wallet.deposit(_allocation);
        vm.stopPrank();

        vm.warp(params.start + params.cliff + _timeElapsed);

        uint256 vested = wallet.vestedAmount(address(arenaToken), uint64(block.timestamp));
        assertLe(vested, _allocation);

        if (_timeElapsed >= _intervals * _intervalDuration) {
            assertEq(vested, _allocation);
        }
    }

    // ============ Helper Functions ============

    function _createValidParams() internal view returns (VestingParams memory) {
        return VestingParams({
            beneficiary: beneficiary,
            cliff: CLIFF_DURATION,
            start: uint64(block.timestamp),
            intervals: INTERVALS,
            intervalDuration: INTERVAL_DURATION
        });
    }

    function _createWallet(VestingParams memory params) internal returns (ArenaVestingWallet) {
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(walletImplementation), abi.encodeCall(ArenaVestingWallet.initialize, (params)));
        return ArenaVestingWallet(payable(address(proxy)));
    }

    function _depositTokens(ArenaVestingWallet wallet, uint256 amount) internal {
        vm.startPrank(depositor);
        arenaToken.approve(address(wallet), amount);
        wallet.deposit(amount);
        vm.stopPrank();
    }
}
