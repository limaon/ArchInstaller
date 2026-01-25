# Quick Diagnostic Checklist - ArchInstaller

Use this checklist to quickly verify that everything worked correctly after installation.

## 1. Log Verification (Important!)

```bash
# Check for errors in installation log
grep -i "error\|failed\|fail" /var/log/install.log | tail -20

# Check warnings
grep -i "warning" /var/log/install.log | tail -20

# Check last log (100 lines)
tail -n 100 /var/log/install.log

# Check real-time logs (still installing)
tail -f /var/log/install.log
```

## 2. Critical Services Verification

```bash
# Check important services
systemctl status NetworkManager
systemctl status lightdm    # or sddm/gdm depending on DE
systemctl status zram-generator  # if ZRAM was configured

# List enabled services
systemctl list-unit-files --state=enabled

# Check failed services
systemctl --failed
```

## 3. Installed Components Verification

```bash
# Check desktop environment (replace based on your DE)
# For KDE
pacman -Q | grep -i plasma

# For GNOME
pacman -Q | grep -i gnome

# For i3-wm
pacman -Q | grep -i i3

# Check AUR helper
which yay  # or paru
yay --version  # or paru --version

# Check swap configuration
swapon --show
free -h

# Check ZRAM (if configured)
zramctl
cat /proc/swaps
```

## 4. Filesystem Verification

```bash
# Check mounted filesystems
df -h

# Check swap
swapon --show
free -h

# Check btrfs subvolumes (if btrfs was used)
btrfs subvolume list /

# Check disk partitions
lsblk -f
```

## 5. User Configuration Verification

```bash
# Check if user was created
id $USERNAME  # Replace $USERNAME with your username

# Check user groups
groups

# Check home directory
ls -la ~

# Check sudo access
sudo -v
```

## 6. Network Verification

```bash
# Test connectivity
ping -c 3 google.com

# Check NetworkManager status
systemctl status NetworkManager

# List network interfaces
ip addr show
# or
nmcli device status
```

## 7. Boot Verification

```bash
# Check GRUB configuration
ls -la /boot/grub/

# Check kernel
uname -r

# Check initramfs
ls -la /boot/initramfs-*.img
```

## 8. Desktop Environment Verification

```bash
# Check if DE is running
systemctl status lightdm  # or sddm/gdm

# Check display manager logs
journalctl -u lightdm -n 50  # or sddm/gdm

# Try to start manually
sudo systemctl start lightdm
```

## 9. Swap Verification (Specific)

```bash
# Check complete swap status
swapon --show
free -h

# Check swap file location (depends on filesystem)
# For Btrfs:
ls -lh /swap/swapfile

# For ext4:
ls -lh /swapfile

# Check failed systemd swap units
systemctl --failed | grep swap
```

---

## Summary - Success Signs

**Installation was successful if:**
- No critical errors in `/var/log/install.log`
- All services start without errors (`systemctl --failed` shows empty)
- Desktop environment starts correctly
- Network connectivity works
- Swap is configured and active
- Can log in
- All selected packages are installed

---

## Next Steps

If any checklist item fails:
- Check [Common Problems](./COMMON-PROBLEMS.md) for solutions
- See [Specific Features](./SPECIFIC-FEATURES.md) for your desktop environment
- Report issues following the [Reporting Guide](./REPORTING.md)
