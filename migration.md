# 📝 Vesting Migration Guide

This guide explains how to migrate existing off-chain vesting schedules to the ArenaVestingWallet smart contract while maintaining the original vesting cadence.

---

## 🎯 Overview

When users have already received vesting payments off-chain, we need to:

1. Deploy their vesting contract with adjusted parameters
2. Ensure future releases continue on the original schedule
3. Account for tokens already distributed

**Important:** This migration only supports users who received **full period releases** - no partial payments.

---

## 🧮 Migration Formula

For each user:

```javascript
newStartTime = originalStartTime + (intervalDuration × periodsAlreadyClaimed)
remainingAllocation = totalAllocation - amountAlreadyDistributed
```

Where:

- `periodsAlreadyClaimed` = number of full releases already paid off-chain
- `intervalDuration` = time between releases (e.g., 90 days)
- `amountAlreadyDistributed` = total tokens sent off-chain

---

## 🧠 Why This Works

By shifting the start time forward by the number of completed periods:

1. The contract's "period 1" aligns with the user's next unclaimed period
2. The remaining allocation divides evenly by remaining periods
3. Each future release maintains the original per-period amount

**Example math:**

- Original: 12,000 tokens / 12 periods = 1,000 per period
- After 5 releases: 7,000 tokens / 7 periods = 1,000 per period ✅

---

## 📚 Example: Quarterly Vesting Migration

### Original Vesting Schedule

| Parameter         | Value                      |
| ----------------- | -------------------------- |
| Total allocation  | 24,000 tokens              |
| Vesting duration  | 3 years                    |
| Release frequency | Quarterly (every 3 months) |
| Total periods     | 12                         |
| Per-period amount | 2,000 tokens               |
| Start date        | Jan 1, 2024                |

### Off-Chain Distribution History

User has received 5 quarterly payments:

| Period | Date        | Amount | Status            |
| ------ | ----------- | ------ | ----------------- |
| 1      | Jan 1, 2024 | 2,000  | ✅ Paid off-chain |
| 2      | Apr 1, 2024 | 2,000  | ✅ Paid off-chain |
| 3      | Jul 1, 2024 | 2,000  | ✅ Paid off-chain |
| 4      | Oct 1, 2024 | 2,000  | ✅ Paid off-chain |
| 5      | Jan 1, 2025 | 2,000  | ✅ Paid off-chain |
| 6      | Apr 1, 2025 | 2,000  | ⏳ Next release   |

**Total distributed:** 10,000 tokens  
**Remaining:** 14,000 tokens

### Migration Parameters

```javascript
// Calculate new parameters
periodsAlreadyClaimed = 5
newStartTime = Jan 1, 2024 + (3 months × 5) = Apr 1, 2025
remainingAllocation = 24,000 - 10,000 = 14,000
remainingPeriods = 7

// Deploy with:
VestingParams {
    beneficiary: userAddress,
    start: Apr 1, 2025,        // Shifted forward by 5 periods
    cliff: 0,                  // No cliff (already passed)
    intervals: 7,              // Remaining periods
    intervalDuration: 3 months // Same as original
}

// Then deposit:
deposit(14,000 tokens)
```

### Post-Migration Schedule

The contract will release tokens on the original quarterly schedule:

| Period | Date        | Amount | Notes                   |
| ------ | ----------- | ------ | ----------------------- |
| 6      | Apr 1, 2025 | 2,000  | First on-chain release  |
| 7      | Jul 1, 2025 | 2,000  | Continues quarterly     |
| 8      | Oct 1, 2025 | 2,000  | Same amount as original |
| ...    | ...         | ...    | ...                     |
| 12     | Oct 1, 2026 | 2,000  | Final release           |

✅ **Result:** Vesting continues seamlessly with the same 2,000 tokens per quarter

---

## 📝 Migration Steps

1. **Verify full releases only**

   - Ensure user received only complete period payments
   - No partial amounts allowed

2. **Calculate parameters**

   ```javascript
   periodsAlreadyClaimed = amountDistributed / perPeriodAmount
   newStartTime = originalStart + (intervalDuration × periodsAlreadyClaimed)
   remainingAllocation = totalAllocation - amountDistributed
   ```

3. **Deploy vesting contract**

   - Use adjusted start time and remaining allocation
   - Set intervals to remaining periods

4. **Deposit tokens**

   - Transfer the remaining allocation to the contract

5. **Verify alignment**
   - Check that first claimable date matches next expected release

---

## ⚠️ Important Considerations

- **No partial releases:** All off-chain distributions must be exact multiples of the per-period amount
- **Timing precision:** Use the exact interval duration from the original schedule (e.g., 90 days vs 3 calendar months)
- **Cliff handling:** If original cliff has passed, set cliff to 0 in migration

---

## ✅ Pre-Migration Checklist

- [ ] Verify user received only full period releases
- [ ] Calculate exact number of periods already claimed
- [ ] Confirm remaining allocation math: `total - distributed = remaining`
- [ ] Test that `remaining / remainingPeriods = originalPerPeriodAmount`
- [ ] Have remaining tokens ready for deposit

---

## 🚀 Post-Migration

Once migrated:

- Users claim future releases on-chain
- Release amounts match original schedule exactly
- Vesting continues on the same dates as planned
- All users remain synchronized on the original cadence
