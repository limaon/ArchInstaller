#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
function_source=$(awk '/^detect_gpu\(\)/,/^}/' "$repository_root/scripts/utils/software-install.sh")
eval "$function_source"

lspci() {
    printf '%s\n' '00:02.0 VGA compatible controller: Intel Corporation Haswell-ULT Integrated Graphics Controller (rev 09)'
}

if [[ "$(detect_gpu)" != "intel" ]]; then
    printf 'Haswell integrated graphics must be detected as Intel\n' >&2
    exit 1
fi
