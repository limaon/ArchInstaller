#!/bin/bash
#github-action genshdoc
#
# @file archinstall.sh
# @brief Entrance script that launches children scripts for each phase of installation.
# @stdout Output routed to install.log
# @stderror Output routed to install.log
# shellcheck disable=SC1090,SC1091

# Find the name of the folder the scripts are in
set -a

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
CONFIGS_DIR="${SCRIPT_DIR}/configs"

CONFIG_FILE="${CONFIGS_DIR}/setup.conf"
LOG_FILE="${SCRIPT_DIR}/install.log"

BOLD='\e[1m'
RESET='\e[0m'
BRED='\e[91m]'

set +a


# Delete existing log file and log output of script
[[ -f "$LOG_FILE" ]] && rm -f "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1


# Load utility scripts
for filename in ${SCRIPTS_DIR}/utils/*.sh; do
  [ -e "$filename" ] || continue
  # shellcheck source=${SCRIPTS_DIR}/utils/*.sh
  source "$filename"
done



# Actual install sequence
# clear
show_logo # loaded from 'install-helper.sh'
source "${SCRIPTS_DIR}/configuration.sh"

# echo -ne "
# -------------------------------------------------------------------------
#                     Automated Arch Linux Installer
# -------------------------------------------------------------------------
#                 Scripts are in directory named ArchInstaller
# "
#     ( bash $SCRIPT_DIR/scripts/startup.sh )|& tee startup.log
#       source $CONFIGS_DIR/setup.conf
#     ( bash $SCRIPT_DIR/scripts/0-preinstall.sh )|& tee 0-preinstall.log
#     ( arch-chroot /mnt/sysArch $HOME/ArchInstaller/scripts/1-setup.sh )|& tee 1-setup.log
#     if [[ ! $DESKTOP_ENV == server ]]; then
#       ( arch-chroot /mnt/sysArch /usr/bin/runuser -u $USERNAME -- /home/$USERNAME/ArchInstaller/scripts/2-user.sh )|& tee 2-user.log
#     fi
#     ( arch-chroot /mnt/sysArch $HOME/ArchInstaller/scripts/3-post-setup.sh )|& tee 3-post-setup.log
#     cp -v *.log /mnt/sysArch/home/$USERNAME
#
# echo -ne "
# -------------------------------------------------------------------------
#                     Automated Arch Linux Installer
# -------------------------------------------------------------------------
#                 Done - Please Eject Install Media and Reboot
# "
