// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";

contract ArenaVestingWallet is VestingWallet {
    using SafeERC20 for IERC20;

    IERC20 public constant ARENA = IERC20(0xB8d7710f7d8349A506b75dD184F05777c82dAd0C);

    address public recover = address(1000);

    error Arena_CannotTransferOwnership();

    constructor(address beneficiaryAddress, uint64 startTimestamp, uint64 durationSeconds)
        VestingWallet(beneficiaryAddress, startTimestamp, durationSeconds)
    {}

    /**
     * @notice Cannot be transferred to another beneficiary.
     */
    function transferOwnership(address) public view override onlyOwner {
        revert Arena_CannotTransferOwnership();
    }

    /**
     * @notice Renouncing ownership will transfer all locked ARENA tokens to the vestor address.
     */
    function renounceOwnership() public override onlyOwner {
        uint256 lockedAmount = ARENA.balanceOf(address(this));
        ARENA.safeTransfer(recover, lockedAmount);

        super.renounceOwnership();
    }
}
