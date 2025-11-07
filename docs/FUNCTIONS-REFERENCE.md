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
**Description**: Disk selection for installation.

**Behavior**:
- Lists disks with `lsblk`
- Displays formatting warning
- Detects SSD and sets mount options

**Saves**: `DISK` and `MOUNT_OPTION` to setup.conf

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
**Description**: Timezone detection and confirmation.

**Behavior**:
- Detects via `curl https://ipapi.co/timezone`
- Asks for confirmation
- Allows manual input if incorrect

**Saves**: `TIMEZONE` to setup.conf

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
**Description**: Shows summary and allows redoing steps.

**Behavior**:
- Displays `setup.conf` content
- Numbered menu to redo any step
- Loops until user confirms (empty Enter)

**Menu**:
1. User info
2. Install type
3. AUR helper
4. Desktop environment
5. Disk
6. Filesystem
7. Timezone
8. Locale
9. Keymap

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
**Description**: Installs desktop environment packages.

**Source**: `packages/desktop-environments/$DESKTOP_ENV.json`

**Filters**: Combines minimal + full, pacman + aur

---

### btrfs_install()
```bash
btrfs_install
```
**Description**: Installs btrfs tools.

**Source**: `packages/btrfs.json`

**Condition**: Only if `FS=btrfs`

**Packages**: snapper, snap-pac, grub-btrfs, etc.

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
**Description**: Partitions disk with GPT.

**UEFI Layout**:
- Partition 1: 1GB EFI (ef00)
- Partition 2: Rest ROOT (8300)

**BIOS Layout**:
- Partition 1: 256MB BIOS boot (ef02)
- Partition 2: Rest ROOT (8300)

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
**Description**: Enables and themes display manager.

**Mapping**:
- KDE → SDDM (Nordic theme if FULL)
- GNOME → GDM
- LXDE → LXDM
- Openbox/Awesome/i3 → LightDM
- Others → LightDM (fallback)

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
