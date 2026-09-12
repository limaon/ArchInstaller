#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
configuration_script="$repository_root/scripts/configuration.sh"

if grep -Eq '^[[:space:]]*swap_type([[:space:]]|$)' "$configuration_script"; then
    printf 'configuration.sh calls undefined swap_type\n' >&2
    exit 1
fi
