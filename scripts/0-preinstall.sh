#!/usr/bin/env bash
#github-action genshdoc
#
# @file Preinstall
# @brief Contains the steps necessary to configure and pacstrap the install to selected drive.
# @stdout Output routed to install.log
# @stderror Output routed to install.log

show_logo

iso=$(curl -4 ifconfig.co/country-iso)
export iso
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

# mount target
mkdir -p /mnt/boot/efi
mount -t vfat -L EFIBOOT /mnt/boot/
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
