#!/bin/bash
# Simple power status script using built-in tools

echo "=== Power Status ==="

# Battery status
if command -v acpi &>/dev/null; then
    echo "Battery:"
    acpi -b 2>/dev/null || echo "  Battery info not available"
else
    echo "Note: acpi not installed (install with: sudo pacman -S acpi)"
fi

# Swap status
echo "Swap:"
swapon --show NAME,SIZE,USED 2>/dev/null || {
    echo "  No active swap found"
    free -h | grep -E "(Swap|Mem)" | head -1
}

# Systemd logind status
echo ""
echo "systemd-logind:"
systemctl is-active systemd-logind 2>/dev/null || echo "  systemd-logind service not running"

# Logind configuration
if [[ -f /etc/systemd/logind.conf.d/50-power.conf ]]; then
    echo "Power configuration:"
    grep -E "(IdleAction|HandleLidSwitch|HandlePowerKey)" /etc/systemd/logind.conf.d/50-power.conf
fi

echo ""
echo "Manual commands:"
echo "  • systemctl suspend          - Force suspend"
echo "  • systemctl hibernate        - Force hibernate"
echo "  • systemd-inhibit -who='Working' -what='sleep' -why='Working' sleep 3600  - Prevent sleep"