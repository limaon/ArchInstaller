# ArchInstaller - Complete Documentation

## Documentation Index

1. **[USER-GUIDE.md](USER-GUIDE.md)** - End-user guide
2. **[AUTO-SWAP-DETECTION.md](AUTO-SWAP-DETECTION.md)** - Automatic swap detection
3. **[FUNCTIONS-REFERENCE.md](FUNCTIONS-REFERENCE.md)** - Complete function reference
4. **[PACKAGE-SYSTEM.md](PACKAGE-SYSTEM.md)** - JSON package system
5. **[DEVELOPMENT-GUIDE.md](DEVELOPMENT-GUIDE.md)** - Developer guide
6. **[troubleshooting/](troubleshooting/)** - Complete troubleshooting guide (organized)

## What is ArchInstaller?

**ArchInstaller** is an automated and interactive Arch Linux installer that transforms the complex manual installation process into a guided and simplified workflow. It installs a complete Arch Linux system with:

- **Automatic disk partitioning** with custom usage percentage
- **Multiple filesystem support** (ext4, btrfs, LUKS)
- **Automatic hardware detection** (CPU, GPU, battery)
- **Complete desktop environment installation**
- **Intelligent package installation** (auto-detects pacman vs AUR)
- **Driver, microcode, and optimization configuration**
- **Snapshot system** (btrfs + Snapper)
- **Pre-applied themes and configurations**

## Quick Start

### Prerequisites

- Boot into an Arch Linux ISO
- Internet connection
- Root privileges

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/limaon/ArchInstaller
cd ArchInstaller

# 2. Run the installer
chmod +x archinstall.sh
./archinstall.sh
```

### Interactive Process

The installer will ask:

1. **Full name, username, and password**
2. **Installation type**: FULL / MINIMAL / SERVER
3. **AUR Helper**: yay, paru, etc. (if not SERVER)
4. **Desktop Environment**: KDE, GNOME, i3, etc. (if not SERVER)
5. **Installation disk** (will be formatted!)
6. **Disk usage percentage** (5-100% of disk space)
7. **Filesystem**: btrfs, ext4, or LUKS
8. **Timezone** (auto-detected)
9. **System language** (locale)
10. **Keyboard layout**

After reviewing the configuration, automatic installation begins!

## Project Structure

```
ArchInstaller/
|-- archinstall.sh         # Main script
|-- configs/
|   |-- base/              # Base configs
|   |-- i3-wm/             # i3-wm configs
|   |-- kde/               # KDE configs
|   |-- awesome/           # AwesomeWM configs
|-- scripts/               # Installation scripts
|   +-- utils/             # Utility scripts
|-- packages/              # Package definitions (JSON)
+-- docs/                  # Documentation
```

## Execution Flow

The installer follows a **4-phase architecture**. Each phase runs in a different execution context (Live ISO, chroot root, chroot user, chroot root).

### Installation Sequence

```
./archinstall.sh
        |
        v
configuration.sh (Interactive wizard)
        |
        v
+-------------------+       arch-chroot /mnt
| Phase 0           |------------+
| 0-preinstall.sh   |            |
| Live ISO (root)   |            v
+-------------------+

                    +-------------------+
                    | Phase 1           |
                    | 1-setup.sh        |
                    | chroot (root)     |
                    +-------------------+
                            |
                            | runuser -u $USER
                            v
                     +-------------------+
                     | Phase 2           |
                     | 2-user.sh         |
                     | chroot (user)     |
                     | (skipped SERVER)  |
                     +-------------------+
                            |
                            | arch-chroot /mnt
                            v
                     +-------------------+
                     | Phase 3           |
                     | 3-post-setup.sh   |
                     | chroot (root)     |
                     +-------------------+
                            |
                            v
                          Reboot
```

### Phase Details

| Phase | Script            | Context            | Key Steps                                                                              |
| ----- | ----------------- | ------------------ | -------------------------------------------------------------------------------------- |
| **0** | `0-preinstall.sh` | Live ISO (root)    | Checks, Config, Mirrors, Format, Filesystems, Pacstrap, Fstab, Swap      |
| **1** | `1-setup.sh`      | chroot /mnt (root) | Network, Locale, Repos, Base pkgs, Microcode, GPU drivers, Theming, User |
| **2** | `2-user.sh`       | chroot /mnt (user) | AUR helper, Fonts, DE packages, Btrfs pkgs _(skipped for SERVER)_        |
| **3** | `3-post-setup.sh` | chroot /mnt (root) | GRUB, Display manager, Services, UFW, SSH, Cleanup                       |

### Configuration Wizard

```
background_checks()
        |
        v
    user_info()
        |
        v
install_type()
(FULL / MINIMAL / SERVER)
        |
        v
    swap_type()
        |
        v
    +-----------+
    | SERVER?   |
    +-----------+
     /        \
    No         Yes
     |          |
     v          v
aur_helper()   |
then           |
desktop_       |
env()          |
     |         |
     v         v
    disk_select()
        |
        v
   filesystem()
(btrfs / ext4 / luks)
        |
        v
  timezone()
  then locale
  then keymap
        |
        v
show_configurations()
        |
        v
    setup.conf
```

### Package Installation Logic

```
JSON files
(base.json, DE, gpu-drivers.json)
        |
        v
    Filters:
.minimal.pacman[] .minimal.aur[]
.full.pacman[]   .full.aur[]
        |
        v
+-------------------+
| Installed?        |
| (pacman -Qi)      |
+-------------------+
    /          \
   Yes         No
    |            |
    v            v
   Skip    +-------------------+
           | In repos?         |
           | (pacman -Si)      |
           +-------------------+
              /          \
             Yes         No
              |            |
              v            v
        pacman -S    AUR helper -S
```

## Key Features

### Automatic Hardware Detection

- **CPU**: Detects Intel or AMD and installs appropriate microcode
- **GPU**: Detects NVIDIA, AMD, Intel, or VM and installs drivers (JSON-based)
- **SSD/HDD**: Automatically adjusts mount options and swap strategy
- **Battery**: Installs and configures TLP only on laptops
- **Memory**: Intelligent swap configuration based on RAM, storage type, and installation type

### Multiple Filesystem Support

- **ext4**: Simple and reliable
- **btrfs**: With subvolumes (@, @home, @snapshots, @var_log, etc.)
- **LUKS**: Full-disk encryption + btrfs

### Supported Desktop Environments

KDE Plasma, GNOME, XFCE, Cinnamon, i3-wm, Awesome, Openbox, Budgie, Deepin, LXDE, MATE

### Installation Types

- **FULL**: Complete desktop + applications + themes + extra services
- **MINIMAL**: Basic desktop without extra apps
- **SERVER**: CLI only (no desktop environment)

### Automatic Optimizations

- Parallel compilation based on CPU cores
- Optimized mirror selection (reflector/rankmirrors)
- Zstd compression for btrfs
- Periodic trim for SSDs
- Pre-configured UFW firewall (FULL)

## Saved Configurations

All user choices are saved in `configs/setup.conf`:

```bash
REAL_NAME="John Doe"
USERNAME=john
PASSWORD=***
NAME_OF_MACHINE=archlinux
INSTALL_TYPE=FULL
AUR_HELPER=yay
DESKTOP_ENV=kde
DISK=/dev/sda
DISK_USAGE_PERCENT=100
FS=btrfs
SUBVOLUMES=(@ @home @snapshots @var_log @var_cache)
TIMEZONE=America/New_York
LOCALE=en_US.UTF-8
KEYMAP=us
MOUNT_OPTION=defaults,noatime,compress=zstd,ssd,discard=async,commit=120
```

This file is read by all subsequent scripts, ensuring consistency.

## Security Checks

Before execution, the installer verifies:

- Running as root
- Running on Arch Linux
- Pacman is not locked
- Not in a Docker container
- Partitions are mounted (phases 1-3)

## Logs

All output is logged to `install.log` and copied to `/var/log/install.log` in the installed system for future reference.

## Next Steps

- See **[FUNCTIONS-REFERENCE.md](FUNCTIONS-REFERENCE.md)** for complete function list
- Read **[DEVELOPMENT-GUIDE.md](DEVELOPMENT-GUIDE.md)** to add new features

## License

This project is distributed under a free license. Check the LICENSE file for details.
