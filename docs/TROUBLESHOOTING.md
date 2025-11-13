# Troubleshooting Guide - Verifying Installation Success

## Automatic Verification After Reboot

After installation completes and you reboot the system, you can verify everything worked correctly:

### Option 1: Run Verification Script Locally

After logging into your new system:

```bash
# Run the verification script (as your user - it will use sudo when needed)
~/.archinstaller/verify-installation.sh

# Or if you're already in your home directory
./.archinstaller/verify-installation.sh
```

The script will automatically:
- Check installation logs for errors
- Verify system services
- Check network and SSH configuration
- Verify swap configuration
- Check user account and permissions
- Verify desktop environment installation
- Display SSH connection information

### Option 2: Connect via SSH and Run Verification

The installer automatically configures SSH for remote access. After reboot:

1. **Find the server IP address** (on the server):
   ```bash
   ip addr show
   # or
   hostname -I
   ```

2. **Connect remotely** (from another machine):
   ```bash
   ssh your-username@server-ip-address
   ```

3. **Run verification script**:
   ```bash
   ~/.archinstaller/verify-installation.sh
   ```

### Files Available After Installation

The installer automatically copies these files to `~/.archinstaller/`:

- `install.log` - Complete installation log
- `verify-installation.sh` - Verification script
- `setup.conf` - Installation configuration (password removed for security)

These files persist even after the installer cleans up temporary files.

---

## Quick Verification Checklist

After installation completes, verify everything worked correctly:

### 1. Check Installation Logs

All installation output is saved to `/var/log/install.log`:

```bash
# View complete log (scroll with arrow keys, press 'q' to quit)
less /var/log/install.log

# Search for errors (case-insensitive)
grep -i error /var/log/install.log

# Search for warnings
grep -i warning /var/log/install.log

# Search for failed operations
grep -i "failed\|fail\|error" /var/log/install.log

# View last 100 lines (most recent output)
tail -n 100 /var/log/install.log

# View last 50 lines and follow new output (if still installing)
tail -f /var/log/install.log
```

### 2. Common Error Patterns to Look For

```bash
# Check for package installation failures
grep -i "error: failed to install\|pacman.*error" /var/log/install.log

# Check for AUR helper failures
grep -i "aur.*error\|yay.*error\|paru.*error" /var/log/install.log

# Check for service failures
grep -i "failed to enable\|systemctl.*failed" /var/log/install.log

# Check for permission errors
grep -i "permission denied\|access denied" /var/log/install.log

# Check for disk/filesystem errors
grep -i "disk\|filesystem\|mount.*error" /var/log/install.log

# Check for network errors
grep -i "network\|connection.*failed\|timeout" /var/log/install.log
```

### 3. Verify System Services

```bash
# Check if critical services are enabled and running
systemctl status NetworkManager
systemctl status lightdm  # or sddm/gdm depending on DE
systemctl status zram-generator  # if ZRAM was configured

# List all enabled services
systemctl list-unit-files --state=enabled

# Check for failed services
systemctl --failed
```

### 4. Verify Installed Components

```bash
# Check desktop environment installation
# For KDE
pacman -Q | grep -i plasma

# For GNOME
pacman -Q | grep -i gnome

# For i3-wm
pacman -Q | grep -i i3

# Check AUR helper installation
which yay  # or paru, depending on choice
yay --version  # or paru --version

# Check swap configuration
swapon --show
free -h

# Check ZRAM (if configured)
zramctl
cat /proc/swaps
```

### 5. Verify Filesystem and Partitions

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

### 6. Verify User Configuration

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

### 7. Verify Network Configuration

```bash
# Check network connectivity
ping -c 3 google.com

# Check NetworkManager status
systemctl status NetworkManager

# List network interfaces
ip addr show
# or
nmcli device status
```

### 8. Verify Boot Configuration

```bash
# Check GRUB configuration
ls -la /boot/grub/

# Check kernel
uname -r

# Check initramfs
ls -la /boot/initramfs-*.img
```

### 9. Check Configuration File

```bash
# View installation configuration
cat /root/archinstaller/configs/setup.conf

# Verify all required variables are set
grep -E "^[A-Z_]+=" /root/archinstaller/configs/setup.conf
```

### 10. Common Issues and Solutions

#### Issue: Desktop Environment Not Starting

```bash
# Check display manager status
systemctl status lightdm  # or sddm/gdm

# Check X11/Wayland logs
journalctl -u lightdm -n 50  # or sddm/gdm

# Try starting manually
sudo systemctl start lightdm
```

#### Issue: Network Not Working

```bash
# Check NetworkManager
systemctl status NetworkManager
sudo systemctl start NetworkManager

# Check network interfaces
ip link show

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

#### Issue: Swap Not Working

```bash
# Check swap status
swapon --show
free -h

# Check ZRAM (if configured)
zramctl
cat /proc/swaps

# Check swap file (if created)
ls -lh /swapfile

# Check for failed systemd swap units
systemctl --failed | grep swap

# Fix swap file issues
# Option 1: Use the fix script (if available)
sudo ~/.archinstaller/fix-swap.sh

# Option 2: Manual fix
# Deactivate and remove old swap
sudo swapoff /swapfile 2>/dev/null || true
sudo rm -f /swapfile

# Remove systemd units
sudo systemctl stop swapfile.swap 2>/dev/null || true
sudo systemctl disable swapfile.swap 2>/dev/null || true
sudo rm -f /etc/systemd/system/swapfile.swap
sudo systemctl daemon-reload

# Remove from fstab
sudo sed -i '/\/swapfile/d' /etc/fstab

# Recreate swap file (4GB example, adjust as needed)
# For Btrfs:
sudo mkswap -U clear --size 4G --file /swapfile
sudo chmod 600 /swapfile
sudo chattr +C /swapfile
sudo btrfs property set /swapfile compression none

# For ext4:
sudo mkswap -U clear --size 4G --file /swapfile
sudo chmod 600 /swapfile

# Activate and add to fstab
sudo swapon /swapfile
echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
```

**Reference**: [ArchWiki - Swap](https://wiki.archlinux.org/title/Swap)

#### Issue: AUR Helper Not Working

```bash
# Check if installed
which yay  # or paru

# Reinstall if needed (as normal user, not root)
cd /tmp
git clone https://aur.archlinux.org/yay.git  # or paru
cd yay
makepkg -si
```

#### Issue: Packages Not Installed

```bash
# Check if package is installed
pacman -Q package-name

# Check installation log for that package
grep -i "package-name" /var/log/install.log

# Try installing manually
sudo pacman -S package-name
```

### 11. Generate Installation Report

Create a comprehensive report of your installation:

```bash
# Create report file
cat > ~/installation-report.txt << 'EOF'
=== ArchInstaller Installation Report ===
Date: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)

=== System Information ===
RAM: $(free -h | grep Mem | awk '{print $2}')
Disk: $(df -h / | tail -1)
CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2)

=== Installation Configuration ===
$(cat /root/archinstaller/configs/setup.conf)

=== Installed Services ===
$(systemctl list-unit-files --state=enabled | grep -E 'enabled|static')

=== Swap Configuration ===
$(swapon --show)
$(free -h)

=== Errors Found in Log ===
$(grep -i "error\|failed\|fail" /var/log/install.log | tail -20)

=== Warnings Found in Log ===
$(grep -i "warning" /var/log/install.log | tail -20)
EOF

# View report
cat ~/installation-report.txt
```

### 12. What to Report if Issues Found

If you encounter errors, gather this information:

1. **Configuration** (from `/root/archinstaller/configs/setup.conf`):
   ```bash
   cat /root/archinstaller/configs/setup.conf | grep -v PASSWORD
   ```

2. **Relevant log sections**:
   ```bash
   grep -A 10 -B 10 "ERROR_MESSAGE" /var/log/install.log
   ```

3. **System information**:
   ```bash
   uname -a
   free -h
   lsblk
   ```

4. **What commit/branch** you used:
   ```bash
   cd /root/archinstaller
   git log -1 --oneline
   git branch
   ```

5. **Installation environment**:
   - VM (VMware, VirtualBox, QEMU/KVM) or bare metal
   - If VM, what configuration (RAM, CPU, disk size)

---

## Quick Commands Summary

```bash
# Most important checks
grep -i error /var/log/install.log | tail -20
systemctl --failed
swapon --show
systemctl status NetworkManager
pacman -Q | grep -i "your-desktop-env"
```

---

## Success Indicators

✅ **Installation was successful if:**
- No critical errors in `/var/log/install.log`
- All services start without errors (`systemctl --failed` shows nothing)
- Desktop environment starts correctly
- Network connectivity works
- Swap is configured and active
- User can log in
- All selected packages are installed

---

For more help, check:
- [Arch Linux Wiki](https://wiki.archlinux.org)
- [ArchInstaller Issues](https://github.com/limaon/ArchInstaller/issues)

