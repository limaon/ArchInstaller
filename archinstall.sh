#!/usr/bin/env bash
#github-action genshdoc
#
# @file archinstall.sh
# @brief Entrance script that launches children scripts for each phase of installation.
# @stdout Output routed to install.log
# @stderror Output routed to install.log
# shellcheck disable=SC1090,SC1091

# Find the name of the folder the scripts are in
set -a

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
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
for filename in "$SCRIPTS_DIR"/utils/*.sh; do
    [ -e "$filename" ] || continue
    source "$filename"
done


# Initialize logging system
log_init "$LOG_FILE"
log_info SYSTEM
log_info FILESYSTEM


# Actual install sequence
setfont ter-v18b
show_logo
source "${SCRIPTS_DIR}/configuration.sh"
source_file "$CONFIG_FILE"
run_installation_phases

echo -ne "
            Done - Please Eject Install Media and Reboot
"

# Finalize logging and copy to installed system
log_finish /mnt

end_script
