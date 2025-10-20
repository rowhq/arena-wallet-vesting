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
    echo "Arena Vesting Wallet Creation Script (via Factory)"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required arguments:"
    echo "  --factory ADDRESS         Factory contract address"
    echo "  --beneficiary ADDRESS     Beneficiary address for vesting"
    echo "  --start TIMESTAMP         Start timestamp (Unix timestamp)"
    echo "  --cliff DURATION          Cliff duration in seconds"
    echo "  --interval DURATION       Interval duration in seconds"
    echo "  --intervals NUMBER        Number of vesting intervals"
    echo ""
    echo "Optional arguments:"
    echo "  --network NETWORK         Network to deploy to: mainnet|fuji (default: fuji)"
    echo "  --rpc-url URL            Custom RPC URL (overrides network selection)"
    echo "  --private-key KEY        Private key (alternative to PRIVATE_KEY env var)"
    echo "  --verify                 Verify contract after deployment"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  PRIVATE_KEY             Deployment private key (required if not using --private-key)"
    echo ""
    echo "Example:"
    echo "  $0 --factory 0x123... --beneficiary 0x789... \\"
    echo "     --start 1704067200 --cliff 7776000 --interval 2592000 --intervals 12 \\"
    echo "     --network mainnet"
}

# Default values
NETWORK="fuji"
VERIFY=false
CUSTOM_RPC=""
PRIVATE_KEY_ARG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --factory)
            FACTORY="$2"
            shift 2
            ;;
        --beneficiary)
            BENEFICIARY="$2"
            shift 2
            ;;
        --start)
            START="$2"
            shift 2
            ;;
        --cliff)
            CLIFF="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --intervals)
            INTERVALS="$2"
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
        --verify)
            VERIFY=true
            shift
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

if [ -z "$BENEFICIARY" ]; then
    echo -e "${RED}Error: --beneficiary is required${NC}"
    MISSING_ARGS=true
fi

if [ -z "$START" ]; then
    echo -e "${RED}Error: --start is required${NC}"
    MISSING_ARGS=true
fi

if [ -z "$CLIFF" ]; then
    echo -e "${RED}Error: --cliff is required${NC}"
    MISSING_ARGS=true
fi

if [ -z "$INTERVAL" ]; then
    echo -e "${RED}Error: --interval is required${NC}"
    MISSING_ARGS=true
fi

if [ -z "$INTERVALS" ]; then
    echo -e "${RED}Error: --intervals is required${NC}"
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

# Display deployment information
echo -e "${YELLOW}Arena Vesting Wallet Creation (via Factory)${NC}"
echo "============================================"
echo "Network: $NETWORK"
echo "RPC URL: $RPC_URL"
echo ""
echo "Parameters:"
echo "  Factory: $FACTORY"
echo "  Beneficiary: $BENEFICIARY"
echo "  Start Time: $START ($(date -r $START 2>/dev/null || echo 'Invalid timestamp'))"
echo "  Cliff Duration: $CLIFF seconds"
echo "  Interval Duration: $INTERVAL seconds"
echo "  Number of Intervals: $INTERVALS"
echo ""

# Confirm deployment
read -p "Proceed with wallet creation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Wallet creation cancelled${NC}"
    exit 0
fi

# Run forge script
echo -e "${GREEN}Creating vesting wallet...${NC}"

OUTPUT=$(forge script script/CreateVestingWallet.s.sol:CreateVestingWallet \
    --broadcast \
    --rpc-url "$RPC_URL" \
    --sig "run(address,address,uint64,uint64,uint64,uint64)" \
    "$FACTORY" \
    "$BENEFICIARY" \
    "$START" \
    "$CLIFF" \
    "$INTERVAL" \
    "$INTERVALS" \
    2>&1)

DEPLOYMENT_STATUS=$?

# Display the output
echo "$OUTPUT"

if [ $DEPLOYMENT_STATUS -eq 0 ]; then
    echo -e "${GREEN}Wallet creation successful!${NC}"

    # Extract the wallet address from the output
    WALLET_ADDRESS=$(echo "$OUTPUT" | grep -oE "Vesting Wallet created at: 0x[a-fA-F0-9]{40}" | grep -oE "0x[a-fA-F0-9]{40}")

    if [ -n "$WALLET_ADDRESS" ]; then
        echo ""
        echo -e "${GREEN}==================================================${NC}"
        echo -e "${GREEN}Vesting Wallet: ${YELLOW}$WALLET_ADDRESS${NC}"
        echo -e "${GREEN}==================================================${NC}"
        echo ""
        echo -e "${YELLOW}Next step: Deposit ARENA tokens${NC}"
        echo "Call deposit() on the wallet address above"
        echo ""
    fi

    # TODO: Add verification logic if --verify flag is set
    if [ "$VERIFY" = true ]; then
        echo -e "${YELLOW}Contract verification not implemented yet${NC}"
    fi
else
    echo -e "${RED}Wallet creation failed with exit code $DEPLOYMENT_STATUS${NC}"
    exit $DEPLOYMENT_STATUS
fi
