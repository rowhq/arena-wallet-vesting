// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {ArenaVestingWallet} from "./ArenaVestingWallet.sol";
import {VestingParams} from "./IArenaVestingWallet.sol";

contract ArenaVestingWalletFactory is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    UpgradeableBeacon public walletBeacon;
    address public walletImplementation;

    mapping(bytes32 key => address vestingWallet) public vestingWallets;
    mapping(address beneficiary => uint16 nonce) public beneficiaries;

    // Enumerable storage for admin dashboard
    address[] public allVestingWallets;
    mapping(address beneficiary => address[] vestingWallets) public beneficiaryVestingWallets;

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
    function create(VestingParams memory params) external onlyRole(DEFAULT_ADMIN_ROLE) returns (address) {
        bytes4 selector = ArenaVestingWallet.initialize.selector;
        bytes memory initData = abi.encodeWithSelector(selector, params);

        BeaconProxy vestingWallet = new BeaconProxy(address(walletBeacon), initData);

        bytes32 key = _setVestingWalletKey(params.beneficiary);
        vestingWallets[key] = address(vestingWallet);

        // Add to enumerable storage
        allVestingWallets.push(address(vestingWallet));
        beneficiaryVestingWallets[params.beneficiary].push(address(vestingWallet));

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
     * @dev computes the last key for the vesting wallet
     * @return last vesting wallet key of the beneficiary
     */
    function getVestingWalletKey(address beneficiary) external view returns (bytes32) {
        return _computeVestingWalletKey(beneficiary, beneficiaries[beneficiary]);
    }

    /**
     * @dev computes the key for the vesting wallet given the nonce counter
     * @return vesting wallet key
     */
    function getVestingWalletKey(address beneficiary, uint256 nonce) external pure returns (bytes32) {
        return _computeVestingWalletKey(beneficiary, nonce);
    }

    /**
     * @dev computes the next key for the vesting wallet
     * @return next vesting wallet key
     */
    function _setVestingWalletKey(address beneficiary) internal returns (bytes32) {
        return _computeVestingWalletKey(beneficiary, ++beneficiaries[beneficiary]);
    }

    /**
     * @dev computes the key for the vesting wallet mapping
     */
    function _computeVestingWalletKey(address beneficiary, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(beneficiary, nonce));
    }

    /**
     * @notice Returns all vesting wallets created by this factory
     * @return Array of all vesting wallet addresses
     */
    function getAllVestingWallets() external view returns (address[] memory) {
        return allVestingWallets;
    }

    /**
     * @notice Returns the total number of vesting wallets created
     * @return Total count of vesting wallets
     */
    function getVestingWalletsCount() external view returns (uint256) {
        return allVestingWallets.length;
    }

    /**
     * @notice Returns all vesting wallets for a specific beneficiary
     * @param beneficiary The beneficiary address
     * @return Array of vesting wallet addresses for the beneficiary
     */
    function getBeneficiaryVestingWallets(address beneficiary) external view returns (address[] memory) {
        return beneficiaryVestingWallets[beneficiary];
    }

    /**
     * @notice Returns the number of vesting wallets for a specific beneficiary
     * @param beneficiary The beneficiary address
     * @return Count of vesting wallets for the beneficiary
     */
    function getBeneficiaryVestingWalletsCount(address beneficiary) external view returns (uint256) {
        return beneficiaryVestingWallets[beneficiary].length;
    }

    /**
     * @notice Returns a paginated list of vesting wallets
     * @param offset Starting index
     * @param limit Maximum number of results
     * @return Array of vesting wallet addresses
     */
    function getVestingWalletsPaginated(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory)
    {
        uint256 total = allVestingWallets.length;
        if (offset >= total) return new address[](0);

        uint256 end = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;

        address[] memory result = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            result[i] = allVestingWallets[offset + i];
        }
        return result;
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @dev Can only be called by an address with the DEFAULT_ADMIN_ROLE
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
