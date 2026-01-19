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
set_password "VARIABLE_NAME"
```
**Description**: Collects password with confirmation and saves to setup.conf.

**Parameters**: `$1` - Variable name in setup.conf where password will be stored

**Behavior**:
- Prompts for password (hidden input)
- Prompts for password confirmation
- If passwords match, saves to setup.conf using `set_option "$1" "$PASSWORD1"`
- If passwords don't match, shows error and recurs until matching
- Clears temporary entries from setup.conf if validation fails

**Example**:
```bash
set_password "LUKS_PASSWORD"  # Saves as LUKS_PASSWORD=value in setup.conf
set_password "PASSWORD"         # Saves as PASSWORD=value in setup.conf
```

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
**Description**: Interactive timezone selection with automatic detection via web API and comprehensive fallback mechanisms.

**Behavior**:
1. **Web API Detection**: Attempts to detect timezone via `curl --fail --max-time 3 https://ipapi.co/timezone`
2. **User Choice**: Offers options to use detected timezone or select from list
3. **Interactive Selection**: If "Select from list" is chosen:
   - Scans `/usr/share/zoneinfo` recursively to build complete timezone list
   - Uses `select_option_with_search()` for searchable menu (3 columns)
   - Real-time search filtering when `/` is pressed
   - Case-insensitive search functionality
4. **File Validation**: Verifies timezone file exists at `/usr/share/zoneinfo/$timezone`
5. **Error Handling**: 
   - 3-second timeout for API call to prevent hanging
   - Fallback to manual entry if API fails
   - Warning if timezone file not found but continues anyway

**Fallback Mechanisms**:
- API failure → Manual selection list
- Missing timezone files → Manual text input
- Invalid file path → Warning but continues

**Saves**: `TIMEZONE` to setup.conf (format: `Region/City`, e.g., `America/New_York`)

**Implementation Details**:
```bash
# Web API with timeout and error handling
detected_tz="$(curl --fail --max-time 3 https://ipapi.co/timezone 2>/dev/null || echo "")"

# Recursive timezone building
find /usr/share/zoneinfo -type f -printf "%P\n" | sort

# File validation before saving
if [[ ! -f "/usr/share/zoneinfo/$full_timezone" ]]; then
    echo "Warning: Timezone file not found"
fi
```

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
**Description**: Installs bootloader prerequisites during Phase 0 (live ISO, before chroot).

**Behavior**:
- Detects UEFI vs Legacy BIOS via `/sys/firmware/efi`
- **UEFI**: Installs `efibootmgr` via pacstrap (required for GRUB EFI installation)
- **Legacy BIOS**: No additional packages needed at this stage

**Note**: This function only installs prerequisites. The actual GRUB installation happens in **Phase 3** (`3-post-setup.sh`):
- **UEFI**: `grub-install --target=x86_64-efi --efi-directory=/boot`
- **Legacy BIOS**: `grub-install --target=i386-pc`

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
**Description**: Detects GPU and installs appropriate drivers using JSON-based configuration.

**Detection Flow**:
1. **VM Detection**: Checks for VirtualBox, VMware, QEMU/KVM via DMI and lspci
2. **GPU Detection**: Parses `lspci` for VGA/3D/Display controllers
3. **Hybrid Detection**: Checks for NVIDIA + Intel combination
4. **NVIDIA Choice**: If NVIDIA detected, prompts user for driver type

**Source**: `packages/gpu-drivers.json`

**Supported Configurations**:

| GPU Type | Variants | Packages |
|----------|----------|----------|
| **VM** | auto | `virtualbox-guest-utils` / `open-vm-tools` / `qemu-guest-agent` |
| **NVIDIA** | proprietary, open-dkms, nouveau | `nvidia-dkms`, `nvidia-open-dkms`, or `xf86-video-nouveau` |
| **AMD** | auto | `xf86-video-amdgpu`, `mesa`, `vulkan-radeon`, `libva-mesa-driver` |
| **Intel** | auto | `xf86-video-intel`, `mesa`, `vulkan-intel`, `libva-intel-driver` |
| **Hybrid** | nvidia-intel | NVIDIA driver + Intel packages + `optimus-manager` |
| **Fallback** | auto | `xf86-video-vesa`, `mesa` |

**NVIDIA Driver Selection**:
- **Proprietary (nvidia-dkms)**: Best performance, closed-source
- **Open Kernel (nvidia-open-dkms)**: For Turing+ GPUs (RTX 20xx, 30xx, 40xx, GTX 16xx)
- **Open-source (nouveau)**: Free software, limited performance

**Helper Functions**:
- `detect_vm()`: Returns 0 if running in VM
- `detect_gpu()`: Returns `nvidia`, `amd`, `intel`, or `unknown`
- `detect_hybrid_graphics()`: Returns 0 if NVIDIA + Intel detected
- `nvidia_supports_open_dkms()`: Returns 0 if GPU supports open kernel module
- `get_nvidia_driver_choice()`: Interactive menu for driver selection
- `install_gpu_from_json()`: Installs packages from JSON based on GPU type

---

### detect_vm()
```bash
detect_vm
```
**Description**: Detects if the system is running inside a virtual machine.

**Detection Methods**:
1. **DMI Product Name**: Reads `/sys/class/dmi/id/product_name` for VM signatures
2. **lspci Output**: Checks for virtual graphics adapters

**Detected VMs**:
- VirtualBox
- VMware
- QEMU/KVM
- Bochs

**Return**: 0 if VM detected, 1 otherwise

**Example**:
```bash
if detect_vm; then
    echo "Running in virtual machine"
fi
```

---

### detect_gpu()
```bash
detect_gpu
```
**Description**: Detects the primary GPU type from lspci output.

**Detection**: Parses `lspci | grep -iE "VGA|3D|Display"`

**Return** (stdout): One of `nvidia`, `amd`, `intel`, `unknown`

**Patterns Matched**:
- NVIDIA: `NVIDIA`, `GeForce`
- AMD: `Radeon`, `AMD`, `ATI`
- Intel: `Intel.*Graphics`, `Integrated Graphics Controller`

**Example**:
```bash
gpu_type=$(detect_gpu)
echo "Detected GPU: $gpu_type"
```

---

### detect_hybrid_graphics()
```bash
detect_hybrid_graphics
```
**Description**: Detects if the system has hybrid graphics (NVIDIA + Intel).

**Detection**: Checks if both NVIDIA and Intel GPUs are present in lspci output.

**Return**: 0 if hybrid detected, 1 otherwise

**Use Case**: Laptops with switchable graphics (Optimus)

---

### nvidia_supports_open_dkms()
```bash
nvidia_supports_open_dkms
```
**Description**: Checks if the NVIDIA GPU supports the open kernel module.

**Supported GPUs** (Turing architecture and newer):
- RTX 20xx series
- RTX 30xx series
- RTX 40xx series
- GTX 16xx series

**Return**: 0 if supported, 1 otherwise

**Note**: Open kernel module provides better integration with Linux kernel but requires newer GPUs.

---

### get_nvidia_driver_choice()
```bash
get_nvidia_driver_choice
```
**Description**: Interactive menu for selecting NVIDIA driver type.

**Options** (if GPU supports open-dkms):
1. Proprietary (nvidia-dkms) - Best performance, closed-source
2. Open-source Kernel (nvidia-open-dkms) - Open kernel module, good performance
3. Open-source (nouveau) - Free software, limited performance

**Options** (older GPUs):
1. Proprietary (nvidia-dkms)
2. Open-source (nouveau)

**Return** (stdout): `proprietary`, `open-dkms`, or `nouveau`

---

### install_gpu_from_json()
```bash
install_gpu_from_json GPU_TYPE [DRIVER_VARIANT] [NVIDIA_TYPE]
```
**Description**: Installs GPU drivers from the JSON configuration file.

**Parameters**:
- `$1` - GPU type: `vm`, `nvidia`, `amd`, `intel`, `hybrid`, `fallback`
- `$2` - Driver variant (optional): `proprietary`, `open-dkms`, `nouveau`, `nvidia-intel`
- `$3` - NVIDIA type for hybrid (optional): driver type when hybrid

**Source**: `packages/gpu-drivers.json`

**Behavior**:
1. Reads package list from JSON based on GPU type and variant
2. Installs each package using `install_package_intelligent()`
3. Executes post-install commands if defined in JSON

**JSON Structure**:
```json
{
  "nvidia": {
    "proprietary": {
      "packages": ["nvidia-dkms", "nvidia-utils", ...],
      "post_install": ["nvidia-xconfig"]
    }
  }
}
```

---

### install_package_intelligent()
```bash
install_package_intelligent PACKAGE
```
**Description**: Intelligently installs a package, checking if already installed and verifying it exists.

**Parameters**:
- `$1` - Package name to install

**Behavior**:
1. **Check if installed**: Skips if `pacman -Qi` succeeds
2. **Check if exists**: Uses `pacman -Si` to verify package exists in repositories
3. **Install**: Uses `pacman -S` with `--noconfirm --needed`

**Return**: 0 on success, 1 on failure

**Example**:
```bash
install_package_intelligent "firefox"
```

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

### i3wm_auto_suspend_hibernate()
```bash
i3wm_auto_suspend_hibernate
```
**Description**: Installs and configures automatic suspend/hibernate on inactivity for i3-wm.

**Condition**: Only if `DESKTOP_ENV=i3-wm`

**What it installs**:

1. **Scripts to `/usr/local/bin/`**:
   - `auto-suspend-hibernate` - Decides between suspend/hibernate based on power state
   - `check-swap-for-hibernate` - Verifies if swap is sufficient for hibernation

2. **Systemd logind configuration** (`/etc/systemd/logind.conf.d/50-hibernate.conf`):
   - Configures lid switch and power key behavior

3. **Sudoers configuration** (`/etc/sudoers.d/99-i3wm-suspend-hibernate`):
   - Allows `wheel` group to run `systemctl suspend` and `systemctl hibernate` without password
   - Required for xidlehook to trigger suspend/hibernate

4. **i3 config integration**:
   - Adds xidlehook autostart with 30-minute timeout


**Behavior**:
- **With AC power**: System suspends (suspend to RAM)
- **On battery**:
  - If swap >= RAM: System hibernates (suspend to disk)
  - If swap < RAM: System suspends (fallback)

**Requirements**:
- `xidlehook` from AUR (installed if AUR_HELPER != NONE)
- `acpi` for power state detection

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
**Description**: Intelligently configures swap based on system hardware analysis.

**System Analysis**:
- RAM amount (total memory)
- Storage type (SSD vs HDD via `lsblk ROTA`)
- Installation type (FULL, MINIMAL, SERVER)
- Available disk space

**Decision Table by RAM**:

| RAM | SSD | HDD | Strategy | Configuration |
|-----|-----|-----|----------|---------------|
| **<4GB** | ZRAM | ZRAM | ZRAM only | 2x RAM, zstd compression |
| **4-8GB** | ZRAM | ZRAM+Swap | ZRAM primary | 2x RAM + 2GB swap file (HDD only) |
| **8-16GB** | ZRAM | Swap File | Conditional | 1x RAM ZRAM (SSD) or 4GB swap (HDD) |
| **16-32GB** | Swap File | Swap File | Swap only | 2GB (SSD) or 4GB (HDD) |
| **>32GB** | Swap File | Swap File | Minimal swap | 1GB (SSD) or 2GB (HDD) |

**Special Cases**:
- **SERVER installations**: Always creates 4GB swap file regardless of RAM/storage
- **Disk space requirement**: Needs at least (SWAP_SIZE + 2GB) free space
- **ZRAM configuration**: Uses zstd compression, priority 100

**Swap File Configuration**:
- Path: `/swapfile`
- Permissions: `600`
- Created with: `mkswap --file` (handles btrfs nocow automatically)
- Priority: 50 if ZRAM exists, default otherwise
- `vm.swappiness`: 10 if ZRAM exists, 60 otherwise

**GRUB Resume Parameter**:
- Automatically adds `resume=UUID=...` to GRUB if swap file is created
- Required for hibernation support

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

### configure_base_skel()
```bash
configure_base_skel
```
**Description**: Configures base skel directory with common configurations for all users.

**Source**: `configs/base/etc/skel/`

**Behavior**:
- Copies all files from `configs/base/etc/skel/` to `/etc/skel/`
- Preserves permissions with `cp -a`
- Verifies copied files (.nanorc, nvim, .bashrc, .bash_profile)

**Files Copied**:
- `.nanorc` - Nano editor configuration
- `.bashrc` - Bash shell configuration
- `.bash_profile` - Bash login profile
- `.config/nvim/init.lua` - Neovim configuration

**Usage**: Called in Phase 1 before `add_user()` so new users receive these configs automatically.

---

### configure_pam_faillock()
```bash
configure_pam_faillock
```
**Description**: Configures PAM to allow 5 password attempts before account lockout.

**Configuration File**: `/etc/security/faillock.conf`

**Settings**:
- `deny = 5` - Maximum failed attempts before lockout
- `fail_interval = 900` - Time window (15 min) for counting failures
- `unlock_time = 600` - Lockout duration (10 min)

**Behavior**:
- Creates `/etc/security/faillock.conf` if not exists
- Updates existing file if already present
- Removes duplicate `deny` entries to prevent conflicts

**Note**: Arch Linux PAM configuration already references `pam_faillock`, so only the conf file needs to be configured.

---

### configure_pipewire()
```bash
configure_pipewire
```
**Description**: Configures PipeWire as the audio server and removes PulseAudio if present.

**Condition**: Only runs for graphical installations (not SERVER)

**Behavior**:
1. Checks if PipeWire is installed
2. Removes PulseAudio packages if installed (obsolete)
3. Masks PulseAudio services to prevent conflicts
4. Notes that PipeWire uses systemd/User socket activation

**PulseAudio Packages Removed**:
- `pulseaudio`
- `pulseaudio-alsa`
- `pulseaudio-bluetooth`
- `pulseaudio-equalizer`
- `pulseaudio-jack`

**Verification Commands** (after login):
```bash
systemctl --user status pipewire pipewire-pulse wireplumber
pactl info | grep 'Server Name'  # Should show 'PulseAudio (on PipeWire ...)'
```

**Configuration Paths**:
- `/etc/wireplumber/` - System-wide
- `~/.config/wireplumber/` - User-specific

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

## Additional Functions (Not Previously Documented)

### detect_vm()
```bash
detect_vm
```
**Description**: Detects if the system is running inside a virtual machine using DMI and PCI analysis.

**Detection Methods**:
1. **DMI Product Name**: Reads `/sys/class/dmi/id/product_name` for VM signatures
2. **PCI Devices**: Checks `/sys/bus/pci/devices` for virtual graphics adapters

**Detected VMs**:
- VirtualBox
- VMware
- QEMU/KVM
- Bochs

**Return**: Exit code 0 if VM detected, 1 if bare metal

**Usage Example**:
```bash
if detect_vm; then
    echo "Installing VM-specific packages..."
    install_gpu_from_json "vm"
fi
```

### detect_hybrid_graphics()
```bash
detect_hybrid_graphics
```
**Description**: Detects hybrid graphics systems (NVIDIA + Intel combination) for Optimus laptops.

**Detection**: Parses `lspci` output for both NVIDIA and Intel graphics controllers simultaneously.

**Return**: Exit code 0 if hybrid graphics detected, 1 otherwise

**Use Case**: Enables special handling for laptops with switchable graphics (Optimus technology).

### nvidia_supports_open_dkms()
```bash
nvidia_supports_open_dkms
```
**Description**: Checks if NVIDIA GPU supports the open-source kernel module (nvidia-open-dkms).

**Supported GPUs** (Turing architecture and newer):
- RTX 20xx series (Turing)
- RTX 30xx series (Ampere)  
- RTX 40xx series (Ada Lovelace)
- GTX 16xx series (Turing)

**Detection**: Checks GPU model patterns in `lspci` output against supported series.

**Return**: Exit code 0 if supports open-dkms, 1 otherwise

### get_nvidia_driver_choice()
```bash
get_nvidia_driver_choice
```
**Description**: Interactive menu for selecting NVIDIA driver type based on GPU capabilities.

**Options** (if GPU supports open-dkms):
1. **Proprietary** (nvidia-dkms) - Best performance, closed-source
2. **Open Kernel** (nvidia-open-dkms) - Open kernel module, good performance  
3. **Open-source** (nouveau) - Free software, limited performance

**Options** (older GPUs):
1. **Proprietary** (nvidia-dkms)
2. **Open-source** (nouveau)

**Return**: Outputs driver type string to stdout

### install_package_intelligent()
```bash
install_package_intelligent PACKAGE_NAME
```
**Description**: Intelligently installs a package with existence verification and duplicate checking.

**Parameters**:
- `$1` - Package name to install

**Behavior**:
1. **Check if installed**: Uses `pacman -Qi "$package"` - skips if already installed
2. **Check if exists**: Uses `pacman -Si "$package"` - verifies package exists in repositories
3. **Install**: Uses `pacman -S "$package" --noconfirm --needed`

**Return**: Exit code 0 on success, 1 on failure

**Benefits**:
- Prevents unnecessary reinstallations
- Fails gracefully if package doesn't exist
- Provides clear error messages

### install_fonts()
```bash
install_fonts
```
**Description**: Installs system fonts from JSON configuration.

**Source**: `packages/optional/fonts.json`

**Condition**: Only runs if `INSTALL_TYPE != SERVER`

**Packages**: Various font families for desktop environments including:
- Noto fonts (comprehensive Unicode coverage)
- Liberation fonts (Microsoft-compatible)
- DejaVu fonts (popular web fonts)

---

## Functions by Use Case

### Adding New Desktop Environment

1. Create `packages/desktop-environments/my-de.json` with package structure:
```json
{
  "minimal": {
    "pacman": [
      {"package": "my-de-core"},
      {"package": "display-manager"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "my-de-full"}
    ],
    "aur": [
      {"package": "my-de-themes"}
    ]
  }
}
```

2. The `desktop_environment()` function will detect and offer it automatically
3. Optionally add theming in `user_theming()` function
4. Configure display manager in `display_manager()` function

### Adding Hardware Detection

In `software-install.sh`, follow the pattern:

```bash
my_hardware_detection() {
    local detection=$(detection_command)
    if grep -E "pattern" <<<"$detection"; then
        echo "Hardware detected: $detection"
        install_gpu_from_json "my-hardware-type" "variant"
        return 0
    fi
    return 1
}
```

Then call in `graphics_install()` or appropriate installation phase.

### Adding Custom Validation

In `user-options.sh`, use the established pattern:

```bash
my_option() {
    while true; do
        read -rp "Enter value: " answer
        
        # Validation logic here
        if [[ "$answer" =~ validation_regex ]]; then
            set_option MY_OPTION "$answer"
            break
        else
            echo "Invalid input. Please try again."
        fi
    done
}
```

Add to `show_configurations()` menu to allow reconfiguration.

### Adding New Package Categories

1. Create JSON file in appropriate `packages/` directory
2. Follow the established structure with `pacman` and `aur` arrays
3. Use `install_package_intelligent()` for each package
4. Add installation function following the naming pattern: `category_install()`

---

## Implementation Notes

### Error Handling Pattern

Most functions use this consistent error handling pattern:

```bash
command_that_might_fail
exit_on_error $? "Descriptive error message"
```

### Configuration Access Pattern

All functions access configuration using:

```bash
source "$HOME"/archinstaller/configs/setup.conf
# Then use variables directly: $USERNAME, $DESKTOP_ENV, etc.
```

### Package Installation Pattern

The intelligent package installation pattern ensures reliability:

```bash
install_package_intelligent "package-name"
# Handles:
# - Already installed (skips)
# - Package doesn't exist (errors)
# - Permission issues (uses appropriate method)
```

---

Consult source code for complete implementation details and additional helper functions!
