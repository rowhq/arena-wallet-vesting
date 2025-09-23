// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Initializable,
    VestingWalletCliffUpgradeable
} from "@openzeppelin/contracts-upgradeable/finance/VestingWalletCliffUpgradeable.sol";
import {IArenaVestingWallet, VestingParams} from "./IArenaVestingWallet.sol";

contract ArenaVestingWallet is Initializable, IArenaVestingWallet, VestingWalletCliffUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public constant ARENA = IERC20(0xB8d7710f7d8349A506b75dD184F05777c82dAd0C);

    uint256 public allocation;
    bool public started;
    uint64 public intervals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(VestingParams memory params) public initializer {
        if (params.beneficiary == address(0) || params.intervals == 0 || params.intervalDuration == 0) {
            revert Arena_InvalidParams();
        }

        intervals = params.intervals;

        __VestingWallet_init(params.beneficiary, params.start, params.intervals * params.intervalDuration);
        __VestingWalletCliff_init(params.cliff);
    }

    /**
     * @notice Deposits the total amount of ARENA tokens to be vested (single deposit ever).
     * @dev post transfer of Arena or tokens will not be vested.
     */
    function deposit(uint256 _amount) external {
        if (started) revert Arena_VestingStarted(true);
        if (_amount == 0) revert Arena_InvalidAmount();

        ARENA.safeTransferFrom(msg.sender, address(this), _amount);
        allocation = _amount;
        started = true;

        emit Arena_VestingDeposit(address(ARENA), _amount);
    }

    /**
     * @dev Release only after vesting has started.
     */
    function release(address token) public override {
        if (!started) revert Arena_VestingStarted(false);

        super.release(token);
    }

    /**
     * @notice Calculates the amount of ARENA that has already vested.
     * @dev other tokens will always return 0 and post ARENA transfers will not be vested.
     */
    function vestedAmount(address token, uint64 timestamp) public view override returns (uint256) {
        if (token != address(ARENA)) revert Arena_InvalidToken(token);

        return _vestingSchedule(allocation, timestamp);
    }

    /**
     * @notice Cannot be transferred to another beneficiary.
     */
    function transferOwnership(address) public view override onlyOwner {
        revert Arena_CannotTransferOwnership();
    }

    /**
     * @notice Cannot renounce ownership.
     */
    function renounceOwnership() public view override onlyOwner {
        revert Arena_CannotRenounceOwnership();
    }

    /**
     * IMPORTANT: The maximum possible loss is always intervals - 1 wei
     * the amount released at the end of the vesting duration is ~100% (99.99...%).
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp)
        internal
        view
        override /* (VestingWalletCliff) */
        returns (uint256)
    {
        if (timestamp < cliff()) return 0;
        if (timestamp >= end()) return totalAllocation;
        if (released() >= totalAllocation) return totalAllocation;

        uint256 intervalDuration = duration() / intervals;

        uint256 elapsedIntervals = (timestamp - start()) / intervalDuration;
        if (elapsedIntervals > intervals) elapsedIntervals = intervals;

        uint256 vested = (totalAllocation * elapsedIntervals) / intervals;

        if (vested > totalAllocation) vested = totalAllocation;

        return vested;
    }
}
