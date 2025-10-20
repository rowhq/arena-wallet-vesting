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
    echo "Arena Vesting Wallet Factory Admin Transfer Script (SAFE VERSION)"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script transfers the DEFAULT_ADMIN_ROLE to a new address with safety checks."
    echo ""
    echo "Required arguments:"
    echo "  --factory ADDRESS         Factory contract address"
    echo "  --new-admin ADDRESS       New admin address"
    echo ""
    echo "Optional arguments:"
    echo "  --revoke-from-caller      Revoke admin role from the caller (full transfer)"
    echo "  --network NETWORK         Network: mainnet|fuji (default: fuji)"
    echo "  --rpc-url URL            Custom RPC URL (overrides network selection)"
    echo "  --private-key KEY        Private key (alternative to PRIVATE_KEY env var)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  PRIVATE_KEY              Private key of current admin (required if not using --private-key)"
    echo ""
    echo "Examples:"
    echo "  # Grant admin to new address (both have admin)"
    echo "  $0 --factory 0x123... --new-admin 0x456... --network mainnet"
    echo ""
    echo "  # Transfer admin completely (only new admin has control)"
    echo "  $0 --factory 0x123... --new-admin 0x456... --revoke-from-caller --network mainnet"
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
        return 0  # True, is zero address
    fi
    return 1  # False, not zero address
}

# Default values
NETWORK="fuji"
CUSTOM_RPC=""
PRIVATE_KEY_ARG=""
REVOKE_FROM_CALLER=false

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
        --revoke-from-caller)
            REVOKE_FROM_CALLER=true
            shift
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
    echo -e "${RED}CRITICAL ERROR: Cannot transfer to zero address!${NC}"
    echo -e "${RED}========================================${NC}"
    echo "The zero address (0x0000...0000) is a black hole."
    echo "Transferring admin to this address will PERMANENTLY BRICK the factory."
    echo ""
    echo "Please check your command and try again with a valid address."
    exit 1
fi

# Check if factory and new admin are the same (unlikely but possible mistake)
if [ "$FACTORY" == "$NEW_ADMIN" ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ERROR: Factory and new admin are the same address!${NC}"
    echo -e "${RED}========================================${NC}"
    echo "This is likely a copy-paste error."
    echo "Please verify your addresses and try again."
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
# DISPLAY TRANSFER INFORMATION
# ============================================

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Factory Admin Transfer${NC}"
echo -e "${YELLOW}========================================${NC}"
echo "Network: $NETWORK"
echo "RPC URL: $RPC_URL"
echo ""
echo "Transfer Details:"
echo "  Factory:            $FACTORY"
echo "  New Admin:          $NEW_ADMIN"
echo "  Revoke from caller: $REVOKE_FROM_CALLER"
echo ""

# ============================================
# CRITICAL WARNINGS
# ============================================

if [ "$NETWORK" = "mainnet" ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}⚠️  MAINNET DEPLOYMENT WARNING ⚠️${NC}"
    echo -e "${RED}========================================${NC}"
    echo "You are about to transfer admin control on MAINNET."
    echo "This operation is IRREVERSIBLE if --revoke-from-caller is used."
    echo ""
fi

if [ "$REVOKE_FROM_CALLER" = true ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}⚠️  FULL TRANSFER WARNING ⚠️${NC}"
    echo -e "${RED}========================================${NC}"
    echo "You are about to REVOKE your own admin access!"
    echo ""
    echo "After this transaction:"
    echo "  ❌ You will NO LONGER have admin control"
    echo "  ✅ Only the new admin will have control"
    echo ""
    echo "Make sure you have:"
    echo "  1. Verified the new admin address is CORRECT"
    echo "  2. Confirmed the new admin can access their wallet"
    echo "  3. Tested this process on testnet first"
    echo ""
    echo -e "${RED}THIS CANNOT BE UNDONE WITHOUT THE NEW ADMIN'S COOPERATION!${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
else
    echo -e "${YELLOW}Note: Both you and the new admin will have admin access.${NC}"
    echo -e "${YELLOW}Use --revoke-from-caller to fully transfer control.${NC}"
    echo ""
fi

# ============================================
# MANUAL CONFIRMATION
# ============================================

echo -e "${YELLOW}Please verify the following addresses are correct:${NC}"
echo "Factory:  $FACTORY"
echo "New Admin: $NEW_ADMIN"
echo ""

if [ "$REVOKE_FROM_CALLER" = true ]; then
    echo -e "${RED}Type 'I UNDERSTAND THE RISKS' to proceed with full transfer:${NC}"
    read -r CONFIRMATION
    if [[ "$CONFIRMATION" != "I UNDERSTAND THE RISKS" ]]; then
        echo -e "${YELLOW}Admin transfer cancelled${NC}"
        exit 0
    fi
else
    read -p "Proceed with admin transfer? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Admin transfer cancelled${NC}"
        exit 0
    fi
fi

# ============================================
# EXECUTE TRANSFER
# ============================================

echo ""
echo -e "${GREEN}Transferring admin role...${NC}"
echo ""

# Use the SAFE version of the script
forge script script/TransferFactoryAdmin.SAFE.s.sol:TransferFactoryAdminSafe \
    --broadcast \
    --rpc-url "$RPC_URL" \
    --sig "run(address,address,bool)" \
    "$FACTORY" \
    "$NEW_ADMIN" \
    "$REVOKE_FROM_CALLER"

TRANSFER_STATUS=$?

# ============================================
# POST-EXECUTION VERIFICATION
# ============================================

if [ $TRANSFER_STATUS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ Admin transfer successful!${NC}"
    echo -e "${GREEN}========================================${NC}"

    if [ "$REVOKE_FROM_CALLER" = true ]; then
        echo -e "${GREEN}New admin now has exclusive control of the factory.${NC}"
        echo ""
        echo -e "${YELLOW}IMPORTANT: Verify the new admin can access the factory:${NC}"
        echo "1. Ask new admin to call: factory.hasRole(DEFAULT_ADMIN_ROLE, theirAddress)"
        echo "2. Should return: true"
        echo ""
        echo "If verification fails, contact new admin IMMEDIATELY."
    else
        echo -e "${YELLOW}Both addresses now have admin access.${NC}"
        echo ""
        echo "To fully transfer control later, run:"
        echo "./script/transfer-admin.SAFE.sh \\"
        echo "  --factory $FACTORY \\"
        echo "  --new-admin $NEW_ADMIN \\"
        echo "  --revoke-from-caller \\"
        echo "  --network $NETWORK"
    fi

    echo ""
    echo -e "${GREEN}========================================${NC}"
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}❌ Admin transfer FAILED${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Exit code: $TRANSFER_STATUS${NC}"
    echo ""
    echo "Possible reasons:"
    echo "  1. Caller does not have admin role"
    echo "  2. Factory address is incorrect"
    echo "  3. Gas limit exceeded"
    echo "  4. Network connectivity issues"
    echo ""
    echo "Your admin access has NOT been changed."
    echo "It is safe to retry after fixing the issue."
    exit $TRANSFER_STATUS
fi
