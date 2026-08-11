#!/usr/bin/env bash
#github-action genshdoc
#
# @file Setup
# @brief Configures installed system, installs base packages, and creates user.
# @stdout Output routed to install.log
# @stderror Output routed to install.log

# source utility scripts
for filename in /root/archinstaller/scripts/utils/*.sh; do
    [ -e "$filename" ] || continue
    # shellcheck source=./utils/*.sh
    source "$filename"
done
source "$HOME"/archinstaller/configs/setup.conf

show_logo

# Configure network settings for the Arch installation
# process on 'software-install.sh'
network_install

pacman -S --noconfirm --needed --color=always pacman-contrib curl
pacman -S --noconfirm --needed --color=always rsync grub arch-install-scripts git

# Configures makepkg settings based on the number
# of CPU cores available on 'system-config.sh'
cpu_config

# Configures the system's locale and timezone
# settings on 'system-config.sh'
locale_config

# Add sudo no password rights
sed -Ei 's/^# (%wheel ALL=\(ALL(:ALL)?\) NOPASSWD: ALL)/\1/' /etc/sudoers

# Enables the multilib repository and adds the chaotic-aur repository
# to the system's package manager configuration 'system-config.sh'
extra_repos

# Installs the base Arch Linux system by parsing a JSON file for
# package names and using pacman to install them on 'software-install.sh'.
base_install

# Installs the appropriate CPU microcode based on the detected
# processor type (Intel or AMD) on 'software-install.sh'.
microcode_install

# Detects the GPU type using lspci and installs the appropriate
# graphics drivers for NVIDIA, AMD, or Intel graphics on 'software-install.sh'
if [[ "$INSTALL_TYPE" != "SERVER" ]]; then
    graphics_install
fi

# Function to apply desktop environment theming based on user selection
# during FULL installation on 'software-install.sh'
user_theming

# Configure base skel directory before creating user (so user gets configs automatically)
# function from 'system-config.sh'
configure_base_skel

# If this file run without configuration, ask for basic user info before setting up user
if ! source "$HOME"/archinstaller/configs/setup.conf; then
    user_info
fi

# Adds a new user with the specified username and password, creates a
# home directory and assign to groups 'system-config.sh'
add_user

# Check if the filesystem is LUKS; if so, add sd-encrypt hook and rebuild initramfs
# According to Arch Wiki, use sd-encrypt (systemd-based) with systemd initramfs
# https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LUKS_on_a_partition
if [[ "${FS}" == "luks" ]]; then
    echo "Adding sd-encrypt hook to mkinitcpio for LUKS..."
    # Add sd-encrypt hook BEFORE filesystems in HOOKS array
    sed -i 's/\(block\) filesystems/\1 sd-encrypt filesystems/' /etc/mkinitcpio.conf
    echo "Rebuilding initramfs for LUKS..."
    mkinitcpio -p linux
    mkinitcpio -p linux-lts
fi

echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 2-user.sh
-------------------------------------------------------------------------
"
