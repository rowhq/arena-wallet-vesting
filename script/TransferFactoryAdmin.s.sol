// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ArenaVestingWalletFactory} from "./../src/ArenaVestingWalletFactory.sol";

/// @title Transfer factory admin role
/// @author Rowship
/// @notice This script grants DEFAULT_ADMIN_ROLE to a new admin and optionally revokes it from the caller
/// @dev Requires caller to have DEFAULT_ADMIN_ROLE on the factory

contract TransferFactoryAdmin is Script {
    function run(
        address factoryAddress,
        address newAdmin,
        bool revokeFromCaller
    ) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(pk);

        vm.startBroadcast(pk);

        ArenaVestingWalletFactory factory = ArenaVestingWalletFactory(factoryAddress);

        bytes32 adminRole = factory.DEFAULT_ADMIN_ROLE();

        // Grant admin role to new admin
        factory.grantRole(adminRole, newAdmin);

        bool callerStillAdmin = true;

        // Optionally revoke from caller
        if (revokeFromCaller) {
            factory.revokeRole(adminRole, caller);
            callerStillAdmin = false;
        }

        vm.stopBroadcast();

        console.log("=================================================");
        console.log("Factory Admin Transfer Complete");
        console.log("=================================================");
        console.log("Factory:           ", factoryAddress);
        console.log("New Admin:         ", newAdmin);
        console.log("Previous Admin:    ", caller);
        console.log("Revoked from prev: ", revokeFromCaller);
        console.log("=================================================");

        if (callerStillAdmin) {
            console.log("");
            console.log("WARNING: Previous admin still has admin role!");
            console.log("Both addresses can now manage the factory.");
            console.log("To fully transfer control, run with --revoke-from-caller");
        } else {
            console.log("");
            console.log("Admin role has been fully transferred.");
            console.log("Only the new admin can manage the factory now.");
        }
    }
}
