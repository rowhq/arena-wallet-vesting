// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ArenaVestingWallet, IArenaVestingWallet, VestingParams} from "./../src/ArenaVestingWallet.sol";
/// @title deploy script for ArenaVestingWallet
/// @author Rowship
/// @notice This script deploys the ArenaVestingWallet contract

contract DeployVestingWalletProxy is Script {
    address private vestingWalletImplementation = address(0); //@warn: set implementation
    address private proxyAdmin = address(0); //@warn: set admin

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        VestingParams memory params =
            VestingParams({beneficiary: address(0), start: 0, cliff: 0, intervalDuration: 0, intervals: 0});

        bytes memory data = abi.encodeWithSelector(ArenaVestingWallet.initialize.selector, params);

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(vestingWalletImplementation, proxyAdmin, data);

        vm.stopBroadcast();

        console.log("ArenaVestingWallet proxy at:", address(proxy));
    }
}
