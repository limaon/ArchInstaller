# JSON Package System

This document explains how the JSON-based package management system works in ArchInstaller.

---

## Why JSON?

### Advantages

**Data and logic separation**: Package lists separate from code
**Easy maintenance**: Add/remove packages without touching bash
**Flexible queries**: JQ allows complex filters
**Clear hierarchy**: minimal vs full, pacman vs aur
**Comments via description**: Each package can have metadata

### Considered Alternatives

- **Shell arrays**: Difficult to structure hierarchically
- **YAML**: Requires extra parser not available in ISO
- **TOML**: Same limitation as YAML
- **Plain text**: No structure, difficult to filter

**Chosen**: JSON + JQ (already available in Arch ISO)

---

## Directory Structure

```
packages/
├── base.json                    # Base system packages
├── btrfs.json                   # Btrfs tools
├── desktop-environments/        # One JSON per DE
│   ├── kde.json
│   ├── gnome.json
│   ├── xfce.json
│   ├── cinnamon.json
│   ├── i3-wm.json
│   ├── awesome.json
│   ├── openbox.json
│   ├── budgie.json
│   ├── deepin.json
│   ├── lxde.json
│   └── mate.json
└── optional/
    └── fonts.json               # System fonts
```

---

## JSON Format

### Basic Template

```json
{
  "minimal": {
    "pacman": [
      {"package": "package-name"}
    ],
    "aur": [
      {"package": "aur-package"}
    ]
  },
  "full": {
    "pacman": [
      {"package": "extra-package"}
    ],
    "aur": [
      {"package": "extra-aur-package"}
    ]
  }
}
```

### Fields

- **minimal**: Minimal installation (always installed if not SERVER)
  - **pacman**: Official packages
  - **aur**: AUR packages (only if AUR_HELPER ≠ NONE)

- **full**: Complete installation (only if INSTALL_TYPE=FULL)
  - **pacman**: Extra official packages
  - **aur**: Extra AUR packages

---

## base.json

Fundamental system packages (not desktop).

### Structure

```json
{
  "minimal": {
    "pacman": [
      {"package": "bash-completion"},
      {"package": "man-db"},
      {"package": "man-pages"},
      {"package": "git"},
      {"package": "curl"},
      {"package": "wget"},
      ...
    ],
    "aur": [
      {"package": "downgrade"}
    ]
  },
  "full": {
    "pacman": [
      {"package": "firefox"},
      {"package": "vlc"},
      {"package": "gimp"},
      {"package": "libreoffice-fresh"},
      ...
    ],
    "aur": [
      {"package": "google-chrome"},
      {"package": "visual-studio-code-bin"}
    ]
  }
}
```

### Common Categories

**CLI Tools**: git, curl, wget, rsync, htop, neofetch
**Compression**: zip, unzip, p7zip, unrar
**Development**: base-devel, gcc, make, cmake
**Network**: net-tools, bind-tools, nmap
**System**: man-db, man-pages, bash-completion

**FULL adds**:
**Browsers**: firefox, chromium
**Media**: vlc, ffmpeg, imagemagick
**Office**: libreoffice-fresh
**Graphics**: gimp, inkscape

---

## Desktop Environments

Each DE has its own JSON in `desktop-environments/`.

### Example: kde.json

```json
{
  "minimal": {
    "pacman": [
      {"package": "plasma-desktop"},
      {"package": "plasma-nm"},
      {"package": "plasma-pa"},
      {"package": "konsole"},
      {"package": "dolphin"},
      {"package": "sddm"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "plasma-meta"},
      {"package": "kde-applications-meta"},
      {"package": "kdenlive"},
      {"package": "krita"},
      {"package": "ark"},
      {"package": "gwenview"},
      {"package": "okular"},
      {"package": "spectacle"}
    ],
    "aur": [
      {"package": "sddm-theme-nordic-git"}
    ]
  }
}
```

### Recommended Structure

**minimal.pacman**:
- Meta-package or core DE packages
- Display manager (sddm, gdm, lightdm)
- Terminal emulator
- File manager
- Network manager applet
- Audio applet

**full.pacman**:
- Complete meta-package
- Ecosystem applications
- Productivity tools
- Extras and plugins

**full.aur**:
- Custom themes
- Unofficial plugins
- Community-specific apps

---

### Example: i3-wm.json

```json
{
  "minimal": {
    "pacman": [
      {"package": "i3-wm"},
      {"package": "i3status"},
      {"package": "i3lock"},
      {"package": "dmenu"},
      {"package": "xorg-server"},
      {"package": "xorg-xinit"},
      {"package": "alacritty"},
      {"package": "thunar"},
      {"package": "lightdm"},
      {"package": "lightdm-gtk-greeter"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "rofi"},
      {"package": "polybar"},
      {"package": "picom"},
      {"package": "nitrogen"},
      {"package": "dunst"},
      {"package": "feh"},
      {"package": "scrot"}
    ],
    "aur": [
      {"package": "i3-gaps-git"},
      {"package": "autotiling"}
    ]
  }
}
```

---

## fonts.json

System fonts (FULL install only).

### Structure

```json
{
  "pacman": [
    {"package": "ttf-dejavu"},
    {"package": "ttf-liberation"},
    {"package": "noto-fonts"},
    {"package": "noto-fonts-emoji"},
    {"package": "ttf-hack"},
    {"package": "ttf-fira-code"}
  ],
  "aur": [
    {"package": "ttf-ms-fonts"},
    {"package": "nerd-fonts-complete"}
  ]
}
```

**Note**: No minimal/full separation - either installs all or nothing.

---

## btrfs.json

Btrfs-specific tools (only installs if FS=btrfs).

### Structure

```json
{
  "pacman": [
    {"package": "btrfs-progs"},
    {"package": "snapper"},
    {"package": "snap-pac"},
    {"package": "grub-btrfs"}
  ],
  "aur": [
    {"package": "snapper-gui-git"}
  ]
}
```

**Packages**:
- **btrfs-progs**: Btrfs utilities
- **snapper**: Snapshot management
- **snap-pac**: Automatic snapshots when using pacman
- **grub-btrfs**: Boot from snapshots via GRUB

---

## JQ Queries

### Installation Logic

```bash
# Example from software-install.sh -> base_install()

# Define filters based on INSTALL_TYPE
MINIMAL_PACMAN_FILTER=".minimal.pacman[].package"
FULL_PACMAN_FILTER=""

if [[ "$INSTALL_TYPE" == "FULL" ]]; then
    FULL_PACMAN_FILTER=", .full.pacman[].package"
fi

# Combine filters and extract packages
jq --raw-output "${MINIMAL_PACMAN_FILTER}${FULL_PACMAN_FILTER}" \
    "$PACKAGE_LIST_FILE" | while read -r package; do
    echo "Installing $package..."
    pacman -S "$package" --noconfirm --needed --color=always
done
```

### Common Queries

**Pacman minimal only**:
```bash
jq -r '.minimal.pacman[].package' base.json
```

**Pacman minimal + full**:
```bash
jq -r '.minimal.pacman[].package, .full.pacman[].package' base.json
```

**Everything (pacman + aur)**:
```bash
jq -r '.minimal.pacman[].package, .minimal.aur[].package,
       .full.pacman[].package, .full.aur[].package' base.json
```

**AUR only**:
```bash
jq -r '.minimal.aur[].package, .full.aur[].package' base.json
```

---

## Adding New Desktop Environment

### Step 1: Create JSON

Create `packages/desktop-environments/my-de.json`:

```json
{
  "minimal": {
    "pacman": [
      {"package": "my-de-core"},
      {"package": "display-manager"},
      {"package": "terminal"},
      {"package": "file-manager"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "my-de-apps"},
      {"package": "extras"}
    ],
    "aur": [
      {"package": "custom-themes"}
    ]
  }
}
```

### Step 2: Configure Display Manager

In `system-config.sh -> display_manager()`:

```bash
elif [[ "${DESKTOP_ENV}" == "my-de" ]]; then
    systemctl enable my-display-manager.service

    if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
        echo "Configuring theme..."
        # Apply theme settings
    fi
```

### Step 3: (Optional) Add Theming

In `software-install.sh -> user_theming()`:

```bash
elif [[ "$DESKTOP_ENV" == "my-de" ]]; then
    cp -r ~/archinstaller/configs/my-de/home/. ~/
    # Apply dotfiles and configurations
```

### Step 4: Test

```bash
./archinstall.sh
# Choose "my-de" from list
```

The installer will detect the new JSON automatically!

---

## Package Installation Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. Determine INSTALL_TYPE (MINIMAL, FULL, SERVER)      │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Determine AUR_HELPER (yay, paru, NONE)              │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Build JQ filters                                     │
│    MINIMAL: .minimal.pacman[].package                   │
│    FULL:    + .full.pacman[].package                    │
│    AUR:     + .minimal.aur[].package                    │
│             + .full.aur[].package (if FULL)             │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Read appropriate JSON                                │
│    - base.json                                          │
│    - desktop-environments/$DESKTOP_ENV.json             │
│    - fonts.json (if not SERVER)                         │
│    - btrfs.json (if FS=btrfs)                           │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Apply JQ filter and extract packages                │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 6. Installation loop                                    │
│    for package in $(jq ...); do                         │
│        pacman -S $package  or  $AUR_HELPER -S $package  │
│    done                                                 │
└─────────────────────────────────────────────────────────┘
```

---

## Best Practices

### 1. Organization

- One package per line
- Alphabetical order (easier to find)
- Comments via "description" field if needed

```json
{
  "pacman": [
    {"package": "firefox", "description": "Main browser"},
    {"package": "thunderbird", "description": "Email client"}
  ]
}
```

### 2. Dependencies

JQ doesn't validate dependencies. Ensure:
- Base packages before extras
- Display manager included in DE
- Audio/video drivers in minimal

### 3. Size

**minimal**: ~50-100 packages (quick installation)
**full**: ~200-400 packages (complete)

### 4. Testing

Always test both:
- MINIMAL install (fast, functional)
- FULL install (complete, may be slow)

---

## Maintenance

### Add Package

```bash
# Edit JSON
vim packages/base.json

# Add to minimal.pacman or full.pacman
{
  "minimal": {
    "pacman": [
      ...
      {"package": "new-package"}
    ]
  }
}
```

### Remove Package

Simply delete the line from JSON.

### Change Category

Move package from `minimal` to `full` or vice versa.

### Verify JSON Validity

```bash
jq . packages/base.json > /dev/null && echo "Valid JSON" || echo "Invalid JSON"
```

---

## Usage Examples

### List All Packages from DE

```bash
jq -r '.minimal.pacman[].package, .full.pacman[].package' \
    packages/desktop-environments/kde.json
```

### Count Packages

```bash
# Minimal
jq '.minimal.pacman | length' packages/base.json

# Full
jq '.full.pacman | length' packages/base.json

# Total
jq '[.minimal.pacman[], .full.pacman[]] | length' packages/base.json
```

### Search for Package

```bash
# Which JSON contains firefox?
grep -r "firefox" packages/
```

### Validate All JSONs

```bash
for json in packages/**/*.json; do
    jq . "$json" > /dev/null && echo "✓ $json" || echo "✗ $json"
done
```

---

This system allows easy customization and maintenance of package lists without touching bash code!
