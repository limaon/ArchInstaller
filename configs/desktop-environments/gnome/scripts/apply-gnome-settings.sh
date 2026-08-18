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
sleep 3

failed=0

# Interface
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' || ((failed++))
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || ((failed++))
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' || ((failed++))
gsettings set org.gnome.desktop.interface show-battery-percentage true || ((failed++))
gsettings set org.gnome.desktop.interface enable-animations true || ((failed++))

# Window Manager
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close' || ((failed++))
gsettings set org.gnome.desktop.wm.preferences focus-mode 'click' || ((failed++))

# Power Management
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 1800 || ((failed++))
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend' || ((failed++))
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900 || ((failed++))
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend' || ((failed++))
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'suspend' || ((failed++))

# Favorite Apps
gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop', 'org.gnome.Console.desktop', 'firefox.desktop']" || ((failed++))

if [[ $failed -gt 0 ]]; then
    echo "Warning: $failed gsettings commands failed" >&2
fi

rm -f ~/.config/autostart/apply-gnome-settings.desktop
