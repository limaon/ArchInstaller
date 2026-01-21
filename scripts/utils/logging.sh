#!/bin/bash

##############################################################################
# ArchInstaller Logging Module (Simplified)
# Sistema de logging conciso e limpo
##############################################################################

# @description Initialize logging system
# @param $1 Log file path (optional, defaults to /tmp/archinstaller.log)
log_init() {
    LOG_FILE="${1:-/tmp/archinstaller.log}"
    SWAP_LOG="${LOG_FILE%.log}_swap.log"

    # Create log files
    touch "$LOG_FILE" "$SWAP_LOG"

    # Write header
    cat << EOF > "$LOG_FILE"
===============================================================================
                ArchInstaller Installation Log
===============================================================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Log File: $LOG_FILE
===============================================================================

EOF

    cat << EOF > "$SWAP_LOG"
===============================================================================
                ArchInstaller Swap Configuration Log
===============================================================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
===============================================================================

EOF

    export LOG_FILE SWAP_LOG
}

# @description Unified log function (replaces log, log_swap)
# @param $1 Log level: INFO|WARN|ERROR|SUCCESS|DEBUG|SWAP
# @param $2+ Message to log
# @param $3 Log file (optional, defaults to $LOG_FILE)
# Usage: log ERROR "Erro ao criar swapfile"
#        log SWAP "Swapfile criado com sucesso"
log() {
    local level="$1"
    shift
    local message="$*"
    local log_file="${3:-$LOG_FILE}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Determine color
    local color nc_color
    case "$level" in
        INFO)    color='\033[0;34m' nc_color='[INFO]   ' ;;
        WARN)    color='\033[1;33m' nc_color='[WARNING]' ;;
        ERROR)   color='\033[0;31m' nc_color='[ERROR]  ' ;;
        SUCCESS) color='\033[0;32m' nc_color='[SUCCESS]' ;;
        DEBUG)   color='\033[0;90m' nc_color='[DEBUG]  ' ;;
        SWAP)    color='\033[0;36m' nc_color='[SWAP]   ' ;;
        *)        color='\033[0m'      nc_color='[LOG]    ' ;;
    esac

    # Log to file
    echo "[$timestamp] $nc_color $message" >> "$log_file"

    # Also log to swap file if SWAP level
    [[ "$level" == "SWAP" ]] && echo "[$timestamp] $nc_color $message" >> "$SWAP_LOG"

    # Console output (with color)
    [[ "${DEBUG:-false}" == "true" || "$level" != "DEBUG" ]] && \
        echo -e "${color}[$level]${nc_color} $message"
}

# @description Unified command execution logger (replaces log_exec, log_swap_exec)
# @param $1 Log level (SWAP/INFO/etc.)
# @param $2 Command to execute
# @param $3 Description of command
# @param $4 Log file (optional)
# Usage: log_exec SWAP "swapon /swap/swapfile" "Ativando swapfile"
log_exec() {
    local level="$1"
    local cmd="$2"
    local desc="$3"
    local log_file="${4:-$LOG_FILE}"
    local output exit_code

    log "$level" "Executing: $desc" "$log_file"
    [[ "${DEBUG:-false}" == "true" ]] && log "$level" "Command: $cmd" "$log_file"

    # Execute and capture
    output=$(eval "$cmd" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log "$level" "SUCCESS: $desc" "$log_file"
    else
        log "$level" "ERROR: $desc (exit: $exit_code)" "$log_file"
    fi

    # Log output if not empty or if error
    if [[ -n "$output" || $exit_code -ne 0 ]]; then
        echo "$output" | while IFS= read -r line; do
            log "$level" "  $line" "$log_file"
        done
    fi

    return $exit_code
}

# @brief Swap-specific shortcuts (aliases)
log_swap() { log SWAP "$@"; }
log_swap_exec() { log_exec SWAP "$@"; }

# @description Unified system info logger
# @param $1 Type: SYSTEM|FILESYSTEM|SWAP
# @usage log_info SYSTEM
#        log_info FILESYSTEM
#        log_info SWAP
log_info() {
    local type="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$type" in
        SYSTEM)
            log INFO "=== System Information ==="
            log INFO "Hostname: $(hostname 2>/dev/null || echo unknown)"
            log INFO "Kernel: $(uname -r 2>/dev/null || echo unknown)"
            log INFO "RAM: $(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')"
            log INFO "Swap: $(free -h 2>/dev/null | awk '/^Swap:/ {print $2}')"
            ;;

        FILESYSTEM)
            log INFO "=== Filesystem Information ==="
            if [[ -d /sys/fs/btrfs ]]; then
                log INFO "Filesystem: Btrfs"
                command -v btrfs &>/dev/null && log INFO "Btrfs subvolumes listed"
            else
                log INFO "Filesystem: $(findmnt -n -o FSTYPE / 2>/dev/null || echo unknown)"
            fi
            ;;

        SWAP)
            log SWAP "=== Swap Information ==="
            log SWAP "Devices:"
            swapon --show 2>/dev/null | while IFS= read -r line; do log SWAP "  $line"; done
            log SWAP "Summary: Total: $(free -h | awk '/^Swap:/ {print $2}') Used: $(free -h | awk '/^Swap:/ {print $3}')"
            lsmod | grep -q zram && log SWAP "ZRAM module loaded"
            [[ -f /swap/swapfile ]] && log SWAP "Swapfile exists: /swap/swapfile"
            ;;
    esac
}

# @description Finalize logging and copy to installed system
# @param $1 Mount point (default: /mnt)
log_finish() {
    local mount_point="${1:-/mnt}"

    # Copy logs
    mkdir -p "${mount_point}/var/log/archinstaller"
    cp "$LOG_FILE" "${mount_point}/var/log/archinstaller/install.log" 2>/dev/null && \
        log SUCCESS "Logs copied to ${mount_point}/var/log/archinstaller/"

    [[ -f "$SWAP_LOG" ]] && cp "$SWAP_LOG" "${mount_point}/var/log/archinstaller/swap.log" 2>/dev/null

    chmod -R 755 "${mount_point}/var/log/archinstaller" 2>/dev/null

    log INFO "=== Installation Complete ==="
    log INFO "Logs: $LOG_FILE, $SWAP_LOG"
    echo ""
    echo "Logs saved to: $LOG_FILE"
}

# Export functions
export -f log log_exec log_swap log_swap_exec log_info log_finish
