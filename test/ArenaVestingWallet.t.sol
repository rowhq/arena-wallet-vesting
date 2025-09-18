// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../src/ArenaVestingWallet.sol";

contract ArenaWalletVestingTest is Test {
    address public vestor = makeAddr("vestor");

    function setUp() public {}

    function testCannotTransferOwnership() public {
        address beneficiary = makeAddr("beneficiary");
        uint64 start = uint64(vm.getBlockTimestamp() + 1 days);
        uint64 duration = 365 days;

        ArenaVestingWallet app = _create(beneficiary, start, duration);

        vm.prank(beneficiary);
        vm.expectRevert(ArenaVestingWallet.Arena_CannotTransferOwnership.selector);
        app.transferOwnership(address(2));
    }

    function _create(address beneficiary, uint64 start, uint64 duration) internal returns (ArenaVestingWallet) {
        ArenaVestingWallet.VestingParams memory params = ArenaVestingWallet.VestingParams({
            beneficiary: beneficiary,
            cliff: start,
            start: start,
            intervals: duration / 30 days,
            intervalDuration: 30 days
        });
        return new ArenaVestingWallet(params);
    }
}
