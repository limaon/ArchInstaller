# Complete Function Reference

This document lists all available functions in ArchInstaller, organized by module.

---

## installer-helper.sh

### exit_on_error()
```bash
exit_on_error $exit_code $last_command
```
**Description**: Checks exit code and terminates script if failed.

**Parameters**:
- `$1` - Exit code of previous command (`$?`)
- `$2+` - Command that was executed (for error message)

**Example**:
```bash
pacstrap /mnt base
exit_on_error $? "pacstrap /mnt base"
```

**Usage**: After critical commands that cannot fail.

---

### show_logo()
```bash
show_logo
```
**Description**: Displays archinstall ASCII logo and script path.

**Return**: None (visual output only)

**Example**:
```bash
show_logo
# Displays:
#                    _      _              _          _  _
#    archinstall
#    SCRIPTHOME: /root/ArchInstaller
```

---

### multiselect()
```bash
multiselect RESULT_VAR "opt1;opt2;opt3" "defaults"
```
**Description**: Interactive menu for multiple selection (checkbox).

**Parameters**:
- `$1` - Variable name to store result (array)
- `$2` - Options separated by `;`
- `$3` - Default values (optional)

**Controls**:
- `↑/↓` - Navigate
- `Space` - Toggle selection
- `Enter` - Confirm

**Example**:
```bash
options="Firefox;Chrome;Brave"
multiselect selected "$options"
# selected=(true false true) if Firefox and Brave selected
```

---

### select_option()
```bash
select_option num_options num_columns "${options[@]}"
return $?  # Selected index
```
**Description**: Interactive menu for single selection.

**Parameters**:
- `$1` - Number of options
- `$2` - Number of columns to display
- `$3+` - Array of options

**Return**: Index of selected option (via `$?`)

**Controls**:
- `↑/↓/←/→` or `k/j/h/l` - Navigate
- `Enter` - Confirm

**Example**:
```bash
options=(KDE GNOME XFCE)
select_option ${#options[@]} 3 "${options[@]}"
selected_index=$?
echo "You chose: ${options[$selected_index]}"
```

---

### select_option_with_search()
```bash
select_option_with_search num_options num_columns "${options[@]}"
return $?  # Selected index
```
**Description**: Interactive menu with inline search functionality for large lists.

**Parameters**:
- `$1` - Number of options (can be ignored)
- `$2` - Number of columns (typically 1-3)
- `$3+` - Array of options

**Return**: Index of selected option (via `$?`)

**Controls**:
- `↑/↓` or `k/j` - Navigate up/down
- `/` - Enter search mode
- Type characters - Filter list (case-insensitive)
- `Backspace` - Remove characters from search
- `Enter` - Confirm selection (exits search mode if active)

**Features**:
- **Search Mode**: Press `/` to filter options in real-time
- **Pagination**: Shows up to 10 items at a time for readability
- **Auto-scroll**: Automatically scrolls to keep selected item visible
- **Case-insensitive**: Search matches regardless of case

**Example**:
```bash
timezones=(Africa/Abidjan Africa/Algiers America/Manaus America/Sao_Paulo ...)
select_option_with_search ${#timezones[@]} 1 "${timezones[@]}"
selected_index=$?
echo "Selected: ${timezones[$selected_index]}"
```

**Use Case**: Ideal for selecting from large lists (timezones, packages, etc.) where search speeds up selection.

---

### sequence()
```bash
sequence
```
**Description**: Orchestrates execution of 4 installation phases.

**Flow**:
1. Executes `0-preinstall.sh` (live ISO)
2. Chroot and executes `1-setup.sh` (as root)
3. If not SERVER, executes `2-user.sh` (as user)
4. Executes `3-post-setup.sh` (as root again)

**Example**:
```bash
# Called automatically by archinstall.sh
sequence
```

---

### set_option()
```bash
set_option KEY VALUE
```
**Description**: Saves configuration to `setup.conf` file.

**Parameters**:
- `$1` - Variable name (key)
- `$2` - Value

**Behavior**:
- If key exists, updates value
- If doesn't exist, adds new line
- Quotes added automatically if value contains spaces

**Example**:
```bash
set_option USERNAME "john"
set_option REAL_NAME "John Smith"  # Quoted due to space
```

---

### source_file()
```bash
source_file /path/to/file.sh
```
**Description**: Loads file with existence verification.

**Parameters**:
- `$1` - File path

**Behavior**:
- Checks if file exists
- Attempts to source
- Exits with error if fails

**Example**:
```bash
source_file "$CONFIG_FILE"  # /configs/setup.conf
```

---

### end_script()
```bash
end_script
```
**Description**: Copies logs to installed system and finalizes.

**Behavior**:
- Copies `install.log` to `/mnt/var/log/install.log`
- Checks if log directory exists
- Displays error message if fails

**Example**:
```bash
# At end of archinstall.sh
end_script
```

---

## system-checks.sh

### root_check()
```bash
root_check
```
**Description**: Verifies script is running as root.

**Behavior**: Exits if not root (UID ≠ 0)

---

### arch_check()
```bash
arch_check
```
**Description**: Verifies running on Arch Linux.

**Behavior**: Exits if `/etc/arch-release` doesn't exist

---

### pacman_check()
```bash
pacman_check
```
**Description**: Verifies pacman is not locked.

**Behavior**: Exits if `/var/lib/pacman/db.lck` exists

---

### docker_check()
```bash
docker_check
```
**Description**: Prevents execution in Docker container.

**Behavior**: Checks `/.dockerenv` and `/proc/self/cgroup`

---

### mount_check()
```bash
mount_check
```
**Description**: Verifies `/mnt` is mounted.

**Behavior**: Reboots system if not mounted

**Usage**: Called before phases 1-3

---

### background_checks()
```bash
background_checks
```
**Description**: Executes all security checks.

**Calls**: `root_check`, `arch_check`, `pacman_check`, `docker_check`

**Usage**: At start of `configuration.sh`

---

## user-options.sh

### set_password()
```bash
set_password "PASSWORD"
```
**Description**: Collects password with confirmation.

**Parameters**: `$1` - Variable name in setup.conf

**Behavior**:
- Asks for password (hidden)
- Asks for confirmation
- Recursive if don't match

---

### user_info()
```bash
user_info
```
**Description**: Collects complete user information.

**Collects**:
- Full name (validated: only letters and spaces)
- Username (validated: Linux regex)
- Password (with confirmation)
- Hostname (validated with force option)

**Validations**:
- Name: `[a-zA-Z ]`
- Username: `^[a-z_]([a-z0-9_-]{0,31})$`
- Hostname: `^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$`

---

### install_type()
```bash
install_type
```
**Description**: Installation type selection.

**Options**: FULL, MINIMAL, SERVER

**Saves**: `INSTALL_TYPE` to setup.conf

---

### aur_helper()
```bash
aur_helper
```
**Description**: AUR helper selection.

**Options**: paru, yay, picaur, aura, trizen, pacaur, NONE

**Saves**: `AUR_HELPER` to setup.conf

---

### desktop_environment()
```bash
desktop_environment
```
**Description**: Desktop environment selection.

**Behavior**:
- Reads JSON files in `packages/desktop-environments/`
- Extracts filenames (without extension and "pkgs")
- Displays menu

**Saves**: `DESKTOP_ENV` to setup.conf

---

### disk_select()
```bash
disk_select
```
**Description**: Disk selection for installation with usage percentage.

**Behavior**:
- Lists disks with `lsblk` (format: `/dev/sda  |  500G`)
- Displays formatting warning
- Asks for disk usage percentage (5-100%)
  - Option 1: Use 100% of the disk (default)
  - Option 2: Set custom percentage
- Shows preview of disk usage (total size, will use, remaining)
- Validates percentage input (must be numeric, 5-100)
- Detects SSD/HDD and sets mount options accordingly

**Saves**: `DISK`, `DISK_USAGE_PERCENT`, and `MOUNT_OPTION` to setup.conf

**Example**:
```
Select the disk to install on:
  /dev/sda  |  500G

/dev/sda selected

Disk space usage:
  > Use 100% of the disk
    Set custom percentage

Enter percentage to use (5-100): 50

Preview:
Total disk size: 500GB
Will use: 250GB (50%)
Remaining: 250GB (unused)

Confirm this percentage? (y/n): y
```

---

### filesystem()
```bash
filesystem
```
**Description**: Filesystem selection.

**Options**: btrfs, ext4, luks, exit

**Behavior**:
- If btrfs: calls `set_btrfs()`
- If luks: calls `set_password("LUKS_PASSWORD")`

**Saves**: `FS` to setup.conf

---

### set_btrfs()
```bash
set_btrfs
```
**Description**: Defines btrfs subvolumes.

**Behavior**:
- Asks for custom subvolumes
- If empty, uses defaults
- Ensures `@` exists
- Removes duplicates

**Defaults**: `@ @docker @flatpak @home @opt @snapshots @var_cache @var_log @var_tmp`

**Saves**: `SUBVOLUMES` and `MOUNTPOINT` to setup.conf

---

### timezone()
```bash
timezone
```
**Description**: Interactive timezone selection with automatic detection and search functionality.

**Behavior**:
1. **Automatic Detection**: Attempts to detect timezone via `curl https://ipapi.co/timezone`
2. **User Choice**: Offers to use detected timezone or select from list
3. **Interactive Selection**: If "Select from list" is chosen:
   - Displays all available timezones from `/usr/share/zoneinfo`
   - Uses `select_option_with_search()` for searchable menu
   - Shows up to 10 items at a time (paginated)
   - Press `/` to search, arrow keys to navigate
4. **Validation**: Verifies timezone file exists before saving

**Features**:
- Automatic detection with fallback to manual selection
- Search functionality (press `/` to filter)
- Paginated display (10 items max)
- Case-insensitive search

**Saves**: `TIMEZONE` to setup.conf (format: `Region/City`, e.g., `America/Sao_Paulo`)

---

### locale_selection()
```bash
locale_selection
```
**Description**: Locale (system language) selection.

**Options**: en_US.UTF-8, pt_BR.UTF-8, es_ES.UTF-8, fr_FR.UTF-8, etc.

**Saves**: `LOCALE` to setup.conf

---

### keymap()
```bash
keymap
```
**Description**: Keyboard layout selection.

**Options**: us, br-abnt2, de, fr, es, etc. (28 options)

**Saves**: `KEYMAP` to setup.conf

---

### show_configurations()
```bash
show_configurations
```
**Description**: Shows summary and allows redoing steps with dynamic menu based on installation type.

**Behavior**:
- Displays `setup.conf` content
- Dynamic menu based on `INSTALL_TYPE`:
  - **If SERVER**: Hides AUR Helper and Desktop Environment options
  - **If not SERVER**: Shows all options
- Numbered menu to redo any step
- Loops until user confirms (empty Enter)
- Reloads `INSTALL_TYPE` after changes to update menu dynamically

**Menu (FULL/MINIMAL)**:
1. Full Name, Username and Password
2. Installation Type
3. AUR Helper
4. Desktop Environment
5. Disk Selection and Usage Percentage
6. File System
7. Timezone
8. System Language (Locale)
9. Keyboard Layout

**Menu (SERVER)**:
1. Full Name, Username and Password
2. Installation Type
3. Disk Selection and Usage Percentage
4. File System
5. Timezone
6. System Language (Locale)
7. Keyboard Layout

---

## software-install.sh

### arch_install()
```bash
arch_install
```
**Description**: Installs base system with pacstrap.

**Packages**: base, base-devel, linux, linux-firmware, linux-lts, jq, neovim, sudo, wget, libnewt

---

### bootloader_install()
```bash
bootloader_install
```
**Description**: Installs GRUB bootloader.

**Behavior**:
- Detects UEFI vs BIOS
- If UEFI: installs efibootmgr

---

### network_install()
```bash
network_install
```
**Description**: Installs NetworkManager and network tools.

**Packages**: NetworkManager, VPN clients, wireless tools, SSH

**Services**: Enables NetworkManager.service

---

### install_fonts()
```bash
install_fonts
```
**Description**: Installs system fonts.

**Source**: `packages/optional/fonts.json`

**Behavior**: Skips if INSTALL_TYPE=SERVER

---

### base_install()
```bash
base_install
```
**Description**: Installs base system packages.

**Source**: `packages/base.json`

**JQ Filters**:
- MINIMAL: `.minimal.pacman[]`
- FULL: `.minimal.pacman[], .full.pacman[]`

---

### microcode_install()
```bash
microcode_install
```
**Description**: Detects CPU and installs microcode.

**Detection**: `lscpu | grep "GenuineIntel"` or `"AuthenticAMD"`

**Packages**: `intel-ucode` or `amd-ucode`

---

### graphics_install()
```bash
graphics_install
```
**Description**: Detects GPU and installs drivers.

**Detection**: `lspci`

**Drivers**:
- NVIDIA: `nvidia-dkms nvidia-settings`
- AMD: `xf86-video-amdgpu`
- Intel: `vulkan-intel libva-intel-driver`

---

### aur_helper_install()
```bash
aur_helper_install
```
**Description**: Clones and compiles AUR helper.

**Behavior**:
- Clones from `https://aur.archlinux.org/$AUR_HELPER.git`
- Compiles with `makepkg -sirc`
- Installs AUR packages from `base.json`

---

### desktop_environment_install()
```bash
desktop_environment_install
```
**Description**: Installs desktop environment packages with intelligent package source detection.

**Source**: `packages/desktop-environments/$DESKTOP_ENV.json`

**Filters**: Combines minimal + full, pacman + aur based on `INSTALL_TYPE` and `AUR_HELPER`

**Installation Logic**:
1. **Check if already installed**: Skips if package is already installed
2. **Detect package source**:
   - Uses `pacman -Si <package>` to check if in official repository
   - If YES → installs with `sudo pacman -S` (official repo)
   - If NO → installs with `$AUR_HELPER -S` (AUR, if AUR helper configured)
3. **Error handling**: Provides clear error messages if installation fails
4. **Warnings**: Warns if package not found and no AUR helper configured

**Benefits**:
- Official packages installed with proper permissions (sudo)
- AUR packages installed via AUR helper
- No silent failures
- Handles both official and AUR packages correctly

---

### btrfs_install()
```bash
btrfs_install
```
**Description**: Installs btrfs tools with intelligent package source detection.

**Source**: `packages/btrfs.json`

**Condition**: Only if `FS=btrfs`

**Installation Logic**: Same as `desktop_environment_install()`
1. Check if already installed
2. Detect package source (pacman vs AUR)
3. Install with appropriate method
4. Handle errors and warnings

**Packages**: snapper, snap-pac, grub-btrfs, etc.

---

### i3wm_battery_notifications()
```bash
i3wm_battery_notifications
```
**Description**: Installs and configures battery notifications for i3-wm.

**Condition**: Only if `DESKTOP_ENV=i3-wm`

**What it does**:
1. Verifies dependencies (`acpi`, `libnotify`)
2. Copies scripts to `/usr/local/bin/`:
   - `battery-alert` - Periodic battery level checks
   - `battery-charging` - Charging state notifications
   - `battery-udev-notify` - Udev wrapper script
3. Copies systemd user units to `/etc/skel/.config/systemd/user/`:
   - `battery-alert.service` - Service that runs battery-alert
   - `battery-alert.timer` - Timer that triggers service every 5 minutes
4. Configures systemd units for current user
5. Enables timer for current user
6. Copies udev rules to `/etc/udev/rules.d/`:
   - `60-battery-notifications.rules` - Triggers notifications on plug/unplug

**Scripts**:
- `battery-alert`: Checks battery level, sends notifications when low/critical/full
- `battery-charging`: Sends notification when charger connected/disconnected
- `battery-udev-notify`: Wrapper called by udev to notify logged-in user

**Help**: All scripts support `-h` or `--help` flags

**Note**: Timer may need to be manually enabled after first login if systemd user session wasn't active during installation

---

### user_theming()
```bash
user_theming
```
**Description**: Applies themes and DE configurations.

**Supported**:
- KDE: Konsave profile
- Awesome: Dotfiles
- i3: Configs
- Openbox: GitHub dotfiles

---

### essential_services()
```bash
essential_services
```
**Description**: Enables essential services.

**Always**:
- NetworkManager
- fstrim.timer (SSD)
- TLP (if battery detected)

**FULL only**:
- UFW firewall
- Cups (printing)
- NTP
- Bluetooth
- Avahi
- Snapper (btrfs/luks)
- Plymouth

---

## system-config.sh

### mirrorlist_update()
```bash
mirrorlist_update
```
**Description**: Updates mirror list.

**Method 1** (preferred): reflector
**Method 2** (fallback): manual rankmirrors

---

### format_disk()
```bash
format_disk
```
**Description**: Partitions disk with GPT using disk usage percentage.

**Parameters**: Reads `DISK_USAGE_PERCENT` from setup.conf (defaults to 100)

**UEFI Layout**:
- Partition 1: 1GB EFI (ef00)
- Partition 2: Percentage of available space ROOT (8300)
  - If 100%: Uses all remaining space
  - If <100%: Calculates size based on percentage of available space (after EFI)

**BIOS Layout**:
- Partition 1: 256MB BIOS boot (ef02)
- Partition 2: Percentage of available space ROOT (8300)
  - If 100%: Uses all remaining space
  - If <100%: Calculates size based on percentage of available space (after BIOS Boot)

**Calculation**:
```bash
# For UEFI:
available_bytes = disk_size_bytes - efi_size_bytes (1GB)
root_size_mb = (available_bytes * DISK_USAGE_PERCENT) / 100 / 1024 / 1024

# For BIOS:
available_bytes = disk_size_bytes - bios_boot_size_bytes (256MB)
root_size_mb = (available_bytes * DISK_USAGE_PERCENT) / 100 / 1024 / 1024
```

---

### create_filesystems()
```bash
create_filesystems
```
**Description**: Creates filesystems on partitions.

**EFI**: FAT32
**ROOT**: Depends on `$FS` (ext4/btrfs/luks)

---

### do_btrfs()
```bash
do_btrfs LABEL DEVICE
```
**Description**: Creates btrfs filesystem with subvolumes.

**Parameters**:
- `$1` - Label (ex: ROOT)
- `$2` - Device (ex: /dev/sda2)

**Behavior**:
- Creates btrfs
- Mounts temporarily
- Creates all subvolumes from `$SUBVOLUMES`
- Unmounts
- Remounts @ as root
- Mounts other subvolumes in correct places

---

### low_memory_config()
```bash
low_memory_config
```
**Description**: Configures ZRAM if <8GB RAM.

**Behavior**:
- Checks total memory
- If <8GB, installs zram-generator
- Configures zram0 with 200% RAM and zstd

---

### cpu_config()
```bash
cpu_config
```
**Description**: Adjusts makepkg for parallel compilation.

**Behavior**:
- Counts CPU cores
- Sets `MAKEFLAGS="-j$cores"`
- Sets parallel XZ compression

---

### locale_config()
```bash
locale_config
```
**Description**: Configures locale, timezone and keymap.

**Steps**:
1. Uncomments locale in `/etc/locale.gen`
2. Creates `/etc/locale.conf` with all LC_* variables
3. Generates locales with `locale-gen`
4. Configures timezone with `timedatectl`
5. Creates `/etc/localtime` symlink
6. Syncs hardware clock
7. Configures keymap
8. Creates `/etc/vconsole.conf`

---

### extra_repos()
```bash
extra_repos
```
**Description**: Enables extra repositories.

**Enables**:
- multilib (32-bit packages)
- (chaotic-aur commented by default)

---

### add_user()
```bash
add_user
```
**Description**: Creates system user.

**Steps**:
1. Creates groups (libvirt, vboxusers, gamemode, docker)
2. Creates user with `useradd`
3. Sets password
4. Copies `/root/archinstaller` to `/home/$USERNAME/`
5. Sets hostname
6. Creates `/etc/hosts`

---

### grub_config()
```bash
grub_config
```
**Description**: Configures GRUB.

**Behavior**:
- If LUKS: adds cryptdevice to kernel cmdline
- Adds `splash` for Plymouth
- Disables OS prober
- Generates final config

---

### display_manager()
```bash
display_manager
```
**Description**: Enables and themes display manager with automatic installation and configuration.

**Mapping**:
- KDE → SDDM (Nordic theme if FULL)
- GNOME → GDM
- LXDE → LXDM
- Openbox/Awesome/i3 → LightDM (with auto-installation)
- Others → LightDM (fallback)

**LightDM Handling** (for i3-wm, openbox, awesome):
1. **Check if installed**: If not installed, installs LightDM and greeter
2. **Create config directory**: Creates `/etc/lightdm` if it doesn't exist
3. **Create config files**: Creates `lightdm.conf` if it doesn't exist
4. **Check service exists**: Only enables service if it exists
5. **Conditional theming**: Applies advanced themes only if `INSTALL_TYPE == FULL`
6. **Basic configuration**: Always applies basic configuration

**Benefits**:
- Prevents errors when LightDM not yet installed
- Creates necessary config files automatically
- Handles missing services gracefully
- Conditional theming based on installation type

---

### snapper_config()
```bash
snapper_config
```
**Description**: Configures Snapper for snapshots.

**Steps**:
1. Copies config from `configs/base/etc/snapper/`
2. Adjusts user permissions
3. Enables timers (timeline, cleanup)
4. Enables grub-btrfsd
5. Creates initial snapshot

---

### configure_tlp()
```bash
configure_tlp
```
**Description**: Configures TLP for power management.

**Behavior**:
- Detects battery (`/sys/class/power_supply/BAT0`)
- If no battery, skips
- Installs TLP
- Configures `/etc/tlp.conf` with optimized defaults
- Configures logind to suspend on lid close

---

### plymouth_config()
```bash
plymouth_config
```
**Description**: Installs and configures Plymouth boot splash.

**Theme**: arch-glow

**Behavior**:
- Copies theme from `configs/base/usr/share/plymouth/themes/`
- Adds plymouth to mkinitcpio hooks
- If LUKS: adds plymouth-encrypt
- Regenerates initramfs

---

## Functions by Use Case

### Adding New Desktop Environment

1. Create `packages/desktop-environments/my-de.json`
2. `desktop_environment()` will detect automatically
3. Optionally, add theming in `user_theming()`
4. Optionally, configure display manager in `display_manager()`

### Adding Custom Validation

In `user-options.sh`, use pattern:

```bash
my_option() {
    while true; do
        read -rp "Question: " answer
        [[ validation ]] && break
        echo "Error: invalid"
    done
    set_option MY_OPTION "$answer"
}
```

### Adding Hardware Detection

In `software-install.sh`:

```bash
my_hardware_install() {
    detection=$(detection_command)
    if grep -E "pattern" <<<"$detection"; then
        pacman -S my-driver
    fi
}
```

---

Consult source code for implementation details!
