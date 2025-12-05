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

#### Swap File Creation Requirements

The installer automatically creates a swap file based on intelligent hardware analysis. The decision considers RAM amount, storage type (SSD/HDD), installation type, and available disk space.

**Decision Table by RAM:**

| RAM | SSD | HDD | Strategy | Swap File Size |
|-----|-----|-----|----------|----------------|
| **< 4GB** | ❌ No | ❌ No | ZRAM only (2x RAM) | N/A |
| **4-8GB** | ❌ No | ✅ **Yes** | ZRAM (2x RAM) + Swap File | **2GB** |
| **8-16GB** | ❌ No | ✅ **Yes** | Swap File only | **4GB** |
| **16-32GB** | ✅ **Yes** | ✅ **Yes** | Swap File only | **2GB (SSD)** or **4GB (HDD)** |
| **> 32GB** | ✅ **Yes** | ✅ **Yes** | Swap File only | **1GB (SSD)** or **2GB (HDD)** |

**Special Cases:**
- **SERVER installations**: Always creates 4GB swap file, regardless of RAM or storage type
- **Disk space requirement**: Needs at least (SWAP_SIZE + 2GB) free space
- **If insufficient space**: Swap file is not created, uses ZRAM only if available

**Why swap file wasn't created:**

1. **Check RAM amount:**
   ```bash
   free -h
   grep MemTotal /proc/meminfo
   ```

2. **Check storage type:**
   ```bash
   lsblk -n --output TYPE,ROTA /dev/sda  # Replace /dev/sda with your disk
   # SSD: ROTA=0, HDD: ROTA=1
   ```

3. **Check available space:**
   ```bash
   df -h /
   ```

4. **Check installation type:**
   ```bash
   grep INSTALL_TYPE ~/.archinstaller/setup.conf
   ```

**Swap file location:**
- Path: `/swapfile` (root of filesystem)
- Permissions: `600` (rw-------)
- Created with: `mkswap --file`

**Automatic configuration:**
When created, the swap file is automatically:
- Activated immediately (`swapon /swapfile`)
- Added to `/etc/fstab` for automatic activation on boot
- Configured with appropriate priority (50 if ZRAM exists, default otherwise)
- Configured `vm.swappiness` (10 if ZRAM exists, 60 otherwise)

**Reference**: Function `low_memory_config()` in `scripts/utils/system-config.sh`

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

## Auto Suspend/Hibernate (i3-wm)

### How to Test the Suspend/Hibernate Implementation

After installing the system with i3-wm, you can verify if the automatic suspend/hibernate implementation is working correctly:

#### 1. Basic Checks

**Check if `xidlehook` is installed**:
```bash
which xidlehook
xidlehook --version
```

**If not installed** (because you chose `AUR_HELPER=NONE`):
```bash
# Install base-devel and git first
sudo pacman -S base-devel git

# Clone and compile xidlehook manually
cd /tmp
git clone https://aur.archlinux.org/xidlehook.git
cd xidlehook
makepkg -si
```

**Check if scripts are installed**:
```bash
ls -la /usr/local/bin/auto-suspend-hibernate
ls -la /usr/local/bin/check-swap-for-hibernate

# Test scripts
/usr/local/bin/check-swap-for-hibernate --help
/usr/local/bin/auto-suspend-hibernate --help
```

**Check GRUB configuration (resume=)**:
```bash
grep -i "resume" /etc/default/grub
# Should show something like:
# GRUB_CMDLINE_LINUX_DEFAULT="... resume=UUID=..."
```

**Note**: The `resume=` parameter is automatically added to GRUB when:
- A swap file exists at `/swapfile` (created by the installer's intelligent swap configuration)
- This enables hibernation support by telling the kernel which swap device to resume from
- The installer automatically detects the swap file UUID and adds it during GRUB configuration
- If no swap file exists, this parameter is **not** added (hibernation won't work without swap)

**When swap file is created (and thus `resume=` is added):**
- **4-8GB RAM + HDD**: Swap file (2GB) is created → `resume=` is added
- **8-16GB RAM + HDD**: Swap file (4GB) is created → `resume=` is added
- **16-32GB RAM + SSD/HDD**: Swap file (2GB SSD / 4GB HDD) is created → `resume=` is added
- **>32GB RAM + SSD/HDD**: Swap file (1GB SSD / 2GB HDD) is created → `resume=` is added
- **SERVER installations**: Swap file (4GB) is always created → `resume=` is always added

**When swap file is NOT created (and thus `resume=` is NOT added):**
- **<4GB RAM**: Only ZRAM, no swap file → `resume=` is **not** added
- **4-8GB RAM + SSD**: Only ZRAM, no swap file → `resume=` is **not** added
- **8-16GB RAM + SSD**: Only ZRAM, no swap file → `resume=` is **not** added
- **Insufficient disk space**: Swap file not created → `resume=` is **not** added

**Check swap**:
```bash
# Check active swap
swapon --show
free -h

# Check if swap is sufficient for hibernation
/usr/local/bin/check-swap-for-hibernate --verbose
```

**Check systemd logind configuration**:
```bash
cat /etc/systemd/logind.conf.d/50-hibernate.conf
# Should show lid switch and power keys configuration
```

#### 2. Manual Tests

**Test power detection (AC/Battery)**:
```bash
# Check power status
acpi -a  # Should show "on-line" or "off-line"
acpi -b  # Should show battery status

# Test suspend/hibernate script (verbose to see what it decides)
/usr/local/bin/auto-suspend-hibernate --verbose
```

**Test manual hibernation**:
```bash
# Check swap first
/usr/local/bin/check-swap-for-hibernate --verbose

# If swap is sufficient, test manual hibernation
# WARNING: This will hibernate the system!
systemctl hibernate

# After returning, verify if programs are still open
```

**Test manual suspension**:
```bash
# Test manual suspension
# WARNING: This will suspend the system!
systemctl suspend

# After returning, verify if system returned quickly
```

**Check if xidlehook is running**:
```bash
ps aux | grep xidlehook
# Should show xidlehook process running
```

**View xidlehook logs** (if available):
```bash
# Check systemd logs (if xidlehook was started via systemd)
journalctl --user -f | grep -i xidlehook
```

#### 4. Test Automatic Behavior

**Restart i3** to ensure xidlehook starts:
```bash
# In i3-wm, press Mod+Shift+R (usually Alt+Shift+R)
# Or restart i3 manually
i3-msg restart
```

**Check if xidlehook started automatically**:
```bash
# Wait a few seconds after login to i3
ps aux | grep xidlehook
```

**Test inactivity**:
1. Log into i3-wm
2. Do not touch the computer for **30 minutes and 30 seconds** (default configured time)
3. After 30 minutes, you should see a notification: "The system will hibernate/suspend in 30 seconds..."
4. If you don't touch it, after another 30 seconds the system should suspend or hibernate

**Expected behavior**:
- **With charger connected (AC)**: System suspends (suspend to RAM)
- **Without charger (Battery)**:
  - If swap >= RAM: System hibernates (suspend to disk)
  - If swap < RAM: System suspends (suspend to RAM, fallback)

**During audio or fullscreen**: xidlehook does not execute (thanks to `--not-when-audio` and `--not-when-fullscreen`)

#### 5. Troubleshooting Checks

**Problem: xidlehook does not start automatically**

```bash
# Check i3 config
cat ~/.config/i3/config | grep -A 10 xidlehook

# Check if xidlehook is installed
which xidlehook

# Try starting manually
xidlehook --help
```

**Problem: auto-suspend-hibernate script does not work**

```bash
# Test script manually with verbose
/usr/local/bin/auto-suspend-hibernate --verbose

# Check permissions
ls -la /usr/local/bin/auto-suspend-hibernate
ls -la /usr/local/bin/check-swap-for-hibernate

# Check if acpi is installed
which acpi
acpi -b
```

**Problem: Hibernation does not work (always suspends)**

```bash
# Check swap
swapon --show
free -h
/usr/local/bin/check-swap-for-hibernate --verbose

# Check GRUB resume=
grep resume /etc/default/grub
# If there's no resume=, regenerate GRUB:
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Check if swap file exists
ls -lh /swapfile

# Check swap UUID
sudo findmnt -no UUID -T /swapfile
# Or
sudo blkid | grep swap
```

**Problem: System does not return from hibernation**

```bash
# Check if resume= is in GRUB
grep resume /boot/grub/grub.cfg

# Check if UUID is correct
sudo blkid | grep swap
grep resume /etc/default/grub

# Regenerate initramfs (may help)
sudo mkinitcpio -P
```

**Problem: xidlehook executes even with audio/fullscreen**

```bash
# Check configuration in i3 config
grep -A 10 xidlehook ~/.config/i3/config
# Should have --not-when-audio and --not-when-fullscreen

# Restart i3 to apply changes
i3-msg restart
```

#### 6. Useful Commands for Diagnosis

```bash
# Check everything at once
echo "=== Checking Auto Suspend/Hibernate ==="
echo ""
echo "1. xidlehook installed:"
which xidlehook && xidlehook --version || echo "Not installed"
echo ""
echo "2. Scripts installed:"
ls -la /usr/local/bin/auto-suspend-hibernate /usr/local/bin/check-swap-for-hibernate 2>/dev/null || echo "Scripts not found"
echo ""
echo "3. i3 config configured:"
grep -q xidlehook ~/.config/i3/config && echo "✓ Configured" || echo "✗ Not configured"
echo ""
echo "4. GRUB resume=:"
grep -q resume /etc/default/grub && echo "✓ Configured" || echo "✗ Not configured"
echo ""
echo "5. Swap status:"
swapon --show
echo ""
echo "6. Sufficient swap for hibernation:"
/usr/local/bin/check-swap-for-hibernate --verbose 2>/dev/null || echo "Script not found"
echo ""
echo "7. Power status:"
acpi -a 2>/dev/null || echo "acpi not available"
echo ""
echo "8. xidlehook running:"
ps aux | grep -v grep | grep xidlehook && echo "✓ Running" || echo "✗ Not running"
```

**Restart i3** after changing:
```bash
i3-msg restart
```

---

## Battery Notifications (i3-wm)

### Problem: Battery notifications not working

**Symptoms**: No notifications appear for battery level or charger connection.

**Diagnosis**:

```bash
# Check if timer is enabled
systemctl --user status battery-alert.timer

# Check if scripts exist
ls -la /usr/local/bin/battery-*

# Check if dependencies are installed
which acpi
which notify-send

# Check if dunst is running (notification daemon)
systemctl --user status dunst

# Test script manually
/usr/local/bin/battery-alert

# Check systemd unit files
ls -la ~/.config/systemd/user/battery-alert.*

# Check udev rules
ls -la /etc/udev/rules.d/60-battery-notifications.rules
```

**Solutions**:

#### Timer not enabled
```bash
# Enable and start timer
systemctl --user enable battery-alert.timer
systemctl --user start battery-alert.timer

# Reload systemd user daemon if needed
systemctl --user daemon-reload
```

#### Dependencies missing
```bash
# Install required packages
sudo pacman -S acpi libnotify

# Start notification daemon (dunst should be in i3 autostart)
dunst &
```

#### Scripts not found
```bash
# If configs are available, copy scripts manually
sudo cp ~/.archinstaller/configs/i3-wm/usr/local/bin/battery-* /usr/local/bin/
sudo chmod 755 /usr/local/bin/battery-*

# Copy systemd units
mkdir -p ~/.config/systemd/user/
cp ~/.archinstaller/configs/i3-wm/etc/skel/.config/systemd/user/* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable battery-alert.timer
```

#### Dunst not running
```bash
# Start dunst manually
dunst &

# Add to i3 config if not present
echo 'exec --no-startup-id dunst' >> ~/.config/i3/config

# Restart i3 (press Mod+Shift+R in i3)
```

#### Udev rules not working
```bash
# Check if udev rules exist
cat /etc/udev/rules.d/60-battery-notifications.rules

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=power_supply

# Test udev trigger manually
sudo udevadm trigger --action=change --subsystem-match=power_supply
```

#### Desktop system (no battery)
**Expected behavior**: Scripts exit silently if no battery is detected. This is normal.

```bash
# Check if battery exists
acpi -b

# If no output, system doesn't have a battery (desktop)
# Notifications won't work, but this is expected
```

### Problem: Too many notifications

**Solution**: Lock files prevent duplicate notifications. They are automatically managed, but you can clear them manually:

```bash
# Remove lock files (resets notification state)
rm -f /tmp/battery-$USER-*
```

### Problem: Want to customize notification levels

**Solution**: Edit the script:

```bash
# Edit warning/critical levels
sudo nano /usr/local/bin/battery-alert

# Change these lines:
# WARNING_LEVEL=20   # Change to your preferred level
# CRITICAL_LEVEL=5   # Change to your preferred level
```

### Problem: Want to change check interval

**Solution**: Edit the systemd timer:

```bash
# Edit timer unit
systemctl --user edit battery-alert.timer

# Or edit file directly
nano ~/.config/systemd/user/battery-alert.timer

# Change these lines:
# OnBootSec=5min      # Time after boot to first check
# OnUnitActiveSec=5min # Interval between checks
```

### Useful Commands

```bash
# View help for scripts
battery-alert --help
battery-charging --help
battery-udev-notify --help

# Check timer logs
journalctl --user -u battery-alert.service -f

# View timer status
systemctl --user status battery-alert.timer

# Disable notifications
systemctl --user disable battery-alert.timer
systemctl --user stop battery-alert.timer

# Re-enable notifications
systemctl --user enable battery-alert.timer
systemctl --user start battery-alert.timer
```

---

## Btrfs Snapshot Restoration

If you installed with btrfs filesystem, the system uses **Snapper** for snapshot management and **grub-btrfs** for booting from snapshots. The **snap-pac** package automatically creates snapshots before and after every pacman operation.

### Restoring After a Failed Pacman Installation

When you install a package that breaks your system, `snap-pac` has already created "pre" and "post" snapshots:

#### 1. List Available Snapshots

```bash
sudo snapper -c root list
```

Example output:
```
 # | Type   | Pre # | Date                     | Description
---+--------+-------+--------------------------+-------------
 1 | single |       | Mon Dec  4 10:00:00 2024 | Initial
 2 | pre    |       | Mon Dec  4 14:30:00 2024 | pacman -S problematic-package
 3 | post   |     2 | Mon Dec  4 14:30:05 2024 | pacman -S problematic-package
```

#### 2. Undo the Last Pacman Operation

```bash
# Revert changes between pre (2) and post (3) snapshots
sudo snapper -c root undochange 2..3
```

This restores all files changed by that pacman operation.

#### 3. Quick Undo (Last Operation)

```bash
# Find the last "pre" snapshot and undo changes to current state
sudo snapper -c root undochange $(sudo snapper -c root list | grep "pre" | tail -1 | awk '{print $1}')..0
```

### Restoring When System Won't Boot

If the system doesn't boot after a bad update:

#### 1. Boot from Snapshot via GRUB

1. At the GRUB menu, select **"Arch Linux snapshots"**
2. Choose the snapshot labeled **"pre"** from before the problematic update
3. The system boots in read-only mode from that snapshot

#### 2. Make the Rollback Permanent

After booting from the snapshot and verifying it works:

```bash
# Perform permanent rollback
sudo snapper -c root rollback

# Reboot to apply
sudo reboot
```

### Restoring Individual Files

If only specific files are broken:

```bash
# Restore a single file from a snapshot
sudo snapper -c root undochange <snapshot_number> /path/to/file

# Restore multiple files
sudo snapper -c root undochange <snapshot_number> /file1 /file2 /file3
```

### Comparing Snapshots

To see what changed between snapshots:

```bash
# List files that differ between two snapshots
sudo snapper -c root status <old_number> <new_number>

# Show detailed diff
sudo snapper -c root diff <old_number> <new_number>
```

### Manual Restoration (Advanced)

If you need to restore from a Live ISO:

```bash
# 1. Boot Arch Linux ISO and mount the btrfs volume
mount /dev/sdXY /mnt

# 2. List all subvolumes and snapshots
btrfs subvolume list /mnt

# 3. Rename the broken root subvolume
mv /mnt/@ /mnt/@_broken

# 4. Create a new @ from a working snapshot
btrfs subvolume snapshot /mnt/.snapshots/<number>/snapshot /mnt/@

# 5. Unmount and reboot
umount /mnt
reboot
```

### Useful Snapper Commands

```bash
# List all snapshots
sudo snapper -c root list

# Create manual snapshot before risky operation
sudo snapper -c root create --description "Before manual changes"

# Delete a specific snapshot
sudo snapper -c root delete <number>

# Delete old snapshots (cleanup)
sudo snapper -c root cleanup number

# View snapshot space usage
sudo btrfs filesystem du -s /.snapshots

# Enable automatic timeline snapshots (disabled by default)
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
```

### Snapshot Types

| Type | Created By | Description |
|------|------------|-------------|
| **pre** | snap-pac | Before pacman operations (-S, -R, -U) |
| **post** | snap-pac | After pacman operations |
| **single** | Manual/timeline | Manual snapshots or timeline |

### GUI Tool (If Installed)

For FULL installations, **btrfs-assistant** provides a graphical interface:

```bash
btrfs-assistant
```

Features:
- Visual snapshot browser
- One-click restore
- Subvolume management
- Disk usage analysis

### Important Notes

1. **@home is separate**: The `@home` subvolume is NOT included in root snapshots. Your personal files in `/home` are not affected by system rollbacks.

2. **Snapshots ≠ Backups**: Snapshots are on the same disk. For real backups, copy to another device.

3. **Space limit**: Snapshots are limited to 50% of disk space (`SPACE_LIMIT="0.5"` in snapper config).

4. **After rollback**: Regenerate GRUB to update the snapshot menu:
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```

**Reference**: [ArchWiki - Snapper](https://wiki.archlinux.org/title/Snapper)

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

