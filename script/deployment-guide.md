# Arena Vesting Wallet Deployment Guide

This guide explains how to use the deployment scripts to deploy the Arena Vesting Wallet on Avalanche networks.

## Prerequisites

- **Foundry/Forge** installed
- **Private key** with sufficient AVAX for deployment gas fees
- **Environment variable** `PRIVATE_KEY` set (or use `--private-key` flag)

## Deployment Scripts

### 1. Deploy Implementation Contract

The implementation contract must be deployed first. This is the logic contract that proxies will delegate to.

```sh
./script/deploy-implementation.sh [OPTIONS]

# Deploy to Fuji testnet (default)
./script/deploy-implementation.sh

# Deploy to mainnet
./script/deploy-implementation.sh --network mainnet
```

**Options:**

- `--network mainnet | fuji` - Target network (default: fuji)
- `--private-key KEY` - Private key (alternative to env var)
- `-h, --help` - Show help

> [!IMPORTANT]
> Save this address - you'll need it for deploying proxies.

### 2. Deploy Vesting Wallet Proxy

After deploying the implementation, you can deploy multiple proxy contracts for different beneficiaries.

```bash
./script/deploy-vesting-wallet.sh [OPTIONS]
```

**Required Parameters:**

- `--implementation ADDRESS` - Implementation contract address
- `--admin ADDRESS` - Proxy admin address
- `--beneficiary ADDRESS` - Beneficiary who receives vested tokens
- `--start TIMESTAMP` - Vesting start time (Unix timestamp)
- `--cliff DURATION` - Cliff duration in seconds (0 for no cliff)
- `--interval DURATION` - Time between releases in seconds
- `--intervals NUMBER` - Total number of release intervals

**Optional Parameters:**

- `--network [mainnet|fuji]` - Target network (default: fuji)
- `--rpc-url URL` - Custom RPC URL
- `--private-key KEY` - Private key
- `--verify` - Verify contract

**Example - 3-Year Quarterly Vesting:**

```bash
# Get current timestamp (Unix)
NOW=$(date +%s)

# Deploy proxy with 3-year quarterly vesting
./script/deploy-vesting-wallet.sh \
  --implementation 0x123...abc \
  --admin 0x456...def \
  --beneficiary 0x789...ghi \
  --start $NOW \
  --cliff 0 \
  --interval 7776000 \
  --intervals 12 \
  --network fuji
```

## Full Deployment Flow

1. **Set up environment:**

   ```bash
   export PRIVATE_KEY="your-private-key-here"
   ```

2. **Deploy implementation:**

   ```bash
   ./script/deploy-implementation.sh --network mainnet
   # Output: Implementation deployed at: 0xIMPL...
   ```

3. **Deploy proxy for each beneficiary:**

   ```bash
   ./script/deploy-vesting-wallet.sh \
     --implementation $IMPL_ADDRESS \
     --admin $ADMIN_ADDRESS \
     --beneficiary $BENEFICIARY \
     --start $TIMESTAMP \
     --cliff 0 \
     --interval 7776000 \
     --intervals 12
   ```

4. **Deposit Arena in the vesting wallet:**
   After deployment, call `deposit` to transfer ARENA tokens to the `Vesting Wallet Contract`.
