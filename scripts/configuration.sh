#!/usr/bin/env bash
#github-action genshdoc
#
# @file Configuration
# @brief This script will ask users about their prefrences like disk, file system, timezone, keyboard layout, user name, password, etc.
# @stdout Output routed to install.log
# @stderror Output routed to install.log


# settings-header General Settings
# @setting CONFIG_FILE string[$CONFIGS_DIR/setup.conf] Location of setup.conf to be used by set_option and all subsequent scripts.
[ -f "$CONFIG_FILE" ] || touch -f "$CONFIG_FILE" # crete $CONFIG_FILE if it doesn't exist


# Start functions
echo -e "configuration.sh file loaded\n"
