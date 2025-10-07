// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "./../src/ArenaVestingWallet.sol";

contract DeployImplementation is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        ArenaVestingWallet wallet = new ArenaVestingWallet();

        vm.stopBroadcast();

        console.log("ArenaVestingWallet implementation at:", address(wallet));

        //@remove 0xa3Eb4218246CD3160adce88b25595BD059C6644A
    }
}
