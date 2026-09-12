#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

run_phase_2() {
    local failing_package="$1"
    local expected_status="$2"
    local failing_pacman_package="${3:-}"
    local sandbox
    sandbox=$(mktemp -d)
    trap 'rm -rf "$sandbox"' RETURN

    export HOME="$sandbox/home"
    export PATH="$sandbox/bin:$PATH"
    unset BASH_ENV
    mkdir -p "$HOME/archinstaller/packages/desktop-environments" \
        "$HOME/archinstaller/packages/optional" "$HOME/archinstaller/configs" "$sandbox/bin"
    ln -s "$repository_root/scripts" "$HOME/archinstaller/scripts"
    cp "$repository_root/packages/desktop-environments/i3-wm.json" \
        "$HOME/archinstaller/packages/desktop-environments/i3-wm.json"
    cp "$repository_root/packages/btrfs.json" "$HOME/archinstaller/packages/btrfs.json"

    cat >"$HOME/archinstaller/packages/base.json" <<'JSON'
{"minimal": {"aur": []}, "full": {"aur": []}}
JSON
    cp "$repository_root/packages/optional/fonts.json" "$HOME/archinstaller/packages/optional/fonts.json"
    cat >"$HOME/archinstaller/packages/aur-helpers.json" <<'JSON'
{"helpers":{"paru":{"dependencies":["base-devel","git"],"aur_url":"https://aur.archlinux.org/paru.git","build_cmd":"makepkg -sirc --noconfirm","enabled":true}}}
JSON
    cat >"$HOME/archinstaller/configs/setup.conf" <<'CONF'
AUR_HELPER=paru
INSTALL_TYPE=MINIMAL
DESKTOP_ENV=i3-wm
FS=btrfs
CONF

cat >"$sandbox/bin/pacman" <<'SH'
#!/usr/bin/env bash
case "$1" in
-Qi) exit 1 ;;
 -S)
    [[ "$2" == "${PACMAN_FAILURE_PACKAGE:-}" ]] && exit 1
    exit 0
    ;;
*) exit 0 ;;
esac
SH
    cat >"$sandbox/bin/sudo" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == pacman ]]; then
    shift
    exec pacman "$@"
fi
exit 0
SH
    cat >"$sandbox/bin/git" <<'SH'
#!/usr/bin/env bash
mkdir -p "$3"
SH
    cat >"$sandbox/bin/makepkg" <<'SH'
#!/usr/bin/env bash
exit 0
SH
    cat >"$sandbox/bin/paru" <<'SH'
#!/usr/bin/env bash
if [[ "$2" == "$PARU_FAILURE_PACKAGE" ]]; then
    exit 1
fi
exit 0
SH
    cat >"$sandbox/bin/systemctl" <<'SH'
#!/usr/bin/env bash
exit 1
SH
    chmod +x "$sandbox/bin"/*

    local output="$sandbox/phase-2.log"
    if PARU_FAILURE_PACKAGE="$failing_package" PACMAN_FAILURE_PACKAGE="$failing_pacman_package" bash "$repository_root/scripts/2-user.sh" >"$output" 2>&1; then
        if [[ "$expected_status" == failure ]]; then
            printf '%s package failure must fail Phase 2\n' "${failing_package:-$failing_pacman_package}" >&2
            return 1
        fi
    elif [[ "$expected_status" == success ]]; then
        printf 'successful profile installation must complete Phase 2\n' >&2
        return 1
    fi

    if [[ "$expected_status" == failure ]] && grep -q 'SYSTEM READY FOR 3-post-setup.sh' "$output"; then
        printf '%s package failure must not report Phase 2 success\n' "${failing_package:-$failing_pacman_package}" >&2
        return 1
    fi
    if [[ "$expected_status" == success ]] && ! grep -q 'SYSTEM READY FOR 3-post-setup.sh' "$output"; then
        printf 'successful profile installation must report Phase 2 success\n' >&2
        return 1
    fi
}

run_phase_2 pop-icon-theme failure
run_phase_2 btrfsmaintenance failure
run_phase_2 '' success
run_phase_2 '' failure adobe-source-han-sans-cn-fonts
