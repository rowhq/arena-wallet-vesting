// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ArenaVestingWalletFactory} from "./../src/ArenaVestingWalletFactory.sol";

/// @title Revoke factory admin role
/// @author Rowship
/// @notice This script revokes DEFAULT_ADMIN_ROLE from an address
/// @dev HIGH-RISK operation. Use with extreme caution.

contract RevokeFactoryAdmin is Script {
    error InvalidFactoryAddress();
    error InvalidTargetAdmin();
    error CallerNotAdmin();
    error FactoryNotContract();
    error TargetDoesNotHaveRole();
    error CannotRevokeFromSelf();

    function run(address factoryAddress, address targetAdmin) external {
        // ============================================
        // SAFETY VALIDATIONS
        // ============================================

        // Check 1: Factory address is valid
        if (factoryAddress == address(0)) revert InvalidFactoryAddress();
        if (factoryAddress.code.length == 0) revert FactoryNotContract();

        // Check 2: Target admin is valid
        if (targetAdmin == address(0)) revert InvalidTargetAdmin();

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(pk);

        // Check 3: Cannot revoke from yourself (use separate self-revoke if needed)
        if (targetAdmin == caller) {
            revert CannotRevokeFromSelf();
        }

        ArenaVestingWalletFactory factory = ArenaVestingWalletFactory(factoryAddress);
        bytes32 adminRole = factory.DEFAULT_ADMIN_ROLE();

        // Check 4: Caller actually has admin role
        if (!factory.hasRole(adminRole, caller)) {
            revert CallerNotAdmin();
        }

        // Check 5: Target actually has admin role
        if (!factory.hasRole(adminRole, targetAdmin)) {
            console.log("ERROR: Target address does not have admin role");
            console.log("Target:", targetAdmin);
            revert TargetDoesNotHaveRole();
        }

        // ============================================
        // DISPLAY WARNING
        // ============================================

        console.log("");
        console.log("=================================================");
        console.log("WARNING: HIGH-RISK OPERATION");
        console.log("=================================================");
        console.log("You are about to REVOKE admin access from:");
        console.log("  ", targetAdmin);
        console.log("");
        console.log("After this operation:");
        console.log("  - Target will lose ALL admin permissions");
        console.log("  - Target cannot create wallets");
        console.log("  - Target cannot upgrade implementations");
        console.log("  - Target cannot grant/revoke roles");
        console.log("");
        console.log("This script will now execute the revocation.");
        console.log("Make sure this is what you intended!");
        console.log("=================================================");
        console.log("");

        // ============================================
        // EXECUTE REVOKE
        // ============================================

        vm.startBroadcast(pk);

        factory.revokeRole(adminRole, targetAdmin);

        vm.stopBroadcast();

        // ============================================
        // POST-EXECUTION VERIFICATION
        // ============================================

        // Verify target no longer has role
        require(!factory.hasRole(adminRole, targetAdmin), "Revoke failed");

        // Verify caller still has role
        require(factory.hasRole(adminRole, caller), "Caller lost role");

        // ============================================
        // LOGGING
        // ============================================

        console.log("=================================================");
        console.log("Factory Admin Revoke Complete");
        console.log("=================================================");
        console.log("Factory:        ", factoryAddress);
        console.log("Revoked From:   ", targetAdmin);
        console.log("Revoked By:     ", caller);
        console.log("=================================================");
        console.log("");
        console.log("SUCCESS: Admin role revoked");
        console.log("");
        console.log("Target address NO LONGER has admin access");
        console.log("You (caller) still have admin access");
        console.log("");
        console.log("=================================================");
        console.log("POST-REVOKE VERIFICATION");
        console.log("=================================================");
        console.log("Target has role:  ", factory.hasRole(adminRole, targetAdmin));
        console.log("Caller has role:  ", factory.hasRole(adminRole, caller));
        console.log("=================================================");
    }
}
