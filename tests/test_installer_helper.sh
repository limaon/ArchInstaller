#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

export HOME="$sandbox/home"
SCRIPTS_DIR="$sandbox/scripts"
USERNAME=installer
INSTALL_TYPE=MINIMAL
mkdir -p "$HOME/archinstaller/scripts" "$SCRIPTS_DIR"
touch "$SCRIPTS_DIR/0-preinstall.sh"
phase_log="$sandbox/phases.log"

source "$repository_root/scripts/utils/installer-helper.sh"

arch-chroot() {
    case "$*" in
    *2-user.sh*)
        printf 'phase2\n' >>"$phase_log"
        return "${PHASE2_STATUS:-0}"
        ;;
    *3-post-setup.sh*)
        printf 'phase3\n' >>"$phase_log"
        ;;
    *)
        printf 'phase1\n' >>"$phase_log"
        ;;
    esac
}

PHASE2_STATUS=1
if run_installation_phases; then
    printf 'failed Phase 2 must fail parent orchestration\n' >&2
    exit 1
fi
if grep -q 'phase3' "$phase_log"; then
    printf 'Phase 3 must not run after failed Phase 2\n' >&2
    exit 1
fi

: >"$phase_log"
PHASE2_STATUS=0
run_installation_phases
if [[ $(<"$phase_log") != $'phase1\nphase2\nphase3' ]]; then
    printf 'successful Phase 2 must continue to Phase 3\n' >&2
    exit 1
fi
