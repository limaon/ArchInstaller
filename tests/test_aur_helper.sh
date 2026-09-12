#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)
original_directory=$PWD
trap 'cd "$original_directory"; rm -rf "$sandbox"' EXIT

export HOME="$sandbox/home"
export PATH="$sandbox/bin:$PATH"
unset BASH_ENV
mkdir -p "$HOME/archinstaller/packages" "$sandbox/bin"
log_file="$sandbox/operations.log"

cat >"$HOME/archinstaller/packages/aur-helpers.json" <<'JSON'
{
  "helpers": {
    "paru": {
      "dependencies": ["base-devel", "git"],
      "aur_url": "https://aur.archlinux.org/paru.git",
      "build_cmd": "makepkg -sirc --noconfirm",
      "enabled": true
    },
    "disabled": {
      "dependencies": [],
      "aur_url": "https://aur.archlinux.org/disabled.git",
      "build_cmd": "makepkg -sirc --noconfirm",
      "enabled": false
    }
  }
}
JSON

cat >"$sandbox/bin/pacman" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == "-Qi" ]]; then
    exit 1
fi
if [[ -z "${SUDO_STUB:-}" ]]; then
    printf 'pacman %s\n' "$*" >>"$AUR_TEST_LOG"
fi
SH

cat >"$sandbox/bin/sudo" <<'SH'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$AUR_TEST_LOG"
SUDO_STUB=1 "$@"
SH

cat >"$sandbox/bin/git" <<'SH'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$AUR_TEST_LOG"
mkdir -p "$3"
SH

cat >"$sandbox/bin/makepkg" <<'SH'
#!/usr/bin/env bash
printf 'makepkg %s\n' "$*" >>"$AUR_TEST_LOG"
exit "${MAKEPKG_STATUS:-0}"
SH

cat >"$sandbox/bin/paru" <<'SH'
#!/usr/bin/env bash
printf 'paru %s\n' "$*" >>"$AUR_TEST_LOG"
exit "${PARU_STATUS:-0}"
SH

chmod +x "$sandbox/bin/pacman" "$sandbox/bin/sudo" "$sandbox/bin/git" "$sandbox/bin/makepkg" "$sandbox/bin/paru"
export AUR_TEST_LOG="$log_file"

source "$repository_root/scripts/utils/aur-helpers.sh"

assert_log_equals() {
    local expected="$1"
    local actual
    actual=$(<"$log_file")
    if [[ "$actual" != "$expected" ]]; then
        printf 'unexpected operations:\n%s\n' "$actual" >&2
        exit 1
    fi
}

: >"$log_file"
AUR_HELPER=paru
install_aur_helper paru
install_package_via_aur downgrade
assert_log_equals "$(cat <<EOF
sudo pacman -S base-devel git --noconfirm --needed --color=always
git clone https://aur.archlinux.org/paru.git $HOME/paru
makepkg -sirc --noconfirm
paru -S downgrade --noconfirm --needed --color=always
EOF
)"

: >"$log_file"
if install_aur_helper unknown; then
    printf 'unknown helper must fail\n' >&2
    exit 1
fi
[[ ! -s "$log_file" ]] || { printf 'unknown helper must not invoke commands\n' >&2; exit 1; }

: >"$log_file"
if install_aur_helper disabled; then
    printf 'disabled helper must fail\n' >&2
    exit 1
fi
[[ ! -s "$log_file" ]] || { printf 'disabled helper must not invoke commands\n' >&2; exit 1; }

: >"$log_file"
export MAKEPKG_STATUS=1
if install_aur_helper paru; then
    printf 'makepkg failure must fail helper installation\n' >&2
    exit 1
fi
unset MAKEPKG_STATUS

: >"$log_file"
export PARU_STATUS=1
if install_package_via_aur downgrade; then
    printf 'paru failure must fail package installation\n' >&2
    exit 1
fi
unset PARU_STATUS

: >"$log_file"
AUR_HELPER=NONE
install_aur_helper NONE
install_package_via_aur downgrade
[[ ! -s "$log_file" ]] || { printf 'NONE must not invoke AUR commands\n' >&2; exit 1; }

ln -s "$repository_root/scripts" "$HOME/archinstaller/scripts"
cat >"$HOME/archinstaller/packages/base.json" <<'JSON'
{
  "minimal": {
    "aur": [{"package": "downgrade"}]
  },
  "full": {
    "aur": [{"package": "google-chrome"}]
  }
}
JSON

source "$repository_root/scripts/utils/software-install.sh"

: >"$log_file"
AUR_HELPER=paru
INSTALL_TYPE=MINIMAL
aur_helper_install
assert_log_equals "$(cat <<EOF
sudo pacman -S base-devel git --noconfirm --needed --color=always
git clone https://aur.archlinux.org/paru.git $HOME/paru
makepkg -sirc --noconfirm
paru -S downgrade --noconfirm --needed --color=always
EOF
)"

: >"$log_file"
INSTALL_TYPE=FULL
aur_helper_install
assert_log_equals "$(cat <<EOF
sudo pacman -S base-devel git --noconfirm --needed --color=always
git clone https://aur.archlinux.org/paru.git $HOME/paru
makepkg -sirc --noconfirm
paru -S downgrade --noconfirm --needed --color=always
paru -S google-chrome --noconfirm --needed --color=always
EOF
)"

: >"$log_file"
export PARU_STATUS=1
if aur_helper_install; then
    printf 'AUR package failure must fail Phase 2\n' >&2
    exit 1
fi

empty_packages="$sandbox/empty-packages.json"
cat >"$empty_packages" <<'JSON'
{"minimal": {"aur": []}}
JSON
if ! install_packages_from_json "$empty_packages" '.minimal.aur[].package' aur; then
    printf 'an empty valid package list must succeed\n' >&2
    exit 1
fi

if install_packages_from_json "$empty_packages" '.minimal.aur[' aur; then
    printf 'an invalid jq filter must fail package installation\n' >&2
    exit 1
fi

invalid_schema_packages="$sandbox/invalid-schema-packages.json"
cat >"$invalid_schema_packages" <<'JSON'
{"minimal": {"aur": "not-an-array"}}
JSON
if install_packages_from_json "$invalid_schema_packages" '.minimal.aur[].package' aur; then
    printf 'an invalid package schema must fail package installation\n' >&2
    exit 1
fi

mkdir -p "$HOME/archinstaller/configs"
cat >"$HOME/archinstaller/configs/setup.conf" <<'CONF'
AUR_HELPER=unknown
INSTALL_TYPE=SERVER
DESKTOP_ENV=none
FS=ext4
CONF

phase_output="$sandbox/phase-2.log"
if bash "$repository_root/scripts/2-user.sh" >"$phase_output" 2>&1; then
    printf 'Phase 2 must exit nonzero when AUR helper installation fails\n' >&2
    exit 1
fi
if grep -q 'SYSTEM READY FOR 3-post-setup.sh' "$phase_output"; then
    printf 'Phase 2 must not report success after AUR helper failure\n' >&2
    exit 1
fi
