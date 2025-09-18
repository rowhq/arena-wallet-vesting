# ArenaVestingWallet

A secure, interval-based vesting contract for the ARENA ERC20 token.  
Supports a single deposit, single beneficiary, cliff periods, and non-transferable ownership.

## Features

- **Single deposit only** – All tokens must be deposited at once, by the owner.
- **Single token** – Only ARENA (`0xB8d7710f7d8349A506b75dD184F05777c82dAd0C`) can be vested/released.
- **Interval vesting** – Tokens vest in equal intervals (e.g., monthly, quarterly), with customizable duration and count.
- **Cliff support** – No tokens vest before the cliff timestamp.
- **Locked ownership** – Ownership cannot be transferred or renounced.
- **Release** – Only vested tokens can be released to the beneficiary, and only after the vesting has started.
- **Events** – Emits deposit and release events.
- **Custom errors** – Clear revert reasons for all invalid usage.

## Usage

### Constructor Parameters

```solidity
struct VestingParams {
    address beneficiary;          // The address to receive vested tokens
    uint64 cliff;                 // Timestamp for cliff (no tokens released before this)
    uint64 start;                 // Vesting start timestamp
    uint64 intervals;             // Number of vesting intervals (e.g., 4 for quarterly over a year)
    uint64 intervalDuration;      // Duration of each interval in seconds (e.g., 90 days for quarterly)
}
```

Example (1 year, quarterly vesting, 3 month intervals):

```solidity
new ArenaVestingWallet(VestingParams({
    beneficiary: 0xBeneficiaryAddress,
    cliff: 1700000000, // UNIX timestamp
    start: 1700000000, // UNIX timestamp
    intervals: 4,
    intervalDuration: 7776000 // 90 days in seconds
}));
```

### Deposit

- Can only be called once.
- Any additional tokens sent directly to the contract will **not** be vested or released.

```solidity
app.deposit(amount);
```

### Release

- Anyone can call `release(address token)` after deposit, but only ARENA will be relased.
- Released to `beneficiary` always.
- Only vested tokens are released.
- Release emits `Arena_VestingRelease` event.

```solidity
app.release(ARENA_ADDRESS);
```

### Vesting Calculation

- No tokens vest before the cliff.
- Afterwards, tokens vest proportionally at each interval.
- At the end of the vesting period, all tokens are released.
- Interval rounding loss is at most `intervals - 1 wei`; final interval always releases all remaining tokens.

### Ownership

- Ownership is locked; cannot be transferred or renounced.
- Beneficiary is set at deployment and cannot be changed.

## Events

- `Arena_VestingDeposit(address token, uint256 amount)`
- `Arena_VestingRelease(address token, uint256 amount)`

## Errors

- `Arena_CannotTransferOwnership()`
- `Arena_CannotRenounceOwnership()`
- `Arena_InvalidAmount()`
- `Arena_VestingStarted(bool started)`
- `Arena_InvalidParams()`
- `Arena_InvalidToken()`

## Security Notes

- Direct transfers of ARENA to the contract (not via `deposit`) are unrecoverable and will not be vested.
- Contract is non-upgradeable and ownership is locked.
- Only the deposited amount is considered for vesting.

## Example Test Cases

## License

MIT
