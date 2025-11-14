#!/usr/bin/env bash
#github-action genshdoc
#
# @file Software Install
# @brief Contains the functions to install software
# @stdout Output routed to install.log
# @stderror Output routed to install.log


# @description Pacstrap arch linux to install location
# @noargs
arch_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Arch Install on Main Drive
-------------------------------------------------------------------------
"
    pacstrap /mnt base base-devel linux linux-firmware linux-lts jq neovim sudo wget libnewt --noconfirm --needed --color=always
}


# @description Install bootloader
# @noargs
bootloader_install() {
    echo -ne "
-------------------------------------------------------------------------
                    GRUB BIOS Bootloader Install & Check
-------------------------------------------------------------------------
"
    if [[ ! -d "/sys/firmware/efi" ]]; then
        grub-install --target=x86_64-efi --efi-directory=/boot "${DISK}" --bootloader-id='Arch Linux'
    else
        pacstrap /mnt efibootmgr --noconfirm --needed --color=always
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

    # Check if installation type is SERVER
    if [[ "$INSTALL_TYPE" == "SERVER" ]]; then
        echo "Skipping font installation (SERVER installation type detected)."
        return 0
    fi

    # Path to the JSON file containing the list of fonts
    FONTS_LIST_FILE="$HOME/archinstaller/packages/optional/fonts.json"

    # Check if the fonts list file exists
    if [[ ! -f "$FONTS_LIST_FILE" ]]; then
        echo "Error: Fonts list file not found at $FONTS_LIST_FILE"
        return 1
    fi

    # Define JQ filters for pacman and AUR packages
    PACMAN_FILTER=".pacman[].package"
    AUR_FILTER=$([ "$AUR_HELPER" != NONE ] && echo ", .aur[].package" || echo "")

    # Parse the JSON file and install the fonts
    jq --raw-output "${PACMAN_FILTER}${AUR_FILTER}" "$FONTS_LIST_FILE" | while read -r font; do
        if [[ -n "$font" ]]; then
            echo "Installing font: $font..."
            if pacman -Qi "$font" &>/dev/null || [[ "$AUR_HELPER" != NONE && "$($AUR_HELPER -Qi "$font" &>/dev/null; echo $?)" -eq 0 ]]; then
                echo "Font $font is already installed."
                continue
            fi

            if [[ "$AUR_HELPER" != NONE && $(pacman -Si "$font" &>/dev/null; echo $?) -ne 0 ]]; then
                echo "Installing $font via AUR helper ($AUR_HELPER)..."
                if ! "$AUR_HELPER" -S "$font" --noconfirm --needed --color=always; then
                    echo "Error: Failed to install font $font via $AUR_HELPER"
                fi
            else
                echo "Installing $font via pacman..."
                if ! sudo pacman -S "$font" --noconfirm --needed --color=always; then
                    echo "Error: Failed to install font $font via pacman"
                fi
            fi
        fi
    done
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


# @description Detect if running in virtual machine
# @noargs
# @return 0 if VM detected, 1 otherwise
detect_vm() {
    # Check DMI product name
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        local product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        case "$product_name" in
            *VirtualBox*|*VMware*|*QEMU*|*KVM*|*Bochs*)
                return 0
                ;;
        esac
    fi

    # Check lspci for virtual graphics
    if lspci | grep -iE "VirtualBox|VMware|QEMU|Virtio" &>/dev/null; then
        return 0
    fi

    return 1
}

# @description Detect GPU type from lspci
# @noargs
# @stdout GPU type: nvidia, amd, intel, unknown
detect_gpu() {
    local gpu_info=$(lspci | grep -iE "VGA|3D|Display" 2>/dev/null)

    if echo "$gpu_info" | grep -iE "NVIDIA|GeForce" &>/dev/null; then
        echo "nvidia"
    elif echo "$gpu_info" | grep -iE "Radeon|AMD|ATI" &>/dev/null; then
        echo "amd"
    elif echo "$gpu_info" | grep -iE "Intel.*Graphics|Integrated Graphics Controller" &>/dev/null; then
        echo "intel"
    else
        echo "unknown"
    fi
}

# @description Detect hybrid graphics (NVIDIA + Intel)
# @noargs
# @return 0 if hybrid detected, 1 otherwise
detect_hybrid_graphics() {
    local gpu_info=$(lspci | grep -iE "VGA|3D|Display" 2>/dev/null)

    if echo "$gpu_info" | grep -iE "NVIDIA|GeForce" &>/dev/null && \
       echo "$gpu_info" | grep -iE "Intel.*Graphics|Integrated Graphics Controller" &>/dev/null; then
        return 0
    fi

    return 1
}

# @description Check if NVIDIA GPU supports open-dkms (Turing+)
# @noargs
# @return 0 if supported, 1 otherwise
nvidia_supports_open_dkms() {
    local nvidia_model=$(lspci | grep -iE "NVIDIA|GeForce" | head -1)

    # RTX 20xx, 30xx, 40xx, GTX 16xx, GTX 20xx series
    if echo "$nvidia_model" | grep -iE "RTX|GTX 16|GTX 20|GTX 30|GTX 40" &>/dev/null; then
        return 0
    fi

    return 1
}

# @description Get NVIDIA driver choice from user
# @noargs
# @stdout Driver type: proprietary, open-dkms, nouveau
get_nvidia_driver_choice() {
    local supports_open=false
    nvidia_supports_open_dkms && supports_open=true

    echo -ne "\nNVIDIA GPU detected. Select driver type:\n"

    if [[ "$supports_open" == true ]]; then
        options=(
            "Proprietary (nvidia-dkms) - Best performance, closed-source"
            "Open-source Kernel (nvidia-open-dkms) - Open kernel module, good performance"
            "Open-source (nouveau) - Free software, limited performance"
        )
    else
        options=(
            "Proprietary (nvidia-dkms) - Best performance, closed-source"
            "Open-source (nouveau) - Free software, limited performance"
        )
    fi

    select_option ${#options[@]} 1 "${options[@]}"
    local choice=$?

    if [[ "$supports_open" == true ]]; then
        case $choice in
            0) echo "proprietary" ;;
            1) echo "open-dkms" ;;
            2) echo "nouveau" ;;
            *) echo "proprietary" ;;
        esac
    else
        case $choice in
            0) echo "proprietary" ;;
            1) echo "nouveau" ;;
            *) echo "proprietary" ;;
        esac
    fi
}

# @description Install package intelligently (check if installed, verify exists)
# @arg $1 Package name
install_package_intelligent() {
    local package="$1"

    # Check if already installed
    if pacman -Qi "$package" &>/dev/null; then
        echo "Package $package is already installed, skipping."
        return 0
    fi

    # Check if package exists in official repositories
    if pacman -Si "$package" &>/dev/null; then
        echo "Installing $package from official repository..."
        if ! pacman -S "$package" --noconfirm --needed --color=always; then
            echo "Error: Failed to install $package via pacman"
            return 1
        fi
        return 0
    else
        echo "Warning: Package $package not found in repositories"
        return 1
    fi
}

# @description Install GPU drivers from JSON file
# @arg $1 GPU type (vm, nvidia, amd, intel, hybrid, fallback)
# @arg $2 Driver variant (proprietary, open-dkms, nouveau) or "" for simple types
# @arg $3 NVIDIA driver type (if hybrid, e.g., proprietary)
install_gpu_from_json() {
    local gpu_type="$1"
    local driver_variant="${2:-}"
    local nvidia_type="${3:-}"

    local json_file="$HOME/archinstaller/packages/gpu-drivers.json"

    if [[ ! -f "$json_file" ]]; then
        echo "Error: GPU drivers JSON file not found at $json_file"
        return 1
    fi

    # Build JQ filter based on GPU type and variant
    local jq_filter=""
    local post_install_filter=""

    if [[ "$gpu_type" == "hybrid" ]]; then
        # Hybrid: .hybrid.nvidia-intel.proprietary.pacman[].package
        jq_filter=".hybrid.nvidia-intel.${nvidia_type}.pacman[].package"
        post_install_filter=".hybrid.nvidia-intel.${nvidia_type}.post_install[]?"
    elif [[ "$gpu_type" == "nvidia" ]]; then
        # NVIDIA: .nvidia.proprietary.pacman[].package
        jq_filter=".nvidia.${driver_variant}.pacman[].package"
        post_install_filter=".nvidia.${driver_variant}.post_install[]?"
    else
        # Simple types: .amd.pacman[].package
        jq_filter=".${gpu_type}.pacman[].package"
        post_install_filter=".${gpu_type}.post_install[]?"
    fi

    # Extract packages using JQ
    local packages=()
    while IFS= read -r package; do
        [[ -n "$package" ]] && packages+=("$package")
    done < <(jq --raw-output "$jq_filter" "$json_file" 2>/dev/null)

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "Error: No packages found for GPU type: $gpu_type"
        return 1
    fi

    echo "Installing ${#packages[@]} packages for $gpu_type..."

    # Install packages using intelligent installation logic
    local failed=0
    for package in "${packages[@]}"; do
        if ! install_package_intelligent "$package"; then
            ((failed++))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        echo "Warning: $failed package(s) failed to install"
    fi

    # Execute post-installation commands
    local post_commands=()
    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] && post_commands+=("$cmd")
    done < <(jq --raw-output "$post_install_filter" "$json_file" 2>/dev/null)

    for cmd in "${post_commands[@]}"; do
        echo "Running post-installation: $cmd"
        if command -v "$cmd" &>/dev/null; then
            $cmd || echo "Warning: $cmd failed (may need reboot)"
        else
            echo "Warning: Command $cmd not found"
        fi
    done

    # Save configuration
    set_option GPU_TYPE "$gpu_type"
    if [[ -n "$driver_variant" ]]; then
        set_option NVIDIA_DRIVER_TYPE "$driver_variant"
    fi

    echo "✓ GPU drivers installed successfully"
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
    if detect_vm; then
        echo "Virtual machine detected - installing VM graphics drivers"
        install_gpu_from_json "vm" ""
        return $?
    fi

    # 2. Detect GPU type
    local detected_gpu=$(detect_gpu)
    echo "Detected GPU type: $detected_gpu"

    # 3. Handle NVIDIA with user choice
    if [[ "$detected_gpu" == "nvidia" ]]; then
        # Check for hybrid graphics
        if detect_hybrid_graphics; then
            echo "Hybrid graphics detected (NVIDIA + Intel)"
            local nvidia_driver_type=$(get_nvidia_driver_choice)
            install_gpu_from_json "hybrid" "nvidia-intel" "$nvidia_driver_type"
        else
            local nvidia_driver_type=$(get_nvidia_driver_choice)
            install_gpu_from_json "nvidia" "$nvidia_driver_type"
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
            echo "Unknown or no GPU detected - installing fallback drivers"
            install_gpu_from_json "fallback" ""
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
    if [[ ! "$AUR_HELPER" == NONE ]]; then
        echo "Selected AUR Helper: $AUR_HELPER"

        # Clone the AUR helper repository
        if ! git clone https://aur.archlinux.org/"$AUR_HELPER".git ~/"$AUR_HELPER"; then
            echo "ERROR! Failed to clone the repository for $AUR_HELPER. Please check your network connection or the helper name."
            exit 1
        fi
        cd ~/"$AUR_HELPER" || return

        # Build and install the AUR helper
        if ! makepkg -sirc --noconfirm; then
            echo "ERROR! Failed to build and install $AUR_HELPER. Please check for missing dependencies or errors in the PKGBUILD."
            exit 1
        fi
        echo "$AUR_HELPER installed successfully."

        # JQ filters to determine AUR packages to install
        MINIMAL_AUR_FILTER=".minimal.aur[].package"
        FULL_AUR_FILTER=$([ "$AUR_HELPER" != NONE ] && [ "$INSTALL_TYPE" == "FULL" ] && echo ", .full.aur[].package" || echo "")

        # Parse the JSON file and install AUR packages
        jq --raw-output "${MINIMAL_AUR_FILTER}""${FULL_AUR_FILTER}" ~/archinstaller/packages/base.json | (
            while read -r line; do
                echo "Installing $line"
                "$AUR_HELPER" -S "$line" --noconfirm --needed --color=always
            done
        )
    fi
}


# @description Installs desktop environment packages from base repositories
# @noargs
desktop_environment_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing Desktop Environment Software
-------------------------------------------------------------------------
"
    # JQ filters
    MINIMAL_PACMAN_FILTER=".minimal.pacman[].package"
    MINIMAL_AUR_FILTER=$([ "$AUR_HELPER" != NONE ] && echo ", .minimal.aur[].package" || echo "")
    FULL_PACMAN_FILTER=$([ "$INSTALL_TYPE" == "FULL" ] && echo ", .full.pacman[].package" || echo "")
    FULL_AUR_FILTER=$([ "$AUR_HELPER" != NONE ] && [ "$INSTALL_TYPE" == "FULL" ] && echo ", .full.aur[].package" || echo "")

    # Parse file with JQ to determine packages to install
    jq --raw-output "${MINIMAL_PACMAN_FILTER}""${MINIMAL_AUR_FILTER}""${FULL_PACMAN_FILTER}""${FULL_AUR_FILTER}" ~/archinstaller/packages/desktop-environments/"${DESKTOP_ENV}".json | (
        while read -r line; do
            if [[ -z "$line" ]]; then
                continue
            fi

            echo "Installing $line"

            # Check if package is already installed
            if pacman -Qi "$line" &>/dev/null; then
                echo "Package $line is already installed, skipping."
                continue
            fi

            # Determine if package is from official repo or AUR
            # Check if package exists in official repositories
            if pacman -Si "$line" &>/dev/null; then
                echo "Installing $line from official repository..."
                if ! sudo pacman -S "$line" --noconfirm --needed --color=always; then
                    echo "Error: Failed to install $line via pacman"
                fi
            else
                if [[ "$AUR_HELPER" != NONE ]]; then
                    echo "Installing $line from AUR via $AUR_HELPER..."
                    if ! "$AUR_HELPER" -S "$line" --noconfirm --needed --color=always; then
                        echo "Error: Failed to install $line via $AUR_HELPER"
                    fi
                else
                    echo "Warning: Package $line not found in official repositories and no AUR helper configured. Skipping."
                fi
            fi
        done
    )
}


# @description Installs btrfs packages
# @noargs
btrfs_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing Btrfs Packages
-------------------------------------------------------------------------
"
    if [[ "$FS" == btrfs ]]; then
        # JQ filters
        PACMAN_FILTER=".pacman[].package"
        AUR_FILTER=$([ "$AUR_HELPER" != NONE ] && echo ", .aur[].package" || echo "")

        # Parse file with JQ to determine packages to install
        jq --raw-output "${PACMAN_FILTER}""${AUR_FILTER}" ~/archinstaller/packages/btrfs.json | (
            while read -r line; do
                if [[ -z "$line" ]]; then
                    continue
                fi

                echo "Installing $line"

                # Check if package is already installed
                if pacman -Qi "$line" &>/dev/null; then
                    echo "Package $line is already installed, skipping."
                    continue
                fi

                # Determine if package is from official repo or AUR
                if pacman -Si "$line" &>/dev/null; then
                    echo "Installing $line from official repository..."
                    if ! sudo pacman -S "$line" --noconfirm --needed --color=always; then
                        echo "Error: Failed to install $line via pacman"
                    fi
                else
                    if [[ "$AUR_HELPER" != NONE ]]; then
                        echo "Installing $line from AUR via $AUR_HELPER..."
                        if ! "$AUR_HELPER" -S "$line" --noconfirm --needed --color=always; then
                            echo "Error: Failed to install $line via $AUR_HELPER"
                        fi
                    else
                        echo "Warning: Package $line not found in official repositories and no AUR helper configured. Skipping."
                    fi
                fi
            done
        )
    fi
}


# @description Perform desktop environment specific theming
# @noargs
user_theming() {
    echo -ne "
-------------------------------------------------------------------------
            Theming Desktop Environment ($INSTALL_TYPE)
-------------------------------------------------------------------------
"
    # Theming DE if not user chose SERVER installation
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
            cd ~/archinstaller/ && git submodule update --init
            cp -r ~/archinstaller/configs/awesome/home/. ~/
            sudo cp -r ~/archinstaller/configs/awesome/etc/xdg/awesome /etc/xdg/awesome
            sudo mkdir -p /usr/share/backgrounds/
            sudo cp ~/archinstaller/configs/base/usr/share/backgrounds/butterfly.png /usr/share/backgrounds/butterfly.png

        elif [[ "$DESKTOP_ENV" == "i3-wm" ]]; then
            # Check if configs directory exists before modifying
            if [[ -d ~/archinstaller/configs/i3-wm/etc ]]; then
                chmod -R a+rX ~/archinstaller/configs/i3-wm/etc
            fi

            # Copy configs if they exist
            if [[ -d ~/archinstaller/configs/i3-wm ]]; then
                cp -r ~/archinstaller/configs/i3-wm/. /
            fi

            # Set permissions for snapper configs if they exist (both source and destination)
            if [[ -d ~/archinstaller/configs/i3-wm/etc/snapper/configs ]] && [[ -n "$(ls -A ~/archinstaller/configs/i3-wm/etc/snapper/configs 2>/dev/null)" ]]; then
                chmod ug+r ~/archinstaller/configs/i3-wm/etc/snapper/configs/*
            fi

            # Also set permissions on the copied files if they exist
            if [[ -d /etc/snapper/configs ]] && [[ -n "$(ls -A /etc/snapper/configs 2>/dev/null)" ]]; then
                chmod ug+r /etc/snapper/configs/*
            fi

            mkdir -p /usr/share/backgrounds/

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
            echo 'IPV6=no' >> /etc/ufw/ufw.conf
        fi

        echo "Enabling UFW"
        systemctl enable ufw.service

        echo "Setting UFW rules for home user"

        ufw default allow outgoing
        ufw default deny incoming

        # Allow inbound connections for essential services
        ufw allow in 22/tcp    # SSH
        ufw allow in 80/tcp    # HTTP
        ufw allow in 443/tcp   # HTTPS

        # Allow local sharing (home network)
        ufw allow in 5353/udp  # mDNS (Avahi)
        ufw allow in 631/tcp   # Printers (CUPS)

        echo "Enabling UFW"
        ufw --force enable
        echo -e "UFW configured and enabled \n"

        # services part of full installation
        echo "Enabling Cups"
        if systemctl enable cups.service; then
            echo -e "  Cups enabled \n"
        else
            echo -e "The cups.service not found, skipping. \n"
        fi

        echo "Syncing time with ntp"
        ntpd -qg
        echo -e "Time synced \n"

        echo "Enabling ntpd"
        systemctl enable ntpd.service
        echo -e "NTP enabled \n"

        echo "Enabling Bluetooth"
        systemctl enable bluetooth
        echo -e "Bluetooth enabled \n"

        echo "Enabling Avahi"
        systemctl enable avahi-daemon.service
        echo -e "Avahi enabled \n"

        if [[ "${FS}" == "luks" || "${FS}" == "btrfs" ]]; then
            snapper_config
            systemctl enable snapper-timeline.timer
            systemctl status snapper-cleanup.timer
        fi

        plymouth_config

    fi
}
