// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Test.sol";

import {ArenaVestingWallet} from "../src/ArenaVestingWallet.sol";
import {ArenaVestingWalletFactory} from "../src/ArenaVestingWalletFactory.sol";
import {VestingParams} from "../src/IArenaVestingWallet.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockArenaVestingWalletV2 is ArenaVestingWallet {
    function version() external pure returns (string memory) {
        return "v2";
    }
}

contract ArenaVestingWalletFactoryTest is Test {
    ArenaVestingWalletFactory public factory;
    ArenaVestingWallet public walletImplementation;

    address public admin = makeAddr("admin");
    address public user = makeAddr("user");
    address public beneficiary1 = makeAddr("beneficiary1");
    address public beneficiary2 = makeAddr("beneficiary2");

    event Arena_VestingWalletCreated(address indexed beneficiary, address indexed vestingWallet);
    event BeaconUpgraded(address indexed implementation);

    function setUp() public {
        vm.startPrank(admin);

        walletImplementation = new ArenaVestingWallet();

        ArenaVestingWalletFactory factoryImplementation = new ArenaVestingWalletFactory();

        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factoryImplementation),
            abi.encodeCall(ArenaVestingWalletFactory.initialize, (address(walletImplementation)))
        );

        factory = ArenaVestingWalletFactory(address(factoryProxy));

        vm.stopPrank();
    }

    function test_Initialize() public view {
        assertEq(factory.walletImplementation(), address(walletImplementation));
        assertTrue(address(factory.walletBeacon()) != address(0));
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        assertEq(UpgradeableBeacon(factory.walletBeacon()).implementation(), address(walletImplementation));
    }

    function test_InitializeRevertsWhenCalledAgain() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(address(walletImplementation));
    }

    function test_CreateVestingWallet() public {
        VestingParams memory params = _createValidParams(beneficiary1);

        vm.startPrank(admin);

        address wallet = factory.create(params);

        assertTrue(wallet != address(0));

        bytes32 key = factory.getVestingWalletKey(beneficiary1);
        assertEq(factory.vestingWallets(key), wallet);
        assertEq(factory.beneficiaries(beneficiary1), 1);

        ArenaVestingWallet vestingWallet = ArenaVestingWallet(payable(wallet));
        assertEq(vestingWallet.owner(), beneficiary1);
        assertEq(vestingWallet.start(), params.start);
        assertEq(vestingWallet.cliff(), params.start + params.cliff);
        assertEq(vestingWallet.intervals(), params.intervals);
        assertEq(vestingWallet.duration(), params.intervals * params.intervalDuration);

        vm.stopPrank();
    }

    function test_CreateMultipleWalletsForSameBeneficiary() public {
        VestingParams memory params1 = _createValidParams(beneficiary1);
        VestingParams memory params2 = _createValidParams(beneficiary1);
        params2.start = params1.start + 365 days;

        vm.startPrank(admin);

        address wallet1 = factory.create(params1);
        address wallet2 = factory.create(params2);

        assertTrue(wallet1 != wallet2);
        assertEq(factory.beneficiaries(beneficiary1), 2);

        bytes32 key1 = keccak256(abi.encodePacked(beneficiary1, uint256(1)));
        bytes32 key2 = keccak256(abi.encodePacked(beneficiary1, uint256(2)));

        assertEq(factory.vestingWallets(key1), wallet1);
        assertEq(factory.vestingWallets(key2), wallet2);

        vm.stopPrank();
    }

    function test_CreateRevertsWithoutAdminRole() public {
        VestingParams memory params = _createValidParams(beneficiary1);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, factory.DEFAULT_ADMIN_ROLE()
            )
        );
        factory.create(params);
        vm.stopPrank();
    }

    function test_UpgradeBeacon() public {
        MockArenaVestingWalletV2 walletV2 = new MockArenaVestingWalletV2();

        vm.startPrank(admin);

        vm.expectEmit(true, false, false, true);
        emit BeaconUpgraded(address(walletV2));

        factory.upgradeBeacon(address(walletV2));

        assertEq(factory.walletImplementation(), address(walletV2));
        assertEq(UpgradeableBeacon(factory.walletBeacon()).implementation(), address(walletV2));

        vm.stopPrank();
    }

    function test_UpgradeBeaconRevertsWithoutAdminRole() public {
        MockArenaVestingWalletV2 walletV2 = new MockArenaVestingWalletV2();

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, factory.DEFAULT_ADMIN_ROLE()
            )
        );
        factory.upgradeBeacon(address(walletV2));
        vm.stopPrank();
    }

    function test_UpgradeBeaconAffectsExistingWallets() public {
        VestingParams memory params = _createValidParams(beneficiary1);

        vm.startPrank(admin);
        address wallet = factory.create(params);

        MockArenaVestingWalletV2 walletV2 = new MockArenaVestingWalletV2();
        factory.upgradeBeacon(address(walletV2));

        MockArenaVestingWalletV2 upgradedWallet = MockArenaVestingWalletV2(payable(wallet));
        assertEq(upgradedWallet.version(), "v2");

        vm.stopPrank();
    }

    function test_FactoryUpgradeability() public {
        vm.startPrank(admin);

        ArenaVestingWalletFactory factoryV2 = new ArenaVestingWalletFactory();

        factory.upgradeToAndCall(address(factoryV2), "");

        assertEq(factory.walletImplementation(), address(walletImplementation));
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));

        vm.stopPrank();
    }

    function test_FactoryUpgradeRevertsWithoutAdminRole() public {
        ArenaVestingWalletFactory factoryV2 = new ArenaVestingWalletFactory();

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, factory.DEFAULT_ADMIN_ROLE()
            )
        );
        factory.upgradeToAndCall(address(factoryV2), "");
        vm.stopPrank();
    }

    function test_BeaconOwnership() public view {
        UpgradeableBeacon beacon = UpgradeableBeacon(factory.walletBeacon());
        assertEq(beacon.owner(), address(factory));
    }

    function test_GetVestingWalletKeyOverloads() public {
        vm.startPrank(admin);

        // Create first wallet
        VestingParams memory params = _createValidParams(beneficiary1);
        factory.create(params);

        // Test view function that returns last key
        bytes32 lastKey = factory.getVestingWalletKey(beneficiary1);
        assertEq(lastKey, keccak256(abi.encodePacked(beneficiary1, uint256(1))));

        // Test pure function with specific nonce
        bytes32 specificKey = factory.getVestingWalletKey(beneficiary1, 5);
        assertEq(specificKey, keccak256(abi.encodePacked(beneficiary1, uint256(5))));

        // Create another wallet
        factory.create(params);

        // Verify last key updated
        bytes32 newLastKey = factory.getVestingWalletKey(beneficiary1);
        assertEq(newLastKey, keccak256(abi.encodePacked(beneficiary1, uint256(2))));

        vm.stopPrank();
    }

    function test_UpgradeBeaconWithZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert();
        factory.upgradeBeacon(address(0));
        vm.stopPrank();
    }

    function test_WalletsCannotBeOverwritten() public {
        vm.startPrank(admin);

        VestingParams memory params = _createValidParams(beneficiary1);
        address wallet1 = factory.create(params);

        // Get the key for the first wallet
        bytes32 key1 = keccak256(abi.encodePacked(beneficiary1, uint256(1)));
        assertEq(factory.vestingWallets(key1), wallet1);

        // Create another wallet - should not overwrite the first
        address wallet2 = factory.create(params);

        // Verify first wallet still exists at its key
        assertEq(factory.vestingWallets(key1), wallet1);

        // Verify second wallet is at a different key
        bytes32 key2 = keccak256(abi.encodePacked(beneficiary1, uint256(2)));
        assertEq(factory.vestingWallets(key2), wallet2);

        vm.stopPrank();
    }

    function test_RetrieveWalletWithSpecificNonce() public {
        vm.startPrank(admin);

        VestingParams memory params = _createValidParams(beneficiary1);

        // Create 3 wallets
        address wallet1 = factory.create(params);
        address wallet2 = factory.create(params);
        address wallet3 = factory.create(params);

        // Retrieve each wallet using specific nonce
        bytes32 key1 = factory.getVestingWalletKey(beneficiary1, 1);
        bytes32 key2 = factory.getVestingWalletKey(beneficiary1, 2);
        bytes32 key3 = factory.getVestingWalletKey(beneficiary1, 3);

        assertEq(factory.vestingWallets(key1), wallet1);
        assertEq(factory.vestingWallets(key2), wallet2);
        assertEq(factory.vestingWallets(key3), wallet3);

        vm.stopPrank();
    }

    function test_NonExistentWalletReturnsZeroAddress() public view {
        // Test with beneficiary that has no wallets
        bytes32 key = factory.getVestingWalletKey(beneficiary1, 1);
        assertEq(factory.vestingWallets(key), address(0));

        // Test with existing beneficiary but wrong nonce
        bytes32 wrongKey = factory.getVestingWalletKey(beneficiary1, 999);
        assertEq(factory.vestingWallets(wrongKey), address(0));
    }

    function test_BeaconImplementationConsistency() public {
        vm.startPrank(admin);

        // Initial state
        UpgradeableBeacon beacon = UpgradeableBeacon(factory.walletBeacon());
        assertEq(beacon.implementation(), factory.walletImplementation());

        // After upgrade
        MockArenaVestingWalletV2 walletV2 = new MockArenaVestingWalletV2();
        factory.upgradeBeacon(address(walletV2));

        // Both should be updated
        assertEq(beacon.implementation(), address(walletV2));
        assertEq(factory.walletImplementation(), address(walletV2));

        vm.stopPrank();
    }

    function testFuzz_CreateWithVariousParams(
        address _beneficiary,
        uint64 _start,
        uint64 _cliff,
        uint64 _intervals,
        uint64 _intervalDuration
    ) public {
        vm.assume(_beneficiary != address(0));
        vm.assume(_intervals > 0 && _intervals < 1000);
        vm.assume(_intervalDuration > 0 && _intervalDuration < 365 days);
        vm.assume(_start > vm.getBlockTimestamp() && _start < vm.getBlockTimestamp() + 10 * 365 days);
        uint64 duration = _intervals * _intervalDuration;
        vm.assume(_cliff <= duration);

        VestingParams memory params = VestingParams({
            beneficiary: _beneficiary,
            cliff: _cliff,
            start: _start,
            intervals: _intervals,
            intervalDuration: _intervalDuration
        });

        vm.startPrank(admin);
        address wallet = factory.create(params);

        assertTrue(wallet != address(0));
        ArenaVestingWallet vestingWallet = ArenaVestingWallet(payable(wallet));
        assertEq(vestingWallet.owner(), _beneficiary);
        assertEq(vestingWallet.intervals(), _intervals);

        vm.stopPrank();
    }

    function _createValidParams(address _beneficiary) internal view returns (VestingParams memory) {
        return VestingParams({
            beneficiary: _beneficiary,
            cliff: uint64(block.timestamp + 30 days),
            start: uint64(block.timestamp),
            intervals: 12,
            intervalDuration: 30 days
        });
    }
}
