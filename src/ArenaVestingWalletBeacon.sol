// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {ArenaVestingWallet} from "./ArenaVestingWallet.sol";

contract ArenaVestingWalletFactory is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    UpgradeableBeacon public walletBeacon;
    address public walletImplementation;

    mapping(bytes32 key => address vestingWallet) public vestingWallets;
    mapping(address beneficiary => uint16 nonce) public beneficiaries;

    event Arena_VestingWalletCreated(address indexed beneficiary, address indexed vestingWallet);
    event BeaconUpgraded(address indexed implementation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with required addresses and roles
    function initialize(address _walletImplementation) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        walletImplementation = _walletImplementation;
        walletBeacon = new UpgradeableBeacon(walletImplementation, address(this));
    }

    /**
     * @notice Creates a new vesting wallet for a beneficiary
     * @param params The parameters for the vesting wallet
     */
    function create(ArenaVestingWallet.VestingParams memory params)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (address)
    {
        bytes4 selector = ArenaVestingWallet.initialize.selector;
        bytes memory initData = abi.encodeWithSelector(selector, params);

        BeaconProxy vestingWallet = new BeaconProxy(address(walletBeacon), initData);

        bytes32 key = getVestingWalletKey(params.beneficiary);
        vestingWallets[key] = address(vestingWallet);

        emit Arena_VestingWalletCreated(params.beneficiary, address(vestingWallet));

        return address(vestingWallet);
    }

    /// @notice Upgrades the implementation for all vesting wallet contracts
    /// @param implementation The address of the new implementation
    function upgradeBeacon(address implementation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        walletBeacon.upgradeTo(implementation);
        walletImplementation = implementation;

        emit BeaconUpgraded(implementation);
    }

    /**
     * @dev computes the key for the vesting wallet mapping
     * @param beneficiary The address of the beneficiary
     */
    function getVestingWalletKey(address beneficiary) public returns (bytes32) {
        return keccak256(abi.encodePacked(beneficiary, ++beneficiaries[beneficiary]));
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @dev Can only be called by an address with the DEFAULT_ADMIN_ROLE
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
