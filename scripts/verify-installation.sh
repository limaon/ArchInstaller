#!/usr/bin/env bash
#
# @file verify-installation.sh
# @brief Post-installation verification script to check for errors
# @description Run this script after installation to verify everything worked correctly
# Can be run as root or normal user (uses sudo when needed)

# Error handling: be more lenient to allow script to continue
# Don't exit immediately on errors in conditionals or when checking things
set +e
set -o pipefail
# Don't exit on unset variables, handle them explicitly
set +u

# Detect if running as root or normal user
if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
    SUDO_CMD=""
    LOG_FILE="/var/log/install.log"
    CONFIG_FILE="/root/archinstaller/configs/setup.conf"
else
    IS_ROOT=false
    SUDO_CMD="sudo"

    if [[ -f "$HOME/.archinstaller/install.log" ]]; then
        LOG_FILE="$HOME/.archinstaller/install.log"
    else
        LOG_FILE="/var/log/install.log"
    fi

    if [[ -f "$HOME/.archinstaller/setup.conf" ]]; then
        CONFIG_FILE="$HOME/.archinstaller/setup.conf"
    else
        CONFIG_FILE="/root/archinstaller/configs/setup.conf"
    fi
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
ERRORS=0
WARNINGS=0
CHECKS=0

# Helper functions
check_pass() {
    ((CHECKS++))
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    ((CHECKS++))
    ((ERRORS++))
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    ((CHECKS++))
    ((WARNINGS++))
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "=========================================="
echo "  ArchInstaller Post-Installation Check"
echo "=========================================="
if [[ "$IS_ROOT" == true ]]; then
    echo "Running as: root"
else
    echo "Running as: $(whoami) (will use sudo when needed)"
    if ! command -v sudo &>/dev/null; then
        echo -e "${RED}Error: sudo not found. Please run as root or install sudo.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}Note: You may be prompted for your password when sudo is needed.${NC}"
fi
echo ""

if [[ -f "$LOG_FILE" ]]; then
    check_pass "Installation log found: $LOG_FILE"
else
    if [[ -f "/var/log/install.log" ]] && [[ "$IS_ROOT" == true ]]; then
        LOG_FILE="/var/log/install.log"
        check_pass "Installation log found: $LOG_FILE"
    else
        check_warn "Installation log not found. Tried: $LOG_FILE"
        LOG_FILE=""
    fi
fi

if [[ -n "$LOG_FILE" ]] && [[ -f "$LOG_FILE" ]] && [[ -r "$LOG_FILE" ]]; then
    ERROR_COUNT=$(grep -ic "error\|failed\|fail" "$LOG_FILE" 2>/dev/null || echo "0")
    if [[ $ERROR_COUNT -eq 0 ]]; then
        check_pass "No errors found in installation log"
    else
        check_warn "Found $ERROR_COUNT potential errors in log"
        echo "  Recent errors:"
        grep -i "error\|failed\|fail" "$LOG_FILE" 2>/dev/null | tail -5 | sed 's/^/    /' || true
    fi
else
    check_warn "Cannot read installation log file"
fi

if [[ -n "$LOG_FILE" ]] && [[ -f "$LOG_FILE" ]] && [[ -r "$LOG_FILE" ]]; then
    WARNING_COUNT=$(grep -ic "warning" "$LOG_FILE" 2>/dev/null || echo "0")
    if [[ $WARNING_COUNT -eq 0 ]]; then
        check_pass "No warnings found in installation log"
    else
        check_warn "Found $WARNING_COUNT warnings in log"
    fi
fi

if [[ -f "$CONFIG_FILE" ]]; then
    check_pass "Configuration file found: $CONFIG_FILE"

    if grep -q "^INSTALL_TYPE=" "$CONFIG_FILE"; then
        INSTALL_TYPE=$(grep "^INSTALL_TYPE=" "$CONFIG_FILE" | cut -d= -f2)
        check_pass "Installation type: $INSTALL_TYPE"
    else
        check_fail "INSTALL_TYPE not found in config"
    fi

    if grep -q "^USERNAME=" "$CONFIG_FILE"; then
        USERNAME=$(grep "^USERNAME=" "$CONFIG_FILE" | cut -d= -f2)
        check_pass "Username configured: $USERNAME"
    else
        check_fail "USERNAME not found in config"
    fi
else
    check_fail "Configuration file not found: $CONFIG_FILE"
fi

echo ""
echo "Checking system services..."
FAILED_SERVICES=$($SUDO_CMD systemctl --failed --no-legend 2>/dev/null | wc -l || echo "0")
if [[ $FAILED_SERVICES -eq 0 ]]; then
    check_pass "No failed system services"
else
    check_fail "$FAILED_SERVICES failed service(s) found"
    $SUDO_CMD systemctl --failed --no-legend | sed 's/^/    /'
fi

if $SUDO_CMD systemctl is-enabled NetworkManager &>/dev/null; then
    if $SUDO_CMD systemctl is-active NetworkManager &>/dev/null; then
        check_pass "NetworkManager is running"
    else
        check_fail "NetworkManager is enabled but not running"
    fi
else
    check_warn "NetworkManager is not enabled"
fi

if [[ -n "${INSTALL_TYPE:-}" ]] && [[ "$INSTALL_TYPE" != "SERVER" ]]; then
    DM_FOUND=false
    for dm in lightdm sddm gdm; do
        if $SUDO_CMD systemctl is-enabled "$dm" &>/dev/null; then
            DM_FOUND=true
            if $SUDO_CMD systemctl is-active "$dm" &>/dev/null; then
                check_pass "Display manager ($dm) is running"
            else
                check_warn "Display manager ($dm) is enabled but not running"
            fi
            break
        fi
    done
    if [[ "$DM_FOUND" == false ]]; then
        check_warn "No display manager found (expected for desktop installation)"
    fi
fi

echo ""
echo "Checking swap configuration..."
if $SUDO_CMD swapon --show &>/dev/null; then
    SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
    if [[ "$SWAP_SIZE" != "0B" ]] && [[ "$SWAP_SIZE" != "0" ]]; then
        check_pass "Swap is active (Size: $SWAP_SIZE)"

        if $SUDO_CMD zramctl &>/dev/null && $SUDO_CMD zramctl | grep -q .; then
            check_pass "ZRAM is configured"
        fi

        if [[ -f /swapfile ]] || $SUDO_CMD test -f /swapfile 2>/dev/null; then
            check_pass "Swap file exists: /swapfile"
        fi
    else
        check_warn "Swap is configured but size is 0"
    fi
else
    check_warn "No swap found (may be intentional for high-RAM systems)"
fi

if [[ -n "${USERNAME:-}" ]]; then
    if id "$USERNAME" &>/dev/null; then
        check_pass "User account '$USERNAME' exists"

        # Check home directory
        if [[ -d "/home/$USERNAME" ]]; then
            check_pass "Home directory exists: /home/$USERNAME"
        else
            check_fail "Home directory not found: /home/$USERNAME"
        fi

        if [[ "$USERNAME" == "$(whoami)" ]] || [[ "$IS_ROOT" == true ]]; then
            if sudo -v &>/dev/null 2>&1 || [[ "$IS_ROOT" == true ]]; then
                check_pass "User '$USERNAME' has sudo access"
            else
                check_warn "User '$USERNAME' may not have sudo access"
            fi
        else
            if groups "$USERNAME" 2>/dev/null | grep -q wheel; then
                check_pass "User '$USERNAME' is in wheel group (has sudo access)"
            else
                check_warn "User '$USERNAME' is not in wheel group"
            fi
        fi
    else
        check_fail "User account '$USERNAME' not found"
    fi
fi

if [[ -n "${INSTALL_TYPE:-}" ]] && [[ "$INSTALL_TYPE" != "SERVER" ]]; then
    if [[ -f "$CONFIG_FILE" ]] && grep -q "^AUR_HELPER=" "$CONFIG_FILE"; then
        AUR_HELPER=$(grep "^AUR_HELPER=" "$CONFIG_FILE" | cut -d= -f2)
        if [[ "$AUR_HELPER" != "NONE" ]]; then
            if command -v "$AUR_HELPER" &>/dev/null; then
                check_pass "AUR helper installed: $AUR_HELPER"
            else
                check_fail "AUR helper '$AUR_HELPER' not found in PATH"
            fi
        fi
    fi
fi

if [[ -n "${INSTALL_TYPE:-}" ]] && [[ "$INSTALL_TYPE" != "SERVER" ]]; then
    if [[ -f "$CONFIG_FILE" ]] && grep -q "^DESKTOP_ENV=" "$CONFIG_FILE"; then
        DESKTOP_ENV=$(grep "^DESKTOP_ENV=" "$CONFIG_FILE" | cut -d= -f2)
        case "$DESKTOP_ENV" in
            kde)
                if pacman -Q plasma-desktop &>/dev/null; then
                    check_pass "KDE Plasma is installed"
                else
                    check_fail "KDE Plasma packages not found"
                fi
                ;;
            gnome)
                if pacman -Q gnome-shell &>/dev/null; then
                    check_pass "GNOME is installed"
                else
                    check_fail "GNOME packages not found"
                fi
                ;;
            i3-wm)
                if pacman -Q i3-wm &>/dev/null; then
                    check_pass "i3-wm is installed"
                else
                    check_fail "i3-wm not found"
                fi
                ;;
            *)
                check_warn "Desktop environment check not implemented for: $DESKTOP_ENV"
                ;;
        esac
    fi
fi

echo ""
echo "Checking SSH service..."
if $SUDO_CMD systemctl is-enabled sshd &>/dev/null; then
    if $SUDO_CMD systemctl is-active sshd &>/dev/null; then
        check_pass "SSH service is running"

        # Get IP address for SSH connection info
        IP_ADDRESS=$(hostname -I 2>/dev/null | awk '{print $1}' || ip addr show 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        if [[ -n "$IP_ADDRESS" ]]; then
            echo "    SSH connection: ssh $USERNAME@$IP_ADDRESS"
        fi
    else
        check_warn "SSH service is enabled but not running"
    fi
else
    check_warn "SSH service is not enabled"
fi

echo ""
echo "Checking network connectivity..."
if ping -c 1 -W 2 google.com &>/dev/null; then
    check_pass "Network connectivity working"
else
    check_warn "Cannot reach google.com (network may be down or not configured)"
fi

echo ""
echo "Checking disk space..."
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $DISK_USAGE -lt 90 ]]; then
    check_pass "Disk usage: ${DISK_USAGE}% (healthy)"
elif [[ $DISK_USAGE -lt 95 ]]; then
    check_warn "Disk usage: ${DISK_USAGE}% (getting full)"
else
    check_fail "Disk usage: ${DISK_USAGE}% (critical)"
fi

echo ""
echo "=========================================="
echo "  Verification Summary"
echo "=========================================="
echo "Total checks: $CHECKS"
echo -e "${GREEN}Passed: $((CHECKS - ERRORS - WARNINGS))${NC}"
if [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
fi
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Errors: $ERRORS${NC}"
fi
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ Installation verification completed successfully!${NC}"
    echo ""
    echo "If you see warnings, they may not be critical. Check the details above."
    echo "For detailed error analysis, check: $LOG_FILE"
    exit 0
else
    echo -e "${RED}✗ Installation verification found $ERRORS error(s)${NC}"
    echo ""
    echo "Please review the errors above and check the installation log:"
    echo "  $LOG_FILE"
    echo ""
    echo "For troubleshooting help, see:"
    echo "  /root/archinstaller/docs/TROUBLESHOOTING.md"
    exit 1
fi