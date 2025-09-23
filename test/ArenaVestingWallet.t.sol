// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Test.sol";

import {ArenaVestingWallet} from "../src/ArenaVestingWallet.sol";
import {ArenaVestingWalletFactory} from "../src/ArenaVestingWalletFactory.sol";
import {VestingParams, IArenaVestingWallet} from "../src/IArenaVestingWallet.sol";

contract ArenaWalletVestingTest is Test {
    ArenaVestingWalletFactory public app;

    address public vestor = makeAddr("vestor");

    function setUp() public {}

    function testCannotTransferOwnership() public {
        ArenaVestingWallet wallet = _createBasicWallet();

        vm.prank(wallet.owner());
        vm.expectRevert(IArenaVestingWallet.Arena_CannotTransferOwnership.selector);
        wallet.transferOwnership(address(2));
    }

    function _createBasicWallet() internal returns (ArenaVestingWallet) {
        address beneficiary = makeAddr("beneficiary");
        uint64 _now = uint64(vm.getBlockTimestamp());
        uint64 start = _now;
        uint64 cliff = 30 days;
        uint64 intervals = 4;
        uint64 intervalDuration = 30 days;

        VestingParams memory params = VestingParams(beneficiary, cliff, start, intervals, intervalDuration);
        return _create(params);
    }

    function _create(VestingParams memory params) internal returns (ArenaVestingWallet) {
        address wallet = app.create(params);
        return ArenaVestingWallet(payable(wallet));
    }
}
