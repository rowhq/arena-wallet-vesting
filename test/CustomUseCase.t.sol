// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Test.sol";

import {ArenaVestingWallet} from "../src/ArenaVestingWallet.sol";
import {VestingParams, IArenaVestingWallet} from "../src/IArenaVestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockArenaToken is ERC20Mock {
    constructor() ERC20Mock() {}
}

contract ArenaVestingWalletTest is Test {
    ArenaVestingWallet public walletImplementation;
    MockArenaToken public arenaToken;

    address public beneficiary = makeAddr("beneficiary");
    address public depositor = makeAddr("depositor");
    address public user = makeAddr("user");

    uint256 public constant ALLOCATION = 1000e18;
    uint64 public constant CLIFF_DURATION = 30 days;
    uint64 public constant INTERVAL_DURATION = 30 days;
    uint64 public constant INTERVALS = 12;

    event Arena_VestingDeposit(address indexed token, uint256 amount);

    function setUp() public {
        // Deploy mock ARENA token
        arenaToken = new MockArenaToken();

        // Replace ARENA constant in wallet with our mock (for testing)
        vm.etch(0xB8d7710f7d8349A506b75dD184F05777c82dAd0C, address(arenaToken).code);
        arenaToken = MockArenaToken(0xB8d7710f7d8349A506b75dD184F05777c82dAd0C);

        // Deploy implementation
        walletImplementation = new ArenaVestingWallet();

        // Setup tokens
        arenaToken.mint(depositor, ALLOCATION * 10);
        vm.prank(depositor);
        arenaToken.approve(address(this), type(uint256).max);
    }
}
