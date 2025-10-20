#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default RPC URLs
AVALANCHE_MAINNET_RPC="https://api.avax.network/ext/bc/C/rpc"
AVALANCHE_FUJI_RPC="https://api.avax-test.network/ext/bc/C/rpc"

# Help function
show_help() {
    echo "Arena Vesting Wallet Factory - Revoke Admin Role"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo -e "${RED}⚠️  WARNING: HIGH-RISK OPERATION ⚠️${NC}"
    echo "This script REVOKES admin access from an address."
    echo "Use with extreme caution!"
    echo ""
    echo "Required arguments:"
    echo "  --factory ADDRESS         Factory contract address"
    echo "  --target ADDRESS          Address to revoke admin role from"
    echo ""
    echo "Optional arguments:"
    echo "  --network NETWORK         Network: mainnet|fuji (default: fuji)"
    echo "  --rpc-url URL            Custom RPC URL (overrides network selection)"
    echo "  --private-key KEY        Private key (alternative to PRIVATE_KEY env var)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  PRIVATE_KEY              Private key of current admin"
    echo ""
    echo "Examples:"
    echo "  # Revoke admin from an address"
    echo "  $0 --factory 0x123... --target 0x456... --network mainnet"
    echo ""
    echo "Note:"
    echo "  - You CANNOT revoke from yourself using this script (safety measure)"
    echo "  - To revoke your own access, use a different admin or create a separate script"
    echo "  - To grant admin, use ./script/grant-admin.sh"
}

# Validate Ethereum address format
validate_address() {
    local addr=$1
    local name=$2

    if [[ ! $addr =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${RED}Error: Invalid $name address format: $addr${NC}"
        echo "Expected format: 0x followed by 40 hexadecimal characters"
        return 1
    fi
    return 0
}

# Check for zero address
is_zero_address() {
    local addr=$1
    if [[ $addr == "0x0000000000000000000000000000000000000000" ]]; then
        return 0
    fi
    return 1
}

# Default values
NETWORK="fuji"
CUSTOM_RPC=""
PRIVATE_KEY_ARG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --factory)
            FACTORY="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --rpc-url)
            CUSTOM_RPC="$2"
            shift 2
            ;;
        --private-key)
            PRIVATE_KEY_ARG="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# Validate required arguments
MISSING_ARGS=false

if [ -z "$FACTORY" ]; then
    echo -e "${RED}Error: --factory is required${NC}"
    MISSING_ARGS=true
fi

if [ -z "$TARGET" ]; then
    echo -e "${RED}Error: --target is required${NC}"
    MISSING_ARGS=true
fi

if [ "$MISSING_ARGS" = true ]; then
    echo ""
    show_help
    exit 1
fi

# ============================================
# SAFETY VALIDATIONS
# ============================================

echo -e "${MAGENTA}Running safety validations...${NC}"
echo ""

# Validate address formats
validate_address "$FACTORY" "factory" || exit 1
validate_address "$TARGET" "target" || exit 1

# Check if factory and target are the same
if [ "$FACTORY" == "$TARGET" ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ERROR: Factory and target are the same address!${NC}"
    echo -e "${RED}========================================${NC}"
    echo "Cannot revoke admin from the factory contract itself."
    exit 1
fi

# Set private key
if [ -n "$PRIVATE_KEY_ARG" ]; then
    export PRIVATE_KEY="$PRIVATE_KEY_ARG"
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY environment variable or --private-key argument is required${NC}"
    exit 1
fi

# Get caller address from private key
CALLER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null)

if [ -z "$CALLER_ADDRESS" ]; then
    echo -e "${RED}Error: Failed to derive address from private key${NC}"
    echo "Please ensure your PRIVATE_KEY is valid"
    exit 1
fi

# Check if trying to revoke from self (CRITICAL CHECK)
if [ "$TARGET" == "$CALLER_ADDRESS" ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}⛔ CRITICAL ERROR: SELF-REVOCATION BLOCKED${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "You are attempting to revoke admin from YOURSELF!"
    echo ""
    echo "Your address:   $CALLER_ADDRESS"
    echo "Target address: $TARGET"
    echo ""
    echo "This operation has been BLOCKED for your safety."
    echo ""
    echo "If you truly want to remove your own admin access:"
    echo "  1. First grant admin to another address:"
    echo "     ./script/grant-admin.sh --factory $FACTORY --new-admin <OTHER_ADDRESS>"
    echo ""
    echo "  2. Have the OTHER admin revoke your access, or"
    echo "     Create a custom script for self-revocation with proper warnings"
    echo ""
    echo -e "${RED}========================================${NC}"
    exit 1
fi

# Set RPC URL based on network
if [ -n "$CUSTOM_RPC" ]; then
    RPC_URL="$CUSTOM_RPC"
elif [ "$NETWORK" = "mainnet" ]; then
    RPC_URL="$AVALANCHE_MAINNET_RPC"
elif [ "$NETWORK" = "fuji" ]; then
    RPC_URL="$AVALANCHE_FUJI_RPC"
else
    echo -e "${RED}Error: Unknown network $NETWORK. Use 'mainnet' or 'fuji'${NC}"
    exit 1
fi

# ============================================
# DISPLAY REVOKE INFORMATION
# ============================================

echo -e "${RED}========================================${NC}"
echo -e "${RED}⚠️  REVOKE FACTORY ADMIN ROLE ⚠️${NC}"
echo -e "${RED}========================================${NC}"
echo "Network: $NETWORK"
echo "RPC URL: $RPC_URL"
echo ""
echo -e "${RED}Revocation Details:${NC}"
echo "  Factory: $FACTORY"
echo "  Target:  $TARGET"
echo "  Caller:  $CALLER_ADDRESS (you)"
echo ""
echo -e "${RED}What this does:${NC}"
echo "  ❌ Revokes DEFAULT_ADMIN_ROLE from target"
echo "  ✅ You keep your admin role"
echo "  ⚠️  HIGH-RISK operation (removes permissions)"
echo ""
echo -e "${RED}After this operation, target will NOT be able to:${NC}"
echo "  - Create vesting wallets"
echo "  - Upgrade beacon implementations"
echo "  - Grant or revoke admin roles"
echo "  - Upgrade the factory"
echo ""
echo -e "${YELLOW}Before proceeding, verify:${NC}"
echo "  1. Target address is correct: $TARGET"
echo "  2. You want to remove their admin access"
echo "  3. Target is not a critical admin"
echo "  4. This won't leave the factory without admins"
echo ""

# ============================================
# MAINNET WARNING
# ============================================

if [ "$NETWORK" = "mainnet" ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}⚠️  MAINNET OPERATION WARNING ⚠️${NC}"
    echo -e "${RED}========================================${NC}"
    echo "You are about to revoke admin on MAINNET."
    echo "This operation is IRREVERSIBLE."
    echo ""
    echo "Make absolutely sure:"
    echo "  - Target address is correct"
    echo "  - You have confirmed with relevant parties"
    echo "  - This won't strand the factory"
    echo ""
fi

# ============================================
# DOUBLE CONFIRMATION
# ============================================

echo -e "${RED}========================================${NC}"
echo -e "${RED}CONFIRMATION REQUIRED${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo "You are about to revoke admin from:"
echo -e "${YELLOW}$TARGET${NC}"
echo ""
echo -e "${RED}Type the FULL target address to confirm:${NC}"
read -r CONFIRMATION

if [[ "$CONFIRMATION" != "$TARGET" ]]; then
    echo ""
    echo -e "${YELLOW}Address mismatch. Revocation cancelled.${NC}"
    echo "You typed: $CONFIRMATION"
    echo "Expected:  $TARGET"
    exit 0
fi

echo ""
echo -e "${RED}Final confirmation - Type 'REVOKE' to proceed:${NC}"
read -r FINAL_CONFIRM

if [[ "$FINAL_CONFIRM" != "REVOKE" ]]; then
    echo ""
    echo -e "${YELLOW}Revocation cancelled.${NC}"
    exit 0
fi

# ============================================
# EXECUTE REVOKE
# ============================================

echo ""
echo -e "${RED}Revoking admin role...${NC}"
echo ""

forge script script/RevokeFactoryAdmin.s.sol:RevokeFactoryAdmin \
    --broadcast \
    --rpc-url "$RPC_URL" \
    --sig "run(address,address)" \
    "$FACTORY" \
    "$TARGET"

REVOKE_STATUS=$?

# ============================================
# POST-EXECUTION VERIFICATION
# ============================================

if [ $REVOKE_STATUS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ Admin role revoked successfully${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Admin role has been REVOKED from:"
    echo "  $TARGET"
    echo ""
    echo -e "${YELLOW}Post-revocation verification:${NC}"
    echo ""
    echo "1. Verify target no longer has admin:"
    echo "   cast call $FACTORY \"hasRole(bytes32,address)\" \\"
    echo "     0x0000000000000000000000000000000000000000000000000000000000000000 \\"
    echo "     $TARGET --rpc-url $RPC_URL"
    echo ""
    echo "   Expected: false (0x0000...0000)"
    echo ""
    echo "2. Verify you still have admin:"
    echo "   cast call $FACTORY \"hasRole(bytes32,address)\" \\"
    echo "     0x0000000000000000000000000000000000000000000000000000000000000000 \\"
    echo "     $CALLER_ADDRESS --rpc-url $RPC_URL"
    echo ""
    echo "   Expected: true (0x0000...0001)"
    echo ""
    echo -e "${GREEN}========================================${NC}"
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}❌ Admin revocation FAILED${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Exit code: $REVOKE_STATUS${NC}"
    echo ""
    echo "Possible reasons:"
    echo "  1. Caller does not have admin role"
    echo "  2. Target does not have admin role"
    echo "  3. Target is yourself (blocked by script)"
    echo "  4. Factory address is incorrect"
    echo "  5. Gas limit exceeded"
    echo "  6. Network connectivity issues"
    echo ""
    echo "No changes have been made to the factory."
    echo "Target still has admin access (if they had it before)."
    exit $REVOKE_STATUS
fi
