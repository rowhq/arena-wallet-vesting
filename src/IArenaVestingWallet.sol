// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

/**
 * @notice Parameters for creating a new vesting wallet
 * @param beneficiary The address that will own the vesting wallet and receive vested tokens
 * @param cliff The timestamp when the cliff period ends
 * @param start The timestamp when the vesting starts
 * @param intervals The number of intervals over which the tokens will vest
 * @param intervalDuration The duration of each interval in seconds
 */
struct VestingParams {
    address beneficiary;
    uint64 cliff;
    uint64 start;
    uint64 intervals;
    uint64 intervalDuration;
}

interface IArenaVestingWallet {
    event Arena_VestingDeposit(address indexed token, uint256 amount);

    error Arena_CannotTransferOwnership();
    error Arena_CannotRenounceOwnership();
    error Arena_InvalidAmount();
    error Arena_VestingStarted(bool started);
    error Arena_InvalidParams();
    error Arena_InvalidToken(address token);

    /**
     * @notice the full amount of tokens allocated for vesting
     */
    function allocation() external view returns (uint256);

    /**
     * @notice whether the vesting has started
     */
    function started() external view returns (bool);

    /**
     * @notice number of intervals for the vesting schedule
     */
    function intervals() external view returns (uint64);

    /**
     * @notice Deposits the total amount of ARENA tokens to be vested (single deposit ever).
     * @dev post transfer of Arena or tokens will not be vested.
     */
    function deposit(uint256 allocation) external;
}
