#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default RPC URLs
AVALANCHE_MAINNET_RPC="https://api.avax.network/ext/bc/C/rpc"
AVALANCHE_FUJI_RPC="https://api.avax-test.network/ext/bc/C/rpc"

# Help function
show_help() {
    echo "Arena Vesting Wallet Factory Admin Transfer Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script transfers the DEFAULT_ADMIN_ROLE to a new address."
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

# Display transfer information
echo -e "${YELLOW}Factory Admin Transfer${NC}"
echo "======================"
echo "Network: $NETWORK"
echo "RPC URL: $RPC_URL"
echo ""
echo "Parameters:"
echo "  Factory: $FACTORY"
echo "  New Admin: $NEW_ADMIN"
echo "  Revoke from caller: $REVOKE_FROM_CALLER"
echo ""

if [ "$REVOKE_FROM_CALLER" = true ]; then
    echo -e "${RED}WARNING: You will lose admin access after this operation!${NC}"
    echo -e "${RED}Only the new admin will be able to manage the factory.${NC}"
else
    echo -e "${YELLOW}Note: Both you and the new admin will have admin access.${NC}"
    echo -e "${YELLOW}Use --revoke-from-caller to fully transfer control.${NC}"
fi

echo ""

# Confirm transfer
read -p "Proceed with admin transfer? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Admin transfer cancelled${NC}"
    exit 0
fi

# Run forge script
echo -e "${GREEN}Transferring admin role...${NC}"

forge script script/TransferFactoryAdmin.s.sol:TransferFactoryAdmin \
    --broadcast \
    --rpc-url "$RPC_URL" \
    --sig "run(address,address,bool)" \
    "$FACTORY" \
    "$NEW_ADMIN" \
    "$REVOKE_FROM_CALLER"

TRANSFER_STATUS=$?

if [ $TRANSFER_STATUS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}Admin transfer successful!${NC}"

    if [ "$REVOKE_FROM_CALLER" = true ]; then
        echo -e "${GREEN}New admin now has exclusive control of the factory.${NC}"
    else
        echo -e "${YELLOW}Both addresses now have admin access.${NC}"
    fi
else
    echo -e "${RED}Admin transfer failed with exit code $TRANSFER_STATUS${NC}"
    exit $TRANSFER_STATUS
fi
