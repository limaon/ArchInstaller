#!/usr/bin/env bash
#
# @file fix-swap.sh
# @brief Fix swap file configuration issues
# @description Run this script to fix swap file problems after installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  Swap File Fix Script"
echo "=========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Detect filesystem type
FS_TYPE=$(df -T / | awk 'NR==2 {print $2}')
echo "Detected filesystem: $FS_TYPE"

# Get swap size from user or use default
read -rp "Enter swap file size in GB (default: 4): " SWAP_SIZE_GB
SWAP_SIZE_GB=${SWAP_SIZE_GB:-4}

echo ""
echo "Removing existing swap configuration..."

# Deactivate swap file if active
swapoff /swapfile 2>/dev/null || true

# Remove swap file
rm -f /swapfile

# Remove from fstab
sed -i '/\/swapfile/d' /etc/fstab

# Remove systemd swap units
systemctl stop swapfile.swap 2>/dev/null || true
systemctl disable swapfile.swap 2>/dev/null || true
rm -f /etc/systemd/system/swapfile.swap 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

echo ""
echo "Creating new swap file (${SWAP_SIZE_GB}GB)..."

# Create swap file using modern method (per ArchWiki)
if [[ "$FS_TYPE" == "btrfs" ]]; then
    echo "Using Btrfs-specific method..."
    mkswap -U clear --size ${SWAP_SIZE_GB}G --file /swapfile
    chmod 600 /swapfile
    chattr +C /swapfile || true
    btrfs property set /swapfile compression none || true
else
    echo "Using standard method..."
    mkswap -U clear --size ${SWAP_SIZE_GB}G --file /swapfile
    chmod 600 /swapfile
fi

# Verify swap file was created
if [[ -f /swapfile ]]; then
    echo -e "${GREEN}✓ Swap file created successfully${NC}"

    # Activate swap file
    if swapon /swapfile; then
        echo -e "${GREEN}✓ Swap file activated${NC}"
    else
        echo -e "${YELLOW}⚠ Could not activate swap file${NC}"
    fi

    # Add to fstab
    echo "/swapfile none swap defaults 0 0" >> /etc/fstab
    echo -e "${GREEN}✓ Added to /etc/fstab${NC}"

    # Show swap status
    echo ""
    echo "Swap status:"
    swapon --show
    free -h | grep Swap

    echo ""
    echo -e "${GREEN}Swap file fixed successfully!${NC}"
else
    echo -e "${RED}✗ Error: Swap file was not created${NC}"
    exit 1
fi

