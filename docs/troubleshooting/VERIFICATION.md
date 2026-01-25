# Installation Verification - ArchInstaller

This document explains how to verify if your Arch Linux installation worked correctly after reboot.

## Method 1: Automatic Verification (Recommended)

After logging into your new system:

```bash
# Run verification script (as your user - uses sudo when needed)
~/.archinstaller/verify-installation.sh

# Or if you're already in home directory
./.archinstaller/verify-installation.sh
```

### What the script automatically checks:
- Checks installation logs for errors
- Checks system services
- Checks network and SSH configuration
- Checks swap configuration
- Checks user account and permissions
- Checks desktop environment installation
- Displays SSH connection information

## Method 2: Remote Verification via SSH

The installer automatically configures SSH for remote access. After reboot:

### 1. Find the server IP address:
```bash
# On the newly installed server
ip addr show
# or
hostname -I
```

### 2. Connect remotely (from another machine):
```bash
ssh your-user@server-ip-address
```

### 3. Run verification script:
```bash
~/.archinstaller/verify-installation.sh
```

## Files Available After Installation

The installer automatically copies these files to `~/.archinstaller/`:

- `install.log` - Complete installation log
- `verify-installation.sh` - Verification script
- `setup.conf` - Installation configuration (password removed for security)

**Important:** These files persist even after the installer cleans up temporary files.

---

## Next Steps

If verification shows everything OK:
- Congratulations! Your installation was successful
- Continue with post-installation configuration according to [User Guide](../../docs/USER-GUIDE.md)

If you encounter problems:
- Check the [Quick Checklist](./QUICK-CHECK.md) for quick diagnosis
- See [Common Problems](./COMMON-PROBLEMS.md) for solutions
- Report issues following the [Reporting Guide](./REPORTING.md)
