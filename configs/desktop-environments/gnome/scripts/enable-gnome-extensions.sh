#!/bin/bash
# Enable GNOME Shell extensions on first login

# List of extensions installed via AUR
EXTENSIONS=(
    "dash-to-dock@micxgjo.gmail.com"
    "gsconnect@andyholmes.github.io"
)

# Wait for GNOME Shell to be ready (max 30s)
timeout=30
while ! pgrep -x "gnome-shell" > /dev/null && [[ $timeout -gt 0 ]]; do
    sleep 1
    ((timeout--))
done

if [[ $timeout -eq 0 ]]; then
    echo "Error: GNOME Shell not ready after 30s" >&2
    exit 1
fi

# Additional buffer for D-Bus
sleep 3

# Enable each extension
for ext in "${EXTENSIONS[@]}"; do
    # Check if extension is installed
    if gnome-extensions list 2>/dev/null | grep -q "$ext"; then
        if ! gnome-extensions enable "$ext" 2>/dev/null; then
            echo "Warning: Failed to enable extension: $ext" >&2
        fi
    fi
done

# Remove this script from autostart after first execution
rm -f ~/.config/autostart/enable-gnome-extensions.desktop
