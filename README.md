# Arena Vesting Wallet

A secure, interval-based vesting contract for ARENA tokens with cliff support and immutable beneficiary ownership.

## ✨ Core Features

- **Single deposit only** – All tokens deposited once during wallet creation
- **ARENA token exclusive** – Only ARENA (`0xB8d7710f7d8349A506b75dD184F05777c82dAd0C`) can be vested
- **Interval-based vesting** – Tokens vest in equal intervals (monthly, quarterly, etc.)
- **Cliff support** – Optional cliff period before vesting begins
- **Immutable beneficiary** – Ownership cannot be transferred or renounced
- **Precision handling** – Minimal rounding loss (max: intervals - 1 wei)
- **Release control** – Only vested tokens can be released to beneficiary

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

## ⚠️ Important Warnings & Considerations

### Beneficiary Restrictions

- **No contract beneficiaries**: Beneficiaries should be EOAs (Externally Owned Accounts), not smart contracts
- **Token reception**: If a beneficiary is a contract, ensure it can receive ERC20 tokens without reverting
- **No multisig without testing**: Multisig wallets should be thoroughly tested before use as beneficiaries

### Token Security

- **Direct transfers are permanent**: Tokens sent directly to wallet (not via `deposit()`) become permanently locked
- **ARENA only**: Only ARENA tokens participate in vesting; other tokens sent become inaccessible
- **Single deposit**: Once `deposit()` is called, no additional deposits are possible

### Access Control

- **Factory admin control**: Only factory admin can create new vesting wallets
- **Upgrade permissions**: Beacon upgrades affect ALL existing wallets simultaneously
- **Irreversible actions**: Wallet creation and token deposits cannot be undone

## 🧪 Comprehensive Test Suite

Our test suite achieves **~99% code coverage** and includes:

### Core Functionality Tests

- `test_Initialize()` - Wallet initialization and parameter validation
- `test_Deposit()` - Token deposit mechanics and restrictions
- `test_Release*()` - Various release scenarios and timing
- `test_VestedAmount*()` - Vesting calculation accuracy

### Cliff & Timing Tests

- `test_NoVestingBeforeCliff()` - Cliff period enforcement
- `test_VestingStartsAtCliff()` - Cliff boundary conditions
- `test_VestingAtEachInterval()` - Interval-based vesting progression
- `test_FullVestingAfterDuration()` - Complete vesting scenarios

### Access Control Tests

- `test_CannotTransferOwnership()` - Ownership immutability
- `test_CannotRenounceOwnership()` - Ownership permanence
- `test_CreateRevertsWithoutAdminRole()` - Factory access control

### Edge Cases & Security Tests

- `test_OnlyDepositedTokensVest()` - Direct transfer protection
- `test_VestingWithPrimeIntervals()` - Precision handling with difficult math
- `test_PartialReleasesByChoice()` - Strategic release patterns
- `test_MultipleReleases()` - Cumulative release tracking

### Client-Specific Requirements

- `test_QuarterlyVestingWithoutCliff()` - 91-day quarterly vesting over 1 year
- `test_QuarterlyVestingWithCliff()` - Quarterly vesting with 6-month cliff

### Factory Tests

- `test_CreateVestingWallet()` - Wallet creation via factory
- `test_UpgradeBeacon()` - Implementation upgrades
- `test_CreateMultipleWalletsForSameBeneficiary()` - Multi-wallet scenarios
- `test_GetVestingWalletKey*()` - Address derivation and tracking

### Fuzz Testing

- `testFuzz_VestingSchedule()` - Property-based testing with random parameters
- `testFuzz_CreateWithVariousParams()` - Factory robustness testing

## ➕ Enhanced Capabilities with Factory

For enterprise use cases, the `ArenaVestingWalletFactory` adds powerful management features:

### 🔧 Factory Benefits

- **Batch deployment** – Create multiple vesting wallets efficiently
- **Centralized upgrades** – Update all wallets via beacon proxy pattern
- **Access control** – Admin-only wallet creation and system upgrades
- **Multi-wallet support** – Multiple vesting schedules per beneficiary
- **Deterministic addressing** – Predictable wallet addresses for tracking

### 📋 Factory Use Cases

```solidity
// Employee vesting programs
VestingParams memory employee = VestingParams({
    beneficiary: employeeAddress,
    cliff: 365 days,           // 1 year cliff
    start: block.timestamp,
    intervals: 16,             // 4 years quarterly
    intervalDuration: 91 days
});

// Advisor compensation
VestingParams memory advisor = VestingParams({
    beneficiary: advisorAddress,
    cliff: 182 days,           // 6 month cliff
    start: block.timestamp,
    intervals: 8,              // 2 years quarterly
    intervalDuration: 91 days
});

// Create wallets via factory
address employeeWallet = factory.create(employee);
address advisorWallet = factory.create(advisor);
```

### 🔄 Upgrade Infrastructure

```solidity
// Deploy new wallet implementation with additional features
ArenaVestingWalletV2 newImplementation = new ArenaVestingWalletV2();

// Upgrade ALL existing wallets instantly
factory.upgradeBeacon(address(newImplementation));
// Every wallet now uses V2 features while preserving state
```

### 📊 Wallet Management

```solidity
// Track multiple wallets per beneficiary
uint256 walletCount = factory.beneficiaries(beneficiaryAddress);

// Retrieve specific wallet
bytes32 key = factory.getVestingWalletKey(beneficiary, nonce);
address walletAddress = factory.vestingWallets(key);

// Create additional wallet for same beneficiary
VestingParams memory secondVesting = VestingParams({...});
address secondWallet = factory.create(secondVesting); // Different nonce
```

## 🛡️ Security Features

- **100% test coverage** with comprehensive edge case testing
- **Access control** via OpenZeppelin's role-based system
- **Upgrade safety** with beacon proxy pattern
- **Precision mathematics** handling rounding edge cases
- **Event logging** for all critical operations
- **Custom errors** with clear failure reasons

## 📋 Prerequisites

- Foundry framework
- OpenZeppelin Contracts (Upgradeable)
- Solidity ^0.8.25

## 🚀 Quick Start

```bash
# Clone and install dependencies
git clone [repository]
cd arena-wallet-vesting
forge install

# Run tests
forge test

# Check coverage
forge coverage

# Deploy (configure network in foundry.toml)
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

## 📄 License

MIT
