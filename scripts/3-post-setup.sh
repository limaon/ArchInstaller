#!/usr/bin/env bash
#github-action genshdoc
#
# @file Post-Setup
# @brief Finalizing installation configurations and cleaning up after script.
# @stdout Output routed to install.log
# @stderror Output routed to install.log

# source utility scripts
for filename in "$HOME"/archinstaller/scripts/utils/*.sh; do
  [ -e "$filename" ] || continue
  # shellcheck source=./utils/*.sh
  source "$filename"
done
source "$HOME"/archinstaller/configs/setup.conf


show_logo


echo -ne "
  Final Setup and Configurations
  GRUB EFI Bootloader Install & Check
"

[[ -d "/sys/firmware/efi" ]] && grub-install --target=x86_64-efi --efi-directory=/boot "${DISK}" --bootloader-id='Arch Linux'


# Function to configure and theme the GRUB boot menu, including setting
# kernel parameters and installing the some theme, function from 'system-config.sh'
grub_config


# Function to enable and theme the appropriate display manager
# based on the selected desktop environment function from 'system-config.sh'
display_manager


# Function to enable essential services based on installation
# type, including NetworkManager, periodic trim, and additional
# services for full installations function from 'software-install.sh'
essential_services


echo -ne "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------
"

echo "Cleaning up sudoers file"
# Remove no password sudo rights, add sudo rights
sed -Ei 's/^%wheel ALL=\(ALL(:ALL)?\) NOPASSWD: ALL/# &/;
s/^# (%wheel ALL=\(ALL(:ALL)?\) ALL)/\1/' /etc/sudoers

echo "Cleaning up installation files"
rm -r "$HOME"/archinstaller /home/"$USERNAME"/archinstaller
