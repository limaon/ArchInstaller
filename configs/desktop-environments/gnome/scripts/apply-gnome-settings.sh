#!/bin/bash
# Apply GNOME settings on first login

timeout=60
while ! pgrep -x "gnome-shell" > /dev/null && [[ $timeout -gt 0 ]]; do
    sleep 1
    ((timeout--))
done

if [[ $timeout -eq 0 ]]; then
    echo "Error: GNOME Shell not ready after 60s" >&2
    exit 1
fi

# D-Bus needs time to initialize after gnome-shell starts
sleep 5

failed=0

# Create log file
LOG_FILE="$HOME/.local/share/gnome-settings-apply.log"
mkdir -p "$(dirname "$LOG_FILE")"
{
    echo "=== GNOME Settings Application Log ==="
    echo "Date: $(date)"
    echo "GNOME Shell Version: $(gnome-shell --version)"
    echo ""
} > "$LOG_FILE"

# Helper function to safely set gsettings
safe_gsettings() {
    local schema="$1"
    local key="$2"
    local value="$3"
    local description="${4:-$key}"

    {
        echo "Setting: $description"
        echo "  Schema: $schema"
        echo "  Key: $key"
        echo "  Value: $value"
    } >> "$LOG_FILE"

    if gsettings set "$schema" "$key" "$value" 2>>"$LOG_FILE"; then
        echo "  Status: [OK] SUCCESS" >> "$LOG_FILE"
        return 0
    else
        echo "  Status: [FAIL] FAILED" >> "$LOG_FILE"
        ((failed++))
        return 1
    fi
}

# Interface
safe_gsettings org.gnome.desktop.interface gtk-theme 'Adwaita-dark' "GTK Theme"
safe_gsettings org.gnome.desktop.interface icon-theme 'Papirus-Dark' "Icon Theme"
safe_gsettings org.gnome.desktop.interface cursor-theme 'Adwaita' "Cursor Theme"
safe_gsettings org.gnome.desktop.interface font-name 'Ubuntu 11' "Font Name"
safe_gsettings org.gnome.desktop.interface monospace-font-name 'Ubuntu Mono 11' "Monospace Font"
safe_gsettings org.gnome.desktop.interface show-battery-percentage true "Show Battery Percentage"
safe_gsettings org.gnome.desktop.interface enable-animations true "Enable Animations"

# Window Manager
safe_gsettings org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close' "Button Layout"
safe_gsettings org.gnome.desktop.wm.preferences focus-mode 'click' "Focus Mode"

# Power Management
safe_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 1800 "Sleep AC Timeout"
safe_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend' "Sleep AC Type"
safe_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900 "Sleep Battery Timeout"
safe_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend' "Sleep Battery Type"
safe_gsettings org.gnome.settings-daemon.plugins.power power-button-action 'suspend' "Power Button Action"

# Favorite Apps
safe_gsettings org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop', 'org.gnome.Console.desktop', 'firefox.desktop']" "Favorite Apps"

# Terminal Configuration
# Get default profile UUID
TERM_UUID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d \')
TERM_PROFILE="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${TERM_UUID}/"

{
    echo "Terminal Profile: $TERM_UUID"
    echo ""
} >> "$LOG_FILE"

# Terminal appearance
safe_gsettings "$TERM_PROFILE" font 'Ubuntu Mono 12' "Terminal Font"
safe_gsettings "$TERM_PROFILE" use-theme-colors false "Terminal Use Theme Colors"
safe_gsettings "$TERM_PROFILE" background-color '#1e1e1e' "Terminal Background"
safe_gsettings "$TERM_PROFILE" foreground-color '#e0e0e0' "Terminal Foreground"

# Terminal behavior
safe_gsettings "$TERM_PROFILE" scrollback-lines 5000 "Terminal Scrollback"
safe_gsettings "$TERM_PROFILE" scrollbar-policy 'right' "Terminal Scrollbar"
safe_gsettings "$TERM_PROFILE" cursor-blink-mode 'off' "Terminal Cursor Blink"
safe_gsettings "$TERM_PROFILE" cursor-shape 'block' "Terminal Cursor Shape"
safe_gsettings "$TERM_PROFILE" audible-bell false "Terminal Audible Bell"

# Terminal text rendering
safe_gsettings "$TERM_PROFILE" text-blink-mode 'never' "Terminal Text Blink"

# Log summary
{
    echo ""
    echo "=== Summary ==="
    echo "Failed commands: $failed"
    echo "Log file: $LOG_FILE"
} >> "$LOG_FILE"

if [[ $failed -gt 0 ]]; then
    echo "Warning: $failed gsettings commands failed" >&2
    echo "Check log file: $LOG_FILE" >&2
else
    echo "All GNOME settings applied successfully" >> "$LOG_FILE"
fi

rm -f ~/.config/autostart/apply-gnome-settings.desktop
