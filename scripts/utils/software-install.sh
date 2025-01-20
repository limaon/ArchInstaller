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
    pacstrap /mnt base base-devel linux linux-firmware linux-lts \
        jq neovim wget libnewt man-db man-pages sudo usbutils reflector \
        --noconfirm --needed --color=always
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
        grub-install --boot-directory=/mnt/boot "${DISK}"
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
        nmap \
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


# @description Installs graphics drivers depending on detected gpu
# @noargs
graphics_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing Graphics Drivers
-------------------------------------------------------------------------
"
    # Graphics Drivers find and install
    gpu_type=$(lspci)
    if grep -E "NVIDIA|GeForce" <<<"${gpu_type}"; then
        pacman -S --noconfirm --needed --color=always nvidia-dkms nvidia-settings
        nvidia-xconfig
    elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
        pacman -S --noconfirm --needed --color=always xf86-video-amdgpu
    elif grep -E "Integrated Graphics Controller|Intel Corporation UHD" <<<"${gpu_type}"; then
        pacman -S --noconfirm --needed --color=always libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
    else
        echo "No graphics drivers required"
    fi
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
            echo "Installing $line"

            if [[ "$AUR_HELPER" != NONE ]]; then
                "$AUR_HELPER" -S "$line" --noconfirm --needed --color=always
            else
                sudo pacman -S "$line" --noconfirm --needed --color=always
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
                echo "Installing $line"

                if [[ "$AUR_HELPER" != NONE ]]; then
                    "$AUR_HELPER" -S "$line" --noconfirm --needed --color=always
                else
                    sudo pacman -S "$line" --noconfirm --needed --color=always
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
                    Theming Desktop Environment
-------------------------------------------------------------------------
"
    # Theming DE if not user chose SERVER installation
    if [[ ! "$INSTALL_TYPE" == SERVER ]]; then

        # Copy basic system files
        cp -rfv ~/archinstaller/configs/base/. /

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
            echo -e "Applying theming for i3-wm..."
            # Setup system directory config files
            sudo cp -r ~/archinstaller/configs/i3-wm/. /

        else
            echo -e "No theming setup for $DESKTOP_ENV"
        fi
    else
        echo -e "Skipping theming setup for $DESKTOP_ENV (Minimal or Server install)"
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
        ufw allow in 22/tcp   # SSH
        ufw allow in 80/tcp   # HTTP
        ufw allow in 443/tcp  # HTTPS

        # Allow local sharing (home network)
        ufw allow in 5353/udp  # mDNS (Avahi)
        ufw allow in 631/tcp   # Printers (CUPS)

        echo "Enabling UFW"
        ufw --force enable
        echo -e "UFW configured and enabled \n"

        # services part of full installation
        echo "Enabling Cups"
        systemctl enable cups.service
        echo -e "  Cups enabled \n"

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
        fi

        plymouth_config

    fi
}
