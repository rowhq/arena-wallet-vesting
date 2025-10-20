// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ArenaVestingWalletFactory} from "./../src/ArenaVestingWalletFactory.sol";

/// @title Transfer factory admin role (SAFE VERSION)
/// @author Rowship
/// @notice This script grants DEFAULT_ADMIN_ROLE to a new admin and optionally revokes it from the caller
/// @dev Includes comprehensive safety checks to prevent bricking the factory

contract TransferFactoryAdminSafe is Script {
    error InvalidFactoryAddress();
    error InvalidNewAdmin();
    error CannotRevokeFromSelf();
    error CallerNotAdmin();
    error FactoryNotContract();

    function run(
        address factoryAddress,
        address newAdmin,
        bool revokeFromCaller
    ) external {
        // ============================================
        // SAFETY VALIDATIONS
        // ============================================

        // Check 1: Factory address is valid
        if (factoryAddress == address(0)) revert InvalidFactoryAddress();
        if (factoryAddress.code.length == 0) revert FactoryNotContract();

        // Check 2: New admin is valid
        if (newAdmin == address(0)) revert InvalidNewAdmin();
        if (newAdmin == factoryAddress) revert InvalidNewAdmin();

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(pk);

        // Check 3: Prevent self-revocation paradox
        if (revokeFromCaller && newAdmin == caller) {
            revert CannotRevokeFromSelf();
        }

        // ============================================
        // EXECUTE TRANSFER
        // ============================================

        ArenaVestingWalletFactory factory = ArenaVestingWalletFactory(factoryAddress);
        bytes32 adminRole = factory.DEFAULT_ADMIN_ROLE();

        // Check 4: Caller actually has admin role
        if (!factory.hasRole(adminRole, caller)) {
            revert CallerNotAdmin();
        }

        vm.startBroadcast(pk);

        // Log warning if new admin already has role
        if (factory.hasRole(adminRole, newAdmin)) {
            console.log("INFO: New admin already has admin role (no-op grant)");
        }

        // CRITICAL: Grant BEFORE revoking
        // This ensures new admin has access even if something goes wrong
        factory.grantRole(adminRole, newAdmin);

        bool callerStillAdmin = true;

        // Optionally revoke from caller
        if (revokeFromCaller) {
            factory.revokeRole(adminRole, caller);
            callerStillAdmin = false;
        }

        vm.stopBroadcast();

        // ============================================
        // POST-EXECUTION VERIFICATION
        // ============================================

        // Verify new admin has role
        require(factory.hasRole(adminRole, newAdmin), "Grant failed");

        // Verify caller status
        if (revokeFromCaller) {
            require(!factory.hasRole(adminRole, caller), "Revoke failed");
        }

        // ============================================
        // LOGGING
        // ============================================

        console.log("=================================================");
        console.log("Factory Admin Transfer Complete");
        console.log("=================================================");
        console.log("Factory:           ", factoryAddress);
        console.log("New Admin:         ", newAdmin);
        console.log("Previous Admin:    ", caller);
        console.log("Revoked from prev: ", revokeFromCaller);
        console.log("=================================================");
        console.log("");

        if (callerStillAdmin) {
            console.log("INFO: Both addresses now have admin access");
            console.log("Previous admin retains control");
            console.log("To fully transfer, use --revoke-from-caller");
        } else {
            console.log("SUCCESS: Admin role fully transferred");
            console.log("Previous admin no longer has access");
            console.log("Only new admin can manage the factory");
        }

        console.log("");
        console.log("=================================================");
        console.log("POST-TRANSFER VERIFICATION");
        console.log("=================================================");
        console.log("New admin has role:  ", factory.hasRole(adminRole, newAdmin));
        console.log("Prev admin has role: ", factory.hasRole(adminRole, caller));
        console.log("=================================================");
    }
}
