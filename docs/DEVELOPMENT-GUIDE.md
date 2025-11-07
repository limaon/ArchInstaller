# Development Guide

This document is for developers who want to add features, fix bugs, or contribute to ArchInstaller.

---

## Getting Started

### Prerequisites

- Knowledge of Bash scripting
- Familiarity with Arch Linux
- Git
- VM for testing (VirtualBox, VMware, QEMU, etc.)

### Development Setup

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/your-username/ArchInstaller
   cd ArchInstaller
   ```

2. **Create Branch**:
   ```bash
   git checkout -b feature/my-feature
   ```

3. **Test in VM**:
   - Create VM with 20GB+ disk
   - Boot Arch Linux ISO
   - Clone your fork inside the VM

---

## Code Structure

### Hierarchy of Responsibilities

```
archinstall.sh (orchestrator)
    ↓
configuration.sh (user input)
    ↓
sequence() (phase manager)
    ├── 0-preinstall.sh (disk setup)
    ├── 1-setup.sh (system config)
    ├── 2-user.sh (user apps)
    └── 3-post-setup.sh (finalization)
         ↓
    utils/*.sh (helper functions)
```

### When to Modify Each File

**archinstall.sh**: Rarely. Only if changing general orchestration.

**configuration.sh**: Add/remove configuration questions.

**0-preinstall.sh**: Modify partitioning, filesystem creation.

**1-setup.sh**: Add system configurations, new repos.

**2-user.sh**: Change desktop/AUR installation order.

**3-post-setup.sh**: Add services, modify cleanup.

**utils/\*.sh**: Add reusable functions.

**packages/\*.json**: Add/remove packages.

---

## Adding Features

### Feature: New Desktop Environment

#### 1. Create Package JSON

`packages/desktop-environments/my-de.json`:

```json
{
  "minimal": {
    "pacman": [
      {"package": "my-de-core"},
      {"package": "terminal-emulator"},
      {"package": "file-manager"},
      {"package": "display-manager"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "my-de-full"},
      {"package": "extra-apps"}
    ],
    "aur": [
      {"package": "aur-themes"}
    ]
  }
}
```

#### 2. Configure Display Manager

In `scripts/utils/system-config.sh`, add to `display_manager()`:

```bash
elif [[ "${DESKTOP_ENV}" == "my-de" ]]; then
    systemctl enable my-dm.service

    if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
        # Theme configuration
        echo "theme=my-theme" >> /etc/my-dm/my-dm.conf
    fi
```

#### 3. (Optional) Theming

If you have dotfiles in `configs/my-de/`, add to `scripts/utils/software-install.sh -> user_theming()`:

```bash
elif [[ "$DESKTOP_ENV" == "my-de" ]]; then
    cp -r ~/archinstaller/configs/my-de/home/. ~/
    # Apply additional configurations
```

#### 4. Test

```bash
./archinstall.sh
# Select "my-de" from list
```

---

### Feature: New Configuration Option

#### 1. Add Collection Function

In `scripts/utils/user-options.sh`:

```bash
my_option() {
    echo -ne "
Please select option:
"
    options=("Option A" "Option B" "Option C")
    select_option $? 3 "${options[@]}"
    my_choice="${options[$?]}"
    set_option MY_OPTION "$my_choice"
}
```

#### 2. Add to Configuration Workflow

In `scripts/configuration.sh`:

```bash
# After other configurations
my_option
clear
```

#### 3. Add to Show Configurations

In `scripts/utils/user-options.sh -> show_configurations()`:

```bash
# In menu
10) My Option
...

# In case
case $choice in
    ...
    10) my_option ;;
    ...
esac
```

#### 4. Use Configuration

In any later script:

```bash
source "$HOME"/archinstaller/configs/setup.conf

if [[ "$MY_OPTION" == "Option A" ]]; then
    # Do something
fi
```

---

### Feature: Hardware Detection

Example: Detect if touchpad exists.

#### 1. Add Detection Function

In `scripts/utils/software-install.sh`:

```bash
touchpad_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Detecting Touchpad
-------------------------------------------------------------------------
"
    # Detect touchpad
    if xinput list | grep -i "touchpad"; then
        echo "Touchpad detected, installing libinput"
        pacman -S --noconfirm --needed xf86-input-libinput

        # Additional configuration
        cat > /etc/X11/xorg.conf.d/30-touchpad.conf <<EOF
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
EndSection
EOF
    else
        echo "No touchpad detected, skipping"
    fi
}
```

#### 2. Call Function

In `scripts/1-setup.sh` or `scripts/2-user.sh`:

```bash
# After graphics_install()
touchpad_install
```

---

### Feature: New Filesystem

Example: XFS support.

#### 1. Add Option

In `scripts/utils/user-options.sh -> filesystem()`:

```bash
options=("btrfs" "ext4" "xfs" "luks" "exit")
select_option $? 1 "${options[@]}"

case $? in
0) set_btrfs; set_option FS btrfs ;;
1) set_option FS ext4 ;;
2) set_option FS xfs ;;  # New option
3) set_password "LUKS_PASSWORD"; set_option FS luks ;;
4) exit ;;
esac
```

#### 2. Implement Creation

In `scripts/utils/system-config.sh -> create_filesystems()`:

```bash
if [[ "${FS}" == "btrfs" ]]; then
    do_btrfs "ROOT" "${root_partition}"
elif [[ "${FS}" == "ext4" ]]; then
    mkfs.ext4 -L ROOT "${root_partition}"
    mount -t ext4 "${root_partition}" /mnt
elif [[ "${FS}" == "xfs" ]]; then
    # New implementation
    mkfs.xfs -L ROOT "${root_partition}"
    mount -t xfs "${root_partition}" /mnt
elif [[ "${FS}" == "luks" ]]; then
    # ...
fi
```

---

## Debugging

### Logs

Everything is logged to `install.log`:

```bash
# During installation, in another terminal (Ctrl+Alt+F2)
tail -f /root/ArchInstaller/install.log

# After installation, in installed system
less /var/log/install.log
```

### Add Debug Output

```bash
echo "DEBUG: variable=$variable" >> "$LOG_FILE"
```

### Test Specific Phase

```bash
# Skip directly to phase 1 (assuming phase 0 already ran)
arch-chroot /mnt /root/archinstaller/scripts/1-setup.sh
```

### Interactive Shell in Chroot

```bash
# After phase 0
arch-chroot /mnt
# Now you're inside the installed system
# Can test commands manually
```

### Dry Run (Simulate)

Add `-n` flag to critical commands:

```bash
# Doesn't execute, just shows what it would do
pacman -S firefox --needed -n
```

---

## Testing

### Testing Checklist

Before making PR, test:

- [ ] MINIMAL install with ext4
- [ ] FULL install with btrfs
- [ ] SERVER install
- [ ] LUKS encryption
- [ ] Different DEs (at least KDE and GNOME)
- [ ] On UEFI
- [ ] On BIOS legacy (if applicable)

### Quick Test Setup

#### VirtualBox

```bash
# Create VM
VBoxManage createvm --name "ArchTest" --ostype "ArchLinux_64" --register
VBoxManage modifyvm "ArchTest" --memory 4096 --vram 128 --cpus 2
VBoxManage createhd --filename "ArchTest.vdi" --size 20480
VBoxManage storagectl "ArchTest" --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach "ArchTest" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "ArchTest.vdi"
VBoxManage storageattach "ArchTest" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "archlinux.iso"
```

#### QEMU

```bash
# Create disk
qemu-img create -f qcow2 arch-test.qcow2 20G

# Boot ISO
qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 2 \
    -cdrom archlinux.iso \
    -boot d \
    -drive file=arch-test.qcow2,format=qcow2
```

### Automate Tests

Create `test-install.sh`:

```bash
#!/bin/bash
# Auto-responder for testing

cat > test-config.txt <<EOF
John Smith
john
password123
password123
archtest
EOF

# Mock input
./archinstall.sh < test-config.txt
```

---

## Code Conventions

### Bash Style Guide

#### 1. Indentation

- 4 spaces (not tabs)
- Indented if/for/while blocks

```bash
if [[ condition ]]; then
    command
    if [[ other_condition ]]; then
        another_command
    fi
fi
```

#### 2. Naming

- Functions: `snake_case`
- Local variables: `snake_case`
- Global variables (setup.conf): `UPPER_CASE`
- Constants: `UPPER_CASE`

```bash
# Function
install_packages() {
    local package_list="$1"  # Local
    echo "Installing to $INSTALL_DIR"  # Global
}
```

#### 3. Quotes

- Always quote variables: `"$VAR"`
- Arrays: `"${ARRAY[@]}"`

```bash
# GOOD
if [[ "$USERNAME" == "root" ]]; then

# BAD
if [[ $USERNAME == "root" ]]; then
```

#### 4. Conditionals

- Use `[[ ]]` instead of `[ ]`
- Prefer `&&` and `||` for short logic

```bash
# GOOD
[[ -f "$FILE" ]] && echo "Exists"

# ACCEPTABLE
if [[ -f "$FILE" ]]; then
    echo "Exists"
fi
```

#### 5. Commands

- Always check `$?` on critical commands
- Use `--noconfirm` in pacman for non-interactive

```bash
pacman -S package --noconfirm --needed
exit_on_error $? "pacman -S package"
```

#### 6. Comments

- Comments on important sections
- Document complex functions

```bash
# Detects CPU type and installs appropriate microcode
microcode_install() {
    proc_type=$(lscpu)
    # Intel has "GenuineIntel" in output
    if grep -E "GenuineIntel" <<<"${proc_type}"; then
        pacman -S intel-ucode
    fi
}
```

---

## Git Workflow

### Branches

- `main`: Stable code
- `develop`: Active development
- `feature/name`: New feature
- `fix/name`: Bug fix

### Commits

```bash
# Descriptive messages
git commit -m "Add support for XFS filesystem"
git commit -m "Fix touchpad detection on laptops"
git commit -m "Update KDE packages to latest"
```

### Pull Requests

1. Fork repository
2. Create feature branch
3. Make small, focused commits
4. Test thoroughly
5. Open PR with detailed description

**PR Template**:

```markdown
## Description
Brief description of change.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation

## Checklist
- [ ] Tested in VM (UEFI)
- [ ] Tested MINIMAL and FULL
- [ ] Updated documentation
- [ ] Code follows style guide

## Screenshots (if applicable)
```

---

## Code Review Checklist

When reviewing PRs:

- [ ] Code follows conventions
- [ ] Functions have clear purpose
- [ ] No hardcoded values (use variables)
- [ ] Adequate error handling
- [ ] Logs added where necessary
- [ ] No duplicated code
- [ ] Documentation updated
- [ ] Tests mentioned

---

## Useful Resources

### Official Documentation

- [Arch Wiki](https://wiki.archlinux.org)
- [Bash Manual](https://www.gnu.org/software/bash/manual/)
- [JQ Manual](https://stedolan.github.io/jq/manual/)
- [systemd](https://www.freedesktop.org/software/systemd/man/)

### Tools

- **shellcheck**: Bash linter
  ```bash
  shellcheck archinstall.sh
  ```

- **shfmt**: Bash formatter
  ```bash
  shfmt -i 4 -w archinstall.sh
  ```

### Debugging Tools

- `set -x`: Debug mode (shows executed commands)
- `set -e`: Exit on error
- `set -u`: Exit on undefined variable
- `trap`: Catch errors and signals

```bash
#!/bin/bash
set -euo pipefail  # Strict mode
trap 'echo "Error on line $LINENO"' ERR
```

---

## Feature Roadmap

### Planned

- [ ] Wayland support (in addition to X11)
- [ ] More DEs (Sway, Hyprland, etc.)
- [ ] ZFS support
- [ ] Automatic dual-boot installation
- [ ] Configuration presets (Gaming, Developer, Server)
- [ ] Remote installation via SSH
- [ ] Configuration GUI (ncurses)

### Under Consideration

- [ ] Support for other bootloaders (systemd-boot)
- [ ] Support for other Arch-based distributions
- [ ] Plugin system
- [ ] Automatic backup before installation

---

## Contributing

Contributions are welcome! Please:

1. Read this complete guide
2. Test your changes extensively
3. Follow code conventions
4. Document new features
5. Be respectful in discussions

---

## Contact

For development questions:
- Open an issue on GitHub
- Participate in discussions

---

Happy coding!
