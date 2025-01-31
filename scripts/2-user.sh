#!/usr/bin/env bash
#github-action genshdoc
#
# @file User
# @brief User customizations and AUR package installation.
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


# Installs software from the Arch User Repository (AUR) using a
# specified AUR helper on 'software-install.sh'
aur_helper_install


# Installs system fonts by reading a JSON file that specifies font packages
# and uses pacman to install them. 'software-install.sh'
install_fonts


# Installs the specified desktop environment packages based on the user's selection
# of minimal or full installation types, utilizing either the AUR helper or pacman
# for package management on 'software-install.sh'.
desktop_environment_install


# Installs Btrfs packages based on the specified filesystem type, utilizing JQ
# to parse a JSON file for package names and installing them via Pacman or an
# AUR helper if specified on 'software-install.sh'
btrfs_install


echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
