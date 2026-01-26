# Troubleshooting Guide - Index

## Overview

This troubleshooting guide is organized to help quickly and efficiently solve common ArchInstaller problems.

**Quick Reference:**
- [Installation Verification](./VERIFICATION.md) - How to verify installation worked
- [Quick Checklist](./QUICK-CHECK.md) - Most important commands for diagnosis
- [Common Problems](./COMMON-PROBLEMS.md) - Solutions for frequent errors

**Specific Features:**
- [i3-wm Features](./SPECIFIC-FEATURES.md#i3-wm-features) - Auto suspend/hibernate and battery notifications
- [Swap Configuration](./SPECIFIC-FEATURES.md#swap-configuration) - Swap configuration and troubleshooting
- [Btrfs Snapshots](./SPECIFIC-FEATURES.md#btrfs-snapshots) - Snapshot restoration and rollbacks

**How to Report Issues:**
- [Reporting Guide](./REPORTING.md) - How to report problems efficiently

---

## Complete Guide Structure

### Initial Verification
- [Installation Verification](./VERIFICATION.md) - Automatic scripts and post-reboot verification
- [Quick Checklist](./QUICK-CHECK.md) - Essential commands for quick diagnosis

### Problems by Category
- [Common Problems](./COMMON-PROBLEMS.md) - Frequent errors organized by type
  - Boot Issues
  - Network Problems
  - Desktop Environment Issues
  - Package Installation Problems
  - Hardware Detection Problems

### Advanced Features
- [i3-wm Features](./SPECIFIC-FEATURES.md#i3-wm-features)
  - Auto Suspend/Hibernate
  - Battery Notifications
- [Swap Configuration](./SPECIFIC-FEATURES.md#swap-configuration)
  - Decision Table by RAM
  - Btrfs vs ext4
  - Troubleshooting
- [Btrfs Snapshots](./SPECIFIC-FEATURES.md#btrfs-snapshots)
  - Restoration
  - Rollbacks
  - GUI Tools

### How to Help
- [Reporting Issues](./REPORTING.md) - How to provide useful information for support

---

## Quick Reference - Comandos Mais Importantes

```bash
# Verificar logs de erro
grep -i error /var/log/install.log | tail -20

# Verificar serviços falhando
systemctl --failed

# Verificar swap
swapon --show

# Verificar rede
systemctl status NetworkManager

# Verificar desktop environment
pacman -Q | grep -i "your-desktop-env"
```

## Contato e Ajuda

- [Arch Linux Wiki](https://wiki.archlinux.org)
- [ArchInstaller Issues](https://github.com/limaon/ArchInstaller/issues)
- Documentação completa: [Documentation Index](../../docs/README.md)
