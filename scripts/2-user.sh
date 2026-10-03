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
CONFIG_FILE=$(config_file_for_context shared "$(id -un)") || {
    echo "ERROR: Could not resolve user configuration path"
    exit 1
}
export CONFIG_FILE
if ! source "$CONFIG_FILE"; then
    echo "ERROR: Could not load user configuration: $CONFIG_FILE"
    exit 1
fi

show_logo

# Installs software from the Arch User Repository (AUR) using a
# specified AUR helper on 'software-install.sh'
if ! aur_helper_install; then
    echo "Error: AUR helper installation failed; stopping Phase 2"
    exit 1
fi

# Install GPU drivers after the AUR helper is available.
if ! graphics_install; then
    echo "Error: Graphics driver installation failed; stopping Phase 2"
    exit 1
fi

# Installs system fonts by reading a JSON file that specifies font packages
# and uses pacman to install them. 'software-install.sh'
if ! install_fonts; then
    echo "Error: Font installation failed; stopping Phase 2"
    exit 1
fi

# Installs the specified desktop environment packages based on the user's selection
# of minimal or full installation types, utilizing either the AUR helper or pacman
# for package management on 'software-install.sh'.
if ! desktop_environment_install; then
    echo "Error: Desktop environment installation failed; stopping Phase 2"
    exit 1
fi

# Installs battery notifications for i3-wm desktop environment
# Configures scripts, systemd timers, and udev rules for battery monitoring
# on 'software-install.sh'.
i3wm_battery_notifications

# Configure logind power actions, falling back to suspend when swap is insufficient.
if ! i3wm_auto_suspend_hibernate; then
    echo "Error: Power management configuration failed; stopping Phase 2" >&2
    exit 1
fi

# Installs Btrfs packages based on the specified filesystem type, utilizing JQ
# to parse a JSON file for package names and installing them via Pacman or an
# AUR helper if specified on 'software-install.sh'
if ! btrfs_install; then
    echo "Error: Btrfs package installation failed; stopping Phase 2"
    exit 1
fi

echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
