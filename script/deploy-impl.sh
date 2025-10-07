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
    echo "Arena Vesting Wallet Implementation Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script deploys the ArenaVestingWallet implementation contract."
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
    echo "  $0 --network fuji"
    echo "  $0 --network mainnet --verify"
}

# Default values
NETWORK="fuji"
VERIFY=false
CUSTOM_RPC=""
PRIVATE_KEY_ARG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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
echo -e "${YELLOW}Arena Vesting Wallet Implementation Deployment${NC}"
echo "=============================================="
echo "Network: $NETWORK"
echo "RPC URL: $RPC_URL"
echo ""

# Confirm deployment
read -p "Proceed with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# Run forge script
echo -e "${GREEN}Starting deployment...${NC}"

# Run the deployment and capture output
OUTPUT=$(forge script script/DeployImplementation.s.sol:DeployImplementation \
    --broadcast \
    --rpc-url "$RPC_URL" \
    2>&1)

DEPLOYMENT_STATUS=$?

# Display the output
echo "$OUTPUT"

if [ $DEPLOYMENT_STATUS -eq 0 ]; then
    echo -e "${GREEN}Deployment successful!${NC}"
    
    # Extract the deployed address from the output
    IMPLEMENTATION_ADDRESS=$(echo "$OUTPUT" | grep -oE "ArenaVestingWallet implementation at: 0x[a-fA-F0-9]{40}" | grep -oE "0x[a-fA-F0-9]{40}")
    
    if [ -n "$IMPLEMENTATION_ADDRESS" ]; then
        echo ""
        echo -e "${GREEN}Implementation deployed at: ${YELLOW}$IMPLEMENTATION_ADDRESS${NC}"
        echo ""
    fi
    
    # TODO: Add verification logic if --verify flag is set
    if [ "$VERIFY" = true ]; then
        echo -e "${YELLOW}Contract verification not implemented yet${NC}"
    fi
else
    echo -e "${RED}Deployment failed with exit code $DEPLOYMENT_STATUS${NC}"
    exit $DEPLOYMENT_STATUS
fi