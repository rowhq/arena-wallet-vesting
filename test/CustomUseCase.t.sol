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

contract ArenaVestingWalletTest is Test {
    ArenaVestingWallet public walletImplementation;
    MockArenaToken public arenaToken;

    address public beneficiary = makeAddr("beneficiary");
    address public depositor = makeAddr("depositor");
    address public user = makeAddr("user");

    uint256 public constant ALLOCATION = 500000e18;
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

    function test_ThreeYearQuarterlyVestingSimulation() public {
        console.log("\n=== 3-YEAR QUARTERLY VESTING SIMULATION ===");
        console.log("Total Allocation: 500,000 ARENA tokens");
        console.log("Vesting Period: 3 years (36 months)");
        console.log("Release Schedule: Quarterly (every 3 months)");
        console.log("Total Releases: 12");
        console.log("Tokens per Quarter: ~41,666.67 ARENA\n");

        // 3-year vesting parameters
        uint64 startTime = uint64(block.timestamp);
        uint64 cliffDuration = 0; // No cliff for this example
        uint64 intervalDuration = 90 days; // Quarterly (approximately 3 months)
        uint64 intervals = 12; // 12 quarters over 3 years
        uint256 totalTokens = 500_000e18; // 500,000 ARENA tokens

        // Deploy and initialize vesting wallet
        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            start: startTime,
            cliff: cliffDuration,
            intervalDuration: intervalDuration,
            intervals: intervals
        });

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(walletImplementation), abi.encodeWithSelector(ArenaVestingWallet.initialize.selector, params)
        );

        ArenaVestingWallet vestingWallet = ArenaVestingWallet(payable(address(proxy)));

        // Approve and deposit tokens to start vesting
        vm.startPrank(depositor);
        arenaToken.approve(address(vestingWallet), totalTokens);
        vestingWallet.deposit(totalTokens);
        vm.stopPrank();

        console.log("Vesting Contract Deployed at:", address(vestingWallet));
        console.log("Beneficiary:", beneficiary);
        console.log("Start Date:", _formatTimestamp(startTime));
        console.log("End Date:", _formatTimestamp(startTime + intervalDuration * intervals));
        console.log("\n--- VESTING SCHEDULE BREAKDOWN ---\n");

        // Simulate vesting over time
        uint256 totalReleased = 0;
        uint256 lastVested = 0;

        // Initial state
        console.log("Initial State:");
        console.log("- Vested: 0 ARENA");
        console.log("- Released: 0 ARENA");
        console.log("- Releasable: 0 ARENA");
        console.log("- Locked: 1,000 ARENA\n");

        // Simulate each quarter
        for (uint256 quarter = 1; quarter <= 12; quarter++) {
            // Move to the end of the quarter
            uint256 timeElapsed = intervalDuration * quarter;
            vm.warp(startTime + timeElapsed);

            // Get vesting state
            uint256 vestedAmount = vestingWallet.vestedAmount(address(arenaToken), uint64(block.timestamp));
            uint256 releasableAmount = vestingWallet.releasable(address(arenaToken));
            uint256 currentVested = vestedAmount - lastVested;

            console.log(string.concat("Quarter ", _toString(quarter), " (Month ", _toString(quarter * 3), ")"));
            console.log("- Date:", _formatTimestamp(block.timestamp));
            console.log("- Newly Vested:", _formatTokenAmount(currentVested));
            console.log("- Total Vested:", _formatTokenAmount(vestedAmount));
            console.log("- Releasable:", _formatTokenAmount(releasableAmount));

            // Simulate release
            if (releasableAmount > 0) {
                vm.prank(beneficiary);
                vestingWallet.release(address(arenaToken));
                totalReleased += releasableAmount;
                console.log("- Released this Quarter:", _formatTokenAmount(releasableAmount));
                console.log("- Total Released:", _formatTokenAmount(totalReleased));
            }

            uint256 remainingLocked = totalTokens - vestedAmount;
            console.log("- Remaining Locked:", _formatTokenAmount(remainingLocked));

            // Calculate percentage
            uint256 percentVested = (vestedAmount * 100) / totalTokens;
            console.log(string.concat("- Progress: ", _toString(percentVested), "%\n"));

            lastVested = vestedAmount;
        }

        // Final summary
        console.log("--- FINAL SUMMARY ---");
        console.log("Total Tokens Allocated:", _formatTokenAmount(totalTokens));
        console.log("Total Tokens Released:", _formatTokenAmount(totalReleased));
        console.log("Beneficiary Balance:", _formatTokenAmount(arenaToken.balanceOf(beneficiary)));

        // Verify all tokens were released
        assertEq(totalReleased, totalTokens, "All tokens should be released");
        assertEq(arenaToken.balanceOf(beneficiary), totalTokens, "Beneficiary should have all tokens");

        console.log("\n=== SIMULATION COMPLETE ===");
    }

    function test_QuarterlyVestingWithCliff() public {
        console.log("\n=== 3-YEAR QUARTERLY VESTING WITH 6-MONTH CLIFF ===");
        console.log("This simulation shows how a cliff period affects token releases\n");

        // Parameters with 6-month cliff
        uint64 startTime = uint64(block.timestamp);
        uint64 cliffDuration = 180 days; // 6-month cliff
        uint64 intervalDuration = 90 days; // Quarterly
        uint64 intervals = 12;
        uint256 totalTokens = 1000e18;

        // Deploy vesting wallet with cliff
        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            start: startTime,
            cliff: cliffDuration,
            intervalDuration: intervalDuration,
            intervals: intervals
        });

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(walletImplementation), abi.encodeWithSelector(ArenaVestingWallet.initialize.selector, params)
        );

        ArenaVestingWallet vestingWallet = ArenaVestingWallet(payable(address(proxy)));

        // Approve and deposit tokens to start vesting
        vm.startPrank(depositor);
        arenaToken.approve(address(vestingWallet), totalTokens);
        vestingWallet.deposit(totalTokens);
        vm.stopPrank();

        console.log("Cliff Period: 6 months");
        console.log("First Release: After 6 months (2 quarters worth)\n");

        // Show state during cliff
        console.log("During Cliff Period (Month 3):");
        vm.warp(startTime + 90 days);
        uint256 vestedDuringCliff = vestingWallet.vestedAmount(address(arenaToken), uint64(block.timestamp));
        uint256 releasableDuringCliff = vestingWallet.releasable(address(arenaToken));
        console.log("- Vested:", _formatTokenAmount(vestedDuringCliff));
        console.log("- Releasable:", _formatTokenAmount(releasableDuringCliff), "(Nothing releasable during cliff)\n");

        // Show state after cliff
        console.log("After Cliff Period (Month 6):");
        vm.warp(startTime + cliffDuration);
        uint256 vestedAfterCliff = vestingWallet.vestedAmount(address(arenaToken), uint64(block.timestamp));
        uint256 releasableAfterCliff = vestingWallet.releasable(address(arenaToken));
        console.log("- Vested:", _formatTokenAmount(vestedAfterCliff));
        console.log("- Releasable:", _formatTokenAmount(releasableAfterCliff), "(2 quarters worth released at once)");

        // Release after cliff
        vm.prank(beneficiary);
        vestingWallet.release(address(arenaToken));
        console.log("- Released:", _formatTokenAmount(arenaToken.balanceOf(beneficiary)));
    }

    // Helper functions for formatting
    function _formatTokenAmount(uint256 amount) internal pure returns (string memory) {
        uint256 whole = amount / 1e18;
        uint256 decimal = (amount % 1e18) / 1e16; // 2 decimal places
        return string.concat(_toString(whole), ".", _toString(decimal), " ARENA");
    }

    function _formatTimestamp(uint256 timestamp) internal pure returns (string memory) {
        // Simple date representation (would need proper date library for production)
        return string.concat("Timestamp: ", _toString(timestamp));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
