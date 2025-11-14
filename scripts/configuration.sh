#!/usr/bin/env bash
#github-action genshdoc
#
# @file Configuration
# @brief This script will ask users about their prefrences like disk, file system, timezone, keyboard layout, user name, password, etc.
# @stdout Output routed to install.log
# @stderror Output routed to install.log


# settings-header General Settings
# @setting CONFIG_FILE string[$CONFIGS_DIR/setup.conf] Location of setup.conf to be used by set_option and all subsequent scripts.
# Ensure config directory exists before creating file
[[ -d "$CONFIGS_DIR" ]] || mkdir -p "$CONFIGS_DIR"
[ -f "$CONFIG_FILE" ] || touch "$CONFIG_FILE" # create $CONFIG_FILE if it doesn't exist



# Start functions
background_checks
clear
show_logo
user_info
clear
show_logo
install_type
if [[ ! "$INSTALL_TYPE" == SERVER ]]; then
  clear
  show_logo
  aur_helper
  clear
  show_logo
  desktop_environment
fi
clear
show_logo
disk_select
clear
show_logo
filesystem
clear
show_logo
timezone
clear
show_logo
locale_selection
clear
show_logo
keymap
clear

show_configurations
clear
