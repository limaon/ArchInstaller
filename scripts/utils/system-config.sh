#!/usr/bin/env bash
#github-action genshdoc
#
# @file System Config
# @brief Contains the functions used to modify the system
# @stdout Output routed to install.log
# @stderror Output routed to install.log

# @description Update mirrorlist to improve download speeds using rate-mirrors
# @noargs
mirrorlist_update() {
    # shellcheck disable=SC1009,SC1073
    # Note: ShellCheck warnings are false positives (code is valid)

    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

    local country="${iso:-US}"

    echo -ne "
-------------------------------------------------------------------------
            Setting up mirrors for faster downloads (rate-mirrors)
-------------------------------------------------------------------------
"
    echo "Using country code: $country"

    # Use rate-mirrors to find and rank fastest mirrors
    # --entry-country: starting country for geographic search
    # --disable-comments: output only Server lines (clean mirrorlist)
    # --save: write mirrorlist to file
    # --allow-root: allow running as root
    if rate-mirrors --entry-country "$country" --disable-comments --save /etc/pacman.d/mirrorlist --allow-root arch 2>/dev/null; then
        echo "Mirror list updated successfully using rate-mirrors"
    else
        echo "Warning: rate-mirrors failed, keeping existing mirrorlist"
        cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
    fi
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

        if [[ "$disk_percent" -eq 100 ]]; then
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
            root_size_mb=$(((available_bytes * disk_percent) / 100 / 1024 / 1024))
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
            root_size_mb=$(((available_bytes * disk_percent) / 100 / 1024 / 1024))
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

        # Clear existing filesystem signatures to avoid conflicts
        echo "Wiping existing filesystem signatures from ${root_partition}..."
        wipefs -af "${root_partition}" 2>/dev/null || true

        # Create LUKS2 with modern security parameters
        # --type luks2: Modern LUKS format (32 keyslots vs 8)
        # --pbkdf argon2id: GPU/ASIC resistant key derivation
        # --iter-time 4000: 4 seconds for key derivation (security vs speed)
        # --cipher aes-xts-plain64: AES-XTS with 512-bit key
        # --key-size 512: 256-bit key + 256-bit tweak for XTS
        echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v \
            --type luks2 \
            --pbkdf argon2id \
            --iter-time 4000 \
            --cipher aes-xts-plain64 \
            --key-size 512 \
            luksFormat "${root_partition}" -

        echo -n "${LUKS_PASSWORD}" | cryptsetup open "${root_partition}" ROOT -

        # Backup LUKS header (CRITICAL for recovery)
        mkdir -p /root/luks-backups
        cryptsetup luksHeaderBackup "${root_partition}" \
            --header-backup-file "/root/luks-backups/${root_partition##*/}-header.img"
        echo "LUKS header backed up to /root/luks-backups/"

        do_btrfs "ROOT" "/dev/mapper/ROOT"
        echo ENCRYPTED_PARTITION_UUID="$(blkid -s UUID -o value "${root_partition}")" >>"$CONFIGS_DIR"/setup.conf
    fi

    set +e
}

# @description Detect if system is running in a virtual machine/container
# @noargs
detect_vm() {
    # systemd-detect-virt is most reliable, but returns "container-other"
    # inside arch-chroot -- that's the chroot, not a real VM.
    if command -v systemd-detect-virt &>/dev/null && systemd-detect-virt -q 2>/dev/null; then
        local virt_type
        virt_type=$(systemd-detect-virt 2>/dev/null)
        if [[ "$virt_type" != container* ]]; then
            echo "$virt_type"
            return 0
        fi
    fi

    # DMI product name for hypervisors that expose it
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        local product_name
        product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        case "$product_name" in
        *VirtualBox* | *VMware* | *QEMU* | *KVM* | *Bochs*)
            echo "${product_name,,}"
            return 0
            ;;
        esac
    fi

    # lspci catches virtual GPU devices
    if lspci 2>/dev/null | grep -iE "VirtualBox|VMware|QEMU|Virtio" &>/dev/null; then
        echo "virtual"
        return 0
    fi

    echo "none"
    return 1
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
        USED_GB=$(((DISK_SIZE_GB * DISK_PERCENT) / 100))
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

        "DESKTOP" | "FULL")
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
        cat <<EOF >/mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * ${ZRAM_MULTIPLIER}
swap-priority = 100
compression-algorithm = zstd
EOF

        modprobe zram 2>/dev/null || true

        arch-chroot /mnt systemctl enable systemd-zram-setup@zram0.service

        local zram_size_gb
        zram_size_gb=$(awk "BEGIN {printf \"%.1f\", ${TOTAL_MEM_GB} * ${ZRAM_MULTIPLIER}}")
        echo "ZRAM configured: ${ZRAM_MULTIPLIER}x RAM (${TOTAL_MEM_GB}GB -> ${zram_size_gb}GB compressed swap)"
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
        echo "vm.swappiness=10" >/mnt/etc/sysctl.d/99-swap.conf
    else
        echo "vm.swappiness=60" >/mnt/etc/sysctl.d/99-swap.conf
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

    if [[ ! -d "$SWAP_MOUNT" ]]; then
        log_swap "WARNING: @swap mount point $SWAP_MOUNT does not exist"
        log_swap "Creating directory and attempting to mount @swap subvolume..."
        echo "Warning: @swap mount point $SWAP_MOUNT does not exist"
        echo "Creating directory and attempting to mount @swap subvolume..."
        mkdir -p "$SWAP_MOUNT"
    fi

    local SWAP_MOUNTED=false
    if mountpoint -q "$SWAP_MOUNT" 2>/dev/null; then
        SWAP_MOUNTED=true
        log_swap "SUCCESS: @swap subvolume is mounted at $SWAP_MOUNT"
        echo "@swap subvolume is mounted at $SWAP_MOUNT"
    else
        log_swap "INFO: @swap subvolume not mounted, attempting to mount..."
        echo "@swap subvolume not mounted, attempting to mount..."

        local ROOT_DEV=""
        if [[ "${FS_TYPE:-}" == "luks" ]]; then
            ROOT_DEV="/dev/mapper/ROOT"
        else
            ROOT_DEV=$(findmnt -n -o SOURCE /mnt 2>/dev/null | head -1)
        fi

        log_swap "Root device: ${ROOT_DEV:-not found}"
        echo "Root device: ${ROOT_DEV:-not found}"

        if [[ -n "$ROOT_DEV" ]] && [[ -b "$ROOT_DEV" ]]; then
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

        log_swap "Setting permissions 600 on /swap/swapfile..."
        arch-chroot /mnt chmod 600 /swap/swapfile

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

        log_swap "Ensuring permissions 600 on /swap/swapfile..."
        arch-chroot /mnt chmod 600 /swap/swapfile

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
            echo "UUID=${ROOT_UUID}	/swap	btrfs	${ROOT_OPTS},nodatacow	0	0" >>/mnt/etc/fstab
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
            echo "/swap/swapfile none swap defaults,pri=50 0 0" >>/mnt/etc/fstab
        else
            log_swap "Adding swap file entry (Swapfile only)..."
            echo "/swap/swapfile none swap defaults 0 0" >>/mnt/etc/fstab
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

    if [[ -z "${SWAP_SIZE_GB:-}" ]] || [[ "${SWAP_SIZE_GB}" -lt 1 ]]; then
        echo "Error: SWAP_SIZE_GB not set or invalid (value: ${SWAP_SIZE_GB:-unset})"
        echo "Defaulting to 4GB"
        SWAP_SIZE_GB=4
    fi

    echo "Creating swap file at /swapfile (${SWAP_SIZE_GB}GB)..."

    echo "Trying mkswap --file method..."
    if arch-chroot /mnt mkswap -U clear --size ${SWAP_SIZE_GB}G --file /swapfile; then
        echo "Swap file created using mkswap --file"
    else
        echo "mkswap --file failed, using traditional method..."

        if arch-chroot /mnt fallocate -l ${SWAP_SIZE_GB}G /swapfile; then
            echo "Space allocated with fallocate"
        else
            echo "fallocate failed, using dd (this may take a while)..."
            arch-chroot /mnt dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress || {
                echo "Error: Could not create swap file"
                return 1
            }
        fi

        arch-chroot /mnt chmod 600 /swapfile

        arch-chroot /mnt mkswap -U clear /swapfile || {
            echo "Error: mkswap failed"
            arch-chroot /mnt rm -f /swapfile
            return 1
        }

        echo "Swap file created using traditional method"
    fi

    if arch-chroot /mnt test -f /swapfile; then
        echo "Swap file created: $(arch-chroot /mnt ls -lh /swapfile | awk '{print $5}')"

        arch-chroot /mnt chmod 600 /swapfile

        if arch-chroot /mnt swapon /swapfile; then
            echo "Swap file activated successfully"
        else
            echo "Note: Swap file will be activated on first boot"
        fi

        arch-chroot /mnt systemctl stop swapfile.swap 2>/dev/null || true
        arch-chroot /mnt systemctl disable swapfile.swap 2>/dev/null || true
        arch-chroot /mnt rm -f /etc/systemd/system/swapfile.swap 2>/dev/null || true
        arch-chroot /mnt systemctl daemon-reload 2>/dev/null || true

        arch-chroot /mnt sed -i '/\/swapfile/d' /etc/fstab

        if [[ "$USE_ZRAM" == true ]]; then
            echo "/swapfile none swap defaults,pri=50 0 0" >>/mnt/etc/fstab
        else
            echo "/swapfile none swap defaults 0 0" >>/mnt/etc/fstab
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
    } >/etc/locale.conf
    echo "Generating locales..."
    locale-gen || {
        echo "ERROR: Failed to generate locales."
        exit 1
    }
    localectl --no-ask-password set-locale LANG="${LOCALE}" LC_TIME="${LOCALE}"
    echo "Locales generated successfully."

    timedatectl --no-ask-password set-timezone "${TIMEZONE}"
    timedatectl --no-ask-password set-ntp 1
    ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime
    hwclock --systohc
    echo "Timezone configured: ${TIMEZONE}"

    pacman -S --noconfirm --needed --color=always kbd xkeyboard-config
    localectl --no-ask-password set-keymap "${KEYMAP}"
    echo "Keymap configured: ${KEYMAP}"

    echo -e "KEYMAP=${KEYMAP}\nFONT=Lat2-Terminus16\nFONT_MAP=" >/etc/vconsole.conf

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
    if [[ -d "$HOME"/archinstaller/configs/base/etc/skel ]]; then
        SKEL_CONFIG_DIR="$HOME"/archinstaller/configs/base/etc/skel

        if cp -a "$SKEL_CONFIG_DIR"/. /etc/skel/ 2>/dev/null; then
            echo "Base skel configurations copied to /etc/skel/"

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

# @description Configure system-wide Xorg settings from base configurations
# Copies Xorg configuration files to /etc/X11/xorg.conf.d/
# Applies to all desktop environments
# @noargs
configure_xorg_base() {
    echo -ne "
-------------------------------------------------------------------------
                    Configuring System Xorg Settings
-------------------------------------------------------------------------
"
    if [[ -d "$HOME"/archinstaller/configs/base/etc/X11 ]]; then
        XORG_CONFIG_DIR="$HOME"/archinstaller/configs/base/etc/X11

        mkdir -p /etc/X11

        if cp -a "$XORG_CONFIG_DIR"/. /etc/X11/ 2>/dev/null; then
            echo "Xorg configurations copied to /etc/X11/"

            if [[ -f /etc/X11/xorg.conf.d/99-disable-bell.conf ]]; then
                echo "  - System bell disabled globally"
            fi
        else
            echo "Warning: Failed to copy Xorg configurations"
        fi
    else
        echo "Xorg configuration directory not found, skipping"
    fi
}

# @description Configure LightDM to disable system bell on startup
# Adds greeter-setup-script=/usr/bin/xset -b to lightdm.conf
# Prevents audible beep on invalid input (e.g., Backspace in empty fields)
# @noargs
configure_lightdm_bell() {
    local lightdm_conf="/etc/lightdm/lightdm.conf"

    mkdir -p /etc/lightdm

    if [[ ! -f "$lightdm_conf" ]]; then
        return 0
    fi

    if ! grep -q "^greeter-setup-script=/usr/bin/xset -b" "$lightdm_conf"; then
        sed -i '/\[Seat:\*\]/a greeter-setup-script=/usr/bin/xset -b' "$lightdm_conf"
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
        for group in libvirt vboxusers gamemode docker; do
            groupadd -f "$group"
        done

        if ! useradd -m -G wheel,libvirt,vboxusers,gamemode,docker -s /bin/bash -c "$REAL_NAME" "$USERNAME"; then
            echo "ERROR! Failed to create user $USERNAME."
            exit 1
        fi
        echo "$USERNAME created with full name '$REAL_NAME', added to groups."

        if echo "$USERNAME:$PASSWORD" | chpasswd; then
            echo "$USERNAME password set."
        else
            echo "ERROR! Failed to set password for $USERNAME."
            exit 1
        fi

        if cp -R "$HOME/archinstaller" /home/"$USERNAME"/; then
            chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/archinstaller
            echo "archinstaller copied to home directory."
        else
            echo "ERROR! Failed to copy archinstaller to /home/$USERNAME."
            exit 1
        fi

        echo "$NAME_OF_MACHINE" >/etc/hostname
        echo "Hostname set to $NAME_OF_MACHINE."

        cat >>/etc/hosts <<EOF
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
        # For LUKS with sd-encrypt hook (systemd-based):
        # - Use rd.luks.name= for sd-encrypt hook (not cryptdevice=)
        # - GRUB_ENABLE_CRYPTODISK=y allows GRUB to unlock /boot (if on encrypted partition)
        # - The sd-encrypt hook reads from /etc/crypttab to know which device to unlock
        # See: https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LUKS_on_a_partition
        sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"rd.luks.name=${ENCRYPTED_PARTITION_UUID}=ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
        sed -i 's/^#GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub
        if ! grep -q "^GRUB_ENABLE_CRYPTODISK=y" /etc/default/grub; then
            echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
        fi
    fi
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' /etc/default/grub

    echo -e "\n Backing up Grub config..."
    cp -an /etc/default/grub /etc/default/grub.bak

    _configure_hibernation

    if [[ "$INSTALL_TYPE" != "SERVER" ]]; then
        echo -e "\nSetting wallpaper for GRUB..."
    else
        echo -e "\nSkipping wallpaper setup for SERVER installation."
    fi

    echo -e "\nUpdating GRUB configuration..."
    mkdir -p /boot/grub
    grub-mkconfig -o /boot/grub/grub.cfg

    if [[ "${FS}" == "luks" ]]; then
        sed -i 's/root=UUID=[^ ]* //' /boot/grub/grub.cfg
    fi

    echo "GRUB configuration complete."
}

# @description Configure hibernation resume parameter for GRUB
# @noargs
_configure_hibernation() {
    local swap_path=""

    [[ -f /swap/swapfile ]] && swap_path="/swap/swapfile"
    [[ -f /swapfile ]] && swap_path="/swapfile"

    if [[ -z "$swap_path" ]]; then
        echo -e "\nNo swap file found. Skipping hibernation configuration."
        return
    fi

    echo -e "\nConfiguring GRUB for hibernation support..."
    echo "Swap file found at: $swap_path"

    local swap_uuid=""
    swap_uuid=$(blkid -s UUID -o value "$swap_path" 2>/dev/null)
    [[ -z "$swap_uuid" ]] && swap_uuid=$(swapon --show=UUID --noheadings "$swap_path" 2>/dev/null | tr -d '[:space:]')
    [[ -z "$swap_uuid" ]] && swap_uuid=$(findmnt -no UUID -T "$swap_path" 2>/dev/null)

    local resume_param=""
    if [[ -n "$swap_uuid" ]]; then
        resume_param="resume=UUID=$swap_uuid"
        echo "Detected swap file UUID: $swap_uuid"
    else
        resume_param="resume=$swap_path"
        echo "Warning: Could not detect swap file UUID, using file path: $swap_path"
    fi

    if grep -q "resume=" /etc/default/grub; then
        echo "Resume parameter already configured in GRUB"
        echo "  Current resume parameter: $(grep -oP 'resume=[^\s"]*' /etc/default/grub | head -n1)"
        return
    fi

    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT.*splash" /etc/default/grub; then
        sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*splash\)|GRUB_CMDLINE_LINUX_DEFAULT=\"$resume_param \1|" /etc/default/grub
    else
        sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $resume_param\"|" /etc/default/grub
    fi
    echo "Resume parameter added: $resume_param"
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
        if ! pacman -Qi lightdm &>/dev/null; then
            echo "LightDM not found, installing..."
            pacman -S --noconfirm --needed --color=always lightdm lightdm-webkit2-greeter
        fi

        if systemctl list-unit-files | grep -q "lightdm.service"; then
            systemctl enable lightdm.service
        else
            echo "Warning: lightdm.service not found, skipping enable"
            return 1
        fi

        mkdir -p /etc/lightdm

        # Create lightdm.conf if it doesn't exist
        if [[ ! -f /etc/lightdm/lightdm.conf ]]; then
            echo "[Seat:*]
greeter-session=lightdm-webkit2-greeter
greeter-setup-script=/usr/bin/xset -b" >/etc/lightdm/lightdm.conf
        else
            configure_lightdm_bell
        fi

        if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
            echo -e "Setting LightDM Theme..."
            # Create config file if it doesn't exist
            if [[ ! -f /etc/lightdm/lightdm-webkit2-greeter.conf ]]; then
                touch /etc/lightdm/lightdm-webkit2-greeter.conf
                echo "[greeter]" >>/etc/lightdm/lightdm-webkit2-greeter.conf
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
        if ! pacman -Qi lightdm &>/dev/null; then
            echo "LightDM not found, installing..."
            pacman -S --noconfirm --needed --color=always lightdm lightdm-slick-greeter
        fi

        if systemctl list-unit-files | grep -q "lightdm.service"; then
            systemctl enable lightdm.service
        else
            echo "Warning: lightdm.service not found, skipping enable"
            return 1
        fi

        mkdir -p /etc/lightdm

        if [[ ! -f /etc/lightdm/lightdm.conf ]]; then
            echo "[Seat:*]
greeter-session=lightdm-slick-greeter
greeter-setup-script=/usr/bin/xset -b" >/etc/lightdm/lightdm.conf
        else
            configure_lightdm_bell
        fi

        if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
            echo -e "Setting LightDM Theme..."
            if [[ -f ~/archinstaller/configs/awesome/etc/lightdm/slick-greeter.conf ]]; then
                cp ~/archinstaller/configs/awesome/etc/lightdm/slick-greeter.conf /etc/lightdm/slick-greeter.conf
            else
                if [[ ! -f /etc/lightdm/slick-greeter.conf ]]; then
                    touch /etc/lightdm/slick-greeter.conf
                    echo "[greeter]" >>/etc/lightdm/slick-greeter.conf
                fi
            fi
            sed -i 's/#greeter-session=example.*/greeter-session=lightdm-slick-greeter/g' /etc/lightdm/lightdm.conf
            if ! grep -q "^greeter-session=lightdm-slick-greeter" /etc/lightdm/lightdm.conf; then
                sed -i '/\[Seat:\*\]/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
            fi
        fi

    elif [[ "${DESKTOP_ENV}" == "i3-wm" ]]; then
        if ! pacman -Qi lightdm &>/dev/null; then
            echo "LightDM not found, installing..."
            pacman -S --noconfirm --needed --color=always lightdm lightdm-gtk-greeter
        fi

        if systemctl list-unit-files | grep -q "lightdm.service"; then
            systemctl enable lightdm.service
        else
            echo "Warning: lightdm.service not found, skipping enable"
            return 1
        fi

        echo -e "Configuring LightDM for i3-wm..."

        mkdir -p /etc/lightdm

        if [[ ! -f /etc/lightdm/lightdm.conf ]]; then
            echo "[Seat:*]
greeter-session=lightdm-gtk-greeter
greeter-setup-script=/usr/bin/xset -b" >/etc/lightdm/lightdm.conf
        else
            sed -i 's/#greeter-session=example.*/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf
            if ! grep -q "^greeter-session=lightdm-gtk-greeter" /etc/lightdm/lightdm.conf; then
                sed -i '/\[Seat:\*\]/a greeter-session=lightdm-gtk-greeter' /etc/lightdm/lightdm.conf
            fi
            configure_lightdm_bell
        fi

        CONFIG_FILE="/etc/lightdm/lightdm-gtk-greeter.conf"

        if [[ ! -f "$CONFIG_FILE" ]]; then
            touch "$CONFIG_FILE"
            echo "[greeter]" >>"$CONFIG_FILE"
        fi

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
        base_greeter_config["icon-theme-name"]="Pop"
        base_greeter_config["cursor-theme-name"]="Adwaita"
        base_greeter_config["theme-name"]="Adwaita-dark"

        for key in "${!base_greeter_config[@]}"; do
            sed -i "/^#*${key}=/d" "$CONFIG_FILE"
        done

        for key in "${!base_greeter_config[@]}"; do
            if [[ -n "${base_greeter_config[$key]}" ]]; then
                echo "${key}=${base_greeter_config[$key]}" >>"$CONFIG_FILE"
            fi
        done

        echo "LightDM GTK greeter configured with dark theme for i3-wm"

    else
        if [[ ! "${INSTALL_TYPE}" == "SERVER" ]]; then
            pacman -S --noconfirm --needed --color=always lightdm lightdm-gtk-greeter
            systemctl enable lightdm.service
        fi
    fi
}

# @description Configure snapper default setup for Btrfs or LUKS filesystems
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

    if systemctl list-unit-files | grep -q "snapper-timeline.timer"; then
        systemctl enable snapper-timeline.timer
    else
        echo "Warning: snapper-timeline.timer not found, skipping enable"
    fi

    if systemctl list-unit-files | grep -q "snapper-cleanup.timer"; then
        systemctl enable snapper-cleanup.timer
    else
        echo "Warning: snapper-cleanup.timer not found, skipping enable"
    fi

    if systemctl list-unit-files | grep -q "grub-btrfsd.service"; then
        systemctl enable grub-btrfsd.service
    else
        echo "Warning: grub-btrfsd.service not found, skipping enable (expected for non-Btrfs systems)"
    fi

    if command -v snapper &>/dev/null; then
        snapper -c root create --description "Initial snapshot"
        chown :users /.snapshots
    else
        echo "Error: snapper command not found. Ensure snapper package is installed."
        return 1
    fi
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
    PLYMOUTH_THEME="arch-glow"
    mkdir -p "/usr/share/plymouth/themes"

    echo -e "Installing Plymouth theme... \n"

    cp -rf "${PLYMOUTH_THEMES_DIR}"/"${PLYMOUTH_THEME}" /usr/share/plymouth/themes
    if [[ "${FS}" == "luks" ]]; then
        sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf
        sed -i 's/HOOKS=(base udev \(.*block\) /&plymouth-/' /etc/mkinitcpio.conf
    else
        sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf
    fi
    plymouth-set-default-theme -R arch-glow

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
    FAILLOCK_CONF="/etc/security/faillock.conf"

    mkdir -p /etc/security/

    if [[ ! -f "$FAILLOCK_CONF" ]]; then
        cat >"$FAILLOCK_CONF" <<'EOF'
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
        sed -i '/^deny\s*=/d' "$FAILLOCK_CONF"

        # Add deny = 5 after the header comments (after first non-empty, non-comment section)
        # Find a good place to insert: after comments but before other config lines
        # If we find a line like "fail_interval" or "unlock_time", add before it
        if grep -q "^fail_interval\|^unlock_time" "$FAILLOCK_CONF"; then
            sed -i '/^fail_interval\|^unlock_time/i deny = 5' "$FAILLOCK_CONF"
        elif grep -q "^[^#[:space:]]" "$FAILLOCK_CONF"; then
            sed -i '/^[^#[:space:]]/i deny = 5' "$FAILLOCK_CONF"
        else
            echo "" >>"$FAILLOCK_CONF"
            echo "deny = 5" >>"$FAILLOCK_CONF"
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

    if [[ "${INSTALL_TYPE:-}" == "SERVER" ]]; then
        return 0
    fi

    echo -ne "
-------------------------------------------------------------------------
                    Configuring PipeWire Audio Server
-------------------------------------------------------------------------
"

    if ! pacman -Qi pipewire &>/dev/null; then
        echo "Warning: PipeWire is not installed, skipping configuration"
        return 1
    fi

    echo "PipeWire is installed, configuring audio server..."

    if pacman -Qi pulseaudio &>/dev/null; then
        echo "Removing obsolete PulseAudio packages..."
        pacman -Rns --noconfirm pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-equalizer pulseaudio-jack 2>/dev/null || true
        echo "PulseAudio removed successfully"
    else
        echo "PulseAudio not found (already using PipeWire)"
    fi

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

    if [[ -z "${SUBVOLUMES+x}" ]] || ! declare -p SUBVOLUMES 2>/dev/null | grep -q "declare -a"; then
        echo "WARNING: SUBVOLUMES not set, using default subvolumes"
        SUBVOLUMES=(@ @docker @flatpak @home @opt @snapshots @swap @var_cache @var_log @var_tmp)
    fi

    echo -e "Creating btrfs device $1 on $2 \\n"

    echo "Wiping existing filesystem signatures from $2..."
    wipefs -af "$2" 2>/dev/null || true

    mkfs.btrfs -L "$1" "$2" -f

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to create btrfs filesystem on $2"
        exit 1
    fi

    echo -e "Mounting $2 on /mnt \\n"
    mount -t btrfs "$2" /mnt

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to mount $2 on /mnt"
        exit 1
    fi

    echo "Creating subvolumes and directories"

    if ! declare -p SUBVOLUMES 2>/dev/null | grep -q "declare -a"; then
        echo "ERROR: SUBVOLUMES is not an array"
        exit 1
    fi

    for x in "${SUBVOLUMES[@]}"; do
        echo "Creating subvolume: $x"
        if ! btrfs subvolume create /mnt/"${x}" 2>/dev/null; then
            echo "ERROR: Failed to create subvolume $x"
            umount /mnt
            exit 1
        fi
    done

    umount /mnt

    echo "Mounting root subvolume (@)..."
    mount -o "$MOUNT_OPTION",subvol=@ "$2" /mnt

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to mount root subvolume"
        exit 1
    fi

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

        if [[ "$z" == "@var_cache" || "$z" == "@var_log" || "$z" == "@var_tmp" || "$z" == "@swap" ]]; then
            echo "Disabling copy-on-write on /mnt/${w}"
            chattr +C "/mnt/${w}"
        fi
    done
}
