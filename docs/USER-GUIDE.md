# ArchInstaller User Guide

This guide details how to use ArchInstaller to install Arch Linux on a virtual machine or physical hardware.

---

## Prerequisites

### Minimum Recommended Hardware
- **CPU**: x86_64 with 2+ cores
- **RAM**: 2GB minimum (4GB+ recommended)
- **Disk**: 20GB minimum (40GB+ recommended)
- **Network**: Active internet connection

### Before Starting
1. Backup all important data
2. Download latest Arch Linux ISO: https://archlinux.org/download/
3. Create bootable USB or configure VM with the ISO
4. Boot into Arch Linux ISO

---

## Step-by-Step Installation

### Step 1: Boot into Arch Linux ISO

You'll see a prompt like this:
```
root@archiso ~ #
```

### Step 2: Connect to Internet

**Ethernet (wired)**: Usually works automatically

**Wi-Fi**:
```bash
# List interfaces
ip link

# Connect using iwctl
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "Network_Name"
[iwd]# exit

# Test connection
ping -c 3 archlinux.org
```

### Step 3: Clone the Repository

```bash
# Install git if needed (already in ISO)
pacman -Sy git

# Clone repository
git clone https://github.com/your-username/ArchInstaller
cd ArchInstaller
```

### Step 4: Run the Installer

```bash
# Give execution permission
chmod +x archinstall.sh

# Execute
./archinstall.sh
```

---

## Interactive Configuration Process

The installer will ask a series of questions. Let's detail each one:

### 1. User Information

```
Please enter your full name (e.g., David Brown):
```
Enter your full name. Ex: `John Smith`

```
Please enter username:
```
Enter username (lowercase, no spaces). Ex: `john`

```
Please enter password:
Please re-enter password:
```
Enter a strong password and confirm.

```
Please name your machine:
```
Computer name (hostname). Ex: `archlinux` or `my-pc`

---

### 2. Installation Type

```
Please select type of installation:
  Full Install: Installs full featured desktop environment
  Minimal Install: Installs only few selected apps
  Server Install: Installs only base system without desktop
```

**Choose**:
- **FULL**: Complete desktop + apps (Firefox, LibreOffice, etc.) + themes + extras
- **MINIMAL**: Basic desktop + few essential apps
- **SERVER**: Command line only (no graphical interface)

Use arrows ↑↓ to navigate, Enter to confirm.

---

### 3. AUR Helper (if not SERVER)

```
Please select your desired AUR helper:
  paru
  yay
  picaur
  aura
  trizen
  pacaur
  NONE
```

**Recommendation**: `yay` or `paru` (most popular and updated)

**What is it?**: AUR (Arch User Repository) contains community-maintained packages.

---

### 4. Desktop Environment (if not SERVER)

```
Please select your desired Desktop Environment:
  kde
  gnome
  xfce
  cinnamon
  i3-wm
  awesome
  openbox
  budgie
  deepin
  lxde
  mate
```

**Recommendations**:
- **Beginners**: KDE Plasma or GNOME (complete and polished)
- **Lightweight**: XFCE, LXDE, or MATE
- **Advanced**: i3-wm or Awesome (window managers)

---

### 5. Disk Selection

```
------------------------------------------------------------------------
    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK!
    Please make sure you know what you are doing because
    after formatting your disk there is no way to get data back
------------------------------------------------------------------------

Select the disk to install on:
  /dev/sda  |  500G
  /dev/sdb  |  100G

/dev/sda selected

Disk space usage:
  > Use 100% of the disk
    Set custom percentage
```

**WARNING**: The chosen disk will be COMPLETELY ERASED!

**In VMs**: Usually `/dev/sda` or `/dev/vda`
**Physical**: Check size to choose correct disk

Use arrows to select, Enter to confirm.

**Disk Usage Percentage**:

After selecting the disk, you can choose how much of the disk to use:

- **Use 100% of the disk** (default): Uses all available space after boot partition
- **Set custom percentage** (5-100%): Specify how much space to use

**Example**:
```
Enter percentage to use (5-100): 50

Preview:
Total disk size: 500GB
Will use: 250GB (50%)
Remaining: 250GB (unused)

Confirm this percentage? (y/n): y
```

**Note**: The percentage applies to **available space** after the boot partition (EFI: 1GB, BIOS Boot: 256MB). For example, on a 500GB disk with 50% selected and UEFI boot:
- EFI partition: 1GB
- ROOT partition: ~249GB (50% of 499GB available)
- Remaining: ~250GB unused

---

### 6. Filesystem

```
Please Select your file system for both boot and root
  btrfs
  ext4
  luks
  exit
```

**Choose**:

- **ext4**:
  - Simple, fast, reliable
  - No native snapshots
  - **Use if**: You want simplicity

- **btrfs**:
  - Snapshots (incremental backups)
  - Transparent compression (saves space)
  - Failure recovery
  - More complex
  - **Use if**: You want advanced features

- **luks**:
  - Full disk encryption
  - Maximum security
  - Needs password at boot
  - Slightly lower performance
  - **Use if**: Security is priority (laptops, sensitive data)

**If choosing btrfs**:
```
Please enter your btrfs subvolumes separated by space.
Usually they start with @.
For example: @docker @flatpak @home @opt @snapshots @var_cache @var_log @var_tmp

Press enter to use the default subvolumes:
```

Recommendation: **Just press Enter** to use defaults.

**If choosing luks**:
```
Please enter password:
Please re-enter password:
```
Enter a STRONG password for encryption (different from user password).

---

### 7. Timezone

The installer provides an interactive timezone selection with automatic detection and search functionality.

#### Automatic Detection

```
System detected your timezone: America/Sao_Paulo
Select timezone selection method:
  > Use detected timezone
    Select from list
```

If the detected timezone is correct, select "Use detected timezone" and press Enter.

#### Manual Selection with Search

If you choose "Select from list", you'll see a searchable list of all available timezones:

```
Select timezone:
  > Africa/Abidjan
    Africa/Algiers
    Africa/Bissau
    ...
    America/Manaus
    America/Sao_Paulo
    ...

Press '/' to search
```

**Features**:
- **Search**: Press `/` to enter search mode, then type to filter timezones (case-insensitive)
- **Navigation**: Use arrow keys (↑↓) or `k`/`j` to navigate
- **Selection**: Press Enter to select
- **Pagination**: Shows up to 10 items at a time for better readability

**Example**: To find "America/Sao_Paulo":
1. Press `/` to enter search mode
2. Type "sao" or "paulo"
3. List filters automatically
4. Navigate to desired timezone
5. Press Enter to select

The timezone is saved to `configs/setup.conf` as `TIMEZONE=America/Sao_Paulo` and applied during system installation.

---

### 8. System Language (Locale)

```
Please select your system language (locale) from the list below:
  en_US.UTF-8
  pt_BR.UTF-8
  es_ES.UTF-8
  fr_FR.UTF-8
  de_DE.UTF-8
  ...
```

**Important**: This affects system language, date/time formats, currency, etc.

---

### 9. Keyboard Layout

```
Please select keyboard layout from this list:
  us
  br-abnt2
  by
  ca
  de
  es
  fr
  ...
```

**US Users**: Choose `us`
**UK Users**: Choose `uk`
**Others**: Select your country code

---

### 10. Configuration Review

```
------------------------------------------------------------------------
                    Configuration Summary
------------------------------------------------------------------------
REAL_NAME=John Smith
USERNAME=john
NAME_OF_MACHINE=archlinux
INSTALL_TYPE=FULL
AUR_HELPER=yay
DESKTOP_ENV=kde
DISK=/dev/sda
DISK_USAGE_PERCENT=100
FS=btrfs
TIMEZONE=America/New_York
LOCALE=en_US.UTF-8
KEYMAP=us
------------------------------------------------------------------------
Do you want to redo any step? Select an option below, or press Enter to proceed:
1) Full Name, Username and Password
2) Installation Type
3) AUR Helper
4) Desktop Environment
5) Disk Selection and Usage Percentage
6) File System
7) Timezone
8) System Language (Locale)
9) Keyboard Layout
------------------------------------------------------------------------
```

**Note**: If you selected SERVER installation type, the menu will only show relevant options (without AUR Helper and Desktop Environment).

**Review EVERYTHING carefully!**

- If something is wrong, type the number and redo
- If everything is correct, **press Enter** to start installation

---

## Automatic Installation

After confirming, installation starts automatically. The process duration will depend on your internet connection and hardware.

### What happens in each phase:

#### PHASE 0: Pre-Installation
```
-------------------------------------------------------------------------
                    Formatting /dev/sda
-------------------------------------------------------------------------
```
- Updates mirrors
- Partitions disk
- Creates filesystems
- Installs base system (kernel, essential packages)
- Installs GRUB bootloader

**You'll see**: Many lines of packages being downloaded and installed

---

#### PHASE 1: System Setup
```
-------------------------------------------------------------------------
                    SYSTEM READY FOR 1-setup.sh
-------------------------------------------------------------------------
```
- Configures network, locale, timezone
- Installs base packages
- Detects and installs microcode (Intel/AMD)
- Detects and installs GPU drivers
- Creates your user

**You'll see**: Configurations being applied, more packages installed

---

#### PHASE 2: User Installation
```
-------------------------------------------------------------------------
                    SYSTEM READY FOR 2-user.sh
-------------------------------------------------------------------------
```
- Compiles and installs AUR helper (yay/paru)
- Installs fonts
- Installs complete desktop environment
- Installs themes and configurations

**You'll see**: Many desktop packages being installed, AUR helper compilation

This is the longest phase!

---

#### PHASE 3: Finalization
```
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
```
- Configures GRUB (bootloader)
- Configures display manager (login screen)
- Enables services (network, bluetooth, printing, etc.)
- Configures snapshots (if btrfs)
- Cleanup of temporary files

**You'll see**: Services being enabled, final configurations

---

### Completion

```
            Done - Please Eject Install Media and Reboot
```

When you see this message:

1. **In VM**: Remove ISO from VM
2. **Physical USB**: Remove the USB drive
3. **Reboot**:
   ```bash
   reboot
   ```

---

## First Boot into Installed System

### 1. Login Screen

You'll see the graphical login screen (SDDM, GDM, or LightDM).

- Enter your **username** (not full name)
- Enter your **password**
- Select desktop session (should already be correct)
- Click "Login"

### 2. First Use

**KDE Plasma**: Welcome to KDE! Explore the application menu.
**GNOME**: Press Super (Windows key) to see activities.
**i3/Awesome**: Read WM documentation (custom keybindings).

### 3. Connect Wi-Fi (if applicable)

- **KDE/GNOME**: Click network icon in panel
- **Terminal**: Use `nmtui` or `nmcli`

### 4. Enable Battery Notifications (i3-wm only, if not enabled)

If you installed **i3-wm** on a laptop, battery notifications are automatically installed but may need to be enabled:

```bash
# Enable battery notification timer
systemctl --user enable battery-alert.timer
systemctl --user start battery-alert.timer

# Verify status
systemctl --user status battery-alert.timer
```

**What it does**:
- Checks battery level every 5 minutes
- Notifies when battery is low (≤20%), critical (≤5%), or fully charged (>99%)
- Notifies immediately when charger is connected/disconnected

**See help**:
```bash
battery-alert --help
battery-charging --help
battery-udev-notify --help
```

---

## Recommended Post-Installation

### Update System

```bash
# Update everything
sudo pacman -Syu

# If you have AUR helper
yay -Syu
```

### Install Additional Apps

```bash
# Alternative browser
sudo pacman -S chromium

# Code editor
yay -S visual-studio-code-bin

# Email client
sudo pacman -S thunderbird

# Video player
sudo pacman -S vlc
```

### Configure Firewall (if FULL install)

UFW is already enabled! To modify:

```bash
# View status
sudo ufw status

# Allow specific port
sudo ufw allow 8080/tcp

# Deny port
sudo ufw deny 3000/tcp
```

### Check Services

```bash
# See active services
systemctl list-units --type=service --state=running

# Important to check:
systemctl status NetworkManager    # Network
systemctl status bluetooth         # Bluetooth (FULL)
systemctl status sddm             # Display manager (KDE)
```

---

## Troubleshooting

### Problem: Boot directly to GRUB rescue

**Cause**: Bootloader not installed correctly

**Solution**:
1. Boot into ISO again
2. Mount partitions:
   ```bash
   mount /dev/sdaX /mnt  # Replace X with root partition
   mount /dev/sdaY /mnt/boot  # If UEFI
   arch-chroot /mnt
   grub-install --target=x86_64-efi --efi-directory=/boot /dev/sda
   grub-mkconfig -o /boot/grub/grub.cfg
   exit
   reboot
   ```

---

### Problem: Black screen after login

**Cause**: Incorrect GPU driver or display manager

**Solution**:
```bash
# Ctrl+Alt+F2 for terminal
# Login with your user

# Reinstall drivers
sudo pacman -S xf86-video-vesa  # Generic driver

# Or for Intel
sudo pacman -S xf86-video-intel

# Restart display manager
sudo systemctl restart sddm  # or gdm, lightdm
```

---

### Problem: No network connection after installation

**Solution**:
```bash
# Check if NetworkManager is active
sudo systemctl status NetworkManager

# If not, enable
sudo systemctl enable --now NetworkManager

# Connect Wi-Fi via terminal
nmtui
```

---

### Problem: Snapshots not working (btrfs)

**Check**:
```bash
# View Snapper configuration
sudo snapper -c root list-configs

# View snapshots
sudo snapper -c root list

# Create manual snapshot
sudo snapper -c root create --description "test"
```

---

### Problem: Slow system in VM

**Optimizations**:

1. Increase VM RAM to 4GB+
2. Give more CPU cores (2-4)
3. Enable 3D acceleration in VM
4. If VirtualBox, install guest additions:
   ```bash
   sudo pacman -S virtualbox-guest-utils
   sudo systemctl enable vboxservice
   ```

---

## Verifying Installation Success

### Automatic Verification Script

After installation completes and you reboot the system, you can verify everything worked correctly:

#### Option 1: Run Locally After Reboot

After logging into your new system:

```bash
# Run the verification script (as your user - it will use sudo when needed)
~/.archinstaller/verify-installation.sh
```

#### Option 2: Connect via SSH

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

#### What the Script Checks

The verification script automatically checks:
- Installation logs for errors and warnings
- System services status
- Network and SSH configuration
- Swap configuration (ZRAM and swap file)
- User account setup and permissions
- Desktop environment installation
- AUR helper installation
- Disk space usage

#### Files Available After Installation

The installer automatically copies these files to `~/.archinstaller/`:
- `install.log` - Complete installation log
- `verify-installation.sh` - Verification script
- `setup.conf` - Installation configuration (password removed for security)

These files persist even after the installer cleans up temporary files.

### Manual Verification

All logs are in `/var/log/install.log`:

```bash
# View complete log
less /var/log/install.log

# Search for errors
grep -i error /var/log/install.log

# Search for warnings
grep -i warning /var/log/install.log

# Last 50 lines
tail -n 50 /var/log/install.log

# Check for failed services
systemctl --failed

# Check swap
swapon --show
free -h
```

For detailed troubleshooting, see **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**.

---

## Next Steps

1. **Learn about Arch**: https://wiki.archlinux.org
2. **Customize your desktop**: Themes, icons, wallpapers
3. **Install your favorite apps**: Steam, Discord, Spotify, etc.
4. **Configure automatic snapshots** (if btrfs):
   ```bash
   sudo systemctl enable --now snapper-timeline.timer
   sudo systemctl enable --now snapper-cleanup.timer
   ```

---

Enjoy your new Arch Linux system!