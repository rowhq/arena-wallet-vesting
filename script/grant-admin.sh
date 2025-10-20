#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default RPC URLs
AVALANCHE_MAINNET_RPC="https://api.avax.network/ext/bc/C/rpc"
AVALANCHE_FUJI_RPC="https://api.avax-test.network/ext/bc/C/rpc"

# Help function
show_help() {
    echo "Arena Vesting Wallet Factory - Grant Admin Role"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script grants DEFAULT_ADMIN_ROLE to a new address."
    echo "This is a LOW-RISK operation - it only adds admins, never removes them."
    echo ""
    echo "Required arguments:"
    echo "  --factory ADDRESS         Factory contract address"
    echo "  --new-admin ADDRESS       Address to grant admin role"
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
    echo "  # Grant admin to client"
    echo "  $0 --factory 0x123... --new-admin 0x456... --network mainnet"
    echo ""
    echo "  # Add backup admin"
    echo "  $0 --factory 0x123... --new-admin 0x789... --network fuji"
    echo ""
    echo "Note: To remove an admin, use ./script/revoke-admin.sh"
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
        --new-admin)
            NEW_ADMIN="$2"
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

if [ -z "$NEW_ADMIN" ]; then
    echo -e "${RED}Error: --new-admin is required${NC}"
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

echo -e "${BLUE}Running safety validations...${NC}"
echo ""

# Validate address formats
validate_address "$FACTORY" "factory" || exit 1
validate_address "$NEW_ADMIN" "new admin" || exit 1

# Check for zero address (CRITICAL)
if is_zero_address "$NEW_ADMIN"; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ERROR: Cannot grant admin to zero address!${NC}"
    echo -e "${RED}========================================${NC}"
    echo "The zero address (0x0000...0000) cannot execute transactions."
    echo "Granting admin to this address serves no purpose."
    echo ""
    echo "Please check your command and try again with a valid address."
    exit 1
fi

# Check if factory and new admin are the same
if [ "$FACTORY" == "$NEW_ADMIN" ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ERROR: Factory and new admin are the same address!${NC}"
    echo -e "${RED}========================================${NC}"
    echo "The factory contract cannot be an admin of itself."
    echo "This is likely a copy-paste error."
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
# DISPLAY GRANT INFORMATION
# ============================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Grant Factory Admin Role${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Network: $NETWORK"
echo "RPC URL: $RPC_URL"
echo ""
echo "Grant Details:"
echo "  Factory:   $FACTORY"
echo "  New Admin: $NEW_ADMIN"
echo ""
echo -e "${BLUE}What this does:${NC}"
echo "  ✅ Grants DEFAULT_ADMIN_ROLE to new address"
echo "  ✅ You keep your admin role"
echo "  ✅ Both addresses will have admin access"
echo "  ✅ Low-risk operation (only adds, never removes)"
echo ""
echo -e "${BLUE}After this operation:${NC}"
echo "  - New admin can create vesting wallets"
echo "  - New admin can upgrade implementations"
echo "  - New admin can grant/revoke admin roles"
echo "  - You retain all admin permissions"
echo ""

# ============================================
# CONFIRMATION
# ============================================

read -p "Proceed with granting admin role? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Admin grant cancelled${NC}"
    exit 0
fi

# ============================================
# EXECUTE GRANT
# ============================================

echo ""
echo -e "${GREEN}Granting admin role...${NC}"
echo ""

forge script script/GrantFactoryAdmin.s.sol:GrantFactoryAdmin \
    --broadcast \
    --rpc-url "$RPC_URL" \
    --sig "run(address,address)" \
    "$FACTORY" \
    "$NEW_ADMIN"

GRANT_STATUS=$?

# ============================================
# POST-EXECUTION VERIFICATION
# ============================================

if [ $GRANT_STATUS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ Admin role granted successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "New admin has been granted DEFAULT_ADMIN_ROLE"
    echo ""
    echo "Current admins:"
    echo "  - Your address (original admin)"
    echo "  - $NEW_ADMIN (newly granted)"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Verify new admin can access factory:"
    echo "   cast call $FACTORY \"hasRole(bytes32,address)\" \\"
    echo "     0x0000000000000000000000000000000000000000000000000000000000000000 \\"
    echo "     $NEW_ADMIN --rpc-url $RPC_URL"
    echo ""
    echo "2. Test new admin can create wallets (if needed)"
    echo ""
    echo "3. If you want to remove your admin access later:"
    echo "   ./script/revoke-admin.sh --factory $FACTORY --admin <YOUR_ADDRESS>"
    echo ""
    echo -e "${GREEN}========================================${NC}"
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}❌ Admin grant FAILED${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Exit code: $GRANT_STATUS${NC}"
    echo ""
    echo "Possible reasons:"
    echo "  1. Caller does not have admin role"
    echo "  2. New admin already has admin role"
    echo "  3. Factory address is incorrect"
    echo "  4. Gas limit exceeded"
    echo "  5. Network connectivity issues"
    echo ""
    echo "No changes have been made to the factory."
    exit $GRANT_STATUS
fi
