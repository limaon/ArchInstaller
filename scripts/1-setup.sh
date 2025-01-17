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


# Update the mirrorlist for optimal package download speeds on 'system-config.sh'
mirrorlist_update


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
graphics_install


# If this file run without configuration, ask for basic user info before setting up user
if ! source ${HOME}/archinstaller/configs/setup.conf; then
    user_info
fi


# Check if the filesystem is LUKS; if so, update mkinitcpio
# configuratn to include encryption support
if [[ "${FS}" == "luks" ]]; then
    # Making sure to edit mkinitcpio conf if luks is selected
    # add encrypt in mkinitcpio.conf before filesystems in hooks
    sed -i 's/filesystems/encrypt &/g' /etc/mkinitcpio.conf
    # making mkinitcpio with linux kernel
    mkinitcpio -p linux
fi


echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 2-user.sh
-------------------------------------------------------------------------
"
