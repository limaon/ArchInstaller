#!/usr/bin/env bash
#github-action genshdoc
#
# @description System Configuration
# @brief Contains functions used to modify the system
# @stdout Output routed to install.log
# @stderror Output routed to install.log
# shellcheck disable=SC1089
# Reason: False positive for parsing stopped at end of file (file is valid)
#
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
clear
show_logo
swap_type
if [[ ! "$INSTALL_TYPE" == "SERVER" ]]; then
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
