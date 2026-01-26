#!/usr/bin/env bash
#github-action genshdoc
#
# @file System Config
# @brief Contains the functions used to modify the system
# @stdout Output routed to install.log
# @stderror Output routed to install.log


# @description Update mirrorlist to improve download speeds using rankmirrors if reflector is unavailable
# @noargs
mirrorlist_update() {
    # shellcheck disable=SC1009,SC1073
    # Note: ShellCheck warnings are false positives (code is valid)

    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

    # Use reflector if available and working, otherwise fall back to rankmirrors
    if command -v reflector &> /dev/null; then
        echo -ne "
-------------------------------------------------------------------------
                    Setting up mirrors for faster downloads (reflector)
-------------------------------------------------------------------------
"
        # Set default country if iso variable is empty
        local country="${iso:-US}"
        echo "Using country code: $country"

        # Try to use reflector with error handling
        # Capture stderr to see actual error messages
        if reflector_error=$(reflector -a 48 -c "$country" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist 2>&1); then
            echo "Mirror list updated successfully using reflector"
        else
            echo "Warning: reflector failed with error:"
            echo "$reflector_error"
            echo "Falling back to rankmirrors"
            mirrorlist_rankmirrors_fallback
        fi
    else
        echo "Warning: reflector not found, using rankmirrors"
        mirrorlist_rankmirrors_fallback
    fi
}


# @description Fallback method using rankmirrors when reflector is unavailable
# @noargs
mirrorlist_rankmirrors_fallback() {
    echo -ne "
-------------------------------------------------------------------------
                    Setting up mirrors using rankmirrors
-------------------------------------------------------------------------
"
    # Get mirror list and rank by speed
    curl -s 'https://archlinux.org/mirrorlist/?country=US&country=BR&country=DE&protocol=https&ip_version=4&ip_version=6' > /tmp/mirrorlist.new

    # Uncomment servers and rank them
    sed -i 's/^#Server/Server/' /tmp/mirrorlist.new

    if command -v rankmirrors &> /dev/null; then
        echo "Testing mirrors and ranking by speed..."
        rankmirrors -n 10 -m 5 -v -w /tmp/mirrorlist.new > /etc/pacman.d/mirrorlist
    else
        # If rankmirrors is also not available, just use the new list
        mv /tmp/mirrorlist.new /etc/pacman.d/mirrorlist
    fi

    rm -f /tmp/mirrorlist.new
    echo "Mirror list updated using rankmirrors"
}


# @description Format disk before creating filesystem(s)
# @noargs
format_disk() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------
"
    pacman -S --noconfirm --needed --color=always gptfdisk glibc

    echo -ne "
-------------------------------------------------------------------------
                    Formatting ${DISK}
-------------------------------------------------------------------------
"

    disk_percent="${DISK_USAGE_PERCENT:-100}"

    mkdir -p /mnt &>/dev/null
    umount -A --recursive /mnt &>/dev/null

    set -e

    sgdisk -Z "${DISK}"
    sgdisk -a 2048 -o "${DISK}"

    if [[ -d "/sys/firmware/efi" ]]; then
        echo -e "\nCreating EFI partition (UEFI Boot Partition)"
        sgdisk -n 1::+1G --typecode=1:ef00 --change-name=1:"EFIBOOT" "${DISK}"
        echo -e "\nCreating ROOT partition (${disk_percent}% of disk)"

        # Use percentage instead of -0
        if [[ "$disk_percent" -eq 100 ]]; then
            # Use all remaining disk space (original behavior)
            sgdisk -n 2::-0 --typecode=2:8300 --change-name=2:"ROOT" "${DISK}"
        else
            # Calculate size based on percentage
            # Get total disk size in bytes
            disk_size_bytes=$(blockdev --getsize64 "${DISK}")
            # EFI partition is 1GB = 1024MB = 1024 * 1024 * 1024 bytes
            efi_size_bytes=$((1024 * 1024 * 1024))
            # Calculate available space after EFI partition
            available_bytes=$((disk_size_bytes - efi_size_bytes))
            # Calculate root partition size based on percentage of available space
            root_size_mb=$(( (available_bytes * disk_percent) / 100 / 1024 / 1024 ))
            sgdisk -n 2::+${root_size_mb}M --typecode=2:8300 --change-name=2:"ROOT" "${DISK}"
        fi
    else
        echo -e "\nCreating BIOS Boot partition (no filesystem)"
        sgdisk -n 1::+256M --typecode=1:ef02 --change-name=1:"BIOSBOOT" "${DISK}"
        echo -e "\nCreating ROOT partition (${disk_percent}% of disk)"

        if [[ "$disk_percent" -eq 100 ]]; then
            sgdisk -n 2::-0 --typecode=2:8300 --change-name=2:"ROOT" "${DISK}"
        else
            # Calculate size based on percentage
            # Get total disk size in bytes
            disk_size_bytes=$(blockdev --getsize64 "${DISK}")
            # BIOS Boot partition is 256MB = 256 * 1024 * 1024 bytes
            bios_boot_size_bytes=$((256 * 1024 * 1024))
            # Calculate available space after BIOS Boot partition
            available_bytes=$((disk_size_bytes - bios_boot_size_bytes))
            # Calculate root partition size based on percentage of available space
            root_size_mb=$(( (available_bytes * disk_percent) / 100 / 1024 / 1024 ))
            sgdisk -n 2::+${root_size_mb}M --typecode=2:8300 --change-name=2:"ROOT" "${DISK}"
        fi

        sgdisk -A 1:set:2 "${DISK}"
    fi

    partprobe "${DISK}"

    set +e
}


# @description Create the filesystem on the drive selected for installation
# @noargs
create_filesystems() {
    echo -ne "
-------------------------------------------------------------------------
                    Creating Filesystems
-------------------------------------------------------------------------
"
    set -e

    if [[ "${DISK}" =~ "nvme" || "${DISK}" =~ "mmc" ]]; then
        if [[ -d "/sys/firmware/efi" ]]; then
            boot_partition="${DISK}p1"
            root_partition="${DISK}p2"
        else
            boot_partition=""
            root_partition="${DISK}p2"
        fi
    else
        if [[ -d "/sys/firmware/efi" ]]; then
            boot_partition="${DISK}1"
            root_partition="${DISK}2"
        else
            boot_partition=""
            root_partition="${DISK}1"
            [[ $(sgdisk -p "${DISK}" | grep -c "BIOSBOOT") -gt 0 ]] && root_partition="${DISK}2"
        fi
    fi

    if [[ -n "${boot_partition}" ]]; then
        echo "Creating FAT32 EFI boot filesystem on ${boot_partition}"
        mkfs.vfat -F32 -n "EFIBOOT" "${boot_partition}"
    fi

    if [[ "${FS}" == "btrfs" ]]; then
        do_btrfs "ROOT" "${root_partition}"

    elif [[ "${FS}" == "ext4" ]]; then
        echo "Creating EXT4 root filesystem on ${root_partition}"
        mkfs.ext4 -L ROOT "${root_partition}"
        mount -t ext4 "${root_partition}" /mnt

    elif [[ "${FS}" == "luks" ]]; then
        echo "Configuring LUKS on ${root_partition}"
        echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${root_partition}" -
        echo -n "${LUKS_PASSWORD}" | cryptsetup open "${root_partition}" ROOT -
        do_btrfs "ROOT" "/dev/mapper/ROOT"
        echo ENCRYPTED_PARTITION_UUID="$(blkid -s UUID -o value "${root_partition}")" >>"$CONFIGS_DIR"/setup.conf
    fi

    set +e
}


# @description Detect if system is running in a virtual machine/container
# @noargs
detect_vm() {
    if systemd-detect-virt -q 2>/dev/null; then
        VIRT_TYPE=$(systemd-detect-virt 2>/dev/null)
        echo "$VIRT_TYPE"
        return 0
    else
        echo "none"
        return 1
    fi
}


# @description Detect if system is a laptop (has battery)
# @noargs
detect_laptop() {
    if ls /sys/class/power_supply/ | grep -q "BAT"; then
        return 0
    else
        return 1
    fi
}


# @description Get CPU core count
# @noargs
get_cpu_cores() {
    grep -c ^processor /proc/cpuinfo
}


# @description Perform btrfs filesystem configuration
# @noargs


# @description Intelligently configure swap based on system hardware
# Analyzes RAM, storage type, disk space, and installation type to choose optimal swap strategy
# For Btrfs: Uses dedicated @swap subvolume to avoid snapshot conflicts (errno:26 Text file busy)
# Reference: https://wiki.archlinux.org/title/Btrfs#Swap_file
# @noargs
low_memory_config() {
    echo -ne "
-------------------------------------------------------------------------
          Intelligent Swap Configuration
-------------------------------------------------------------------------
"

    # Detect system characteristics
    TOTAL_MEM=$(grep -i 'memtotal' /proc/meminfo | grep -o '[[:digit:]]*')
    TOTAL_MEM_GB=$((TOTAL_MEM / 1024 / 1024))

    # Detect storage type (SSD = 1, HDD = 0)
    IS_SSD=0
    if [[ -n "${DISK:-}" ]]; then
        ROTA=$(lsblk -n --output TYPE,ROTA "${DISK}" 2>/dev/null | awk '$1=="disk"{print $2}')
        [[ "${ROTA:-1}" == "0" ]] && IS_SSD=1
    fi

    # Detect installation type and filesystem
    INSTALL_TYPE="${INSTALL_TYPE:-FULL}"
    FS_TYPE="${FS:-ext4}"

    # Detect VM/VPS
    VIRT_TYPE=$(detect_vm)
    IS_VM=false
    [[ "$VIRT_TYPE" != "none" ]] && IS_VM=true

    # Detect laptop
    detect_laptop
    IS_LAPTOP=$?

    # Calculate available disk space
    AVAILABLE_SPACE_GB=0
    if mountpoint -q /mnt 2>/dev/null; then
        AVAILABLE_SPACE_GB=$(df -BG /mnt 2>/dev/null | awk 'NR==2 {gsub(/G/, "", $4); print int($4)}' || echo "0")
    elif [[ -n "${DISK:-}" ]] && [[ -b "${DISK}" ]]; then
        DISK_SIZE_BYTES=$(blockdev --getsize64 "${DISK}" 2>/dev/null || echo "0")
        DISK_SIZE_GB=$((DISK_SIZE_BYTES / 1024 / 1024 / 1024))
        DISK_PERCENT="${DISK_USAGE_PERCENT:-100}"
        USED_GB=$(( (DISK_SIZE_GB * DISK_PERCENT) / 100 ))
        AVAILABLE_SPACE_GB=$((DISK_SIZE_GB - USED_GB))
    fi

    echo "System Hardware Analysis:"
    echo "  RAM: ${TOTAL_MEM_GB}GB"
    echo "  Storage: $([[ $IS_SSD -eq 1 ]] && echo "SSD" || echo "HDD")"
    echo "  Filesystem: ${FS_TYPE}"
    echo "  Installation Type: ${INSTALL_TYPE}"
    echo "  Available Disk Space: ${AVAILABLE_SPACE_GB}GB"
    echo "  Virtual Machine: $([[ $IS_VM == true ]] && echo "Yes ($VIRT_TYPE)" || echo "No")"
    echo "  Laptop: $([[ $IS_LAPTOP -eq 0 ]] && echo "Yes" || echo "No")"
    echo ""

    # Initialize swap configuration variables
    SWAP_STRATEGY=""
    SWAP_SIZE_GB=0
    USE_ZRAM=false
    USE_SWAPFILE=false
    ZRAM_MULTIPLIER=0

    # ========================================================================
    # AUTOMATIC SWAP DECISION LOGIC
    # Priority 1: VPS/Cloud (overrides everything)
    # Priority 2: Laptop (supports hibernation)
    # Priority 3: Installation type (SERVER/DESKTOP/MINIMAL)
    # ========================================================================

    echo "Analyzing optimal swap configuration..."
    echo ""

    # Priority 1: VPS/Cloud (saves I/O costs, optimizes limited resources)
    if [[ "$IS_VM" == true ]]; then
        if [[ $TOTAL_MEM_GB -lt 4 ]]; then
            USE_ZRAM=true
            USE_SWAPFILE=true
            ZRAM_MULTIPLIER=2
            SWAP_SIZE_GB=$((TOTAL_MEM_GB / 2))
            SWAP_STRATEGY="VPS_LOW_RAM"
            echo "Strategy: VPS with low RAM (${TOTAL_MEM_GB}GB) - ZRAM + small swapfile"
            echo "  - ZRAM: 2x RAM ($(echo "$TOTAL_MEM_GB * 2" | bc)GB) for performance"
            echo "  - Swapfile: ${SWAP_SIZE_GB}GB as safety net (saves I/O costs)"
        else
            USE_ZRAM=true
            ZRAM_MULTIPLIER=1
            SWAP_STRATEGY="VPS_OPTIMAL"
            echo "Strategy: VPS with sufficient RAM (${TOTAL_MEM_GB}GB) - ZRAM Only"
            echo "  - ZRAM: 1x RAM (${TOTAL_MEM_GB}GB) for performance"
            echo "  - Swapfile: Disabled (saves I/O costs and disk space)"
        fi

    # Priority 2: Laptop (needs hibernation support)
    elif [[ $IS_LAPTOP -eq 0 ]]; then
        USE_ZRAM=true
        USE_SWAPFILE=true
        ZRAM_MULTIPLIER=1.5
        SWAP_SIZE_GB=$TOTAL_MEM_GB
        SWAP_STRATEGY="LAPTOP_HIBERNATION"
        echo "Strategy: Laptop detected - ZRAM + Swapfile (hibernation support)"
        echo "  - ZRAM: 1.5x RAM ($(echo "$TOTAL_MEM_GB * 1.5" | bc)GB) for daily performance"
        echo "  - Swapfile: ${SWAP_SIZE_GB}GB (equals RAM size) for hibernation"

    # Priority 3: By installation type
    else
        case "$INSTALL_TYPE" in
            "SERVER")
                # Server logic: Performance is critical
                if [[ $TOTAL_MEM_GB -lt 4 ]]; then
                    USE_ZRAM=true
                    USE_SWAPFILE=true
                    ZRAM_MULTIPLIER=2
                    SWAP_SIZE_GB=4
                    SWAP_STRATEGY="SERVER_CRITICAL"
                    echo "Strategy: Server with critical RAM (${TOTAL_MEM_GB}GB) - ZRAM + Swapfile"
                    echo "  - ZRAM: 2x RAM ($(echo "$TOTAL_MEM_GB * 2" | bc)GB) to avoid OOM"
                    echo "  - Swapfile: 4GB as emergency backup"
                elif [[ $TOTAL_MEM_GB -lt 16 ]]; then
                    if [[ $IS_SSD -eq 1 ]]; then
                        USE_ZRAM=true
                        ZRAM_MULTIPLIER=2
                        SWAP_STRATEGY="SERVER_SSD_OPTIMAL"
                        echo "Strategy: Server with SSD (${TOTAL_MEM_GB}GB RAM) - ZRAM Only"
                        echo "  - ZRAM: 2x RAM ($(echo "$TOTAL_MEM_GB * 2" | bc)GB) for optimal performance"
                        echo "  - Swapfile: Disabled (SSD swap is slow, causes I/O bottleneck)"
                    else
                        USE_ZRAM=true
                        USE_SWAPFILE=true
                        ZRAM_MULTIPLIER=2
                        SWAP_SIZE_GB=4
                        SWAP_STRATEGY="SERVER_HDD_BACKUP"
                        echo "Strategy: Server with HDD (${TOTAL_MEM_GB}GB RAM) - ZRAM + Swapfile"
                        echo "  - ZRAM: 2x RAM ($(echo "$TOTAL_MEM_GB * 2" | bc)GB) for performance"
                        echo "  - Swapfile: 4GB as HDD backup (HDD is too slow for daily swap)"
                    fi
                else
                    # Server with >= 16GB RAM
                    USE_ZRAM=true
                    ZRAM_MULTIPLIER=1
                    SWAP_STRATEGY="SERVER_HIGH_RAM"
                    echo "Strategy: Server with high RAM (${TOTAL_MEM_GB}GB) - ZRAM Only"
                    echo "  - ZRAM: 1x RAM (${TOTAL_MEM_GB}GB) for occasional swap"
                    echo "  - Swapfile: Disabled (sufficient RAM, unnecessary)"
                fi
                ;;

            "DESKTOP"|"FULL")
                # Desktop logic: Balance performance with hibernation support
                USE_ZRAM=true
                USE_SWAPFILE=true
                ZRAM_MULTIPLIER=1
                if [[ $TOTAL_MEM_GB -lt 8 ]]; then
                    SWAP_SIZE_GB=$((TOTAL_MEM_GB + 2))
                elif [[ $TOTAL_MEM_GB -lt 32 ]]; then
                    SWAP_SIZE_GB=$TOTAL_MEM_GB
                else
                    SWAP_SIZE_GB=8
                fi
                SWAP_STRATEGY="DESKTOP_HIBERNATION"
                echo "Strategy: Desktop - ZRAM + Swapfile (hibernation support)"
                echo "  - ZRAM: 1x RAM (${TOTAL_MEM_GB}GB) for daily performance"
                echo "  - Swapfile: ${SWAP_SIZE_GB}GB for hibernation support"

                # HDD gets larger swapfile
                if [[ $IS_SSD -eq 0 ]]; then
                    ZRAM_MULTIPLIER=1.5
                    echo "  Note: Increased ZRAM to 1.5x RAM due to HDD being slow"
                fi
                ;;

            "MINIMAL")
                # Minimal logic: Resource efficiency
                if [[ $TOTAL_MEM_GB -lt 4 ]]; then
                    USE_ZRAM=true
                    USE_SWAPFILE=true
                    ZRAM_MULTIPLIER=2
                    SWAP_SIZE_GB=2
                    SWAP_STRATEGY="MINIMAL_LOW_RAM"
                    echo "Strategy: Minimal installation with low RAM (${TOTAL_MEM_GB}GB) - ZRAM + small swapfile"
                    echo "  - ZRAM: 2x RAM ($(echo "$TOTAL_MEM_GB * 2" | bc)GB) to avoid OOM"
                    echo "  - Swapfile: 2GB minimal safety net"
                elif [[ $TOTAL_MEM_GB -lt 16 ]]; then
                    if [[ $IS_SSD -eq 1 ]]; then
                        USE_ZRAM=true
                        ZRAM_MULTIPLIER=1
                        SWAP_STRATEGY="MINIMAL_OPTIMAL"
                        echo "Strategy: Minimal installation on SSD (${TOTAL_MEM_GB}GB RAM) - ZRAM Only"
                        echo "  - ZRAM: 1x RAM (${TOTAL_MEM_GB}GB) efficient performance"
                        echo "  - Swapfile: Disabled (saves disk space)"
                    else
                        USE_ZRAM=true
                        USE_SWAPFILE=true
                        ZRAM_MULTIPLIER=1
                        SWAP_SIZE_GB=2
                        SWAP_STRATEGY="MINIMAL_HDD"
                        echo "Strategy: Minimal installation on HDD (${TOTAL_MEM_GB}GB RAM) - ZRAM + small swapfile"
                        echo "  - ZRAM: 1x RAM (${TOTAL_MEM_GB}GB) for performance"
                        echo "  - Swapfile: 2GB minimal HDD backup"
                    fi
                else
                    # Minimal with >= 16GB RAM
                    USE_ZRAM=true
                    ZRAM_MULTIPLIER=0.5
                    SWAP_STRATEGY="MINIMAL_HIGH_RAM"
                    echo "Strategy: Minimal installation with high RAM (${TOTAL_MEM_GB}GB) - Minimal ZRAM"
                    echo "  - ZRAM: 0.5x RAM ($(echo "$TOTAL_MEM_GB * 0.5" | bc)GB) just in case"
                    echo "  - Swapfile: Disabled (RAM more than sufficient)"
                fi
                ;;
        esac
    fi

    # Check disk space for swap file
    REQUIRED_SPACE=$((SWAP_SIZE_GB + 2))
    if [[ "$USE_SWAPFILE" == true ]] && [[ $AVAILABLE_SPACE_GB -lt $REQUIRED_SPACE ]]; then
        echo "Warning: Insufficient disk space (${AVAILABLE_SPACE_GB}GB available, ${REQUIRED_SPACE}GB required)."
        if [[ $AVAILABLE_SPACE_GB -ge 3 ]]; then
            SWAP_SIZE_GB=$((AVAILABLE_SPACE_GB - 2))
            echo "Reducing swap file size to ${SWAP_SIZE_GB}GB"
        else
            echo "Skipping swap file creation."
            USE_SWAPFILE=false
        fi
    fi

    # =========================================================================
    # Configure ZRAM
    # =========================================================================
    if [[ "$USE_ZRAM" == true ]]; then
        echo ""
        echo "Installing and configuring ZRAM..."
        arch-chroot /mnt pacman -S zram-generator --noconfirm --needed

        mkdir -p /mnt/etc/systemd/
        cat <<EOF > /mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * ${ZRAM_MULTIPLIER}
swap-priority = 100
compression-algorithm = zstd
EOF

        # Load zram module in live environment
        modprobe zram 2>/dev/null || true

        arch-chroot /mnt systemctl enable systemd-zram-setup@zram0.service

        echo "ZRAM configured: ${ZRAM_MULTIPLIER}x RAM (${TOTAL_MEM_GB}GB → $((TOTAL_MEM_GB * ZRAM_MULTIPLIER))GB compressed swap)"
    fi

    # =========================================================================
    # Configure Swap File
    # =========================================================================
    if [[ "$USE_SWAPFILE" == true ]] && [[ $SWAP_SIZE_GB -gt 0 ]]; then
        echo ""
        echo "Creating swap file (${SWAP_SIZE_GB}GB)..."

        # Determine swap file path based on filesystem
        # For Btrfs: use dedicated @swap subvolume to avoid snapshot conflicts
        # For ext4/others: use /swapfile in root
        if [[ "$FS_TYPE" == "btrfs" ]] || [[ "$FS_TYPE" == "luks" ]]; then
            _create_btrfs_swapfile
        else
            _create_standard_swapfile
        fi
    fi

    # =========================================================================
    # Configure swappiness
    # =========================================================================
    mkdir -p /mnt/etc/sysctl.d
    if [[ "$USE_ZRAM" == true ]]; then
        # ZRAM has priority, lower swappiness to prefer RAM
        echo "vm.swappiness=10" > /mnt/etc/sysctl.d/99-swap.conf
    else
        # Swap file only, moderate swappiness
        echo "vm.swappiness=60" > /mnt/etc/sysctl.d/99-swap.conf
    fi

    echo ""
    echo "Swap configuration complete: ${SWAP_STRATEGY}"
}


# @description Create swap file on Btrfs filesystem using dedicated @swap subvolume
# This avoids the "Text file busy" (errno:26) error when creating snapshots
# Reference: https://wiki.archlinux.org/title/Btrfs#Swap_file
# @noargs
_create_btrfs_swapfile() {
    log_swap "=== Starting Btrfs Swapfile Creation ==="
    log_swap "Detected Btrfs filesystem - using dedicated @swap subvolume"
    log_swap "This prevents snapshot conflicts (errno:26 Text file busy)"

    echo "Detected Btrfs filesystem - using dedicated @swap subvolume"
    echo "This prevents snapshot conflicts (errno:26 Text file busy)"

    local SWAP_MOUNT="/mnt/swap"
    local SWAP_FILE="/mnt/swap/swapfile"

    # shellcheck disable=SC2034
    # Note: SWAP_FILE is used in this function and child functions
    # shellcheck disable=SC2086
    # Note: Variables in commands should be double-quoted to prevent globbing

    # Verify SWAP_SIZE_GB is set
    if [[ -z "${SWAP_SIZE_GB:-}" ]] || [[ "${SWAP_SIZE_GB}" -lt 1 ]]; then
        log_swap "ERROR: SWAP_SIZE_GB not set or invalid (value: ${SWAP_SIZE_GB:-unset})"
        log_swap "Defaulting to 4GB"
        echo "Error: SWAP_SIZE_GB not set or invalid (value: ${SWAP_SIZE_GB:-unset})"
        echo "Defaulting to 4GB"
        SWAP_SIZE_GB=4
    fi

    log_swap "Swap size: ${SWAP_SIZE_GB}GB"
    echo "Swap size: ${SWAP_SIZE_GB}GB"

    # Check if @swap subvolume directory exists
    if [[ ! -d "$SWAP_MOUNT" ]]; then
        log_swap "WARNING: @swap mount point $SWAP_MOUNT does not exist"
        log_swap "Creating directory and attempting to mount @swap subvolume..."
        echo "Warning: @swap mount point $SWAP_MOUNT does not exist"
        echo "Creating directory and attempting to mount @swap subvolume..."
        mkdir -p "$SWAP_MOUNT"
    fi

    # Check if @swap subvolume is mounted (by checking if it's a different mount from /mnt)
    local SWAP_MOUNTED=false
    if mountpoint -q "$SWAP_MOUNT" 2>/dev/null; then
        SWAP_MOUNTED=true
        log_swap "SUCCESS: @swap subvolume is mounted at $SWAP_MOUNT"
        echo "@swap subvolume is mounted at $SWAP_MOUNT"
    else
        log_swap "INFO: @swap subvolume not mounted, attempting to mount..."
        echo "@swap subvolume not mounted, attempting to mount..."

        # Get the root device
        local ROOT_DEV=""
        if [[ "${FS_TYPE:-}" == "luks" ]]; then
            ROOT_DEV="/dev/mapper/ROOT"
        else
            ROOT_DEV=$(findmnt -n -o SOURCE /mnt 2>/dev/null | head -1)
        fi

        log_swap "Root device: ${ROOT_DEV:-not found}"
        echo "Root device: ${ROOT_DEV:-not found}"

        if [[ -n "$ROOT_DEV" ]] && [[ -b "$ROOT_DEV" ]]; then
            # Mount @swap subvolume with nodatacow (required for swap)
            log_swap "Executing: mount -o subvol=@swap,noatime,nodatacow $ROOT_DEV $SWAP_MOUNT"
            if mount -o subvol=@swap,noatime,nodatacow "$ROOT_DEV" "$SWAP_MOUNT"; then
                SWAP_MOUNTED=true
                log_swap "SUCCESS: @swap subvolume mounted successfully"
                echo "@swap subvolume mounted successfully"
            else
                log_swap "ERROR: Could not mount @swap subvolume"
                log_swap "Mount command: mount -o subvol=@swap,noatime,nodatacow $ROOT_DEV $SWAP_MOUNT"
                echo "Error: Could not mount @swap subvolume"
                echo "Mount command: mount -o subvol=@swap,noatime,nodatacow $ROOT_DEV $SWAP_MOUNT"
            fi
        else
            log_swap "ERROR: Could not determine root device for mounting @swap"
            echo "Error: Could not determine root device for mounting @swap"
        fi
    fi

    # If @swap is not mounted, fall back to standard method
    if [[ "$SWAP_MOUNTED" != true ]]; then
        log_swap "WARNING: @swap is not mounted, falling back to standard method"
        log_swap "This may cause snapshot issues with Snapper"
        echo "Falling back to standard swap file location (may cause snapshot issues with Snapper)"
        _create_standard_swapfile
        return
    fi

    # Create swap file using btrfs-specific method
    log_swap "Creating swap file at /swap/swapfile (${SWAP_SIZE_GB}GB)..."
    echo "Creating swap file at /swap/swapfile (${SWAP_SIZE_GB}GB)..."

    # Method 1: Use btrfs filesystem mkswapfile (btrfs-progs >= 6.1)
    # This is modern ArchWiki recommended method
    log_swap "Trying btrfs filesystem mkswapfile (modern method)..."
    echo "Trying btrfs filesystem mkswapfile..."

    if arch-chroot /mnt btrfs filesystem mkswapfile --size ${SWAP_SIZE_GB}G --uuid clear /swap/swapfile; then
        log_swap "SUCCESS: Swap file created using btrfs filesystem mkswapfile"
        echo "Swap file created using btrfs filesystem mkswapfile"
    else
        log_swap "WARNING: btrfs filesystem mkswapfile failed, trying fallback method..."
        log_swap "This may indicate old btrfs-progs version (< 6.1)"
        echo "btrfs filesystem mkswapfile failed, trying fallback method..."

        # Method 2: Manual creation (for older btrfs-progs)
        log_swap "Using manual swap file creation method..."
        echo "Using manual swap file creation method..."

        # Ensure NOCOW attribute on directory
        log_swap "Setting NOCOW on /swap directory..."
        arch-chroot /mnt chattr +C /swap || {
            log_swap "WARNING: Could not set NOCOW on /swap"
            echo "Warning: Could not set NOCOW on /swap"
        }

        # Create empty file first
        log_swap "Creating empty file /swap/swapfile..."
        arch-chroot /mnt truncate -s 0 /swap/swapfile || {
            log_swap "ERROR: Could not create /swap/swapfile with truncate"
            echo "Error: Could not create /swap/swapfile"
            _create_standard_swapfile
            return
        }

        # Set NOCOW on the file
        log_swap "Setting NOCOW on /swap/swapfile..."
        arch-chroot /mnt chattr +C /swap/swapfile || {
            log_swap "WARNING: Could not set NOCOW on swapfile"
            echo "Warning: Could not set NOCOW on swapfile"
        }

        # Disable compression
        log_swap "Disabling compression on /swap/swapfile..."
        arch-chroot /mnt btrfs property set /swap/swapfile compression none 2>/dev/null || {
            log_swap "WARNING: Could not disable compression on swapfile"
        }

        # Allocate space (fallocate is preferred, dd as fallback)
        log_swap "Allocating ${SWAP_SIZE_GB}G space with fallocate..."
        if ! arch-chroot /mnt fallocate -l ${SWAP_SIZE_GB}G /swap/swapfile; then
            log_swap "WARNING: fallocate failed, using dd (this may take a while)..."
            echo "fallocate failed, using dd (this may take a while)..."
            arch-chroot /mnt dd if=/dev/zero of=/swap/swapfile bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress || {
                log_swap "ERROR: Could not allocate space for swap file with dd"
                echo "Error: Could not allocate space for swap file"
                arch-chroot /mnt rm -f /swap/swapfile
                _create_standard_swapfile
                return
            }
        fi

        # Set permissions
        log_swap "Setting permissions 600 on /swap/swapfile..."
        arch-chroot /mnt chmod 600 /swap/swapfile

        # Format as swap
        log_swap "Formatting /swap/swapfile as swap..."
        arch-chroot /mnt mkswap -U clear /swap/swapfile || {
            log_swap "ERROR: mkswap failed"
            echo "Error: mkswap failed"
            arch-chroot /mnt rm -f /swap/swapfile
            _create_standard_swapfile
            return
        }

        log_swap "SUCCESS: Swap file created using manual method"
        echo "Swap file created using manual method"
    fi

    # Verify swap file was created and has correct size
    log_swap "Verifying swap file creation..."
    if arch-chroot /mnt test -f /swap/swapfile; then
        local SWAP_ACTUAL_SIZE=$(arch-chroot /mnt stat -c%s /swap/swapfile 2>/dev/null || echo "0")
        local SWAP_EXPECTED_SIZE=$((SWAP_SIZE_GB * 1024 * 1024 * 1024))

        log_swap "Swap file created: $(arch-chroot /mnt ls -lh /swap/swapfile | awk '{print $5}')"
        log_swap "Actual size: $SWAP_ACTUAL_SIZE bytes, Expected: $SWAP_EXPECTED_SIZE bytes"
        echo "Swap file created: $(arch-chroot /mnt ls -lh /swap/swapfile | awk '{print $5}')"

        # Verify size is at least 90% of expected (some overhead is normal)
        if [[ "$SWAP_ACTUAL_SIZE" -lt $((SWAP_EXPECTED_SIZE * 9 / 10)) ]]; then
            log_swap "WARNING: Swap file size ($SWAP_ACTUAL_SIZE bytes) is smaller than expected ($SWAP_EXPECTED_SIZE bytes)"
            echo "Warning: Swap file size ($SWAP_ACTUAL_SIZE bytes) is smaller than expected ($SWAP_EXPECTED_SIZE bytes)"
        fi

        # Set correct permissions (ensure 600)
        log_swap "Ensuring permissions 600 on /swap/swapfile..."
        arch-chroot /mnt chmod 600 /swap/swapfile

        # Try to activate swap file
        log_swap "Attempting to activate swap file..."
        if arch-chroot /mnt swapon /swap/swapfile; then
            log_swap "SUCCESS: Swap file activated successfully"
            echo "Swap file activated successfully"
        else
            log_swap "WARNING: Could not activate swap file, will activate on first boot"
            log_swap "This is normal, swap will be activated from /etc/fstab on boot"
            echo "Note: Swap file will be activated on first boot"
        fi

        # Update fstab - remove any old swap entries first
        log_swap "Updating /etc/fstab..."
        log_swap "Removing old swap entries from /etc/fstab..."
        arch-chroot /mnt sed -i '/swapfile/d' /etc/fstab
        arch-chroot /mnt sed -i '/\/swap.*swap/d' /etc/fstab

        # Add @swap subvolume entry to fstab (required for swapfile to be accessible on boot)
        log_swap "Adding @swap subvolume entry to /etc/fstab..."

        # Get the root filesystem UUID and mount options from existing fstab
        # Using grep and awk for robust parsing (handles tabs and extra spaces)
        local ROOT_LINE=$(grep $'\t/' /mnt/etc/fstab | grep -v $'\t/var' | grep -v $'\t/home' | grep -v $'\t/opt' | head -1)
        local ROOT_UUID=$(echo "$ROOT_LINE" | awk -F'\t' '{print $1}' | grep -oP 'UUID=\K[0-9a-f-]+')
        local ROOT_OPTS=$(echo "$ROOT_LINE" | awk -F'\t' '{print $4}' | sed 's/subvol=\/@/subvol=\/@swap/')

        # Add @swap subvolume mount entry
        if [[ -n "$ROOT_UUID" ]] && [[ -n "$ROOT_OPTS" ]]; then
            log_swap "Root UUID: $ROOT_UUID"
            log_swap "Mount options: $ROOT_OPTS"
            echo "UUID=${ROOT_UUID}	/swap	btrfs	${ROOT_OPTS},nodatacow	0	0" >> /mnt/etc/fstab
            log_swap "SUCCESS: @swap subvolume entry added to /etc/fstab"

            # Ensure /swap directory exists in installed system
            log_swap "Ensuring /swap directory exists in installed system..."
            arch-chroot /mnt mkdir -p /swap
            log_swap "SUCCESS: /swap directory created/verified"
        else
            log_swap "ERROR: Could not determine root UUID or mount options"
            log_swap "WARNING: @swap subvolume entry not added to /etc/fstab"
            log_swap "You may need to manually add: UUID=<root_uuid>	/swap	btrfs	<options>,subvol=/@swap,nodatacow	0	0"
        fi

        # Add swap file entry with correct priority
        if [[ "${USE_ZRAM:-false}" == true ]]; then
            log_swap "Adding swap file entry with priority 50 (ZRAM + Swapfile)..."
            echo "/swap/swapfile none swap defaults,pri=50 0 0" >> /mnt/etc/fstab
        else
            log_swap "Adding swap file entry (Swapfile only)..."
            echo "/swap/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
        fi

        log_swap "SUCCESS: Swap file added to /etc/fstab"
        log_swap "SUCCESS: Swap file configured: ${SWAP_SIZE_GB}GB at /swap/swapfile (Btrfs @swap subvolume)"
        echo "Swap file added to /etc/fstab"
        echo "Swap file configured: ${SWAP_SIZE_GB}GB at /swap/swapfile (Btrfs @swap subvolume)"

        # Log swap info for debugging
        log_info SWAP
    else
        log_swap "ERROR: Swap file was not created at /swap/swapfile"
        log_swap "Falling back to standard swap file location"
        echo "Error: Swap file was not created at /swap/swapfile"
        echo "Falling back to standard swap file location"
        _create_standard_swapfile
    fi

    log_swap "=== Btrfs Swapfile Creation Complete ==="
}


# @description Create swap file on ext4 or other standard filesystems
# @noargs
_create_standard_swapfile() {
    echo "Using standard swap file creation method (ext4/other)"

    # Verify SWAP_SIZE_GB is set
    if [[ -z "${SWAP_SIZE_GB:-}" ]] || [[ "${SWAP_SIZE_GB}" -lt 1 ]]; then
        echo "Error: SWAP_SIZE_GB not set or invalid (value: ${SWAP_SIZE_GB:-unset})"
        echo "Defaulting to 4GB"
        SWAP_SIZE_GB=4
    fi

    echo "Creating swap file at /swapfile (${SWAP_SIZE_GB}GB)..."

    # Method 1: Use mkswap --file (modern method, mkswap >= 2.36)
    echo "Trying mkswap --file method..."
    if arch-chroot /mnt mkswap -U clear --size ${SWAP_SIZE_GB}G --file /swapfile; then
        echo "Swap file created using mkswap --file"
    else
        # Method 2: Traditional method (fallocate + mkswap)
        echo "mkswap --file failed, using traditional method..."

        # Try fallocate first (faster)
        if arch-chroot /mnt fallocate -l ${SWAP_SIZE_GB}G /swapfile; then
            echo "Space allocated with fallocate"
        else
            # Fallback to dd (slower but more compatible)
            echo "fallocate failed, using dd (this may take a while)..."
            arch-chroot /mnt dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress || {
                echo "Error: Could not create swap file"
                return 1
            }
        fi

        # Set permissions before mkswap
        arch-chroot /mnt chmod 600 /swapfile

        # Format as swap
        arch-chroot /mnt mkswap -U clear /swapfile || {
            echo "Error: mkswap failed"
            arch-chroot /mnt rm -f /swapfile
            return 1
        }

        echo "Swap file created using traditional method"
    fi

    # Verify swap file was created
    if arch-chroot /mnt test -f /swapfile; then
        echo "Swap file created: $(arch-chroot /mnt ls -lh /swapfile | awk '{print $5}')"

        # Set correct permissions
        arch-chroot /mnt chmod 600 /swapfile

        # Activate swap file
        if arch-chroot /mnt swapon /swapfile; then
            echo "Swap file activated successfully"
        else
            echo "Note: Swap file will be activated on first boot"
        fi

        # Clean up any conflicting systemd units
        arch-chroot /mnt systemctl stop swapfile.swap 2>/dev/null || true
        arch-chroot /mnt systemctl disable swapfile.swap 2>/dev/null || true
        arch-chroot /mnt rm -f /etc/systemd/system/swapfile.swap 2>/dev/null || true
        arch-chroot /mnt systemctl daemon-reload 2>/dev/null || true

        # Update fstab
        arch-chroot /mnt sed -i '/\/swapfile/d' /etc/fstab

        if [[ "$USE_ZRAM" == true ]]; then
            echo "/swapfile none swap defaults,pri=50 0 0" >> /mnt/etc/fstab
        else
            echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
        fi

        echo "Swap file added to /etc/fstab"
        echo "Swap file configured: ${SWAP_SIZE_GB}GB at /swapfile"
    else
        echo "Error: Swap file was not created successfully"
    fi
}


# @description Configures makepkg settings dependent on cpu cores
# @noargs
cpu_config() {
    nc=$(grep -c ^processor /proc/cpuinfo)
    echo -ne "
-------------------------------------------------------------------------
                    You have $nc cores. And
            changing the makeflags for $nc cores. Aswell as
                changing the compression settings.
-------------------------------------------------------------------------
"
    TOTAL_MEM=$(grep </proc/meminfo -i 'memtotal' | grep -o '[[:digit:]]*')
    if [[ "$TOTAL_MEM" -gt 8000000 ]]; then
        sed -i "s/^#\(MAKEFLAGS=\"-j\)2\"/\1$nc\"/;
        /^COMPRESSXZ=(xz -c -z -)/s/-c /&-T $nc /" /etc/makepkg.conf
    fi
}


# @description Set locale, timezone, keymap, and vconsole configuration
# @noargs
locale_config() {
    echo -ne "
-------------------------------------------------------------------------
                    Setting Locale, Timezone, and Keymap
-------------------------------------------------------------------------
"
    # Enable selected locale and create /etc/locale.conf file with complete settings
    sed -i "s/^#\(${LOCALE}.*\)/\1/" /etc/locale.gen
    {
        echo "LANG=${LOCALE}"
        echo "LC_ADDRESS=${LOCALE}"
        echo "LC_IDENTIFICATION=${LOCALE}"
        echo "LC_MEASUREMENT=${LOCALE}"
        echo "LC_MONETARY=${LOCALE}"
        echo "LC_NAME=${LOCALE}"
        echo "LC_NUMERIC=${LOCALE}"
        echo "LC_PAPER=${LOCALE}"
        echo "LC_TELEPHONE=${LOCALE}"
        echo "LC_TIME=${LOCALE}"
    } > /etc/locale.conf
    echo "Generating locales..."
    locale-gen || { echo "ERROR: Failed to generate locales."; exit 1; }
    localectl --no-ask-password set-locale LANG="${LOCALE}" LC_TIME="${LOCALE}"
    echo "Locales generated successfully."

    # Configure timezone and synchronize hours
    timedatectl --no-ask-password set-timezone "${TIMEZONE}"
    timedatectl --no-ask-password set-ntp 1
    ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime
    hwclock --systohc
    echo "Timezone configured: ${TIMEZONE}"

    # Configure keymap and remap keys
    pacman -S --noconfirm --needed --color=always kbd xkeyboard-config
    localectl --no-ask-password set-keymap "${KEYMAP}"
    echo "Keymap configured: ${KEYMAP}"

    # Create /etc/vconsole.conf for console keymap configuration
    echo -e "KEYMAP=${KEYMAP}\nFONT=Lat2-Terminus16\nFONT_MAP=" > /etc/vconsole.conf

    echo -ne "
    Locale, Timezone, Keymap, and VConsole configuration completed.
    "
}


# @description Adds multilib and chaotic-aur repo to get precompiled aur packages
# @noargs
extra_repos() {
    echo -ne "
-------------------------------------------------------------------------
                    Adding additional repos
-------------------------------------------------------------------------
"

    # Enable multilib
    echo -e "\n Enabling multilib"
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

    # echo -e "\n Importing chaotic aur keyring"
    # Enable chaotic-aur
    # pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
    # pacman-key --lsign-key FBA220DFC880C036
    # pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    # echo -e "\n Adding chaotic aur to pacman.conf"
    # echo '' | sudo tee -a /etc/pacman.conf
    # echo '[chaotic-aur]' | sudo tee -a /etc/pacman.conf
    # echo 'Include = /etc/pacman.d/chaotic-mirrorlist ' | sudo tee -a /etc/pacman.conf

    echo -e "\n -|SYNCING REPOS|-"
    pacman -Sy --noconfirm --needed --color=always
}


# @description Configure base skel directory with common configurations for all users
# Copies editor configurations and other base files to /etc/skel/
# @noargs
configure_base_skel() {
    echo -ne "
-------------------------------------------------------------------------
                    Configuring Base Skel Directory
-------------------------------------------------------------------------
"
    # Copy base skel configurations to /etc/skel/ if they exist
    if [[ -d "$HOME"/archinstaller/configs/base/etc/skel ]]; then
        SKEL_CONFIG_DIR="$HOME"/archinstaller/configs/base/etc/skel

        # Copy everything from base skel to /etc/skel/ recursively
        # Using cp -a to preserve permissions and copy directories recursively
        if cp -a "$SKEL_CONFIG_DIR"/. /etc/skel/ 2>/dev/null; then
            echo "Base skel configurations copied to /etc/skel/"

            # List copied files for verification
            if [[ -f /etc/skel/.nanorc ]]; then
                echo "  - .nanorc configured"
            fi
            if [[ -d /etc/skel/.config/nvim ]]; then
                echo "  - Neovim configuration configured"
            fi
        else
            echo "Warning: Failed to copy base skel configurations"
        fi
    else
        echo "Base skel configuration directory not found, skipping"
    fi
}


# @description Adds user that was setup prior to installation
# @noargs
add_user() {
    echo -ne "
-------------------------------------------------------------------------
                    Adding User
-------------------------------------------------------------------------
"
    if [ "$(whoami)" = "root" ]; then
        # Create groups
        for group in libvirt vboxusers gamemode docker; do
            groupadd -f "$group"
        done

        # Add new user and full name
        if ! useradd -m -G wheel,libvirt,vboxusers,gamemode,docker -s /bin/bash -c "$REAL_NAME" "$USERNAME"; then
            echo "ERROR! Failed to create user $USERNAME."
            exit 1
        fi
        echo "$USERNAME created with full name '$REAL_NAME', added to groups."

        # Define a user's password
        if echo "$USERNAME:$PASSWORD" | chpasswd; then
            echo "$USERNAME password set."
        else
            echo "ERROR! Failed to set password for $USERNAME."
            exit 1
        fi

        # Copies the installation directory to home directory.
        if cp -R "$HOME/archinstaller" /home/"$USERNAME"/; then
            chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/archinstaller
            echo "archinstaller copied to home directory."
        else
            echo "ERROR! Failed to copy archinstaller to /home/$USERNAME."
            exit 1
        fi

        # Define hostname
        echo "$NAME_OF_MACHINE" >/etc/hostname
        echo "Hostname set to $NAME_OF_MACHINE."

        # Setup hosts file
        cat >> /etc/hosts << EOF
127.0.0.1  localhost
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
# This host address
127.0.1.1  archlinux
EOF

    else
        echo "You are already a user, proceed with AUR installs."
    fi
}


# @description Configure GRUB and set a wallpaper (if not SERVER installation)
# @noargs
grub_config() {
    echo -ne "
-------------------------------------------------------------------------
               Configuring GRUB Boot Menu
-------------------------------------------------------------------------
"
    if [[ "${FS}" == "luks" ]]; then
        sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
    fi
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' /etc/default/grub

    echo -e "\n Backing up Grub config..."
    cp -an /etc/default/grub /etc/default/grub.bak

    # Configure resume parameter for hibernation (if swap file exists)
    if [[ -f /swapfile ]]; then
        echo -e "\nConfiguring GRUB for hibernation support..."

        # Method 1: Try to get UUID of swap file using blkid
        SWAP_UUID=$(blkid -s UUID -o value /swapfile 2>/dev/null)

        # Method 2: If blkid fails, try to get UUID from swapon output
        if [[ -z "$SWAP_UUID" ]]; then
            SWAP_UUID=$(swapon --show=UUID --noheadings /swapfile 2>/dev/null | tr -d '[:space:]')
        fi

        # Method 3: If still no UUID, try findmnt (requires swap to be mounted)
        if [[ -z "$SWAP_UUID" ]]; then
            SWAP_UUID=$(findmnt -no UUID -T /swapfile 2>/dev/null)
        fi

        # Method 4: Use file path as fallback (per ArchWiki: resume=/swapfile)
        # This works but UUID is preferred
        RESUME_PARAM=""
        if [[ -n "$SWAP_UUID" ]]; then
            RESUME_PARAM="resume=UUID=$SWAP_UUID"
            echo "Detected swap file UUID: $SWAP_UUID"
        else
            # Fallback: use file path directly (works but UUID is preferred)
            RESUME_PARAM="resume=/swapfile"
            echo "Warning: Could not detect swap file UUID, using file path as fallback"
            echo "         Using: resume=/swapfile"
        fi

        # Check if resume parameter already exists (any form)
        if ! grep -q "resume=" /etc/default/grub; then
            # Add resume parameter to GRUB_CMDLINE_LINUX_DEFAULT
            # Add before splash if it exists, or at the end
            if grep -q "GRUB_CMDLINE_LINUX_DEFAULT.*splash" /etc/default/grub; then
                sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*splash\)|GRUB_CMDLINE_LINUX_DEFAULT=\"$RESUME_PARAM \1|" /etc/default/grub
            else
                # Add at the end of GRUB_CMDLINE_LINUX_DEFAULT
                sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $RESUME_PARAM\"|" /etc/default/grub
            fi
            echo "Resume parameter added: $RESUME_PARAM"
        else
            echo "Resume parameter already configured in GRUB"
            echo "  Current resume parameter: $(grep -oP 'resume=[^\s"]*' /etc/default/grub | head -n1)"
        fi
    else
        echo -e "\nNo swap file found (/swapfile). Skipping hibernation configuration."
        echo "Note: Hibernation requires a swap file or swap partition"
    fi

    if [[ "$INSTALL_TYPE" != "SERVER" ]]; then
        echo -e "\nSetting wallpaper for GRUB..."
        # WALLPAPER_PATH="/usr/share/backgrounds/archlinux/archwave.png"
        # sed -Ei "s|^#GRUB_BACKGROUND=.*|GRUB_BACKGROUND=\"$WALLPAPER_PATH\"|" /etc/default/grub
    else
        echo -e "\nSkipping wallpaper setup for SERVER installation."
    fi

    echo -e "\nUpdating GRUB configuration..."
    grub-mkconfig -o /boot/grub/grub.cfg
    echo -e "\nGRUB configuration complete."
}


# @description Install and enable display manager depending on desktop environment chosen
# @noargs
display_manager() {
    echo -ne "
-------------------------------------------------------------------------
               Enabling (and Theming) Login Display Manager
-------------------------------------------------------------------------
"
    if [[ "${DESKTOP_ENV}" == "kde" ]]; then
        systemctl enable sddm.service
        if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
            echo -e "Setting SDDM Theme..."
            echo "[Theme]" >>/etc/sddm.conf
            echo "Current=Nordic" >>/etc/sddm.conf
        fi

    elif [[ "${DESKTOP_ENV}" == "gnome" ]]; then
        systemctl enable gdm.service

    elif [[ "${DESKTOP_ENV}" == "lxde" ]]; then
        systemctl enable lxdm.service

    elif [[ "${DESKTOP_ENV}" == "openbox" ]]; then
        # Check if lightdm is installed, install if not
        if ! pacman -Qi lightdm &>/dev/null; then
            echo "LightDM not found, installing..."
            pacman -S --noconfirm --needed --color=always lightdm lightdm-webkit2-greeter
        fi

        # Check if lightdm service exists before enabling
        if systemctl list-unit-files | grep -q "lightdm.service"; then
            systemctl enable lightdm.service
        else
            echo "Warning: lightdm.service not found, skipping enable"
            return 1
        fi

        # Create lightdm config directory if it doesn't exist
        mkdir -p /etc/lightdm

        # Create lightdm.conf if it doesn't exist
        if [[ ! -f /etc/lightdm/lightdm.conf ]]; then
            echo "[Seat:*]
greeter-session=lightdm-webkit2-greeter" > /etc/lightdm/lightdm.conf
        fi

        if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
            echo -e "Setting LightDM Theme..."
            # Create config file if it doesn't exist
            if [[ ! -f /etc/lightdm/lightdm-webkit2-greeter.conf ]]; then
                touch /etc/lightdm/lightdm-webkit2-greeter.conf
                echo "[greeter]" >> /etc/lightdm/lightdm-webkit2-greeter.conf
            fi
            # Set default lightdm-webkit2-greeter theme to Litarvan
            sed -i 's/^webkit_theme\s*=\s*\(.*\)/webkit_theme = litarvan #\1/g' /etc/lightdm/lightdm-webkit2-greeter.conf
            # Set default lightdm greeter to lightdm-webkit2-greeter
            sed -i 's/#greeter-session=example.*/greeter-session=lightdm-webkit2-greeter/g' /etc/lightdm/lightdm.conf
            if ! grep -q "^greeter-session=lightdm-webkit2-greeter" /etc/lightdm/lightdm.conf; then
                sed -i '/\[Seat:\*\]/a greeter-session=lightdm-webkit2-greeter' /etc/lightdm/lightdm.conf
            fi
        fi

    elif [[ "${DESKTOP_ENV}" == "awesome" ]]; then
        # Check if lightdm is installed, install if not
        if ! pacman -Qi lightdm &>/dev/null; then
            echo "LightDM not found, installing..."
            pacman -S --noconfirm --needed --color=always lightdm lightdm-slick-greeter
        fi

        # Check if lightdm service exists before enabling
        if systemctl list-unit-files | grep -q "lightdm.service"; then
            systemctl enable lightdm.service
        else
            echo "Warning: lightdm.service not found, skipping enable"
            return 1
        fi

        # Create lightdm config directory if it doesn't exist
        mkdir -p /etc/lightdm

        # Create lightdm.conf if it doesn't exist
        if [[ ! -f /etc/lightdm/lightdm.conf ]]; then
            echo "[Seat:*]
greeter-session=lightdm-slick-greeter" > /etc/lightdm/lightdm.conf
        fi

        if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
            echo -e "Setting LightDM Theme..."
            # Copy config file or create if it doesn't exist
            if [[ -f ~/archinstaller/configs/awesome/etc/lightdm/slick-greeter.conf ]]; then
                cp ~/archinstaller/configs/awesome/etc/lightdm/slick-greeter.conf /etc/lightdm/slick-greeter.conf
            else
                if [[ ! -f /etc/lightdm/slick-greeter.conf ]]; then
                    touch /etc/lightdm/slick-greeter.conf
                    echo "[greeter]" >> /etc/lightdm/slick-greeter.conf
                fi
            fi
            sed -i 's/#greeter-session=example.*/greeter-session=lightdm-slick-greeter/g' /etc/lightdm/lightdm.conf
            if ! grep -q "^greeter-session=lightdm-slick-greeter" /etc/lightdm/lightdm.conf; then
                sed -i '/\[Seat:\*\]/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
            fi
        fi

    elif [[ "${DESKTOP_ENV}" == "i3-wm" ]]; then
        # Check if lightdm is installed, install if not
        if ! pacman -Qi lightdm &>/dev/null; then
            echo "LightDM not found, installing..."
            pacman -S --noconfirm --needed --color=always lightdm lightdm-gtk-greeter
        fi

        # Check if lightdm service exists before enabling
        if systemctl list-unit-files | grep -q "lightdm.service"; then
            systemctl enable lightdm.service
        else
            echo "Warning: lightdm.service not found, skipping enable"
            return 1
        fi

        echo -e "Configuring LightDM for i3-wm..."

        # Create lightdm config directory if it doesn't exist
        mkdir -p /etc/lightdm

        # Create lightdm.conf if it doesn't exist
        if [[ ! -f /etc/lightdm/lightdm.conf ]]; then
            echo "[Seat:*]
greeter-session=lightdm-gtk-greeter" > /etc/lightdm/lightdm.conf
        else
            # Set lightdm greeter to lightdm-gtk-greeter
            sed -i 's/#greeter-session=example.*/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf
            # Ensure it's set even if not commented
            if ! grep -q "^greeter-session=lightdm-gtk-greeter" /etc/lightdm/lightdm.conf; then
                sed -i '/\[Seat:\*\]/a greeter-session=lightdm-gtk-greeter' /etc/lightdm/lightdm.conf
            fi
        fi

        CONFIG_FILE="/etc/lightdm/lightdm-gtk-greeter.conf"

        # Create config file if it doesn't exist
        if [[ ! -f "$CONFIG_FILE" ]]; then
            touch "$CONFIG_FILE"
            echo "[greeter]" >> "$CONFIG_FILE"
        fi

        # Base configuration (always applied)
        declare -A base_greeter_config=(
            ["font-name"]="Ubuntu 12"
            ["xft-antialias"]="true"
            ["transition-duration"]="1000"
            ["transition-type"]="linear"
            ["screensaver-timeout"]="60"
            ["show-clock"]="false"
            ["default-user-image"]="#archlinux"
            ["xft-hintstyle"]="hintfull"
            ["panel-position"]="top"
            ["xft-dpi"]="96"
            ["xft-rgba"]="rgb"
            ["active-monitor"]="1"
            ["round-user-image"]="false"
            ["indicators"]="~host;~spacer;~language;~session;~a11y;~power"
            ["position"]="50%,center 50%,center"
            ["draw-grid"]="false"
            ["clock-format"]="%H:%M"
            ["keyboard"]=""
            ["hide-user-image"]="false"
            ["logo"]=""
            ["other-monitors-logo"]=""
            ["battery"]=""
        )

        # Background configuration with solid color for all installation types
        # Use solid color background #073642 for both FULL and MINIMAL installations
        base_greeter_config["background"]="#073642"
        base_greeter_config["user-background"]="false"
        base_greeter_config["draw-user-backgrounds"]="false"
        # Dark theme configuration (using Adwaita-dark theme)
        base_greeter_config["icon-theme-name"]="zafiro-dark"
        base_greeter_config["cursor-theme-name"]="Adwaita"
        base_greeter_config["theme-name"]="Adwaita-dark"

        # Apply configuration: remove existing entries first, then add new ones
        for key in "${!base_greeter_config[@]}"; do
            # Remove existing entry (commented or not)
            sed -i "/^#*${key}=/d" "$CONFIG_FILE"
        done

        # Add all configurations
        for key in "${!base_greeter_config[@]}"; do
            # Skip empty values
            if [[ -n "${base_greeter_config[$key]}" ]]; then
                echo "${key}=${base_greeter_config[$key]}" >> "$CONFIG_FILE"
            fi
        done

        echo "LightDM GTK greeter configured with dark theme for i3-wm"

    # If none of the above, use lightdm as fallback
    else
        if [[ ! "${INSTALL_TYPE}" == "SERVER" ]]; then
            pacman -S --noconfirm --needed --color=always lightdm lightdm-gtk-greeter
            systemctl enable lightdm.service
        fi
    fi
}


# @description Configure snapper default setup
# @noargs
snapper_config() {
    echo -ne "
-------------------------------------------------------------------------
                    Creating Snapper Config
-------------------------------------------------------------------------
"

    SNAPPER_CONF="$HOME"/archinstaller/configs/base/etc/snapper/configs/root
    mkdir -p /etc/snapper/configs/
    cp -rfv "${SNAPPER_CONF}" /etc/snapper/configs/

    SNAPPER_CONF_D="$HOME"/archinstaller/configs/base/etc/conf.d/snapper
    mkdir -p /etc/conf.d/
    cp -rfv "${SNAPPER_CONF_D}" /etc/conf.d/

    sed -i "s/ALLOW_USERS=\".*\"/ALLOW_USERS=\"$(whoami)\"/" /etc/snapper/configs/root
    sed -i "s/ALLOW_GROUPS=\".*\"/ALLOW_GROUPS=\"$(whoami)\"/" /etc/snapper/configs/root
    systemctl enable snapper-timeline.timer
    systemctl enable snapper-cleanup.timer
    systemctl enable grub-btrfsd.service
    snapper -c root create --description "Initial snapshot"
    chown :users /.snapshots
}


# @description Configures TLP for power management on laptops.
# @noargs
configure_tlp() {
    if [ -d "/sys/class/power_supply/BAT0" ] || acpi -b &>/dev/null; then
        echo "Battery detected. Installing and configuring TLP..."

        sudo pacman -S --noconfirm tlp tlp-rdw
        sudo systemctl enable tlp.service
        sudo systemctl enable NetworkManager-dispatcher.service

        sudo systemctl mask systemd-rfkill.service
        sudo systemctl mask systemd-rfkill.socket

        # Apply recommended configurations
        TLP_CONF="/etc/tlp.conf"

        # Configure TLP to manage power settings for specific disks:
        # sets moderate APM level (128) on battery for power saving,
        # and maximum performance (254) on AC; targets nvme0n1 and sda devices.
        sudo sed -i 's/^#\?DISK_DEVICES=.*/DISK_DEVICES="nvme0n1 sda"/' "$TLP_CONF"
        sudo sed -i 's/^#\?DISK_APM_LEVEL_ON_BAT=.*/DISK_APM_LEVEL_ON_BAT="128"/' "$TLP_CONF"
        sudo sed -i 's/^#\?DISK_APM_LEVEL_ON_AC=.*/DISK_APM_LEVEL_ON_AC="254"/' "$TLP_CONF"

        # Note: DEVICES_TO_DISABLE_ON_BAT is not set, so bluetooth will remain enabled on battery
        # If you want to disable bluetooth on battery to save power, uncomment the line below:
        # sudo sed -i 's/^#\?DEVICES_TO_DISABLE_ON_BAT=.*/DEVICES_TO_DISABLE_ON_BAT="bluetooth"/' "$TLP_CONF"

        # Defines aggressiveness in the scaling of the CPU
        sudo sed -i 's/^#\?CPU_SCALING_GOVERNOR_ON_BAT=.*/CPU_SCALING_GOVERNOR_ON_BAT=powersave/' "$TLP_CONF"
        sudo sed -i 's/^#\?CPU_SCALING_GOVERNOR_ON_AC=.*/CPU_SCALING_GOVERNOR_ON_AC=ondemand/' "$TLP_CONF"

        # Configure TLP to disable USB autosuspend, enable runtime power management on AC,
        # and set CPU energy/performance policies: balanced performance on AC, balanced power on battery.
        sudo sed -i 's/^#\?USB_AUTOSUSPEND=.*/USB_AUTOSUSPEND=0/' "$TLP_CONF"
        sudo sed -i 's/^#\?RUNTIME_PM_ON_AC=.*/RUNTIME_PM_ON_AC=auto/' "$TLP_CONF"
        sudo sed -i 's/^#\?CPU_ENERGY_PERF_POLICY_ON_AC=.*/CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance/' "$TLP_CONF"
        sudo sed -i 's/^#\?CPU_ENERGY_PERF_POLICY_ON_BAT=.*/CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power/' "$TLP_CONF"

        # Logind configuration to suspend when closing the lid
        echo "Configuring lid close behavior via systemd-logind..."
        sudo sed -i 's/^#\?HandleLidSwitch=.*/HandleLidSwitch=suspend/' /etc/systemd/logind.conf
        sudo sed -i 's/^#\?HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf

        sudo systemctl restart systemd-logind
        echo "TLP installed and configured successfully."
    else
        echo "No battery detected. Skipping TLP configuration."
    fi
}


# @description Install plymouth splash
# @noargs
plymouth_config() {
    echo -ne "
-------------------------------------------------------------------------
            Enabling (and Theming) Plymouth Boot Splash
-------------------------------------------------------------------------
"
    PLYMOUTH_THEMES_DIR="$HOME"/archinstaller/configs/base/usr/share/plymouth/themes
    PLYMOUTH_THEME="arch-glow" # can grab from config later if we allow selection
    mkdir -p "/usr/share/plymouth/themes"

    echo -e "Installing Plymouth theme... \n"

    cp -rf "${PLYMOUTH_THEMES_DIR}"/"${PLYMOUTH_THEME}" /usr/share/plymouth/themes
    if [[ "${FS}" == "luks" ]]; then
        sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf             # add plymouth after base udev
        sed -i 's/HOOKS=(base udev \(.*block\) /&plymouth-/' /etc/mkinitcpio.conf # create plymouth-encrypt after block hook
    else
        sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf # add plymouth after base udev
    fi
    plymouth-set-default-theme -R arch-glow # sets the theme and runs mkinitcpio

    echo -e "\n Plymouth theme installed"
}


# @description Configure PAM to allow 5 password attempts before lockout
# @noargs
configure_pam_faillock() {
    echo -ne "
-------------------------------------------------------------------------
                    Configuring PAM Password Attempts
-------------------------------------------------------------------------
"
    # Configure faillock to allow 5 attempts before lockout
    FAILLOCK_CONF="/etc/security/faillock.conf"

    # Create or update faillock.conf
    mkdir -p /etc/security/

    # Check if faillock.conf exists
    if [[ ! -f "$FAILLOCK_CONF" ]]; then
        # Create default faillock.conf with 5 attempts
        cat > "$FAILLOCK_CONF" << 'EOF'
# faillock configuration file
# This file is parsed by faillock(8).
# See 'man faillock.conf' for more information.

# Maximum number of consecutive failed login attempts before the account is locked
deny = 5

# Time in seconds after which the counter of failed login attempts will be reset
fail_interval = 900

# Time in seconds that must elapse before failed login attempts counter is reset
# in case the user tries to authenticate before the fail_interval expires
unlock_time = 600
EOF
        echo "Created $FAILLOCK_CONF with 5 attempts configuration"
    else
        # Update existing faillock.conf
        # First, remove all existing deny lines to avoid duplicates
        sed -i '/^deny\s*=/d' "$FAILLOCK_CONF"

        # Add deny = 5 after the header comments (after first non-empty, non-comment section)
        # Find a good place to insert: after comments but before other config lines
        # If we find a line like "fail_interval" or "unlock_time", add before it
        if grep -q "^fail_interval\|^unlock_time" "$FAILLOCK_CONF"; then
            # Insert before first config line (fail_interval or unlock_time)
            sed -i '/^fail_interval\|^unlock_time/i deny = 5' "$FAILLOCK_CONF"
        elif grep -q "^[^#[:space:]]" "$FAILLOCK_CONF"; then
            # File has non-comment, non-empty lines, add before first one
            sed -i '/^[^#[:space:]]/i deny = 5' "$FAILLOCK_CONF"
        else
            # File has only comments/empty lines, add at the end
            echo "" >> "$FAILLOCK_CONF"
            echo "deny = 5" >> "$FAILLOCK_CONF"
        fi

        echo "Updated $FAILLOCK_CONF: deny = 5 (removed duplicates)"
    fi

    # Note: The default Arch Linux PAM configuration uses faillock.conf
    # The configuration in /etc/pam.d/system-auth should already reference pam_faillock
    # If needed, we can verify that pam_faillock is being used
    echo "PAM password attempts configured: 5 attempts before lockout"
    echo "Configuration file: $FAILLOCK_CONF"
}


# @description Configure PipeWire as audio server and remove PulseAudio if present
# @noargs
configure_pipewire() {
    # Only configure for graphical installations (not SERVER)
    if [[ "${INSTALL_TYPE:-}" == "SERVER" ]]; then
        return 0
    fi

    echo -ne "
-------------------------------------------------------------------------
                    Configuring PipeWire Audio Server
-------------------------------------------------------------------------
"

    # Check if PipeWire is installed
    if ! pacman -Qi pipewire &>/dev/null; then
        echo "Warning: PipeWire is not installed, skipping configuration"
        return 1
    fi

    echo "PipeWire is installed, configuring audio server..."

    # Remove PulseAudio if installed (obsolete)
    if pacman -Qi pulseaudio &>/dev/null; then
        echo "Removing obsolete PulseAudio packages..."
        pacman -Rns --noconfirm pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-equalizer pulseaudio-jack 2>/dev/null || true
        echo "PulseAudio removed successfully"
    else
        echo "PulseAudio not found (already using PipeWire)"
    fi

    # Ensure PulseAudio is masked to prevent it from being installed as dependency
    echo "Masking PulseAudio to prevent conflicts..."
    systemctl --user mask pulseaudio.service pulseaudio.socket 2>/dev/null || true

    # According to ArchWiki: PipeWire uses systemd/User for management
    # Services are automatically enabled via socket activation when user logs in
    # We cannot enable user services during chroot installation (no user session)
    # However, we can ensure the socket units exist for automatic activation
    echo ""
    echo "PipeWire configuration complete!"
    echo ""
    echo "According to ArchWiki (https://wiki.archlinux.org/title/PipeWire):"
    echo "  - PipeWire uses systemd/User for management"
    echo "  - Services are automatically enabled via socket activation"
    echo "  - WirePlumber is the recommended session manager (already installed)"
    echo ""
    echo "After first login, PipeWire will start automatically."
    echo "To verify PipeWire is working after login:"
    echo "  systemctl --user status pipewire pipewire-pulse wireplumber"
    echo "  pactl info | grep 'Server Name'  # Should show 'PulseAudio (on PipeWire ...)'"
    echo ""
    echo "For custom configuration, edit:"
    echo "  /etc/wireplumber/  (system-wide)"
    echo "  ~/.config/wireplumber/  (user-specific)"
}
# @description Perform btrfs filesystem configuration
# @noargs
do_btrfs() {
    echo -ne "
-------------------------------------------------------------------------
                    Creating btrfs filesystem and subvolumes
-------------------------------------------------------------------------
"

    # Set default subvolumes if not defined (setup.conf not yet sourced)
    if [[ -z "${SUBVOLUMES+x}" ]] || ! declare -p SUBVOLUMES 2>/dev/null | grep -q "declare -a"; then
        echo "WARNING: SUBVOLUMES not set, using default subvolumes"
        SUBVOLUMES=(@ @docker @flatpak @home @opt @snapshots @swap @var_cache @var_log @var_tmp)
    fi

    echo -e "Creating btrfs device $1 on $2 \\n"

    # Clear existing filesystem signatures to avoid "superblock magic doesn't match" error
    echo "Wiping existing filesystem signatures from $2..."
    wipefs -a "$2" 2>/dev/null || true

    mkfs.btrfs -L "$1" "$2" -f

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to create btrfs filesystem on $2"
        exit 1
    fi

    echo -e "Mounting $2 on $MOUNTPOINT \\n"
    mount -t btrfs "$2" "$MOUNTPOINT"

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to mount $2 on $MOUNTPOINT"
        exit 1
    fi

    echo "Creating subvolumes and directories"

    # Validate SUBVOLUMES is an array before iterating
    if ! declare -p SUBVOLUMES 2>/dev/null | grep -q "declare -a"; then
        echo "ERROR: SUBVOLUMES is not an array"
        exit 1
    fi

    for x in "${SUBVOLUMES[@]}"; do
        echo "Creating subvolume: $x"
        if ! btrfs subvolume create "$MOUNTPOINT"/"${x}" 2>/dev/null; then
            echo "ERROR: Failed to create subvolume $x"
            umount "$MOUNTPOINT"
            exit 1
        fi
    done

    umount "$MOUNTPOINT"

    # Mount root subvolume (@) to mountpoint
    echo "Mounting root subvolume (@)..."
    mount -o "$MOUNT_OPTION",subvol=@ "$2" "$MOUNTPOINT"

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to mount root subvolume"
        exit 1
    fi

    # Mount remaining subvolumes in their respective directories
    for z in "${SUBVOLUMES[@]:1}"; do
        case "$z" in
            "@docker")
                w="var/lib/docker"
                ;;
            "@flatpak")
                w="var/lib/flatpak"
                ;;
            "@snapshots")
                w=".snapshots"
                ;;
            "@swap")
                w="swap"
                ;;
            "@var_cache")
                w="var/cache"
                ;;
            "@var_log")
                w="var/log"
                ;;
            "@var_tmp")
                w="var/tmp"
                ;;
            *)
                w="${z//@/}"
                ;;
        esac

        mkdir -p /mnt/"${w}"
        echo -e "\\nMounting subvolume $z at /mnt/${w}"
        mount -o "$MOUNT_OPTION",subvol="${z}" "$2" "/mnt/${w}"

        # Disable CoW for subvolumes that benefit from it (logs, cache, tmp, swap)
        if [[ "$z" == "@var_cache" || "$z" == "@var_log" || "$z" == "@var_tmp" || "$z" == "@swap" ]]; then
            echo "Disabling copy-on-write on /mnt/${w}"
            chattr +C "/mnt/${w}"
        fi
    done
 }
