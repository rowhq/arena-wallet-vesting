// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ArenaVestingWallet, IArenaVestingWallet, VestingParams} from "./../src/ArenaVestingWallet.sol";

/// @title Deploy script for ArenaVestingWallet with CLI arguments
/// @author Rowship
/// @notice This script deploys the ArenaVestingWallet contract with CLI arguments
/// @dev Usage: forge script script/DeployVestingWalletProxyWithArgs.s.sol:DeployVestingWalletProxyWithArgs --broadcast --rpc-url <RPC_URL>
///      --sig "run(address,address,address,uint64,uint64,uint64,uint64)" <implementation> <proxyAdmin> <beneficiary> <start> <cliff> <intervalDuration> <intervals>

contract DeployVestingWalletProxyWithArgs is Script {
    function run(
        address vestingWalletImplementation,
        address proxyAdmin,
        address beneficiary,
        uint64 start,
        uint64 cliff,
        uint64 intervalDuration,
        uint64 intervals
    ) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        VestingParams memory params = VestingParams({
            beneficiary: beneficiary,
            start: start,
            cliff: cliff,
            intervalDuration: intervalDuration,
            intervals: intervals
        });

        bytes memory data = abi.encodeWithSelector(ArenaVestingWallet.initialize.selector, params);

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(vestingWalletImplementation, proxyAdmin, data);

        vm.stopBroadcast();

        console.log("ArenaVestingWallet proxy deployed at:", address(proxy));
        console.log("Implementation:", vestingWalletImplementation);
        console.log("ProxyAdmin:", proxyAdmin);
        console.log("Beneficiary:", beneficiary);
        console.log("Start:", start);
        console.log("Cliff:", cliff);
        console.log("Interval Duration:", intervalDuration);
        console.log("Intervals:", intervals);
    }
}
