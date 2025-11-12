# ArchInstaller - Complete Documentation

## Documentation Index

1. **[README.md](README.md)** - This file (overview)
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Complete system architecture
3. **[USER-GUIDE.md](USER-GUIDE.md)** - Installation and usage guide
4. **[FUNCTIONS-REFERENCE.md](FUNCTIONS-REFERENCE.md)** - Complete function reference
5. **[PACKAGE-SYSTEM.md](PACKAGE-SYSTEM.md)** - JSON package system
6. **[DEVELOPMENT-GUIDE.md](DEVELOPMENT-GUIDE.md)** - Developer guide

---

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

---

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

---

## Project Structure

```
ArchInstaller/
├── archinstall.sh              # Main script (entry point)
├── configs/
│   └── setup.conf              # Generated configuration file
├── scripts/
│   ├── configuration.sh        # Interactive configuration workflow
│   ├── 0-preinstall.sh         # Phase 0: Partitioning and pacstrap
│   ├── 1-setup.sh              # Phase 1: System configuration
│   ├── 2-user.sh               # Phase 2: User installation (AUR/DE)
│   ├── 3-post-setup.sh         # Phase 3: Finalization and services
│   └── utils/                  # Utility scripts
│       ├── installer-helper.sh # Helper functions
│       ├── system-checks.sh    # Security checks
│       ├── user-options.sh     # Configuration collection
│       ├── software-install.sh # Software installation
│       └── system-config.sh    # System configuration
├── packages/                   # Package definitions (JSON)
│   ├── base.json              # Base system packages
│   ├── btrfs.json             # Btrfs tools
│   ├── desktop-environments/  # One JSON per DE
│   │   ├── kde.json
│   │   ├── gnome.json
│   │   ├── i3-wm.json
│   │   └── ...
│   └── optional/
│       └── fonts.json         # System fonts
└── docs/                      # This documentation
```

---

## Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. archinstall.sh                                          │
│     - Loads utilities                                       │
│     - Executes configuration.sh (collect data)              │
│     - Starts sequence() with 4 phases                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 0: 0-preinstall.sh (Live ISO - before chroot)       │
│     - Updates mirrors                                       │
│     - Partitions disk (GPT)                                 │
│     - Creates filesystems (ext4/btrfs/LUKS)                │
│     - Pacstrap base system                                  │
│     - Generates fstab                                       │
│     - Installs bootloader                                   │
│     - Configures ZRAM if <8GB RAM                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1: 1-setup.sh (Chroot as root)                      │
│     - Installs NetworkManager                               │
│     - Configures locale, timezone, keymap                   │
│     - Enables multilib                                      │
│     - Installs base packages                                │
│     - Detects and installs microcode (Intel/AMD)            │
│     - Detects and installs GPU drivers                      │
│     - Creates user and groups                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 2: 2-user.sh (As normal user)                       │
│     - Installs AUR helper (yay/paru)                        │
│     - Installs fonts                                        │
│     - Installs desktop environment                          │
│     - Installs btrfs tools                                  │
│     - Applies themes                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 3: 3-post-setup.sh (Chroot as root)                 │
│     - Configures GRUB                                       │
│     - Configures display manager (SDDM/GDM/LightDM)        │
│     - Enables services (NetworkManager, TLP, UFW, etc.)    │
│     - Configures Snapper (snapshots)                        │
│     - Configures Plymouth (boot splash)                     │
│     - Cleanup temporary files                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    INSTALLATION COMPLETE!
                      Eject ISO and Reboot
```

---

## Key Features

### Automatic Hardware Detection
- **CPU**: Detects Intel or AMD and installs appropriate microcode
- **GPU**: Detects NVIDIA, AMD, or Intel and installs drivers
- **SSD/HDD**: Automatically adjusts mount options
- **Battery**: Installs and configures TLP only on laptops
- **Memory**: Configures ZRAM if system has <8GB RAM

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

---

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

---

## Security Checks

Before execution, the installer verifies:
- Running as root
- Running on Arch Linux
- Pacman is not locked
- Not in a Docker container
- Partitions are mounted (phases 1-3)

---

## Logs

All output is logged to `install.log` and copied to `/var/log/install.log` in the installed system for future reference.

---

## Next Steps

- Consult **[ARCHITECTURE.md](ARCHITECTURE.md)** to understand the architecture in detail
- See **[FUNCTIONS-REFERENCE.md](FUNCTIONS-REFERENCE.md)** for complete function list
- Read **[DEVELOPMENT-GUIDE.md](DEVELOPMENT-GUIDE.md)** to add new features

---

## License

This project is distributed under a free license. Check the LICENSE file for details.
