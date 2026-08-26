#!/usr/bin/env bash

# Enable GNOME Shell extensions on first login

ESSENTIAL_EXTENSIONS=(
    "dash-to-dock@micxgx.gmail.com"
    "appindicatorsupport@rgcjonas.gmail.com"
    "gsconnect@andyholmes.github.io"
)

USEFUL_EXTENSIONS=(
    "system-monitor@gnome-shell-extensions.gcampax.github.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
)

OFFICIAL_EXTENSIONS=(
    "light-style@gnome-shell-extensions.gcampax.github.com"
    "native-window-placement@gnome-shell-extensions.gcampax.github.com"
    "places-menu@gnome-shell-extensions.gcampax.github.com"
    "drive-menu@gnome-shell-extensions.gcampax.github.com"
    "screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com"
    "status-icons@gnome-shell-extensions.gcampax.github.com"
    "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
)

EXTENSIONS=("${ESSENTIAL_EXTENSIONS[@]}" "${USEFUL_EXTENSIONS[@]}" "${OFFICIAL_EXTENSIONS[@]}")

timeout=30
while ! pgrep -x "gnome-shell" > /dev/null && [[ $timeout -gt 0 ]]; do
    sleep 1
    ((timeout--))
done

if [[ $timeout -eq 0 ]]; then
    echo "Error: GNOME Shell not ready after 30s" >&2
    exit 1
fi

# D-Bus needs time to initialize after gnome-shell starts
sleep 5

enabled_count=0
failed_count=0

for ext in "${EXTENSIONS[@]}"; do
    if gnome-extensions list 2>/dev/null | grep -q "$ext"; then
        if gnome-extensions enable "$ext" 2>/dev/null; then
            ((enabled_count++))
        else
            echo "Warning: Failed to enable extension: $ext" >&2
            ((failed_count++))
        fi
    else
        echo "Warning: Extension not found: $ext" >&2
        ((failed_count++))
    fi
done

# Log results
echo "GNOME Extensions enabled: $enabled_count"
[[ $failed_count -gt 0 ]] && echo "GNOME Extensions failed: $failed_count" >&2

rm -f ~/.config/autostart/enable-gnome-extensions.desktop

exit 0
