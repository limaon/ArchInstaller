#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
setup_script="$repository_root/scripts/1-setup.sh"
post_setup_script="$repository_root/scripts/3-post-setup.sh"

if grep -qE '^[[:space:]]*mkinitcpio ' "$setup_script"; then
    printf 'Initramfs must not be rebuilt before all installation phases finish\n' >&2
    exit 1
fi

if ! grep -qE '^[[:space:]]*if ! mkinitcpio -P; then$' "$post_setup_script"; then
    printf 'Initramfs rebuild failure must stop the installation\n' >&2
    exit 1
fi
