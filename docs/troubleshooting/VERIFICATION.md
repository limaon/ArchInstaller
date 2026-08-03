# Installation Verification - ArchInstaller

This document explains how to verify if your Arch Linux installation worked correctly after reboot.

## Manual Verification

After logging into your new system, check the following:

### 1. Check Installation Log

```bash
# View the installation log
cat ~/.archinstaller/install.log

# Check for errors
grep -i "error\|failed\|fail" ~/.archinstaller/install.log

# Check for warnings
grep -i "warning" ~/.archinstaller/install.log
```

### 2. Check System Services

```bash
# Check for failed services
systemctl --failed --no-legend

# Check NetworkManager
systemctl is-enabled NetworkManager
systemctl is-active NetworkManager

# Check display manager (lightdm, sddm, or gdm)
systemctl is-enabled sddm
systemctl is-active sddm
```

### 3. Check Network and SSH

```bash
# Test network connectivity
ping -c 1 google.com

# Check SSH service
systemctl is-enabled sshd
systemctl is-active sshd

# Get IP address for SSH connection
ip addr show
# or
hostname -I
```

### 4. Check Swap Configuration

```bash
# Check swap status
swapon --show
free -h

# Check ZRAM
zramctl
```

### 5. Check User Account

```bash
# Verify user exists
id $USER

# Check home directory
ls -la ~/

# Check sudo access
sudo -v
```

### 6. Check Desktop Environment

```bash
# KDE Plasma
pacman -Q plasma-desktop

# GNOME
pacman -Q gnome-shell

# i3
pacman -Q i3-wm
```

### 7. Check Disk Space

```bash
df -h /
```

## Files Available After Installation

The installer automatically copies these files to `~/.archinstaller/`:

- `install.log` - Complete installation log
- `setup.conf` - Installation configuration (password removed for security)

**Important:** These files persist even after the installer cleans up temporary files.

---

## Next Steps

If verification shows everything OK:
- Congratulations! Your installation was successful
- Continue with post-installation configuration according to [User Guide](../../docs/USER-GUIDE.md)

If you encounter problems:
- Check the [Quick Checklist](./QUICK-CHECK.md) for quick diagnosis
- See [Common Problems](./COMMON-PROBLEMS.md) for solutions
- Report issues following the [Reporting Guide](./REPORTING.md)
