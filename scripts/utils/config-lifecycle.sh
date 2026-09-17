#!/usr/bin/env bash
#github-action genshdoc
#
# @file Configuration Lifecycle
# @brief Resolves setup.conf paths for each installer execution context.
# @stdout Configuration path
# @stderror Error messages are returned to the caller

# @description Return the configuration path for an installer context.
# @arg1 string Context: live, root, or user.
# @arg2 string Linux username when the context is user.
# @stdout The absolute setup.conf path.
# @exitcode 1 If the context or username is invalid.
config_file_for_context() {
    local context="${1:-}"
    local username="${2:-}"

    case "$context" in
    live)
        [[ -n "${CONFIGS_DIR:-}" ]] || return 1
        printf '%s/setup.conf\n' "${CONFIGS_DIR%/}"
        ;;
    root)
        printf '%s\n' "/root/archinstaller/configs/setup.conf"
        ;;
    user)
        if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
            return 1
        fi
        printf '/home/%s/archinstaller/configs/setup.conf\n' "$username"
        ;;
    shared)
        if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
            return 1
        fi
        printf '/home/%s/.archinstaller/setup.conf\n' "$username"
        ;;
    *)
        return 1
        ;;
    esac
}

# @description Copy a setup.conf while removing credential values.
# @arg1 string Source configuration file.
# @arg2 string Destination configuration file.
# @exitcode 1 If the source or destination cannot be safely processed.
sanitize_config_file() {
    local source_file="${1:-}"
    local destination_file="${2:-}"
    local destination_dir
    local temp_file

    if [[ ! -f "$source_file" || -L "$source_file" || -z "$destination_file" || -L "$destination_file" ]]; then
        return 1
    fi

    destination_dir=$(dirname -- "$destination_file") || return 1
    mkdir -p -- "$destination_dir" || return 1
    temp_file=$(mktemp -- "$destination_file.tmp.XXXXXX") || return 1

    if ! sed -E '/^(PASSWORD|LUKS_PASSWORD)=/d' "$source_file" >"$temp_file" ||
        ! chmod 600 "$temp_file" ||
        ! mv -- "$temp_file" "$destination_file"; then
        rm -f -- "$temp_file"
        return 1
    fi
}
