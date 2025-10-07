# Arena Vesting Wallet - 3-Year Quarterly Vesting Simulation Report

## Overview

This report demonstrates the behavior of the Arena Vesting Wallet contract configured for a 3-year vesting schedule with quarterly releases.

### Configuration

- **Total Allocation**: 500,000 ARENA tokens
- **Vesting Duration**: 3 years (36 months)
- **Release Schedule**: Quarterly (every 3 months)
- **Total Releases**: 12 quarterly payments
- **Tokens per Quarter**: ~41,666.67 ARENA
- **Cliff Period**: None

## Test

```sh
   forge test --mt test_ThreeYearQuarterlyVestingSimulation -vv
```

## Vesting Schedule Breakdown

*Simulated from Avalanche Mainnet Fork starting October 21, 2025*

| Quarter | Month | Date       | Newly Vested | Total Vested | Released  | Total Released | Remaining Locked | Progress |
| ------- | ----- | ---------- | ------------ | ------------ | --------- | -------------- | ---------------- | -------- |
| Initial | 0     | 2025-10-21 | 0            | 0            | 0         | 0              | 500,000.00       | 0%       |
| 1       | 3     | 2026-01-19 | 41,666.66    | 41,666.66    | 41,666.66 | 41,666.66      | 458,333.33       | 8%       |
| 2       | 6     | 2026-04-19 | 41,666.66    | 83,333.33    | 41,666.66 | 83,333.33      | 416,666.66       | 16%      |
| 3       | 9     | 2026-07-18 | 41,666.66    | 125,000.00   | 41,666.66 | 125,000.00     | 375,000.00       | 25%      |
| 4       | 12    | 2026-10-16 | 41,666.66    | 166,666.66   | 41,666.66 | 166,666.66     | 333,333.33       | 33%      |
| 5       | 15    | 2027-01-14 | 41,666.66    | 208,333.33   | 41,666.66 | 208,333.33     | 291,666.66       | 41%      |
| 6       | 18    | 2027-04-14 | 41,666.66    | 250,000.00   | 41,666.66 | 250,000.00     | 250,000.00       | 50%      |
| 7       | 21    | 2027-07-13 | 41,666.66    | 291,666.66   | 41,666.66 | 291,666.66     | 208,333.33       | 58%      |
| 8       | 24    | 2027-10-11 | 41,666.66    | 333,333.33   | 41,666.66 | 333,333.33     | 166,666.66       | 66%      |
| 9       | 27    | 2028-01-09 | 41,666.66    | 375,000.00   | 41,666.66 | 375,000.00     | 125,000.00       | 75%      |
| 10      | 30    | 2028-04-09 | 41,666.66    | 416,666.66   | 41,666.66 | 416,666.66     | 83,333.33        | 83%      |
| 11      | 33    | 2028-07-08 | 41,666.66    | 458,333.33   | 41,666.66 | 458,333.33     | 41,666.66        | 91%      |
| 12      | 36    | 2028-10-06 | 41,666.66    | 500,000.00   | 41,666.66 | 500,000.00     | 0.00             | 100%     |

## Key Milestones

### Year 1 (Months 0-12)

- **Quarters Completed**: 4
- **Tokens Released**: 166,666.66 ARENA (33.33%)
- **Remaining Locked**: 333,333.33 ARENA

### Year 2 (Months 13-24)

- **Quarters Completed**: 4 (5-8 total)
- **Tokens Released**: 166,666.67 ARENA (33.33%)
- **Total Released by Year 2**: 333,333.33 ARENA (66.67%)
- **Remaining Locked**: 166,666.66 ARENA

### Year 3 (Months 25-36)

- **Quarters Completed**: 4 (9-12 total)
- **Tokens Released**: 166,666.67 ARENA (33.33%)
- **Total Released by Year 3**: 500,000.00 ARENA (100%)
- **Remaining Locked**: 0 ARENA

## Final Summary

| Metric                        | Value                                 |
| ----------------------------- | ------------------------------------- |
| **Total Tokens Allocated**    | 500,000 ARENA                         |
| **Total Tokens Released**     | 500,000 ARENA                         |
| **Beneficiary Final Balance** | 500,000 ARENA                         |
| **Vesting Efficiency**        | 100% (all tokens successfully vested) |

## Simulation Vesting Behavior Insights

1. **Linear Distribution**: Each quarter releases exactly 1/12th of the total allocation (8.33% per quarter)
2. **Predictable Schedule**: Beneficiaries receive tokens every 90 days
3. **No Cliff Period**: Vesting begins immediately from the start date
4. **Complete Distribution**: All 500,000 tokens are distributed with no remainder

## Simulation Technical Details

- **Network**: Avalanche Mainnet (Forked)
- **Simulation Start Date**: October 21, 2025
- **Simulation End Date**: October 6, 2028
- **Contract Address**: 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
- **Beneficiary Address**: 0x5c4d2bd3510C8B51eDB17766d3c96EC637326999
- **Interval Duration**: 7,776,000 seconds (90 days)
- **Total Vesting Duration**: 93,312,000 seconds (1,080 days)
