# Specific Features - ArchInstaller

This document covers specific features and advanced troubleshooting for ArchInstaller features.

---

## i3-wm Features

### Auto Suspend/Hibernate (Minimalist)

This feature implements automatic suspension/hibernation based on idle time using native systemd-logind.

#### Basic Verification

**Check systemd-logind configuration:**
```bash
systemctl status systemd-logind
# Should show: Active: active (running)

# Check power configuration
cat /etc/systemd/logind.conf.d/50-power.conf
# Should contain timeout and lid switch configurations

# Check i3 key bindings
grep -E "(Control+Delete|Control+BackSpace)" ~/.config/i3/config
```

**Check installed scripts:**
```bash
ls -la /usr/local/bin/auto-suspend-hibernate
ls -la /usr/local/bin/check-swap-for-hibernate

# Test scripts
/usr/local/bin/check-swap-for-hibernate --help
/usr/local/bin/auto-suspend-hibernate --help
```

**Check GRUB configuration (`resume=`):**
```bash
grep -i "resume" /etc/default/grub
# Should show something like:
# GRUB_CMDLINE_LINUX_DEFAULT="... resume=UUID=..."
```

**Note:** The `resume=` parameter is automatically added to GRUB when:
- Swap file exists (created by the installer's smart swap configuration)
- **Btrfs:** Swap file at `/swap/swapfile` (dedicated `@swap` subvolume)
- **ext4:** Swap file at `/swapfile` (root filesystem)
- This enables hibernation support by telling the kernel which swap device to use
- If no swap file exists, this parameter is **not** added (hibernation doesn't work without swap)

**Swap file is always created** (with ZRAM) for all RAM configurations:
- **< 4GB RAM:** ZRAM (2x) + 4GB swap file
- **4-8GB RAM:** ZRAM (2x) + 4-6GB swap file
- **8-16GB RAM:** ZRAM (1x) + 4-8GB swap file
- **16-32GB RAM:** ZRAM (1x) + 4-8GB swap file
- **> 32GB RAM:** ZRAM (1x) + 4GB swap file
- **SERVER:** Only swap file (4GB), no ZRAM

**When swap file is NOT created:**
- **Insufficient disk space:** Less than (SWAP_SIZE + 2GB) available

#### Swap Verification

```bash
# Check active swap
swapon --show
free -h

# Check if swap is sufficient for hibernation
/usr/local/bin/check-swap-for-hibernate --verbose
```

**Check systemd logind configuration:**
```bash
cat /etc/systemd/logind.conf.d/50-power-management.conf
# Should show lid switch, power keys and timeout configurations
```

#### Manual Tests

**Power detection test (AC/Battery):**
```bash
# Check power status
acpi -a  # Should show "on-line" or "off-line"
acpi -b  # Should show battery status

# Check systemd status and configuration
systemctl status systemd-logind
journalctl --user -u systemd-logind --since "10 minutes" | grep -i idle
```

**Manual hibernation test:**
```bash
# Check swap first
free -h && echo "---" && swapon --show

# If swap is sufficient, test manual hibernation
# WARNING: This will hibernate the system!
systemctl hibernate

# After returning, check if applications are still open
```

**Manual suspension test:**
```bash
# Test manual suspension
# WARNING: This will suspend the system!
systemctl suspend

# After returning, check if the system returned quickly
```

**Check systemd logind services:**
```bash
systemctl status systemd-logind
journalctl --user -u power-management.timer | tail -10

# Check user power services
systemctl --user list-units --type=service | grep -i power
```

#### Automatic Behavior Test

**Restart systemd-logind** to apply configurations:
```bash
# Restart system service
sudo systemctl restart systemd-logind

# Restart user services (if logged in)
systemctl --user restart power-management.timer
```

**Check idle detection status:**
```bash
# Check detection service status
systemctl --user status power-management.timer

# Check recent logs
journalctl --user -u power-management.timer --since "10 minutes ago"
```

**Test inactivity:**
1. Login to i3-wm
2. Don't touch the computer for **30 minutes** (default configured time)
3. After 30 minutes, the system should automatically suspend/hibernate
4. The system monitors power state and swap availability
4. If not touched, after another 30 seconds the system should suspend or hibernate

**Expected behavior:**
- **With charger connected (AC):** System suspends (suspends to RAM)
- **Without charger (Battery):**
  - If swap >= RAM: System hibernates (suspends to disk)
  - If swap < RAM: System suspends (suspends to RAM, fallback)

**During audio or fullscreen:** systemd-logind automatically suspends execution due to InhibitLock configuration

#### Troubleshooting

**Problem: System doesn't automatically suspend**

```bash
# Check systemd-logind status
systemctl status systemd-logind

# Check recent logs
journalctl -u systemd-logind --since "1 hour ago" | grep -E "(idle|suspend|hibernate)"

# Check configuration
cat /etc/systemd/logind.conf.d/50-power.conf

# Check power management scripts
ls -la /usr/local/bin/configure-power-management.sh
ls -la /usr/local/bin/setup-i3-power.sh

# Test manually
systemctl suspend 2>/dev/null && echo "Suspend OK" || echo "Suspend failed"

# Check status script
if command -v power-status &>/dev/null; then
    power-status
fi
```

**Problem: System doesn't automatically suspend**

```bash
# Check systemd-logind configuration
cat /etc/systemd/logind.conf.d/50-power.conf

# Check service status
systemctl status systemd-logind

# Check if configuration file exists
ls -la /etc/systemd/logind.conf.d/50-power.conf

# Test manually
systemctl suspend 2>/dev/null && echo "Suspend OK" || echo "Suspend failed"
```

**Problem: Hibernation doesn't work (always suspends)**

```bash
# Check swap
swapon --show
free -h

# Check if swap is sufficient for hibernation
SWAP_SIZE=$(free -k | awk '/^Swap:/ {print $2}')
RAM_SIZE=$(free -k | awk '/^Mem:/ {print $2}')
if [[ $SWAP_SIZE -gt 0 && $SWAP_SIZE -ge $RAM_SIZE ]]; then
    echo "Swap sufficient for hibernation: $((SWAP_SIZE/1024/1024))GB >= $((RAM_SIZE/1024/1024))GB"
else
    echo "Insufficient swap: $((SWAP_SIZE/1024/1024))GB < $((RAM_SIZE/1024/1024))GB"
fi

# Check GRUB resume=
grep resume /etc/default/grub
# If no resume=, regenerate GRUB:
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Check if swap file exists (location depends on filesystem)
# For Btrfs:
ls -lh /swap/swapfile

# For ext4:
ls -lh /swapfile

# Check swap UUID/offset (for Btrfs, needs resume_offset)
# For Btrfs:
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
# For ext4:
sudo findmnt -no UUID -T /swapfile
```

**Problem: System doesn't return from hibernation**

```bash
# Check if resume= is in GRUB (required for hibernation)
grep resume /boot/grub/grub.cfg || echo "No resume= found in GRUB configuration"

# Check swap UUID
sudo blkid | grep swap

# Check if resume= parameter exists in GRUB default
grep resume /etc/default/grub || echo "No resume= found in /etc/default/grub"

# If needed, regenerate GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Regenerate initramfs (may help)
sudo mkinitcpio -P
```

**Problem: System suspends even with audio/fullscreen**

```bash
# Check systemd-logind configuration
cat /etc/systemd/logind.conf.d/50-power.conf
# systemd-logind automatically resists suspension during fullscreen/audio

# Check service status
systemctl status systemd-logind

# Restart systemd-logind service
sudo systemctl restart systemd-logind

# Check logs to see if inhibition is working
journalctl -u systemd-logind --since "30 minutes" | grep -E "(inhibit|idle|suspend)"
```

---

### Minimalist Approach

This version uses only native system tools:

#### **Configuration:**
- **systemd-logind**: Native systemd configuration
- **i3 key bindings**: Direct manual controls
- **systemd-inhibit**: Temporary suspension blocking
- **acpi**: Battery information (official package)

#### **Advantages:**
- **No external scripts**: Uses existing tools
- **Fewer dependencies**: No AUR dependencies
- **More stable**: Full kernel integration
- **Simpler**: Easy to understand and debug

#### **Useful Commands:**
```bash
# Complete status (if power-status script exists)
power-status

# Manual controls
systemctl suspend                    # Suspend
systemctl hibernate                  # Hibernate
systemctl hybrid-sleep               # Suspend + Hibernate
systemd-inhibit -who='Working' -what='sleep' -why='Compiling' sleep 3600  # Block for 1h

# i3-wm key bindings
$mod+Control+Delete  → Suspend
$mod+Control+BackSpace → Hibernate
$mod+Shift+p          → Battery status
```

---

### Battery Notifications (i3-wm)

#### Problem: Battery notifications not working

**Symptoms:** No notifications appear for battery level or charger connection.

**Diagnosis:**

```bash
# Check if timer is enabled
systemctl --user status battery-alert.timer

# Check if scripts exist
ls -la /usr/local/bin/b/*

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

**Solutions:**

**Timer not enabled:**
```bash
# Enable and start timer
systemctl --user enable battery-alert.timer
systemctl --user start battery-alert.timer

# Reload systemd daemon if needed
systemctl --user daemon-reload
```

**Missing dependencies:**
```bash
# Install required packages
sudo pacman -S acpi libnotify

# Start notification daemon (dunst should be in i3 autostart)
dunst &
```

**Scripts not found:**
```bash
# If configurations are available, copy scripts manually
sudo cp ~/.archinstaller/configs/i3-wm/usr/local/bin/battery-* /usr/local/bin/
sudo chmod 755 /usr/local/bin/battery-*

# Copy systemd units
mkdir -p ~/.config/systemd/user/
cp ~/.archinstaller/configs/i3-wm/etc/skel/.config/systemd/user/* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable battery-alert.timer
```

**Dunst not running:**
```bash
# Start dunst manually
dunst &

# Add to i3 config if not present
echo 'exec --no-startup-id dunst' >> ~/.config/i3/config

# Restart i3 (press Mod+Shift+R in i3)
```

**udev rules not working:**
```bash
# Check if udev rules exist
cat /etc/udev/rules.d/60-battery-notifications.rules

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=power_supply

# Test udev trigger manually
sudo udevadm trigger --action=change --subsystem-match=power_supply
```

**Desktop system (no battery):** Expected behavior: Scripts exit silently if battery is not detected. This is normal.

```bash
# Check if battery exists
acpi -b

# If no output, system doesn't have battery (desktop)
# Notifications don't work, but this is expected
```

#### Additional Problems

**Too many notifications:**
Solution: Lock files prevent duplicate notifications. They are automatically managed but can be manually cleaned:

```bash
# Remove lock files (resets notification state)
rm -f /tmp/battery-$USER-*
```

**Want to customize notification levels:**
```bash
# Edit warning/critical levels
sudo nano /usr/local/bin/battery-alert

# Change these lines:
# WARNING_LEVEL=20   # Change to preferred level
# CRITICAL_LEVEL=5   # Change to preferred level
```

**Want to change check interval:**
```bash
# Edit timer unit
systemctl --user edit battery-alert.timer

# Or edit file directly
nano ~/.config/systemd/user/battery-alert.timer

# Change these lines:
# OnBootSec=5min      # Time after boot for first check
# OnUnitActiveSec=5min # Interval between checks
```

#### Useful Commands

```bash
# Check script help
battery-alert --help
battery-charging --help
battery-udev-notify --help

# Check timer logs
journalctl --user -u battery-alert.service -f

# Check timer status
systemctl --user status battery-alert.timer

# Disable notifications
systemctl --user disable battery-alert.timer
systemctl --user stop battery-alert.timer

# Re-enable notifications
systemctl --user enable battery-alert.timer
systemctl --user start battery-alert.timer
```

---

## Swap Configuration

The installer's swap configuration is smart and considers RAM amount, storage type (SSD/HDD), installation type, and available disk space.

### Decision Table by RAM

| RAM | Strategy | Swap File Size (SSD) | Swap File Size (HDD) |
|-----|----------|----------------------|----------------------|
| **< 4GB** | ZRAM (2x) + Swapfile | 4GB | 4GB |
| **4-8GB** | ZRAM (2x) + Swapfile | 4GB | 6GB |
| **8-16GB** | ZRAM (1x) + Swapfile | 4GB | 8GB |
| **16-32GB** | ZRAM (1x) + Swapfile | 4GB | 8GB |
| **> 32GB** | ZRAM (1x) + Swapfile | 4GB | 4GB |
| **SERVER** | Only Swapfile | 4GB | 4GB |

### Special Cases

- **SERVER installations:** Only swap file (4GB), no ZRAM
- **Disk space requirement:** Needs at least (SWAP_SIZE + 2GB) of free space
- **Insufficient space:** Swap file size is reduced or ignored

### Btrfs-Specific Configuration

For Btrfs filesystems, the installer creates a **dedicated `@swap` subvolume** to avoid the "Text file busy" (errno:26) error when creating snapshots with Snapper.

- **Swap file location:** `/swap/swapfile` (inside the `@swap` subvolume)
- **Subvolume:** `@swap` mounted at `/swap`
- **Created with:** `btrfs filesystem mkswapfile` (automatically handles NOCOW)

This is necessary because:
1. Btrfs cannot create snapshots of subvolumes containing active swap files
2. The `@swap` subvolume is excluded from snapshots
3. NOCOW (No Copy-on-Write) is applied automatically

### ext4/Other Filesystems

- **Swap file location:** `/swapfile` (root filesystem)
- **Created with:** `mkswap --file`

### Automatic Configuration

When created, the swap file is automatically:
- Immediately activated (`swapon`)
- Added to `/etc/fstab` for automatic activation on boot
- Configured with appropriate priority (50 if ZRAM exists, default otherwise)
- `vm.swappiness` configured (10 if ZRAM exists, 60 otherwise)

### Manual Fix for Btrfs (Recommended)

If swap issues occur with Btrfs:

```bash
# 1. Deactivate existing swap
sudo swapoff -a

# 2. Check if @swap subvolume exists and is mounted
findmnt /swap

# 3. If not mounted, mount it
sudo mkdir -p /swap
sudo mount -o subvol=@swap /dev/sdXY /swap  # Replace with your device

# 4. Create swap file using btrfs-specific method
sudo btrfs filesystem mkswapfile --size 4G --uuid clear /swap/swapfile

# 5. Activate swap
sudo swapon /swap/swapfile

# 6. Add to fstab (if not present)
echo "/swap/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
```

### Manual Fix for ext4

```bash
# 1. Deactivate and remove old swap
sudo swapoff /swapfile 2>/dev/null || true
sudo rm -f /swapfile

# 2. Remove from fstab
sudo sed -i '/swapfile/d' /etc/fstab

# 3. Create new swap file
sudo mkswap -U clear --size 4G --file /swapfile
sudo chmod 600 /swapfile

# 4. Activate and add to fstab
sudo swapon /swapfile
echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
```

### Swap Verification

```bash
# Check active swap
swapon --show

# Check memory usage
free -h

# Check ZRAM (if configured)
zramctl
cat /proc/swaps
```

**Reference:** [ArchWiki - Swap](https://wiki.archlinux.org/title/Swap), [ArchWiki - Btrfs Swap](https://wiki.archlinux.org/title/Btrfs#Swap_file)

---

## Btrfs Snapshots

If you installed with btrfs filesystem, the system uses **Snapper** for snapshot management and **grub-btrfs** for booting from snapshots. The **snap-pac** package automatically creates snapshots before and after each pacman operation.

### Recovery After Pacman Installation Failure

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

#### 2. Undo Last Pacman Operation

```bash
# Revert changes between pre (2) and post (3) snapshots
sudo snapper -c root undochange 2..3
```

This restores all files changed by that pacman operation.

#### 3. Quick Undo (Last Operation)

```bash
# Find last "pre" snapshot and undo changes to current state
sudo snapper -c root undochange $(sudo snapper -c root list | grep "pre" | tail -1 | awk '{print $1}')..0
```

### Recovery When System Doesn't Boot

If the system doesn't boot after a bad update:

#### 1. Boot from Snapshot via GRUB

1. In the GRUB menu, select **"Arch Linux snapshots"**
2. Choose the snapshot labeled as **"pre"** before the problematic update
3. The system boots in read-only mode from that snapshot

#### 2. Make Rollback Permanent

After booting from the snapshot and verifying it works:

```bash
# Execute permanent rollback
sudo snapper -c root rollback

# Reboot to apply
sudo reboot
```

### Individual File Recovery

If only specific files are broken:

```bash
# Restore a single file from a snapshot
sudo snapper -c root undochange <snapshot-number> /path/to/file

# Restore multiple files
sudo snapper -c root undochange <snapshot-number> /file1 /file2 /file3
```

### Snapshot Comparison

To see what changed between snapshots:

```bash
# List files that differ between two snapshots
sudo snapper -c root status <old-number> <new-number>

# Show detailed diff
sudo snapper -c root diff <old-number> <new-number>
```

### Manual Recovery (Advanced)

If you need to restore from a Live ISO:

```bash
# 1. Boot Arch Linux ISO and mount btrfs volume
mount /dev/sdXY /mnt

# 2. List all subvolumes and snapshots
btrfs subvolume list /mnt

# 3. Rename broken root subvolume
mv /mnt/@ /mnt/@_broken

# 4. Create new @ from working snapshot
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

# Delete specific snapshot
sudo snapper -c root delete <number>

# Delete old snapshots (cleanup)
sudo snapper -c root cleanup number

# Check snapshot space usage
sudo btrfs filesystem du -s /.snapshots

# Enable automatic timeline snapshots (disabled by default)
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
```

### Snapshot Types

| Type | Created By | Description |
|------|-----------|------------|
| **pre** | snap-pac | Before pacman operations (-S, -R, -U) |
| **post** | snap-pac | After pacman operations |
| **single** | Manual/timeline | Manual or timeline snapshots |

### GUI Tool (If Installed)

For FULL installations, **btrfs-assistant** provides graphical interface:

```bash
btrfs-assistant
```

Features:
- Visual snapshot browser
- One-click restoration
- Subvolume management
- Disk usage analysis

### Important Notes

1. **@home is separate:** The `@home` subvolume is NOT included in root snapshots. Your personal files in `/home` are not affected by system rollbacks.

2. **Snapshots ≠ Backups:** Snapshots are on the same disk. For real backups, copy to another device.

3. **Space limit:** Snapshots are limited to 50% of disk space (`SPACE_LIMIT="0.5"` in snapper configuration).

4. **After rollback:** Regenerate GRUB to update the snapshots menu:
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```

**Reference:** [ArchWiki - Snapper](https://wiki.archlinux.org/title/Snapper)

---

## Next Steps

See other troubleshooting guides:
- [Installation Verification](./VERIFICATION.md)
- [Quick Checklist](./QUICK-CHECK.md)
- [Common Problems](./COMMON-PROBLEMS.md)
- [Issue Reporting Guide](./REPORTING.md)