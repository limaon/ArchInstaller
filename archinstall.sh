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
BRED='\e[91m'

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
setfont ter-v22b
show_logo # function from 'install-helper.sh'
source "${SCRIPTS_DIR}/configuration.sh"
source_file "$CONFIG_FILE"
sequence

echo -ne "
            Done - Please Eject Install Media and Reboot
"

end_script
