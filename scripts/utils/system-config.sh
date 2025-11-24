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
    # Verifica se o reflector está instalado
    if command -v reflector &> /dev/null; then
        pacman -S --noconfirm --needed --color=always reflector
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
        echo -ne "
-------------------------------------------------------------------------
                    Setting up mirrors for faster downloads (reflector)
-------------------------------------------------------------------------
"
        reflector -a 48 -c "$iso" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
    else
        echo -ne "
-------------------------------------------------------------------------
                    Reflector not found or get a error, using rankmirrors
-------------------------------------------------------------------------
"
        pacman -S --noconfirm --needed --color=always curl
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
        curl -s "https://archlinux.org/mirrorlist/?country=$iso&protocol=https&use_mirror_status=on" \
            | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist
        rankmirrors -n 5 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.temp
        mv /etc/pacman.d/mirrorlist.temp /etc/pacman.d/mirrorlist
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


# @description Perform the btrfs filesystem configuration
# @noargs
do_btrfs() {
    echo -ne "
-------------------------------------------------------------------------
                    Creating btrfs filesystem and subvolumes
-------------------------------------------------------------------------
"
    echo -e "Creating btrfs device $1 on $2 \n"
    mkfs.btrfs -L "$1" "$2" -f

    echo -e "Mounting $2 on $MOUNTPOINT \n"
    mount -t btrfs "$2" "$MOUNTPOINT"

    echo "Creating subvolumes and directories"
    for x in "${SUBVOLUMES[@]}"; do
        btrfs subvolume create "$MOUNTPOINT"/"${x}"
    done

    umount "$MOUNTPOINT"

    # Mount the root subvolume (@) to the mountpoint
    mount -o "$MOUNT_OPTION",subvol=@ "$2" "$MOUNTPOINT"

    # Mount the remaining subvolumes in their respective directories
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
        echo -e "\nMounting subvolume $z at /mnt/${w}"
        mount -o "$MOUNT_OPTION",subvol="${z}" "$2" "/mnt/${w}"

        if [[ "$z" == "@var_cache" || "$z" == "@var_log" || "$z" == "@var_tmp" ]]; then
            echo "Disabling copy-on-write on /mnt/${w}"
            chattr +C "/mnt/${w}"
        fi
    done
}


# @description Intelligently configure swap based on system hardware
# Analyzes RAM, storage type, disk space, and installation type to choose optimal swap strategy
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

    # Detect storage type (SSD = 0, HDD = 1)
    IS_SSD=0
    if [[ -n "${DISK:-}" ]]; then
        ROTA=$(lsblk -n --output TYPE,ROTA "${DISK}" 2>/dev/null | awk '$1=="disk"{print $2}')
        [[ "${ROTA:-1}" == "0" ]] && IS_SSD=1
    fi

    # Detect installation type
    INSTALL_TYPE="${INSTALL_TYPE:-FULL}"

    # Calculate available disk space
    # Check free space in mounted root partition (more accurate)
    AVAILABLE_SPACE_GB=0
    if mountpoint -q /mnt 2>/dev/null; then
        # Get free space in mounted root partition (in GB)
        AVAILABLE_SPACE_GB=$(df -BG /mnt 2>/dev/null | awk 'NR==2 {gsub(/G/, "", $4); print int($4)}' || echo "0")
    elif [[ -n "${DISK:-}" ]] && [[ -b "${DISK}" ]]; then
        # Fallback: calculate from unpartitioned space
        DISK_SIZE_BYTES=$(blockdev --getsize64 "${DISK}" 2>/dev/null || echo "0")
        DISK_SIZE_GB=$((DISK_SIZE_BYTES / 1024 / 1024 / 1024))
        DISK_PERCENT="${DISK_USAGE_PERCENT:-100}"
        USED_GB=$(( (DISK_SIZE_GB * DISK_PERCENT) / 100 ))
        AVAILABLE_SPACE_GB=$((DISK_SIZE_GB - USED_GB))
    fi

    echo "System Analysis:"
    echo "  RAM: ${TOTAL_MEM_GB}GB"
    echo "  Storage: $([[ $IS_SSD -eq 1 ]] && echo "SSD" || echo "HDD")"
    echo "  Installation Type: ${INSTALL_TYPE}"
    echo "  Available Disk Space: ${AVAILABLE_SPACE_GB}GB"
    echo ""

    # Decision logic based on RAM
    SWAP_STRATEGY=""
    SWAP_SIZE_GB=0
    USE_ZRAM=false
    USE_SWAPFILE=false

    if [[ $TOTAL_MEM -lt 4194304 ]]; then
        # <4GB RAM: ZRAM critical
        SWAP_STRATEGY="ZRAM"
        USE_ZRAM=true
        ZRAM_MULTIPLIER=2
        echo "Strategy: ZRAM (2x RAM) - Critical for low RAM systems"

    elif [[ $TOTAL_MEM -lt 8388608 ]]; then
        # 4-8GB RAM
        if [[ $IS_SSD -eq 1 ]]; then
            SWAP_STRATEGY="ZRAM"
            USE_ZRAM=true
            ZRAM_MULTIPLIER=2
            echo "Strategy: ZRAM (2x RAM) - SSD-friendly, fast swap"
        else
            SWAP_STRATEGY="ZRAM+SWAPFILE"
            USE_ZRAM=true
            USE_SWAPFILE=true
            ZRAM_MULTIPLIER=2
            SWAP_SIZE_GB=2
            echo "Strategy: ZRAM (2x RAM) + Swap File (2GB) - ZRAM primary, file backup"
        fi

    elif [[ $TOTAL_MEM -lt 16777216 ]]; then
        # 8-16GB RAM
        if [[ $IS_SSD -eq 1 ]]; then
            SWAP_STRATEGY="ZRAM"
            USE_ZRAM=true
            ZRAM_MULTIPLIER=1
            echo "Strategy: ZRAM (1x RAM) - Light swap, SSD-friendly"
        else
            SWAP_STRATEGY="SWAPFILE"
            USE_SWAPFILE=true
            SWAP_SIZE_GB=4
            echo "Strategy: Swap File (4GB) - Moderate swap needs"
        fi

    elif [[ $TOTAL_MEM -lt 33554432 ]]; then
        # 16-32GB RAM
        SWAP_STRATEGY="SWAPFILE"
        USE_SWAPFILE=true
        if [[ $IS_SSD -eq 1 ]]; then
            SWAP_SIZE_GB=2
            echo "Strategy: Swap File (2GB) - Hibernation support only"
        else
            SWAP_SIZE_GB=4
            echo "Strategy: Swap File (4GB) - Moderate swap needs"
        fi

    else
        # >32GB RAM
        SWAP_STRATEGY="SWAPFILE"
        USE_SWAPFILE=true
        if [[ $IS_SSD -eq 1 ]]; then
            SWAP_SIZE_GB=1
            echo "Strategy: Swap File (1GB) - Minimal swap for hibernation"
        else
            SWAP_SIZE_GB=2
            echo "Strategy: Swap File (2GB) - Minimal swap needs"
        fi
    fi

    # Override for SERVER installations (always use swap file)
    if [[ "$INSTALL_TYPE" == "SERVER" ]]; then
        if [[ "$SWAP_STRATEGY" != *"SWAPFILE"* ]]; then
            SWAP_STRATEGY="SWAPFILE"
            USE_ZRAM=false
            USE_SWAPFILE=true
            SWAP_SIZE_GB=4
            echo "Override: Server installation - Using Swap File (4GB)"
        fi
    fi

    # Check if we have enough disk space for swap file
    # Need at least (SWAP_SIZE_GB + 2GB) free for safety
    REQUIRED_SPACE=$((SWAP_SIZE_GB + 2))
    if [[ "$USE_SWAPFILE" == true ]] && [[ $AVAILABLE_SPACE_GB -lt $REQUIRED_SPACE ]]; then
        if [[ $AVAILABLE_SPACE_GB -gt 0 ]]; then
            echo "Warning: Insufficient disk space (${AVAILABLE_SPACE_GB}GB available, ${REQUIRED_SPACE}GB required)."
            echo "Skipping swap file creation."
        else
            echo "Warning: No disk space available for swap file."
        fi
        USE_SWAPFILE=false
        if [[ "$USE_ZRAM" == false ]]; then
            echo "Note: Consider using ZRAM or freeing disk space for swap."
        fi
    fi

    # Configure ZRAM
    if [[ "$USE_ZRAM" == true ]]; then
        echo ""
        echo "Installing zram-generator..."
        arch-chroot /mnt pacman -S zram-generator --noconfirm --needed

        echo "Configuring zram-generator..."
        mkdir -p /mnt/etc/systemd/
        cat <<EOF > /mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * ${ZRAM_MULTIPLIER}
swap-priority = 100
compression-algorithm = zstd
EOF

        echo "Loading zram module..."
        modprobe zram

        echo "Regenerating initramfs..."
        arch-chroot /mnt mkinitcpio -P

        echo "Enabling systemd-zram-setup@zram0.service..."
        arch-chroot /mnt systemctl enable systemd-zram-setup@zram0.service

        echo "ZRAM configured: ${ZRAM_MULTIPLIER}x RAM (${TOTAL_MEM_GB}GB → $((TOTAL_MEM_GB * ZRAM_MULTIPLIER))GB compressed swap)"
    fi

    # Configure Swap File
    if [[ "$USE_SWAPFILE" == true ]] && [[ $SWAP_SIZE_GB -gt 0 ]]; then
        echo ""
        echo "Creating swap file (${SWAP_SIZE_GB}GB)..."

        # Check filesystem type
        FS_TYPE="${FS:-ext4}"

        # For Btrfs, we need special handling (no CoW, no compression)
        if [[ "$FS_TYPE" == "btrfs" ]] || [[ "$FS_TYPE" == "luks" ]]; then
            echo "Detected Btrfs filesystem - using Btrfs-specific swap file method"

            # Create swap file using mkswap --file (modern method per ArchWiki)
            # For Btrfs, mkswap --file handles CoW and compression automatically
            arch-chroot /mnt mkswap -U clear --size ${SWAP_SIZE_GB}G --file /swapfile

            # Set permissions
            arch-chroot /mnt chmod 600 /swapfile

            # Disable CoW and compression on swap file (Btrfs specific)
            arch-chroot /mnt chattr +C /swapfile || true
            arch-chroot /mnt btrfs property set /swapfile compression none || true
        else
            # For ext4 and other filesystems, use standard method
            echo "Using standard swap file creation method"

            # Create swap file using mkswap --file (modern method per ArchWiki)
            arch-chroot /mnt mkswap -U clear --size ${SWAP_SIZE_GB}G --file /swapfile

            # Set permissions
            arch-chroot /mnt chmod 600 /swapfile
        fi

        # Verify swap file was created successfully
        if arch-chroot /mnt test -f /swapfile; then
            echo "Swap file created successfully"

            # Activate swap file immediately
            if arch-chroot /mnt swapon /swapfile; then
                echo "Swap file activated successfully"
            else
                echo "Warning: Could not activate swap file immediately (may need reboot)"
            fi

            # Remove any existing systemd swap units that might conflict
            arch-chroot /mnt systemctl stop swapfile.swap 2>/dev/null || true
            arch-chroot /mnt systemctl disable swapfile.swap 2>/dev/null || true
            arch-chroot /mnt rm -f /etc/systemd/system/swapfile.swap 2>/dev/null || true
            arch-chroot /mnt systemctl daemon-reload 2>/dev/null || true

            # Add to fstab (per ArchWiki: use file path, not UUID/LABEL)
            # Remove any existing /swapfile entries first
            arch-chroot /mnt sed -i '/\/swapfile/d' /etc/fstab

            # Add correct entry
            if [[ "$USE_ZRAM" == true ]]; then
                # Set priority: lower than ZRAM (100) if ZRAM exists
                echo "/swapfile none swap defaults,pri=50 0 0" >> /mnt/etc/fstab
            else
                echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
            fi

            echo "Swap file added to /etc/fstab"
        else
            echo "Error: Swap file was not created successfully"
        fi

        # Configure swappiness (lower priority than ZRAM if both exist)
        mkdir -p /mnt/etc/sysctl.d
        if [[ "$USE_ZRAM" == true ]]; then
            # ZRAM has priority, swap file is backup
            echo "vm.swappiness=10" >> /mnt/etc/sysctl.d/99-swap.conf
        else
            # Swap file only
            echo "vm.swappiness=60" >> /mnt/etc/sysctl.d/99-swap.conf
        fi

        echo "Swap file configured: ${SWAP_SIZE_GB}GB at /swapfile"
    fi

    echo ""
    echo "Swap configuration complete: ${SWAP_STRATEGY}"
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
        )

        # Background configuration based on installation type
        if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
            # FULL: Use wallpaper image
            base_greeter_config["background"]="/usr/share/backgrounds/archlinux/geolanes.png"
            base_greeter_config["user-background"]="true"
            # Theme configuration (only for FULL installation)
            base_greeter_config["icon-theme-name"]="Pop"
            base_greeter_config["cursor-theme-name"]="Pop"
            base_greeter_config["theme-name"]="Yaru-blue-dark"
        else
            # MINIMAL: Use solid color background
            base_greeter_config["background"]="#6a6a6a"
            base_greeter_config["user-background"]="false"
        fi

        for key in "${!base_greeter_config[@]}"; do
            if grep -q "^#${key}=" "$CONFIG_FILE"; then
                sed -i "s|^#${key}=.*|${key}=${base_greeter_config[$key]}|" "$CONFIG_FILE"
            else
                echo "${key}=${base_greeter_config[$key]}" >> "$CONFIG_FILE"
            fi
        done

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
