 # 1. Deploy the ArenaVestingWallet implementation
./script/deploy-impl.sh --network mainnet
# Save the output address as $IMPL_ADDRESS

# 2. Deploy the Factory with UUPS proxy
./script/deploy-factory.sh \
  --implementation $IMPL_ADDRESS \
  --network mainnet
# Save the factory proxy address as $FACTORY_ADDRESS
# You now have DEFAULT_ADMIN_ROLE

# 3. Create vesting wallets for beneficiaries
./script/create-via-factory.sh \
  --factory $FACTORY_ADDRESS \
  --beneficiary 0xBENEFICIARY_ADDRESS \
  --start 1704067200 \
  --cliff 0 \
  --interval 7889400 \
  --intervals 12 \
  --network mainnet
# Repeat for each beneficiary

# 4. Fund each vesting wallet
# Call deposit(amount) on each vesting wallet to transfer ARENA tokens

# 5. Grant admin to new address
./script/grant-admin.sh \
  --factory $FACTORY_ADDRESS \
  --new-admin ADDRESS \
  --network mainnet

Admin Model:

- Factory Admin: You and the new address (ADDRESS) will both have DEFAULT_ADMIN_ROLE
  - Can create new vesting wallets
  - Can upgrade the wallet beacon implementation
  - Can grant/revoke admin to/from other addresses
- Vesting Wallet Ownership: Each beneficiary owns their own vesting wallet
  - Cannot transfer or renounce ownership
  - Only they can release their vested tokens