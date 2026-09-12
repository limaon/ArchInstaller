#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
system_config_script="$repository_root/scripts/utils/system-config.sh"

if ! grep -Fq 'find /etc/skel -type d -exec chmod 755 {} \;' "$system_config_script"; then
    printf 'Base skeleton directories must be traversable by created users\n' >&2
    exit 1
fi
