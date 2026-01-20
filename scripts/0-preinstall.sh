#!/usr/bin/env bash
#github-action genshdoc
#
# @file Preinstall
# @brief Contains the steps necessary to configure and pacstrap the install to selected drive.
# @stdout Output routed to install.log
# @stderror Output routed to install.log

show_logo

# Get country code for mirror selection
echo -e "\nDetecting country code for mirror configuration..."
if iso=$(curl -4 -s --max-time 5 ifconfig.co/country-iso); then
    export iso
    echo "Detected country code: $iso"
else
    # Fallback to US if curl fails
    export iso="US"
    echo "Warning: Could not detect country code, using US as default"
fi
timedatectl set-ntp true
pacman -Sy --noconfirm --color=always archlinux-keyring # update keyrings to latest to prevent packages failing to install
pacman -Sy --noconfirm --needed --color=always pacman-contrib reflector rsync grub
sed -i \
    -e '/^#ParallelDownloads/s/^#//' \
    -e '/^ParallelDownloads/s/=.*/= 6/' \
    -e '/^#VerbosePkgLists/s/^#//' \
    -e '/^#Color/s/^#//' \
    /etc/pacman.conf

# Update mirrors
mirrorlist_update

# Format Disk
format_disk

# Make filesystems
create_filesystems

# mount target (boot partition only for UEFI systems)
if [[ -d "/sys/firmware/efi" ]]; then
    # UEFI system: Mount EFI partition to /mnt/boot
    echo "UEFI system detected - Mounting EFI partition..."
    mkdir -p /mnt/boot
    mount -t vfat -L EFIBOOT /mnt/boot/
else
    # Legacy BIOS system: No separate boot partition to mount
    # BIOS Boot partition (ef02) is not mounted - GRUB uses it directly
    echo "Legacy BIOS system detected - No EFI partition to mount"
    mkdir -p /mnt/boot
fi
mount_check


# Function to install the Arch base system using pacstrap on 'software-install.sh'
arch_install


# Configure GPG, copies necessary files to a mounted Arch Linux installation, and generates the filesystem table (fstab).
echo -e "\n Adding keyserver to gpg.conf"
echo "keyserver hkp://keyserver.ubuntu.com" >>/mnt/etc/pacman.d/gnupg/gpg.conf

echo -e "\n Copying $SCRIPT_DIR to /mnt/root/archinstaller"
cp -R "${SCRIPT_DIR}" /mnt/root/archinstaller

echo -e "\n Copying mirrorlist to /mnt/etc/pacman.d/mirrorlist"
cp "/etc/pacman.d/mirrorlist" "/mnt/etc/pacman.d/mirrorlist"

echo -e "\n Copying pacman file configuration to /mnt/etc/pacman.conf"
cp "/etc/pacman.conf" "/mnt/etc/pacman.conf"

echo -e "\n Generating fstab"
# genfstab -L /mnt >>/mnt/etc/fstab
genfstab -U /mnt >> /mnt/etc/fstab
sed -i 's/subvolid=.*,//' /mnt/etc/fstab

echo "
  Generated /etc/fstab:
"
cat /mnt/etc/fstab


# Install the bootloader for the Arch base system, this function is located on 'software-install.sh'
bootloader_install


# Configure swap memory settings for systems with limited resources, function is located on 'system-config.sh'
low_memory_config


echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 1-setup.sh
-------------------------------------------------------------------------
"
