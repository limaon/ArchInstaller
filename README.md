# ArchLinux Installer Script
[![GitHub Super-Linter](https://github.com/limaon/ArchInstaller/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/marketplace/actions/super-linter)

An automated and interactive Arch Linux installer that transforms the complex manual installation process into a guided workflow. Install a complete Arch Linux system with desktop environment, drivers, optimizations, and configurations pre-applied.

## Features

- **Intelligent Hardware Detection**: Automatically detects CPU, GPU, RAM, storage type (SSD/HDD), and battery
- **Adaptive Swap Configuration**: Automatically chooses optimal swap strategy (ZRAM/swap file) based on RAM, storage type, and installation profile
- **Interactive Timezone Selection**: Automatic detection with searchable menu (press `/` to search)
- **Custom Disk Usage**: Choose percentage of disk to use (5-100%) instead of using entire disk
- **Multiple Filesystems**: Support for ext4, btrfs (with snapshots), and LUKS encryption
- **Desktop Environments**: KDE, GNOME, XFCE, Cinnamon, i3-wm, Awesome, Openbox, Budgie, Deepin, LXDE, MATE
- **Battery Notifications**: Automatic battery monitoring for i3-wm (laptops) with desktop notifications
- **Installation Profiles**: FULL (complete desktop), MINIMAL (basic desktop), SERVER (CLI only)
- **Automatic SSH Setup**: SSH server configured and enabled for remote access
- **Post-Installation Verification**: Automatic verification script to check installation success
- **Complete Logging**: All output logged to `/var/log/install.log` for troubleshooting

---
## Prerequisites

- Arch Linux ISO downloaded from <https://archlinux.org/download/>
- USB drive with ISO written using [Etcher](https://www.balena.io/etcher/), [Ventoy](https://www.ventoy.net/en/index.html), or [Rufus](https://rufus.ie/en/)
- Internet connection (required for package downloads)

## Quick Start

### Installation

1. **Boot Arch ISO** and connect to internet
2. **Run installer**:
   ```bash
   # Quick method (single command)
   bash <(curl -L tinyurl.com/4b3jcbpd)

   # Or manual method
   pacman -Sy git
   git clone --depth=1 https://github.com/limaon/ArchInstaller.git
   cd ArchInstaller
   ./archinstall.sh
   ```

3. **Follow interactive prompts**:
   - User information (name, username, password)
   - Installation type (FULL/MINIMAL/SERVER)
   - Desktop environment (if not SERVER)
   - Disk selection and usage percentage
   - Filesystem choice
   - Timezone (auto-detected with searchable menu)
   - Locale and keyboard layout

4. **Review configuration** and confirm installation

5. **Reboot** when installation completes

### After Installation

**Verify installation success**:
```bash
# Run verification script (as your user)
~/.archinstaller/verify-installation.sh

# Or connect via SSH (if remote access needed)
ssh your-username@server-ip
~/.archinstaller/verify-installation.sh
```

**Files available in `~/.archinstaller/`**:
- `install.log` - Complete installation log
- `verify-installation.sh` - Verification script
- `setup.conf` - Installation configuration (password removed)
- `fix-swap.sh` - Swap fix script (if needed)

## Documentation

- **[Complete Documentation](docs/README.md)** - Overview and index
- **[User Guide](docs/USER-GUIDE.md)** - Step-by-step installation guide
- **[Architecture](docs/ARCHITECTURE.md)** - System architecture details
- **[Functions Reference](docs/FUNCTIONS-REFERENCE.md)** - Complete function documentation
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Package System](docs/PACKAGE-SYSTEM.md)** - JSON package management

## Troubleshooting

### Installation Logs

All installation output is logged to `/var/log/install.log` and copied to `~/.archinstaller/install.log` for easy access after reboot.

### Quick Checks

```bash
# Check for errors in log
grep -i error /var/log/install.log

# Check failed services
systemctl --failed

# Check swap status
swapon --show
free -h

# Check network
ip addr show
systemctl status NetworkManager
```

### No WiFi

You can check if the WiFi is blocked by running `rfkill list`.
If it says **Soft blocked: yes**, then run `rfkill unblock wifi`

After unblocking the WiFi, you can connect to it. Go through these 5 steps:

#1: Run `iwctl`

#2: Run `device list`, and find your device name.

#3: Run `station [device name] scan`

#4: Run `station [device name] get-networks`

#5: Find your network, and run `station [device name] connect [network name]`, enter your password and run `exit`. You can test if you have internet connection by running `ping google.com`, and then Press Ctrl and C to stop the ping test.

## Reporting Issues

When reporting issues, please include:

1. **Configuration** (from `~/.archinstaller/setup.conf` - **DO NOT INCLUDE PASSWORDS**):
   ```bash
   cat ~/.archinstaller/setup.conf | grep -v PASSWORD
   ```

2. **Installation log** (relevant error sections):
   ```bash
   grep -A 10 -B 10 "ERROR_MESSAGE" ~/.archinstaller/install.log
   ```

3. **Verification script output**:
   ```bash
   ~/.archinstaller/verify-installation.sh
   ```

4. **System information**:
   - Git commit/branch used
   - Installation environment (VMWare, VirtualBox, QEMU/KVM, Baremetal)
   - If VM: RAM, CPU cores, disk size
   - Hardware specs (if relevant)

5. **Error details**:
   - What step failed
   - Error messages
   - Screenshots (if applicable)

## Credits

- Original packages script was a post install cleanup script called ArchMatic located here: https://github.com/rickellis/ArchMatic

- This repository was originally created and maintained by Chris Titus, located at https://github.com/ChrisTitusTech/ArchTitus.

- Thank you to Chris for developing the initial automated Arch Linux installation scripts and tutorials that served as a foundation for this project.
