# Overview

This is an automated Arch Linux installation script that streamlines the process of installing and configuring a complete Arch Linux desktop system. The installer provides a guided, interactive setup that allows users to customize their installation with different desktop environments, window managers, AUR helpers, and package sets (minimal or full). The script handles everything from disk partitioning and filesystem creation to desktop environment installation and system configuration.

# User Preferences

Preferred communication style: Simple, everyday language.

# System Architecture

## Installation Flow

The installer follows a sequential, multi-phase architecture:

1. **Pre-installation (0-preinstall.sh)** - Handles disk partitioning, filesystem creation, and pacstrap of base system
2. **System Setup (1-setup.sh)** - Configures the installed system, sets up locales, users, and installs base packages
3. **User Configuration (2-user.sh)** - Applies user-specific customizations and installs AUR packages
4. **Post-Setup (3-post-setup.sh)** - Finalizes configuration and cleanup

**Rationale**: This phased approach separates concerns cleanly - system installation, configuration, user setup, and finalization each have distinct responsibilities. This makes the installation process more maintainable and easier to debug.

## Configuration Management

The system uses a centralized configuration file (`setup.conf`) that stores all user preferences collected during the interactive setup phase. All installation scripts read from this single source of truth.

**Rationale**: Centralizing configuration prevents duplication and ensures consistency across all installation phases. The `set_option()` and `source_file()` helper functions provide standardized access to configuration values.

## Package Management Strategy

Packages are defined in JSON files organized by:
- Installation type (minimal vs full)
- Desktop environment
- Package source (pacman vs AUR)
- Special categories (fonts, btrfs tools)

**Rationale**: JSON-based package definitions separate package lists from installation logic, making it easy to add new desktop environments or modify package sets without changing code. The minimal/full split allows users to choose between lightweight and feature-rich installations.

## Filesystem Support

The installer supports multiple filesystems with special handling for Btrfs:
- Automatic subvolume creation for system organization
- Snapshot configuration via Snapper
- GRUB-Btrfs integration for boot-time snapshots

**Rationale**: Btrfs requires additional setup (subvolumes, snapshots) that ext4 doesn't need. The modular approach allows the installer to provide advanced features for Btrfs while keeping simpler filesystems straightforward.

## Bootloader Configuration

Uses GRUB as the bootloader with automatic configuration for:
- UEFI vs BIOS boot modes
- Filesystem-specific options (especially Btrfs)
- Microcode installation (Intel/AMD)

**Rationale**: GRUB provides broad compatibility and integrates well with Btrfs snapshots. The installer detects boot mode automatically to handle both legacy and modern systems.

## Desktop Environment Architecture

Supports multiple desktop environments and window managers through a plugin-like system:
- Each DE has its own package JSON file
- Display manager automatically selected based on DE choice
- Theming and configuration files organized per DE

**Rationale**: This modular approach makes it easy to add new desktop environments without modifying core installation logic. Each DE can define its own dependencies and configuration requirements.

## Error Handling and Logging

All scripts implement:
- Centralized error handling via `exit_on_error()` function
- Comprehensive logging to `.log` files for each installation phase
- System checks before installation (root privileges, Arch detection, mount points)

**Rationale**: Automated installations can fail in unexpected ways. Detailed logging and pre-flight checks help users troubleshoot issues. The `exit_on_error()` wrapper ensures failures are caught and logged immediately.

## User Interaction Pattern

The installer uses:
- Interactive prompts for configuration choices
- Multi-select menus for features with multiple options
- Configuration review screen before proceeding

**Rationale**: While automation is the goal, user choice is essential for a customized installation. The review screen prevents mistakes by showing all selections before making irreversible changes.

# External Dependencies

## Package Managers
- **pacman** - Official Arch Linux package manager
- **AUR helpers** (user-selectable) - yay, paru, or others for AUR package installation

## Display Managers
- **SDDM** - Used with KDE Plasma
- **LightDM** - Used with lightweight DEs/WMs (i3, Awesome, Openbox)
- **GDM** - Used with GNOME-based environments

## System Tools
- **git** - Required to clone the installer repository
- **reflector/rankmirrors** - For optimizing pacman mirror lists
- **grub** - Bootloader
- **btrfs-progs** - Btrfs filesystem utilities (when using Btrfs)
- **snapper** - Snapshot management (Btrfs installations)

## Desktop Components
Varies by selected desktop environment, but commonly includes:
- **X.org** - Display server (all graphical environments)
- **PipeWire/ALSA** - Audio subsystem
- **NetworkManager** - Network management
- **Bluez** - Bluetooth support

## Optional Services
- **TLP** - Laptop power management
- **Plymouth** - Boot splash screen
- **Docker** - Containerization (checks to prevent running in containers)