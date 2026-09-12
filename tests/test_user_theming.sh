#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
setup_script="$repository_root/scripts/1-setup.sh"
software_script="$repository_root/scripts/utils/software-install.sh"

add_user_line=$(grep -nE '^[[:space:]]*add_user$' "$setup_script" | cut -d: -f1)
theming_line=$(grep -nE '^[[:space:]]*run_user_theming$' "$setup_script" | cut -d: -f1)

if [[ -z "$theming_line" || "$theming_line" -le "$add_user_line" ]]; then
    printf 'User theming must run after the installer user is created\n' >&2
    exit 1
fi

if ! grep -Fq 'local user_home="/home/$USERNAME"' "$software_script" ||
    ! grep -Fq 'runuser -u "$USERNAME" -- env HOME="$user_home"' "$software_script"; then
    printf 'User theming must run with the installer user home directory\n' >&2
    exit 1
fi
