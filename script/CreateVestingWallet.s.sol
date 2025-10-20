// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ArenaVestingWalletFactory} from "./../src/ArenaVestingWalletFactory.sol";
import {VestingParams} from "./../src/IArenaVestingWallet.sol";

/// @title Create vesting wallet via factory
/// @author Rowship
/// @notice This script creates a new vesting wallet using the factory
/// @dev Requires caller to have DEFAULT_ADMIN_ROLE on the factory

contract CreateVestingWallet is Script {
    function run(
        address factoryAddress,
        address beneficiary,
        uint64 start,
        uint64 cliff,
        uint64 intervalDuration,
        uint64 intervals
    ) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        ArenaVestingWalletFactory factory = ArenaVestingWalletFactory(factoryAddress);

        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            start: start,
            cliff: cliff,
            intervalDuration: intervalDuration,
            intervals: intervals
        });

        address vestingWallet = factory.create(params);

        vm.stopBroadcast();

        console.log("=================================================");
        console.log("Vesting Wallet created at:", vestingWallet);
        console.log("Factory:               ", factoryAddress);
        console.log("Beneficiary:           ", beneficiary);
        console.log("Start:                 ", start);
        console.log("Cliff:                 ", cliff);
        console.log("Interval Duration:     ", intervalDuration);
        console.log("Intervals:             ", intervals);
        console.log("=================================================");
        console.log("");
        console.log("Next step: Deposit ARENA tokens to the wallet");
        console.log("Wallet address:", vestingWallet);
    }
}
