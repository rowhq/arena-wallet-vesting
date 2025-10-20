// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ArenaVestingWalletFactory} from "./../src/ArenaVestingWalletFactory.sol";

/// @title Grant factory admin role
/// @author Rowship
/// @notice This script grants DEFAULT_ADMIN_ROLE to a new address
/// @dev Only grants, never revokes. Use RevokeFactoryAdmin for revocation.

contract GrantFactoryAdmin is Script {
    error InvalidFactoryAddress();
    error InvalidNewAdmin();
    error CallerNotAdmin();
    error FactoryNotContract();
    error AdminAlreadyHasRole();

    function run(address factoryAddress, address newAdmin) external {
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

        ArenaVestingWalletFactory factory = ArenaVestingWalletFactory(factoryAddress);
        bytes32 adminRole = factory.DEFAULT_ADMIN_ROLE();

        // Check 3: Caller actually has admin role
        if (!factory.hasRole(adminRole, caller)) {
            revert CallerNotAdmin();
        }

        // Check 4: New admin doesn't already have role (informational)
        if (factory.hasRole(adminRole, newAdmin)) {
            console.log("WARNING: New admin already has admin role");
            console.log("This operation will have no effect");
            revert AdminAlreadyHasRole();
        }

        // ============================================
        // EXECUTE GRANT
        // ============================================

        vm.startBroadcast(pk);

        factory.grantRole(adminRole, newAdmin);

        vm.stopBroadcast();

        // ============================================
        // POST-EXECUTION VERIFICATION
        // ============================================

        // Verify new admin has role
        require(factory.hasRole(adminRole, newAdmin), "Grant failed");

        // ============================================
        // LOGGING
        // ============================================

        console.log("=================================================");
        console.log("Factory Admin Grant Complete");
        console.log("=================================================");
        console.log("Factory:     ", factoryAddress);
        console.log("New Admin:   ", newAdmin);
        console.log("Granted By:  ", caller);
        console.log("=================================================");
        console.log("");
        console.log("SUCCESS: New admin now has DEFAULT_ADMIN_ROLE");
        console.log("");
        console.log("Current admins (known):");
        console.log("  - ", caller, " (you)");
        console.log("  - ", newAdmin, " (newly granted)");
        console.log("");
        console.log("Both addresses can now:");
        console.log("  - Create vesting wallets");
        console.log("  - Upgrade beacon implementation");
        console.log("  - Grant/revoke admin roles");
        console.log("  - Upgrade factory");
        console.log("");
        console.log("To remove an admin, use: ./script/revoke-admin.sh");
    }
}
