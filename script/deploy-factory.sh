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
    echo "Arena Vesting Wallet Factory Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script deploys the ArenaVestingWalletFactory with UUPS proxy pattern."
    echo ""
    echo "Required arguments:"
    echo "  --implementation ADDRESS    ArenaVestingWallet implementation address"
    echo ""
    echo "Optional arguments:"
    echo "  --network NETWORK           Network to deploy to: mainnet|fuji (default: fuji)"
    echo "  --rpc-url URL              Custom RPC URL (overrides network selection)"
    echo "  --private-key KEY          Private key (alternative to PRIVATE_KEY env var)"
    echo "  --verify                   Verify contract after deployment"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  PRIVATE_KEY                Deployment private key (required if not using --private-key)"
    echo ""
    echo "Example:"
    echo "  $0 --implementation 0xa3Eb4218246CD3160adce88b25595BD059C6644A --network mainnet"
}

# Default values
NETWORK="fuji"
VERIFY=false
CUSTOM_RPC=""
PRIVATE_KEY_ARG=""
IMPLEMENTATION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --implementation)
            IMPLEMENTATION="$2"
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
if [ -z "$IMPLEMENTATION" ]; then
    echo -e "${RED}Error: --implementation is required${NC}"
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
echo -e "${YELLOW}Arena Vesting Wallet Factory Deployment${NC}"
echo "========================================"
echo "Network: $NETWORK"
echo "RPC URL: $RPC_URL"
echo "Wallet Implementation: $IMPLEMENTATION"
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
OUTPUT=$(forge script script/DeployFactory.s.sol:DeployFactory \
    --broadcast \
    --rpc-url "$RPC_URL" \
    --sig "run(address)" \
    "$IMPLEMENTATION" \
    2>&1)

DEPLOYMENT_STATUS=$?

# Display the output
echo "$OUTPUT"

if [ $DEPLOYMENT_STATUS -eq 0 ]; then
    echo -e "${GREEN}Deployment successful!${NC}"

    # Extract the factory proxy address from the output
    FACTORY_ADDRESS=$(echo "$OUTPUT" | grep -oE "Factory Proxy deployed at:\s+0x[a-fA-F0-9]{40}" | grep -oE "0x[a-fA-F0-9]{40}")

    if [ -n "$FACTORY_ADDRESS" ]; then
        echo ""
        echo -e "${GREEN}==================================================${NC}"
        echo -e "${GREEN}Factory deployed at: ${YELLOW}$FACTORY_ADDRESS${NC}"
        echo -e "${GREEN}==================================================${NC}"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Create vesting wallets using: ./script/create-via-factory.sh"
        echo "2. Transfer admin role using: ./script/transfer-admin.sh"
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
