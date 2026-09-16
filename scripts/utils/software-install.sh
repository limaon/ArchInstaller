#!/usr/bin/env bash
#github-action genshdoc
#
# @file Software Install
# @brief Contains the functions to install software
# @stdout Output routed to install.log
# @stderror Output routed to install.log

# Source AUR helpers utilities
# shellcheck source=./aur-helpers.sh
source "$HOME"/archinstaller/scripts/utils/aur-helpers.sh

# @description Deploy window manager configuration using metadata.json
# @arg $1 Window manager name (i3 or awesome)
# @noargs
deploy_window_manager() {
    local wm_name="$1"
    local deployment_scope="${2:-user}"
    local wm_dir=~/archinstaller/configs/window-managers/"$wm_name"
    local metadata_file="$wm_dir/metadata.json"

    if [[ ! -f "$metadata_file" ]]; then
        echo "Error: Metadata file not found: $metadata_file"
        return 1
    fi

    echo "Deploying $wm_name window manager configuration..."

    local display_name=$(jq -r '.display_name' "$metadata_file")
    echo "Installing: $display_name"

    # Deploy config files
    if [[ "$deployment_scope" != "system" ]] && jq -e '.deployment.config' "$metadata_file" >/dev/null 2>&1; then
        local config_source="$wm_dir/$(jq -r '.deployment.config.source' "$metadata_file")"
        local config_target=$(jq -r '.deployment.config.target' "$metadata_file" | sed "s|~|$HOME|g")
        local config_perms=$(jq -r '.deployment.config.permissions' "$metadata_file")

        if [[ -d "$config_source" ]]; then
            echo "  Deploying config files to $config_target..."
            mkdir -p "$config_target"
            cp -r "$config_source"* "$config_target/" 2>/dev/null || true
            find "$config_target" -type d -exec chmod "$config_perms" {} \; 2>/dev/null || true
            echo "  [OK] Config files deployed"
        fi
    fi

    # Deploy scripts and system files from the root installer process.
    if [[ "$deployment_scope" != "user" ]] && jq -e '.deployment.scripts' "$metadata_file" >/dev/null 2>&1; then
        local scripts_source="$wm_dir/$(jq -r '.deployment.scripts.source' "$metadata_file")"
        local scripts_target=$(jq -r '.deployment.scripts.target' "$metadata_file")
        local scripts_perms=$(jq -r '.deployment.scripts.permissions' "$metadata_file")

        if [[ -d "$scripts_source" ]]; then
            echo "  Deploying scripts to $scripts_target..."
            mkdir -p "$scripts_target"
            cp "$scripts_source"* "$scripts_target/" 2>/dev/null || true
            chmod "$scripts_perms" "$scripts_target"/* 2>/dev/null || true
            echo "  [OK] Scripts deployed"
        fi
    fi

    if [[ "$deployment_scope" != "user" ]] && jq -e '.deployment.system' "$metadata_file" >/dev/null 2>&1; then
        local system_source="$wm_dir/$(jq -r '.deployment.system.source' "$metadata_file")"
        local system_target=$(jq -r '.deployment.system.target' "$metadata_file")

        if [[ -d "$system_source" ]]; then
            echo "  Deploying system files to $system_target..."
            cp -r "$system_source"* "$system_target/" 2>/dev/null || true
            # Set permissions for specific file types
            find "$system_target" -name "*.rules" -exec chmod 644 {} \; 2>/dev/null || true
            find "$system_target" -name "*.conf" -exec chmod 644 {} \; 2>/dev/null || true
            find "$system_target" -name "*.service" -exec chmod 644 {} \; 2>/dev/null || true
            find "$system_target" -name "*.timer" -exec chmod 644 {} \; 2>/dev/null || true
            echo "  [OK] System files deployed"
        fi
    fi

    # Deploy dotfiles
    if [[ "$deployment_scope" != "system" ]] && jq -e '.deployment.dotfiles' "$metadata_file" >/dev/null 2>&1; then
        local dotfiles_source="$wm_dir/$(jq -r '.deployment.dotfiles.source' "$metadata_file")"
        local dotfiles_target=$(jq -r '.deployment.dotfiles.target' "$metadata_file" | sed "s|~|$HOME|g")
        local dotfiles_perms=$(jq -r '.deployment.dotfiles.permissions' "$metadata_file")

        if [[ -d "$dotfiles_source" ]]; then
            echo "  Deploying dotfiles to $dotfiles_target..."
            cp "$dotfiles_source".* "$dotfiles_target/" 2>/dev/null || true
            for dotfile in "$dotfiles_source".*; do
                [[ -f "$dotfile" ]] || continue
                chmod "$dotfiles_perms" "$dotfiles_target/$(basename "$dotfile")" 2>/dev/null || true
            done
            echo "  [OK] Dotfiles deployed"
        fi
    fi

    if [[ "$deployment_scope" != "system" ]]; then
        apply_shared_components "$wm_name" "$metadata_file"
    fi

    echo "[OK] $display_name deployment complete"
    return 0
}

# @description Deploy window-manager files that require root permissions
# @arg $1 Window manager name
# @noargs
deploy_window_manager_system_files() {
    deploy_window_manager "$1" system
}

# @description Deploy desktop environment configuration using metadata.json
# @arg $1 Desktop environment name (gnome)
# @noargs
deploy_desktop_environment() {
    local de_name="$1"
    local de_dir=~/archinstaller/configs/desktop-environments/"$de_name"
    local metadata_file="$de_dir/metadata.json"

    if [[ ! -f "$metadata_file" ]]; then
        echo "Error: Metadata file not found: $metadata_file"
        return 1
    fi

    echo "Deploying $de_name desktop environment configuration..."

    local display_name=$(jq -r '.display_name' "$metadata_file")
    echo "Installing: $display_name"

    # Deploy scripts
    if jq -e '.deployment.scripts' "$metadata_file" >/dev/null 2>&1; then
        local scripts_source="$de_dir/$(jq -r '.deployment.scripts.source' "$metadata_file")"
        local scripts_target=$(jq -r '.deployment.scripts.target' "$metadata_file" | sed "s|~|$HOME|g")
        local scripts_perms=$(jq -r '.deployment.scripts.permissions' "$metadata_file")

        if [[ -d "$scripts_source" ]]; then
            echo "  Deploying scripts to $scripts_target..."
            mkdir -p "$scripts_target"
            if ! cp "$scripts_source"/* "$scripts_target/" 2>/dev/null; then
                echo "  [WARNING] Failed to copy some scripts" >&2
            fi
            if ! chmod "$scripts_perms" "$scripts_target"/* 2>/dev/null; then
                echo "  [WARNING] Failed to set permissions on some scripts" >&2
            fi
            echo "  [OK] Scripts deployed"
        fi
    fi

    # Deploy autostart files
    if jq -e '.deployment.autostart' "$metadata_file" >/dev/null 2>&1; then
        local autostart_source="$de_dir/$(jq -r '.deployment.autostart.source' "$metadata_file")"
        local autostart_target=$(jq -r '.deployment.autostart.target' "$metadata_file" | sed "s|~|$HOME|g")
        local autostart_perms=$(jq -r '.deployment.autostart.permissions' "$metadata_file")

        if [[ -d "$autostart_source" ]]; then
            echo "  Deploying autostart files to $autostart_target..."
            mkdir -p "$autostart_target"
            if ! cp "$autostart_source"/* "$autostart_target/" 2>/dev/null; then
                echo "  [WARNING] Failed to copy some autostart files" >&2
            fi
            if ! chmod "$autostart_perms" "$autostart_target"/* 2>/dev/null; then
                echo "  [WARNING] Failed to set permissions on some autostart files" >&2
            fi
            echo "  [OK] Autostart files deployed"
        fi
    fi

    # Deploy system files (requires root)
    if jq -e '.deployment.system' "$metadata_file" >/dev/null 2>&1; then
        local system_source="$de_dir/$(jq -r '.deployment.system.source' "$metadata_file")"
        local system_target=$(jq -r '.deployment.system.target' "$metadata_file")

        if [[ -d "$system_source" ]]; then
            echo "  Deploying system files to $system_target..."
            if ! sudo cp -r "$system_source"/* "$system_target/" 2>/dev/null; then
                echo "  [WARNING] Failed to copy some system files" >&2
            fi
            if ! sudo find "$system_target" -name "*.conf" -exec chmod 644 {} \; 2>/dev/null; then
                echo "  [WARNING] Failed to set permissions on some system files" >&2
            fi
            echo "  [OK] System files deployed"
        fi
    fi

    apply_shared_components "$de_name" "$metadata_file"

    echo "[OK] $display_name deployment complete"
    return 0
}

# @description Deploy shared components (themes, terminal, fonts, autostart)
# @arg $1 Window manager name
# @arg $2 Path to metadata.json
# @noargs
apply_shared_components() {
    local wm_name="$1"
    local metadata_file="$2"
    local shared_dir=~/archinstaller/configs/window-managers/shared

    # Get list of shared components from metadata
    local shared_components=$(jq -r '.shared_components[]' "$metadata_file" 2>/dev/null)

    if [[ -z "$shared_components" ]]; then
        return 0
    fi

    echo "  Deploying shared components..."

    for component in $shared_components; do
        case "$component" in
        "themes")
            # Deploy GTK/Qt/Kvantum themes
            if [[ -d "$shared_dir/themes" ]]; then
                echo "    - Deploying themes..."
                mkdir -p "$HOME/.config"

                # GTK themes
                [[ -d "$shared_dir/themes/gtk-3.0" ]] && cp -r "$shared_dir/themes/gtk-3.0" "$HOME/.config/" 2>/dev/null || true
                [[ -d "$shared_dir/themes/gtk-4.0" ]] && cp -r "$shared_dir/themes/gtk-4.0" "$HOME/.config/" 2>/dev/null || true

                # Qt themes
                [[ -d "$shared_dir/themes/qt5ct" ]] && cp -r "$shared_dir/themes/qt5ct" "$HOME/.config/" 2>/dev/null || true
                [[ -d "$shared_dir/themes/qt6ct" ]] && cp -r "$shared_dir/themes/qt6ct" "$HOME/.config/" 2>/dev/null || true

                # Kvantum themes
                [[ -d "$shared_dir/themes/Kvantum" ]] && cp -r "$shared_dir/themes/Kvantum" "$HOME/.config/" 2>/dev/null || true
            fi
            ;;
        "terminal")
            # Deploy terminal configs (kitty)
            if [[ -d "$shared_dir/terminal/kitty" ]]; then
                echo "    - Deploying terminal config..."
                mkdir -p "$HOME/.config"
                cp -r "$shared_dir/terminal/kitty" "$HOME/.config/" 2>/dev/null || true
            fi
            ;;
        "fonts")
            # Deploy font configs
            if [[ -d "$shared_dir/fonts/fontconfig" ]]; then
                echo "    - Deploying font config..."
                mkdir -p "$HOME/.config"
                cp -r "$shared_dir/fonts/fontconfig" "$HOME/.config/" 2>/dev/null || true
            fi
            ;;
        "autostart")
            # Deploy autostart applications
            if [[ -d "$shared_dir/autostart" ]]; then
                echo "    - Deploying autostart apps..."
                mkdir -p "$HOME/.config"

                # libfm config
                [[ -d "$shared_dir/autostart/libfm" ]] && cp -r "$shared_dir/autostart/libfm" "$HOME/.config/" 2>/dev/null || true

                # autostart desktop files
                [[ -d "$shared_dir/autostart/autostart" ]] && cp -r "$shared_dir/autostart/autostart" "$HOME/.config/" 2>/dev/null || true
            fi
            ;;
        esac
    done

    # Deploy shared dotfiles
    if [[ -d "$shared_dir/dotfiles" ]]; then
        echo "    - Deploying shared dotfiles..."
        cp "$shared_dir/dotfiles"/.* "$HOME/" 2>/dev/null || true
    fi

    echo "  [OK] Shared components deployed"
}

# @description Pacstrap arch linux to install location
# @noargs
arch_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Arch Install on Main Drive
-------------------------------------------------------------------------
"
    local base_packages=(base base-devel linux linux-firmware linux-lts jq neovim sudo wget libnewt)

    # Btrfs support is required before any chroot phase can build initramfs.
    if [[ "${FS:-}" == "btrfs" || "${FS:-}" == "luks" ]]; then
        base_packages+=(btrfs-progs)
    fi

    pacstrap /mnt "${base_packages[@]}" --noconfirm --needed --color=always
}

# @description Install bootloader prerequisites during Phase 0 (live ISO, before chroot)
# For UEFI: Installs efibootmgr via pacstrap (required for GRUB EFI installation)
# For Legacy BIOS: No additional packages needed at this stage
# Note: Actual GRUB installation happens in Phase 3 (3-post-setup.sh)
# @noargs
bootloader_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Bootloader Prerequisites Install
-------------------------------------------------------------------------
"
    if [[ -d "/sys/firmware/efi" ]]; then
        # UEFI system: Install efibootmgr (required for GRUB EFI)
        echo "UEFI system detected - Installing efibootmgr..."
        pacstrap /mnt efibootmgr --noconfirm --needed --color=always
    else
        # Legacy BIOS system: No additional packages needed at this stage
        # GRUB will be installed directly to MBR in Phase 3
        echo "Legacy BIOS system detected - No additional packages needed at this stage"
        echo "GRUB will be installed to MBR in post-setup phase"
    fi
}

# @description Installs network management software
# @noargs
network_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Network Setup
-------------------------------------------------------------------------
"
    pacman -S --noconfirm --needed --color=always \
        networkmanager \
        dhclient \
        networkmanager-openconnect \
        networkmanager-openvpn \
        networkmanager-vpnc \
        networkmanager-l2tp \
        networkmanager-pptp \
        networkmanager-strongswan \
        network-manager-sstp \
        network-manager-applet \
        bind-tools \
        traceroute \
        tcpdump \
        dialog \
        dnsmasq \
        wireless_tools \
        wpa_supplicant \
        iw \
        rfkill \
        openvpn \
        strongswan \
        openconnect \
        openssh

    systemctl enable NetworkManager
}

# @description Installs fonts for the system if the installation type is not SERVER
# @noargs
install_fonts() {
    echo -ne "
-------------------------------------------------------------------------
             Installing Fonts for the System
-------------------------------------------------------------------------
"

    # Skip for SERVER installations
    if [[ "$INSTALL_TYPE" == "SERVER" ]]; then
        echo "Skipping font installation (SERVER installation type detected)."
        return 0
    fi

    local fonts_json="$HOME/archinstaller/packages/optional/fonts.json"

    if [[ ! -f "$fonts_json" ]]; then
        echo "Error: Fonts list file not found at $fonts_json"
        return 1
    fi

    echo "Installing system fonts..."

    # Install pacman fonts
    install_packages_from_json "$fonts_json" ".pacman[].package" "pacman" || return 1

    # Install AUR fonts (if helper configured)
    if [[ "$AUR_HELPER" != NONE ]]; then
        install_packages_from_json "$fonts_json" ".aur[].package" "aur" || return 1
    fi

    return 0
}

# @description Installs base arch linux system
# @noargs
base_install() {
    echo -ne "
-------------------------------------------------------------------------
            Installing Base System for $INSTALL_TYPE
-------------------------------------------------------------------------
"
    if [[ "$INSTALL_TYPE" != "SERVER" ]]; then
        # Define JQ filters
        MINIMAL_PACMAN_FILTER=".minimal.pacman[].package"
        FULL_PACMAN_FILTER=$([[ "$INSTALL_TYPE" == "FULL" ]] && echo ", .full.pacman[].package")

        # Path to the package list JSON file
        PACKAGE_LIST_FILE="$HOME/archinstaller/packages/base.json"
        FONTS_LIST_FILE="$HOME/archinstaller/packages/optional/fonts.json"

        # Check if the package list file exists
        if [[ ! -f "$PACKAGE_LIST_FILE" ]]; then
            echo "Error: Package list file not found at $PACKAGE_LIST_FILE"
            return 1
        fi

        # Combine and parse filters, then install packages
        jq --raw-output "${MINIMAL_PACMAN_FILTER}${FULL_PACMAN_FILTER}" "$PACKAGE_LIST_FILE" | while read -r package; do
            if [[ -n "$package" ]]; then
                echo "Installing $package..."
                if ! pacman -S "$package" --noconfirm --needed --color=always; then
                    echo "Error: Failed to install $package"
                fi
            fi
        done
    fi
}

# @description Installs cpu microcode depending on detected cpu
# @noargs
microcode_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing Microcode
-------------------------------------------------------------------------
"
    # determine processor type and install microcode
    proc_type=$(lscpu)
    if grep -E "GenuineIntel" <<<"${proc_type}"; then
        echo "Installing Intel microcode"
        pacman -S --noconfirm --needed --color=always intel-ucode
    elif grep -E "AuthenticAMD" <<<"${proc_type}"; then
        echo "Installing AMD microcode"
        pacman -S --noconfirm --needed --color=always amd-ucode
    fi
}

# @description Detect GPU type from lspci
# @noargs
# @stdout GPU type: nvidia, amd, intel, unknown
detect_gpu() {
    local gpu_info=$(lspci | grep -iE "VGA|3D|Display" 2>/dev/null)

    if echo "$gpu_info" | grep -iE "NVIDIA|GeForce" &>/dev/null; then
        echo "nvidia"
    elif echo "$gpu_info" | grep -iE 'Radeon|AMD|(^|[^[:alnum:]])ATI([^[:alnum:]]|$)' &>/dev/null; then
        echo "amd"
    elif echo "$gpu_info" | grep -iE "Intel.*Graphics|Integrated Graphics Controller" &>/dev/null; then
        echo "intel"
    else
        echo "unknown"
    fi
}

# @description Detect hybrid graphics with Intel integrated graphics
# @noargs
# @return 0 if hybrid detected, 1 otherwise
detect_hybrid_graphics() {
    local gpu_info=$(lspci | grep -iE "VGA|3D|Display" 2>/dev/null)

    if echo "$gpu_info" | grep -iE "NVIDIA|GeForce|Radeon|AMD|ATI" &>/dev/null &&
        echo "$gpu_info" | grep -iE "Intel.*Graphics|Integrated Graphics Controller" &>/dev/null; then
        return 0
    fi

    return 1
}

# @description Identify NVIDIA GPU family using Nouveau chipset names
# @noargs
# @stdout NVIDIA family (tesla, fermi, kepler, maxwell, pascal, volta, turing, ampere, ada, blackwell, unknown)
nvidia_get_family() {
    local chipset
    local nvidia_model

    chipset=$(dmesg 2>/dev/null | grep -iEo '(NV|NC)[0-9A-F]+' | head -1)
    chipset=${chipset^^}
    case "$chipset" in
    NV5* | NV8* | NV9* | NVA*) echo "tesla" ;;
    NC*) echo "fermi" ;;
    NVE* | NVF*) echo "kepler" ;;
    NV11* | NV12*) echo "maxwell" ;;
    NV13*) echo "pascal" ;;
    NV14*) echo "volta" ;;
    NV16*) echo "turing" ;;
    NV17*) echo "ampere" ;;
    NV18*) echo "ada" ;;
    NV19*) echo "blackwell" ;;
    *)
        nvidia_model=$(lspci | grep -iE "NVIDIA|GeForce" | head -1)
        case "$nvidia_model" in
        *RTX\ 50*) echo "blackwell" ;;
        *RTX\ 30*) echo "ampere" ;;
        *RTX\ 40*) echo "ada" ;;
        *RTX\ 20*|*GTX\ 16*) echo "turing" ;;
        *GTX\ 10*) echo "pascal" ;;
        *GTX\ 9*|*GTX\ 75*) echo "maxwell" ;;
        *) echo "unknown" ;;
        esac
        ;;
    esac
}

# @description Check if NVIDIA GPU supports open-dkms (Turing+)
# @noargs
# @return 0 if supported, 1 otherwise
nvidia_supports_open_dkms() {
    local nvidia_family
    nvidia_family=$(nvidia_get_family)

    # Nouveau families: NV160 (Turing) and newer support NVIDIA's open module.
    if [[ "$nvidia_family" == "turing" || "$nvidia_family" == "ampere" ||
        "$nvidia_family" == "ada" || "$nvidia_family" == "blackwell" ]]; then
        return 0
    fi

    return 1
}

# @description Select the NVIDIA open module package for the configured kernel set
# @noargs
# @stdout Driver variant (open, open-lts or open-dkms)
nvidia_get_open_variant() {
    case "${NVIDIA_KERNEL_VARIANT:-both}" in
    linux) echo "open" ;;
    lts) echo "open-lts" ;;
    *) echo "open-dkms" ;;
    esac
}

# @description Get the default NVIDIA driver variant for the detected family
# @noargs
# @stdout Driver variant for the detected NVIDIA family
get_nvidia_driver_variant() {
    local nvidia_family
    nvidia_family=$(nvidia_get_family)

    case "$nvidia_family" in
    turing | ampere | ada | blackwell) nvidia_get_open_variant ;;
    volta | pascal | maxwell) echo "legacy-580xx" ;;
    kepler) echo "legacy-470xx" ;;
    fermi) echo "legacy-390xx" ;;
    tesla) echo "legacy-340xx" ;;
    *) echo "nouveau" ;;
    esac
}

# @description Validate the GPU driver package schema before selecting packages
# @arg $1 GPU driver JSON file
validate_gpu_driver_config() {
    local json_file="${1:-$HOME/archinstaller/packages/gpu-drivers.json}"

    jq -e '
        (.vm.pacman | type == "array") and
        (.amd.pacman | type == "array") and
        (.intel.pacman | type == "array") and
        (.nvidia["legacy-580xx"].pacman | type == "array") and
        (.nvidia["legacy-580xx"].aur | type == "array") and
        (.nvidia["legacy-470xx"].pacman | type == "array") and
        (.nvidia["legacy-470xx"].aur | type == "array") and
        (.nvidia["legacy-390xx"].pacman | type == "array") and
        (.nvidia["legacy-390xx"].aur | type == "array") and
        (.nvidia["legacy-340xx"].pacman | type == "array") and
        (.nvidia["legacy-340xx"].aur | type == "array") and
        (.nvidia.open.pacman | type == "array") and
        (.nvidia["open-lts"].pacman | type == "array") and
        (.nvidia["open-dkms"].pacman | type == "array") and
        (.nvidia.nouveau.pacman | type == "array") and
        (.hybrid["amd-intel"].pacman | type == "array") and
        (.hybrid["nvidia-intel"]["legacy-580xx"].pacman | type == "array") and
        (.hybrid["nvidia-intel"]["legacy-580xx"].aur | type == "array") and
        (.hybrid["nvidia-intel"]["legacy-470xx"].pacman | type == "array") and
        (.hybrid["nvidia-intel"]["legacy-470xx"].aur | type == "array") and
        (.hybrid["nvidia-intel"]["legacy-390xx"].pacman | type == "array") and
        (.hybrid["nvidia-intel"]["legacy-390xx"].aur | type == "array") and
        (.hybrid["nvidia-intel"]["legacy-340xx"].pacman | type == "array") and
        (.hybrid["nvidia-intel"]["legacy-340xx"].aur | type == "array") and
        (.hybrid["nvidia-intel"].open.pacman | type == "array") and
        (.hybrid["nvidia-intel"]["open-lts"].pacman | type == "array") and
        (.hybrid["nvidia-intel"]["open-dkms"].pacman | type == "array") and
        (.hybrid["nvidia-intel"].nouveau.pacman | type == "array")
    ' "$json_file" >/dev/null 2>&1
}

# @description Get NVIDIA driver choice from user
# @noargs
# @stdout Driver type: proprietary, open-dkms, legacy-580xx, nouveau
get_nvidia_driver_choice() {
    local supports_open=false
    local default_variant
    local proprietary_variant
    local open_variant
    local -a options
    nvidia_supports_open_dkms && supports_open=true
    default_variant=$(get_nvidia_driver_variant)
    open_variant=$(nvidia_get_open_variant)
    proprietary_variant="$default_variant"
    if [[ "$supports_open" == true ]]; then
        proprietary_variant="legacy-580xx"
    fi

    echo -e "\nDetected video card(s):" >&2
    while IFS= read -r gpu_model; do
        [[ -n "$gpu_model" ]] && echo "  - $gpu_model" >&2
    done < <(get_detected_gpu_models || true)

    local nvidia_family
    nvidia_family=$(nvidia_get_family)
    echo -e "\nNVIDIA GPU detected ($nvidia_family family). Select driver type:\n" >&2

    if [[ "$supports_open" == true ]]; then
        options=(
            "Proprietary (nvidia-580xx-dkms, AUR) - Best compatibility"
            "Open-source Kernel (nvidia-$open_variant) - Open kernel module, good performance"
            "Open-source (nouveau) - Free software, limited performance"
        )
    elif [[ "$proprietary_variant" != "nouveau" ]]; then
        options=(
            "Proprietary ($proprietary_variant, AUR) - Best compatibility"
            "Open-source (nouveau) - Free software, limited performance"
        )
    else
        options=(
            "Open-source (nouveau) - Free software, limited performance"
        )
    fi

    select_option ${#options[@]} 1 "${options[@]}" >&2
    local choice=$?

    if [[ "$supports_open" == true ]]; then
        case $choice in
        0) echo "$proprietary_variant" ;;
        1) echo "$open_variant" ;;
        2) echo "nouveau" ;;
        *) echo "$proprietary_variant" ;;
        esac
    elif [[ "$proprietary_variant" != "nouveau" ]]; then
        case $choice in
        0) echo "$proprietary_variant" ;;
        1) echo "nouveau" ;;
        *) echo "$proprietary_variant" ;;
        esac
    else
        case $choice in
        0) echo "nouveau" ;;
        *) echo "nouveau" ;;
        esac
    fi
}

# @description Detect GPU hardware and save the initial driver configuration
# @noargs
configure_gpu_selection() {
    local detected_gpu
    detected_gpu=$(detect_gpu)

    if detect_vm >/dev/null; then
        set_option GPU_TYPE "vm"
        set_option GPU_DRIVER "vm"
        return 0
    fi

    if [[ "$detected_gpu" == "nvidia" || "$detected_gpu" == "amd" ]] && detect_hybrid_graphics; then
        set_option GPU_TYPE "hybrid"
        set_option GPU_DRIVER "$detected_gpu"
        set_option GPU_SECONDARY_VENDOR "intel"
        if [[ "$detected_gpu" == "nvidia" ]]; then
            set_option NVIDIA_DRIVER_TYPE "$(get_nvidia_driver_choice)"
        fi
        return 0
    fi

    set_option GPU_TYPE "$detected_gpu"
    set_option GPU_DRIVER "$detected_gpu"

    if [[ "$detected_gpu" == "nvidia" ]]; then
        set_option NVIDIA_DRIVER_TYPE "$(get_nvidia_driver_choice)"
    fi
}

# @description Install package intelligently (check if installed, verify exists)
# @arg $1 Package name
install_package_intelligent() {
    local package="$1"

    if pacman -Qi "$package" &>/dev/null; then
        echo "Package $package is already installed, skipping."
        return 0
    fi

    if pacman -Si "$package" &>/dev/null; then
        echo "Installing $package from official repository..."
        if ! pacman -S "$package" --noconfirm --needed --color=always; then
            echo "Error: Failed to install $package via pacman"
            return 1
        fi
        return 0
    else
        if [[ "$AUR_HELPER" == NONE ]]; then
            echo "Warning: Package $package not found in repositories and no AUR helper is configured"
            return 1
        fi

        echo "Installing $package from AUR via $AUR_HELPER..."
        if "$AUR_HELPER" -S "$package" --noconfirm --needed --color=always; then
            echo "[OK] $package installed successfully from AUR"
            return 0
        fi

        echo "Error: Failed to install $package via $AUR_HELPER"
        return 1
    fi
}

# @description Install a package from official repo or AUR with intelligent fallback
# @arg $1 Package name
# @arg $2 Source (pacman|aur|auto) - default: auto
# @return 0 on success, 1 on failure
install_package() {
    local package="$1"
    local source="${2:-auto}"

    if [[ -z "$package" ]]; then
        echo "Error: Package name cannot be empty"
        return 1
    fi

    if pacman -Qi "$package" &>/dev/null; then
        echo "Package $package is already installed, skipping."
        return 0
    fi

    case "$source" in
    pacman)
        if pacman -Si "$package" &>/dev/null; then
            echo "Installing $package from official repository..."
            if sudo pacman -S "$package" --noconfirm --needed --color=always; then
                echo "[OK] $package installed successfully"
                return 0
            else
                echo "Error: Failed to install $package via pacman"
                return 1
            fi
        else
            echo "Error: Package $package not found in official repositories"
            return 1
        fi
        ;;
    aur)
        if [[ "$AUR_HELPER" == NONE ]]; then
            echo "Error: AUR helper not configured, cannot install $package from AUR"
            return 1
        fi

        echo "Installing $package from AUR via $AUR_HELPER..."
        if "$AUR_HELPER" -S "$package" --noconfirm --needed --color=always; then
            echo "[OK] $package installed successfully from AUR"
            return 0
        else
            echo "Error: Failed to install $package via $AUR_HELPER"
            return 1
        fi
        ;;
    auto)
        if pacman -Si "$package" &>/dev/null; then
            echo "Installing $package from official repository..."
            if sudo pacman -S "$package" --noconfirm --needed --color=always; then
                echo "[OK] $package installed successfully"
                return 0
            else
                echo "Error: Failed to install $package via pacman"
                return 1
            fi
        elif [[ "$AUR_HELPER" != NONE ]]; then
            echo "Installing $package from AUR via $AUR_HELPER..."
            if "$AUR_HELPER" -S "$package" --noconfirm --needed --color=always; then
                echo "[OK] $package installed successfully from AUR"
                return 0
            else
                echo "Error: Failed to install $package via $AUR_HELPER"
                return 1
            fi
        else
            echo "Error: Package $package not found in official repositories and no AUR helper configured"
            return 1
        fi
        ;;
    *)
        echo "Error: Invalid source '$source'. Use 'pacman', 'aur', or 'auto'"
        return 1
        ;;
    esac
}

# @description Install packages from JSON file using JQ filter
# @arg $1 JSON file path
# @arg $2 JQ filter (e.g., ".minimal.pacman[].package")
# @arg $3 Source (pacman|aur|auto) - default: auto
# @return 0 on success, 1 if any package failed
install_packages_from_json() {
    local json_file="$1"
    local jq_filter="$2"
    local source="${3:-auto}"

    if [[ -z "$json_file" ]]; then
        echo "Error: JSON file path cannot be empty"
        return 1
    fi

    if [[ ! -f "$json_file" ]]; then
        echo "Error: JSON file not found at $json_file"
        return 1
    fi

    if [[ -z "$jq_filter" ]]; then
        echo "Error: JQ filter cannot be empty"
        return 1
    fi

    if ! jq empty "$json_file" 2>/dev/null; then
        echo "Error: Invalid JSON in $json_file"
        return 1
    fi

    echo "Installing packages from $json_file (filter: $jq_filter)"

    local packages
    if ! packages=$(jq --raw-output "$jq_filter" "$json_file"); then
        echo "Error: Failed to extract packages from $json_file"
        return 1
    fi

    local failed=0
    local count=0

    while read -r package; do
        # Skip empty lines
        if [[ -z "$package" ]]; then
            continue
        fi

        ((count += 1))

        # Install package
        if ! install_package "$package" "$source"; then
            ((failed += 1))
        fi
    done <<<"$packages"

    if [[ $failed -gt 0 ]]; then
        echo "Warning: $failed package(s) failed to install"
        return 1
    fi

    echo "[OK] All packages installed successfully"
    return 0
}

# @description Install GPU drivers from JSON file
# @arg $1 GPU type (vm, nvidia, amd, intel, hybrid, fallback)
# @arg $2 Driver variant (open, open-lts, open-dkms, legacy-* or nouveau) or "" for simple types
# @arg $3 NVIDIA driver type (if hybrid, e.g., open-dkms or legacy-580xx)
install_gpu_from_json() {
    local gpu_type="$1"
    local driver_variant="${2:-}"
    local nvidia_type="${3:-}"

    local json_file="$HOME/archinstaller/packages/gpu-drivers.json"

    if [[ ! -f "$json_file" ]]; then
        echo "Error: GPU drivers JSON file not found at $json_file"
        return 1
    fi

    if ! validate_gpu_driver_config "$json_file"; then
        echo "Error: Invalid GPU driver package configuration: $json_file"
        return 1
    fi

    if [[ "$gpu_type" == "nvidia" ]]; then
        case "$driver_variant" in
        open | open-lts | open-dkms | legacy-340xx | legacy-390xx | legacy-470xx | legacy-580xx | nouveau) ;;
        *)
            echo "Error: Invalid NVIDIA driver variant: $driver_variant"
            return 1
            ;;
        esac
    elif [[ "$gpu_type" == "hybrid" && "$driver_variant" == "nvidia-intel" ]]; then
        case "$nvidia_type" in
            open | open-lts | open-dkms | legacy-340xx | legacy-390xx | legacy-470xx | legacy-580xx | nouveau) ;;
        *)
            echo "Error: Invalid NVIDIA hybrid driver variant: $nvidia_type"
            return 1
            ;;
        esac
    fi

    local profile_path
    if [[ "$gpu_type" == "hybrid" ]]; then
        if [[ "$driver_variant" != "nvidia-intel" ]]; then
            profile_path=".hybrid[\"${driver_variant}\"]"
        else
            if [[ -z "$nvidia_type" ]]; then
                echo "Error: NVIDIA driver variant is required for nvidia-intel hybrid graphics"
                return 1
            fi
            profile_path=".hybrid[\"nvidia-intel\"][\"${nvidia_type}\"]"
        fi
    elif [[ "$gpu_type" == "nvidia" ]]; then
        profile_path=".nvidia[\"${driver_variant}\"]"
    else
        profile_path=".${gpu_type}"
    fi

    local pacman_packages=()
    local aur_packages=()
    while IFS= read -r package; do
        [[ -n "$package" ]] && pacman_packages+=("$package")
    done < <(jq --raw-output "${profile_path}.pacman[]?.package" "$json_file" 2>/dev/null)
    while IFS= read -r package; do
        [[ -n "$package" ]] && aur_packages+=("$package")
    done < <(jq --raw-output "${profile_path}.aur[]?.package" "$json_file" 2>/dev/null)

    if [[ ${#pacman_packages[@]} -eq 0 && ${#aur_packages[@]} -eq 0 ]]; then
        echo "Error: No packages found for GPU type: $gpu_type"
        return 1
    fi

    echo "Installing $((${#pacman_packages[@]} + ${#aur_packages[@]})) packages for $gpu_type..."

    local failed=0
    for package in "${pacman_packages[@]}"; do
        if ! install_package "$package" "pacman"; then
            ((failed++))
        fi
    done
    for package in "${aur_packages[@]}"; do
        if ! install_package "$package" "aur"; then
            ((failed++))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        echo "Warning: $failed package(s) failed to install"
    fi

    # Save configuration
    set_option GPU_TYPE "$gpu_type"
    set_option NVIDIA_KERNEL_VARIANT "${NVIDIA_KERNEL_VARIANT:-both}"
    if [[ "$gpu_type" == "hybrid" && -n "$nvidia_type" ]]; then
        set_option NVIDIA_DRIVER_TYPE "$nvidia_type"
    elif [[ -n "$driver_variant" ]]; then
        set_option NVIDIA_DRIVER_TYPE "$driver_variant"
    fi

    echo "[OK] GPU drivers installed successfully"
    return 0
}

# @description Installs graphics drivers depending on detected gpu
# @noargs
graphics_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing Graphics Drivers
-------------------------------------------------------------------------
"

    # 1. Check if running in virtual machine
    if detect_vm >/dev/null; then
        echo "Virtual machine detected - installing VM graphics drivers"
        install_gpu_from_json "vm" ""
        return $?
    fi

    # 2. Detect GPU type
    local detected_gpu=$(detect_gpu)
    echo "Detected GPU type: $detected_gpu"

    # 3. Handle NVIDIA and AMD hybrid graphics using initial configuration
    if [[ "$detected_gpu" == "nvidia" || "$detected_gpu" == "amd" ]]; then
        local hybrid_profile="${GPU_DRIVER:-$detected_gpu}-${GPU_SECONDARY_VENDOR:-intel}"
        local nvidia_driver_type="${NVIDIA_DRIVER_TYPE:-}"
        if [[ "$detected_gpu" == "nvidia" && -z "$nvidia_driver_type" ]]; then
            nvidia_driver_type=$(get_nvidia_driver_choice)
        fi

        # Check for hybrid graphics
        if detect_hybrid_graphics; then
            echo "Hybrid graphics detected ($detected_gpu + Intel)"
            install_gpu_from_json "hybrid" "$hybrid_profile" "$nvidia_driver_type"
        else
            install_gpu_from_json "$detected_gpu" "$nvidia_driver_type"
        fi
        return $?
    fi

    # 4. Handle AMD/Intel (automatic)
    case "$detected_gpu" in
    amd)
        echo "AMD GPU detected - installing AMD drivers"
        install_gpu_from_json "amd" ""
        ;;
    intel)
        echo "Intel GPU detected - installing Intel drivers"
        install_gpu_from_json "intel" ""
        ;;
    *)
        echo "No GPU detected - skipping graphics driver installation"
        return 0
        ;;
    esac
}

# @description Installs software from the AUR
# @noargs
aur_helper_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing AUR Software
-------------------------------------------------------------------------
"
    if [[ "$AUR_HELPER" == NONE ]]; then
        echo "No AUR helper selected; skipping AUR software"
        return 0
    fi

    echo "Selected AUR Helper: $AUR_HELPER"
    install_aur_helper "$AUR_HELPER" || return 1

    local aur_filter=".minimal.aur[].package"
    if [[ "$INSTALL_TYPE" == "FULL" ]]; then
        aur_filter="${aur_filter}, .full.aur[].package"
    fi

    install_packages_from_json "$HOME/archinstaller/packages/base.json" "$aur_filter" aur || return 1
    return 0
}

# @description Installs desktop environment packages from base repositories
# @noargs
desktop_environment_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing Desktop Environment Software
-------------------------------------------------------------------------
"

    local de_json=~/archinstaller/packages/desktop-environments/"${DESKTOP_ENV}".json

    if [[ ! -f "$de_json" ]]; then
        echo "Error: Desktop environment configuration not found at $de_json"
        return 1
    fi

    echo "Installing packages for $DESKTOP_ENV..."

    # Build JQ filter based on installation type
    local pacman_filter=".minimal.pacman[].package"
    local aur_filter=".minimal.aur[].package"

    if [[ "$INSTALL_TYPE" == "FULL" ]]; then
        pacman_filter="${pacman_filter}, .full.pacman[].package"
        aur_filter="${aur_filter}, .full.aur[].package"
    fi

    # Install pacman packages
    install_packages_from_json "$de_json" "$pacman_filter" "pacman" || return 1

    # Install AUR packages (if helper configured)
    if [[ "$AUR_HELPER" != NONE ]]; then
        install_packages_from_json "$de_json" "$aur_filter" "aur" || return 1
    fi

    return 0
}

# @description Installs btrfs and snapper packages for Btrfs or LUKS filesystems
# @noargs
btrfs_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing Btrfs and Snapper Packages
-------------------------------------------------------------------------
"

    # Only install if using btrfs or LUKS
    if [[ "$FS" != "btrfs" && "$FS" != "luks" ]]; then
        echo "Filesystem is $FS, skipping btrfs/snapper installation"
        return 0
    fi

    echo "Installing btrfs and snapper packages..."

    # Install pacman packages
    install_packages_from_json ~/archinstaller/packages/btrfs.json ".pacman[].package" "pacman" || return 1

    # Install AUR packages (if helper configured)
    if [[ "$AUR_HELPER" != NONE ]]; then
        install_packages_from_json ~/archinstaller/packages/btrfs.json ".aur[].package" "aur" || return 1
    fi

    return 0
}

# @description Run desktop theming as the installer user
# @noargs
run_user_theming() {
    local user_home="/home/$USERNAME"

    if [[ ! -d "$user_home" ]]; then
        echo "Error: Home directory not found for $USERNAME"
        return 1
    fi

    local system_window_manager=""
    case "$DESKTOP_ENV" in
    awesome) system_window_manager="awesome" ;;
    i3-wm) system_window_manager="i3" ;;
    esac

    if [[ -n "$system_window_manager" ]]; then
        if ! deploy_window_manager_system_files "$system_window_manager"; then
            return 1
        fi
    fi

    runuser -u "$USERNAME" -- env HOME="$user_home" bash -c '
        for filename in "$HOME"/archinstaller/scripts/utils/*.sh; do
            [ -e "$filename" ] || continue
            source "$filename"
        done
        source "$HOME"/archinstaller/configs/setup.conf
        user_theming
    '
}

# @description Perform desktop environment specific theming
# @noargs
user_theming() {
    echo -ne "
-------------------------------------------------------------------------
            Theming Desktop Environment ($INSTALL_TYPE)
-------------------------------------------------------------------------
"
    if [[ ! "$INSTALL_TYPE" == SERVER ]]; then
        if [[ "$DESKTOP_ENV" == "kde" ]]; then
            cp -r ~/archinstaller/configs/kde/home/. ~/
            pip install konsave
            konsave -i ~/archinstaller/configs/kde/kde.knsv
            sleep 1
            konsave -a kde

        elif [[ "$DESKTOP_ENV" == "openbox" ]]; then
            git clone https://github.com/stojshic/dotfiles-openbox ~/dotfiles-openbox
            ./dotfiles-openbox/install-titus.sh

        elif [[ "$DESKTOP_ENV" == "awesome" ]]; then
            deploy_window_manager "awesome"

            sudo chmod 755 /etc/xdg/awesome 2>/dev/null || true
            sudo chmod 644 /etc/xdg/awesome/rc.lua 2>/dev/null || true

        elif [[ "$DESKTOP_ENV" == "i3-wm" ]]; then
            deploy_window_manager "i3"

            # Configure i3 wallpaper/background with solid color for all installation types
            I3_CONFIG_FILE="$HOME/.config/i3/config"
            if [[ -f "$I3_CONFIG_FILE" ]]; then
                echo "Configuring i3 background with solid color #073642..."

                # Use xsetroot for solid color (part of xorg-apps, usually installed)
                # xsetroot sets the root window color, which serves as background
                if grep -q "xwallpaper\|xsetroot" "$I3_CONFIG_FILE"; then
                    sed -i 's|^exec --no-startup-id xwallpaper.*|exec --no-startup-id xsetroot -solid '"'"'#073642'"'"'|' "$I3_CONFIG_FILE"
                    sed -i 's|^exec --no-startup-id xsetroot.*|exec --no-startup-id xsetroot -solid '"'"'#073642'"'"'|' "$I3_CONFIG_FILE"
                else
                    sed -i '/^# Load Wallpaper/a exec --no-startup-id xsetroot -solid '"'"'#073642'"'"'' "$I3_CONFIG_FILE"
                fi
            fi
        elif [[ "$DESKTOP_ENV" == "gnome" ]]; then
            deploy_desktop_environment "gnome"

            echo "GNOME extensions and settings will be applied on first login"

        else
            echo -e "No theming setup for $DESKTOP_ENV"
        fi
    else
        echo -e "Skipping theming setup for SERVER installation."
    fi
}

# @description Enable essential services
# @noargs
essential_services() {
    echo -ne "
-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------
"
    # services part of the base installation
    echo "Enabling NetworkManager"
    systemctl enable NetworkManager.service
    echo -e "NetworkManager enabled \n"

    echo "Enabling Periodic Trim"
    systemctl enable fstrim.timer
    echo -e "Periodic Trim enabled \n"

    echo "Configuring TLP for battery management"
    configure_tlp
    echo -e "TLP configuration complete \n"

    if [[ ${INSTALL_TYPE} == "FULL" ]]; then

        echo -ne "
-------------------------------------------------------------------------
                    Configuring UFW Firewall
-------------------------------------------------------------------------
"
        echo "Disabling IPv6 in UFW configuration"
        if grep -q '^IPV6=' /etc/ufw/ufw.conf; then
            sed -i 's/^IPV6=.*/IPV6=no/' /etc/ufw/ufw.conf
        else
            echo 'IPV6=no' >>/etc/ufw/ufw.conf
        fi

        echo "Enabling UFW"
        systemctl enable ufw.service

        echo "Setting UFW rules for home user"

        ufw default allow outgoing
        ufw default deny incoming

        # Allow inbound connections for essential services
        ufw allow in 22/tcp  # SSH
        ufw allow in 80/tcp  # HTTP
        ufw allow in 443/tcp # HTTPS

        # Allow local sharing (home network)
        ufw allow in 5353/udp # mDNS (Avahi)

        echo "Enabling UFW"
        ufw --force enable
        echo -e "UFW configured and enabled \n"

        echo "NTP synchronization deferred until first boot"
        echo "Enabling ntpd"
        systemctl enable ntpd.service
        echo -e "NTP enabled \n"

        echo "Enabling Bluetooth"
        systemctl enable bluetooth
        echo -e "Bluetooth enabled \n"

        echo "Enabling Avahi"
        systemctl enable avahi-daemon.service
        echo -e "Avahi enabled \n"

        echo "Enabling cpupower"
        systemctl enable cpupower.service
        echo -e "cpupower enabled \n"

        plymouth_config

    fi

    # Configure snapshots for all installations with Btrfs/LUKS
    # Snapshots are important for recovery on FULL and MINIMAL installations
    # Note: snapper_config() already enables the timers internally
    if [[ "${FS}" == "luks" || "${FS}" == "btrfs" ]]; then
        snapper_config
    fi
}

# @description Install battery notifications for i3-wm
# @noargs
i3wm_battery_notifications() {
    # Only install for i3-wm desktop environment
    if [[ "${DESKTOP_ENV:-}" != "i3-wm" ]]; then
        return 0
    fi

    echo -ne "
-------------------------------------------------------------------------
                    Installing Battery Notifications for i3-wm
-------------------------------------------------------------------------
"

    # Battery data is read directly from sysfs; only libnotify is needed to notify.
    if ! pacman -Qi libnotify &>/dev/null; then
        echo "Warning: libnotify not found, battery notifications may not work"
    fi

    # Scripts and system files are already deployed by deploy_window_manager()
    # Just need to configure systemd user units for current user

    if [[ -n "${USERNAME:-}" ]] && [[ -d "$HOME" ]]; then
        echo "Configuring battery notifications for current user..."

        mkdir -p "$HOME/.config/systemd/user/"
        if [[ -d /etc/systemd/user ]]; then
            cp /etc/systemd/user/battery-alert.* "$HOME/.config/systemd/user/" 2>/dev/null || true
        fi

        # Enable timer for current user
        echo "Enabling battery notification timer for current user..."
        if systemctl --user enable battery-alert.timer 2>/dev/null; then
            echo "Battery alert timer enabled for current user"
        else
            echo "Creating timer symlinks manually..."
            mkdir -p "$HOME/.config/systemd/user/timers.target.wants/"
            ln -sf "$HOME/.config/systemd/user/battery-alert.timer" \
                "$HOME/.config/systemd/user/timers.target.wants/battery-alert.timer" 2>/dev/null || true
            echo "Timer symlink created"
        fi

        # Reload systemd user daemon if running
        if systemctl --user daemon-reload 2>/dev/null; then
            echo "Systemd user daemon reloaded"

            if systemctl --user start battery-alert.timer 2>/dev/null; then
                echo "Battery alert timer started"
            else
                echo "Note: Timer will start automatically after first login"
            fi

        else
            echo "Note: Systemd user daemon not running - timer will be active after first login"
        fi
    fi

    echo "Battery notifications configuration complete!"
}

# @description Configure power management for i3-wm using systemd-logind
# Minimal approach without external scripts
# @noargs
i3wm_auto_suspend_hibernate() {
    # Only install for i3-wm desktop environment
    if [[ "${DESKTOP_ENV:-}" != "i3-wm" ]]; then
        return 0
    fi

    echo -ne "
--------------------------------------------------------------------------
                  Configuring Power Management for i3-wm
--------------------------------------------------------------------------

"

    # Create systemd logind configuration
    echo "Configuring systemd logind for power management..."
    sudo mkdir -p /etc/systemd/logind.conf.d/

    sudo tee /etc/systemd/logind.conf.d/50-power.conf >/dev/null <<'EOF'
HandleLidSwitch=suspend
HandleLidSwitchDocked=hibernate
HandleLidSwitchExternalPower=suspend

IdleAction=suspend
IdleActionSec=1800s  # 30 minutes

InhibitDelayMax=30s

# Suspend when battery is low
HandlePowerKey=suspend
HandleSleepKey=suspend
EOF

    sudo chmod 644 /etc/systemd/logind.conf.d/50-power.conf

    # Restart logind to apply changes
    sudo systemctl restart systemd-logind
    echo "[OK] Power management configured"

    # Check swap and hibernation capability
    echo ""
    echo "Checking swap configuration..."
    SWAP_SIZE=$(free -k | awk '/^Swap:/ {print $2}')
    RAM_SIZE=$(free -k | awk '/^Mem:/ {print $2}')

    if [[ $SWAP_SIZE -gt 0 && $SWAP_SIZE -ge $RAM_SIZE ]]; then
        echo "[OK] Swap sufficient for hibernation ($((SWAP_SIZE / 1024 / 1024))GB >= $((RAM_SIZE / 1024 / 1024))GB)"
    else
        echo "[!] Warning: Insufficient swap for hibernation"
        echo "  Current swap: $((SWAP_SIZE / 1024 / 1024))GB, Required: $((RAM_SIZE / 1024 / 1024))GB"
        echo "  System will suspend instead of hibernating on battery"
        echo "  To enable hibernation: sudo systemctl edit systemd-logind and set:"
        echo "    HandleLidSwitch=hibernate"
        echo "    HandleLidSwitchDocked=hibernate"
    fi

    echo ""
    echo "[OK] Power management configuration complete!"
    echo ""
    echo "Available commands:"
    echo "  - systemctl suspend          - Force immediate suspend"
    echo "  - systemctl hibernate        - Force immediate hibernate"
    echo "  - systemd-inhibit -who='Working' -what='sleep' -why='Working' sleep 3600  - Prevent sleep"
    echo "  - acpi -b                    - Check battery status"
    echo ""
    echo "System will automatically suspend after 30 minutes of inactivity"
    echo "Press $mod+Control+Delete to suspend, $mod+Control+BackSpace to hibernate"
}
