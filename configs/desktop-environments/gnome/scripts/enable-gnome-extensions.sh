#!/bin/bash
# Enable GNOME Shell extensions on first login

EXTENSIONS=(
    "dash-to-dock@micxgjo.gmail.com"
    "gsconnect@andyholmes.github.io"
)

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
sleep 3

for ext in "${EXTENSIONS[@]}"; do
    if gnome-extensions list 2>/dev/null | grep -q "$ext"; then
        if ! gnome-extensions enable "$ext" 2>/dev/null; then
            echo "Warning: Failed to enable extension: $ext" >&2
        fi
    fi
done

rm -f ~/.config/autostart/enable-gnome-extensions.desktop
