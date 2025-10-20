# System Architecture

This document describes the complete architecture of ArchInstaller, including design decisions, data flow, and modular structure.

---

## 📐 Architectural Overview

### Design Principles

1. **Modularity**: Each script has a single, well-defined responsibility
2. **Phase Separation**: Installation divided into 4 sequential phases
3. **Centralized Configuration**: Single `setup.conf` file as source of truth
4. **Automatic Detection**: Hardware detected automatically whenever possible
5. **Idempotency**: Functions can be executed multiple times safely
6. **Complete Logging**: Everything logged to `install.log` for debugging

---

## 🔄 4-Phase Execution Model

### Why 4 Phases?

The installation is divided into phases due to different execution contexts:

```
┌──────────────────────────────────────────────────────────────┐
│ PHASE 0: Live ISO Environment (Before Chroot)               │
│ - Arch ISO live system                                      │
│ - Full hardware access                                      │
│ - No installed system yet                                   │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ PHASE 1: Chroot as Root                                     │
│ - Inside freshly installed system                           │
│ - Root privileges                                            │
│ - System configuration                                       │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ PHASE 2: As Normal User                                     │
│ - Created user context                                       │
│ - AUR package installation                                   │
│ - User configurations                                        │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ PHASE 3: Chroot as Root (Finalization)                      │
│ - Back to root context                                       │
│ - System service configuration                               │
│ - Final cleanup                                              │
└──────────────────────────────────────────────────────────────┘
```

### Phase Transitions

```bash
# In installer-helper.sh -> sequence()
sequence() {
    # PHASE 0: Live ISO
    . "$SCRIPTS_DIR"/0-preinstall.sh
    
    # PHASE 1: Root in chroot
    arch-chroot /mnt "$HOME"/archinstaller/scripts/1-setup.sh
    
    # PHASE 2: User in chroot (only if not SERVER)
    if [[ ! "$INSTALL_TYPE" == SERVER ]]; then
        arch-chroot /mnt /usr/bin/runuser -u "$USERNAME" -- \
            /home/"$USERNAME"/archinstaller/scripts/2-user.sh
    fi
    
    # PHASE 3: Root in chroot again
    arch-chroot /mnt "$HOME"/archinstaller/scripts/3-post-setup.sh
}
```

**Rationale**: AUR packages cannot be compiled as root. We need to switch to user context in PHASE 2.

---

## 📦 Module System (Utility Scripts)

### 1. installer-helper.sh

**Responsibility**: Generic helper functions

```
┌─────────────────────────────────────────────────────────┐
│ installer-helper.sh                                     │
├─────────────────────────────────────────────────────────┤
│ • exit_on_error()      → Error handling                 │
│ • show_logo()          → Visual display                 │
│ • multiselect()        → Multi-select menu              │
│ • select_option()      → Single-select menu             │
│ • sequence()           → Orchestrates 4 phases          │
│ • set_option()         → Saves to setup.conf            │
│ • source_file()        → Loads file with validation     │
│ • end_script()         → Finalizes and copies logs      │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Helper/Utility Module - reusable stateless functions.

---

### 2. system-checks.sh

**Responsibility**: Precondition verification

```
┌─────────────────────────────────────────────────────────┐
│ system-checks.sh                                        │
├─────────────────────────────────────────────────────────┤
│ • root_check()         → Verifies root privileges       │
│ • arch_check()         → Verifies Arch Linux            │
│ • pacman_check()       → Verifies pacman lock           │
│ • docker_check()       → Prevents container execution   │
│ • mount_check()        → Verifies /mnt mount            │
│ • background_checks()  → Executes all checks            │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Guard Clauses - fail fast if preconditions not met.

**When to Execute**:
- `background_checks()`: At the start of `configuration.sh`
- `mount_check()`: Before phases 1-3 (which need /mnt mounted)

---

### 3. user-options.sh

**Responsibility**: Interactive configuration collection

```
┌─────────────────────────────────────────────────────────┐
│ user-options.sh                                         │
├─────────────────────────────────────────────────────────┤
│ • set_password()           → Collects password with confirmation │
│ • user_info()              → Name, username, hostname   │
│ • install_type()           → FULL/MINIMAL/SERVER        │
│ • aur_helper()             → AUR helper selection       │
│ • desktop_environment()    → Reads available JSONs      │
│ • disk_select()            → Selects disk               │
│ • filesystem()             → btrfs/ext4/luks            │
│ • set_btrfs()              → Defines subvolumes         │
│ • timezone()               → Detects and confirms       │
│ • locale_selection()       → System language            │
│ • keymap()                 → Keyboard layout            │
│ • show_configurations()    → Summary + allows redo      │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Wizard/Step-by-Step Configuration

**Validation Flow**:
```
Input → Validation → Retry if invalid → set_option() → Next step
```

**Show Configurations**: Allows user to review ALL choices and redo any step before proceeding. This prevents reinstallations due to configuration errors.

---

### 4. software-install.sh

**Responsibility**: Software and driver installation

```
┌─────────────────────────────────────────────────────────┐
│ software-install.sh                                     │
├─────────────────────────────────────────────────────────┤
│ BASE INSTALLATION:                                      │
│ • arch_install()               → Pacstrap base system   │
│ • bootloader_install()         → GRUB UEFI/BIOS        │
│ • network_install()            → NetworkManager + VPNs │
│ • base_install()               → Reads base.json       │
│                                                         │
│ HARDWARE DETECTION:                                     │
│ • microcode_install()          → Intel/AMD automatic   │
│ • graphics_install()           → NVIDIA/AMD/Intel      │
│                                                         │
│ DESKTOP & THEMES:                                       │
│ • install_fonts()              → Reads fonts.json      │
│ • desktop_environment_install()→ Reads DE JSON         │
│ • user_theming()               → Applies configs/themes│
│ • btrfs_install()              → Snapper, grub-btrfs   │
│                                                         │
│ AUR:                                                    │
│ • aur_helper_install()         → Compiles AUR helper   │
│                                                         │
│ SERVICES:                                               │
│ • essential_services()         → Enables all services  │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Repository Pattern (JSON as package "repositories")

**Hardware Auto-Detection**:
```bash
# Microcode
proc_type=$(lscpu)
if grep -E "GenuineIntel" <<<"${proc_type}"; then
    pacman -S intel-ucode
elif grep -E "AuthenticAMD" <<<"${proc_type}"; then
    pacman -S amd-ucode
fi

# GPU
gpu_type=$(lspci)
if grep -E "NVIDIA|GeForce" <<<"${gpu_type}"; then
    pacman -S nvidia-dkms nvidia-settings
elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
    pacman -S xf86-video-amdgpu
elif grep -E "Intel.*Graphics" <<<"${gpu_type}"; then
    pacman -S vulkan-intel libva-intel-driver
fi
```

---

### 5. system-config.sh

**Responsibility**: System configuration (disk, locale, users, bootloader)

```
┌─────────────────────────────────────────────────────────┐
│ system-config.sh                                        │
├─────────────────────────────────────────────────────────┤
│ DISK AND FILESYSTEM:                                    │
│ • mirrorlist_update()      → Reflector/rankmirrors     │
│ • format_disk()            → sgdisk partitioning       │
│ • create_filesystems()     → mkfs.vfat/ext4/btrfs      │
│ • do_btrfs()               → Subvolumes + mounting     │
│                                                         │
│ OPTIMIZATIONS:                                          │
│ • low_memory_config()      → ZRAM if <8GB RAM          │
│ • cpu_config()             → Makeflags multicore       │
│                                                         │
│ SYSTEM:                                                 │
│ • locale_config()          → Locale, timezone, keymap  │
│ • extra_repos()            → Multilib, chaotic-aur     │
│ • add_user()               → useradd + groups          │
│                                                         │
│ BOOTLOADER:                                             │
│ • grub_config()            → Configures GRUB           │
│ • display_manager()        → SDDM/GDM/LightDM + themes │
│                                                         │
│ ADVANCED:                                               │
│ • snapper_config()         → Btrfs snapshots           │
│ • configure_tlp()          → Laptop power management   │
│ • plymouth_config()        → Boot splash               │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Configuration Management

**GPT Partitioning**:
```
UEFI:
┌─────────────┬──────────────────────────────────────┐
│ EFIBOOT     │ ROOT                                 │
│ 1GB (EF00)  │ Rest of disk (8300)                  │
│ FAT32       │ ext4/btrfs/LUKS                      │
└─────────────┴──────────────────────────────────────┘

BIOS:
┌─────────────┬──────────────────────────────────────┐
│ BIOSBOOT    │ ROOT                                 │
│ 256MB(EF02) │ Rest of disk (8300)                  │
│ (no FS)     │ ext4/btrfs/LUKS                      │
└─────────────┴──────────────────────────────────────┘
```

**Btrfs Subvolumes**:
```
@              → /           (root)
@home          → /home       (user data)
@snapshots     → /.snapshots (Snapper snapshots)
@var_log       → /var/log    (logs, CoW disabled)
@var_cache     → /var/cache  (cache, CoW disabled)
@var_tmp       → /var/tmp    (temp, CoW disabled)
@docker        → /var/lib/docker
@flatpak       → /var/lib/flatpak
```

**Rationale**: Separate subvolumes allow selective snapshots and better management.

---

## 📄 Configuration System

### setup.conf - Central File

```bash
# Generated by configuration.sh
# Read by ALL phases

# User
REAL_NAME="John Doe"
USERNAME=john
PASSWORD=hashed_password
NAME_OF_MACHINE=myarch

# Installation
INSTALL_TYPE=FULL          # FULL, MINIMAL or SERVER
AUR_HELPER=yay             # yay, paru, picaur, etc.
DESKTOP_ENV=kde            # kde, gnome, i3-wm, etc.

# Disk
DISK=/dev/sda
FS=btrfs                   # btrfs, ext4 or luks
SUBVOLUMES=(@ @home @snapshots ...)
MOUNT_OPTION=defaults,noatime,compress=zstd,ssd,discard=async

# Localization
TIMEZONE=America/New_York
LOCALE=en_US.UTF-8
KEYMAP=us

# LUKS (if FS=luks)
LUKS_PASSWORD=***
ENCRYPTED_PARTITION_UUID=partition-uuid
```

**Access Pattern**:
```bash
# All scripts do:
source "$HOME"/archinstaller/configs/setup.conf

# Then use variables directly:
useradd -m -s /bin/bash "$USERNAME"
```

---

## 📦 JSON Package System

### JSON File Structure

```json
{
  "minimal": {
    "pacman": [
      {"package": "firefox"},
      {"package": "vim"}
    ],
    "aur": [
      {"package": "yay"}
    ]
  },
  "full": {
    "pacman": [
      {"package": "libreoffice-fresh"},
      {"package": "gimp"}
    ],
    "aur": [
      {"package": "visual-studio-code-bin"}
    ]
  }
}
```

### Installation Logic

```bash
# Define JQ filters based on INSTALL_TYPE
if [[ "$INSTALL_TYPE" == "FULL" ]]; then
    FILTER=".minimal.pacman[].package, .full.pacman[].package"
else
    FILTER=".minimal.pacman[].package"
fi

# If AUR helper installed, include AUR packages
if [[ "$AUR_HELPER" != NONE ]]; then
    FILTER="$FILTER, .minimal.aur[].package"
    [[ "$INSTALL_TYPE" == "FULL" ]] && FILTER="$FILTER, .full.aur[].package"
fi

# Install
jq -r "$FILTER" package.json | while read -r pkg; do
    pacman -S "$pkg" --noconfirm --needed
done
```

**Rationale**: JQ allows flexible JSON queries. Separating minimal/full allows lightweight or complete installations.

---

## 🔐 Security and Validations

### 1. User Input Validation

```bash
# Username: regex validated
[[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]

# Hostname: regex validated
[[ "${hostname,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]

# Password: confirmation required
set_password() {
    read -rs -p "Enter password: " PASS1
    read -rs -p "Re-enter password: " PASS2
    [[ "$PASS1" == "$PASS2" ]] || { echo "No match!"; set_password; }
}
```

### 2. Pre-Installation Checks

```bash
# Must be root
[[ "$(id -u)" != "0" ]] && exit 1

# Must be Arch
[[ ! -e /etc/arch-release ]] && exit 1

# Pacman cannot be locked
[[ -f /var/lib/pacman/db.lck ]] && exit 1

# Does not support Docker
[[ -f /.dockerenv ]] && exit 1
```

### 3. Error Handling

```bash
exit_on_error() {
    exit_code=$1
    last_command=${*:2}
    if [ "$exit_code" -ne 0 ]; then
        echo "\"${last_command}\" failed with code ${exit_code}."
        exit "$exit_code"
    fi
}

# Usage:
pacstrap /mnt base
exit_on_error $? pacstrap /mnt base
```

---

## 🎨 Themes and Custom Configurations

### Theming System

```
configs/
├── base/                           # Shared configs
│   ├── etc/snapper/configs/root   # Snapper config
│   └── usr/share/plymouth/themes/ # Plymouth themes
├── kde/
│   ├── home/                       # User dotfiles
│   └── kde.knsv                    # Konsave profile
├── awesome/
│   ├── home/.config/awesome/       # Awesome WM config
│   └── etc/xdg/awesome/            # Global config
└── i3-wm/
    └── etc/                        # i3 configs
```

**Theme Application**:
```bash
user_theming() {
    case "$DESKTOP_ENV" in
        kde)
            cp -r ~/archinstaller/configs/kde/home/. ~/
            pip install konsave
            konsave -i ~/archinstaller/configs/kde/kde.knsv
            konsave -a kde
            ;;
        awesome)
            cp -r ~/archinstaller/configs/awesome/home/. ~/
            sudo cp -r ~/archinstaller/configs/awesome/etc/xdg/awesome /etc/xdg/
            ;;
    esac
}
```

---

## 🚀 Implemented Optimizations

### 1. Parallel Compilation

```bash
nc=$(grep -c ^processor /proc/cpuinfo)
sed -i "s/^#\(MAKEFLAGS=\"-j\)2\"/\1$nc\"/" /etc/makepkg.conf
```

### 2. Mirror Optimization

```bash
# Reflector: selects 20 fastest mirrors from country
reflector -a 48 -c "$iso" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

# Fallback: manual rankmirrors
rankmirrors -n 5 /etc/pacman.d/mirrorlist
```

### 3. ZRAM (Systems with <8GB RAM)

```bash
TOTAL_MEM=$(grep -i 'memtotal' /proc/meminfo | grep -o '[[:digit:]]*')
if [[ "$TOTAL_MEM" -lt 8000000 ]]; then
    pacman -S zram-generator
    cat <<EOF > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * 2
compression-algorithm = zstd
EOF
fi
```

**Rationale**: 2x RAM as compressed ZRAM is more efficient than disk swap.

### 4. Btrfs Mount Options

```bash
# SSD detected
if [[ "$(lsblk -n --output ROTA)" -eq "0" ]]; then
    MOUNT_OPTION="defaults,noatime,compress=zstd,ssd,discard=async"
else
    MOUNT_OPTION="defaults,noatime,compress=zstd,discard=async"
fi
```

- `noatime`: Don't update access time (performance)
- `compress=zstd`: Transparent compression
- `ssd`: SSD optimizations
- `discard=async`: Asynchronous TRIM (better performance)

---

## 📊 Data Flow

```
┌──────────────────┐
│ User             │
└────────┬─────────┘
         │ Interactive input
         ↓
┌──────────────────────────┐
│ configuration.sh         │
│ + user-options.sh        │
└────────┬─────────────────┘
         │ Saves
         ↓
┌──────────────────────────┐
│ configs/setup.conf       │ ← Source of truth
└────────┬─────────────────┘
         │ Read by all phases
         ↓
┌──────────────────────────┐
│ 0-preinstall.sh          │ → Creates partitions + filesystem
└────────┬─────────────────┘
         │
┌──────────────────────────┐
│ 1-setup.sh               │ → Installs base + configures system
└────────┬─────────────────┘
         │
┌──────────────────────────┐
│ 2-user.sh                │ → AUR + Desktop + Themes
└────────┬─────────────────┘
         │
┌──────────────────────────┐
│ 3-post-setup.sh          │ → Services + Cleanup
└────────┬─────────────────┘
         │
         ↓
   Installed System
```

---

## 🎯 Important Architectural Decisions

### 1. Why JSON for Packages?

**Alternatives considered**: Shell arrays, TOML, YAML

**Chosen**: JSON with JQ

**Rationale**:
- JQ is available on Arch ISO
- Flexible queries (filter by minimal/full, pacman/aur)
- Easy to edit manually
- Clear hierarchical structure

### 2. Why 4 Separate Phases?

**Alternative**: Monolithic script

**Chosen**: 4 distinct phases

**Rationale**:
- AUR cannot be installed as root
- Separation of contexts (live ISO vs chroot)
- Better for debugging (can re-run specific phases)
- Separate logs per phase

### 3. Why setup.conf?

**Alternative**: Environment variables, database

**Chosen**: Simple text file

**Rationale**:
- Simple to read/write in bash
- Can be manually edited if needed
- Survives context changes (chroot)
- Human-readable for debugging

---

This architecture allows for extensibility, maintainability, and robustness in the Arch Linux installation process.
