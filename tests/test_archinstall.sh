#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
unset BASH_ENV

entrypoint="$sandbox/archinstall.sh"
mkdir -p "$sandbox/scripts/utils" "$sandbox/configs" "$sandbox/bin"
cp "$repository_root/archinstall.sh" "$entrypoint"
touch "$sandbox/scripts/configuration.sh" "$sandbox/configs/setup.conf"

cat >"$sandbox/scripts/utils/test-stubs.sh" <<'SH'
log_init() { :; }
log_info() { :; }
show_logo() { :; }
source_file() { source "$1"; }
run_installation_phases() { return "${PHASE_STATUS:-0}"; }
log_finish() { :; }
end_script() { :; }
SH

cat >"$sandbox/bin/setfont" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$sandbox/bin/setfont"

failure_output="$sandbox/failure.log"
if PATH="$sandbox/bin:$PATH" PHASE_STATUS=1 bash "$entrypoint" >"$failure_output" 2>&1; then
    printf 'archinstall.sh must fail when installation phases fail\n' >&2
    exit 1
fi
if grep -q 'Done - Please Eject Install Media and Reboot' "$failure_output"; then
    printf 'archinstall.sh must not report completion after failed phases\n' >&2
    exit 1
fi

success_output="$sandbox/success.log"
if ! PATH="$sandbox/bin:$PATH" PHASE_STATUS=0 bash "$entrypoint" >"$success_output" 2>&1; then
    printf 'archinstall.sh must succeed when installation phases succeed\n' >&2
    exit 1
fi
if ! grep -q 'Done - Please Eject Install Media and Reboot' "$success_output"; then
    printf 'archinstall.sh must report completion after successful phases\n' >&2
    exit 1
fi
