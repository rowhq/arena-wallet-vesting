// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ArenaVestingWalletFactory} from "./../src/ArenaVestingWalletFactory.sol";

/// @title Deploy script for ArenaVestingWalletFactory
/// @author Rowship
/// @notice This script deploys the factory with UUPS proxy pattern
/// @dev The deployer will be granted DEFAULT_ADMIN_ROLE

contract DeployFactory is Script {
    function run(address walletImplementation) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        // Deploy factory implementation
        ArenaVestingWalletFactory factoryImpl = new ArenaVestingWalletFactory();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            ArenaVestingWalletFactory.initialize.selector,
            walletImplementation
        );

        // Deploy UUPS proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(factoryImpl), initData);

        vm.stopBroadcast();

        console.log("=================================================");
        console.log("Factory Implementation deployed at:", address(factoryImpl));
        console.log("Factory Proxy deployed at:        ", address(proxy));
        console.log("Wallet Implementation:             ", walletImplementation);
        console.log("Factory Admin (deployer):          ", vm.addr(pk));
        console.log("=================================================");
        console.log("");
        console.log("SAVE THIS ADDRESS:");
        console.log("Factory Address: ", address(proxy));
    }
}
