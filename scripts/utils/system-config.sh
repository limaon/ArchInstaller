#!/usr/bin/env bash
#github-action genshdoc
#
# @file System Config
# @brief Contains the functions used to modify the system
# @stdout Output routed to install.log
# @stderror Output routed to install.log


# @description Update mirrorlist to improve download speeds using rankmirrors if reflector is unavailable
# @noargs
mirrorlist_update() {
    # Verifica se o reflector está instalado
    if command -v reflector &> /dev/null; then
        pacman -S --noconfirm --needed --color=always reflector
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
        echo -ne "
-------------------------------------------------------------------------
                    Setting up mirrors for faster downloads (reflector)
-------------------------------------------------------------------------
"
        reflector -a 48 -c "$iso" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
    else
        echo -ne "
-------------------------------------------------------------------------
                    Reflector not found or get a error, using rankmirrors
-------------------------------------------------------------------------
"
        pacman -S --noconfirm --needed --color=always curl
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
        curl -s "https://archlinux.org/mirrorlist/?country=$iso&protocol=https&use_mirror_status=on" \
            | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist
        rankmirrors -n 5 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.temp
        mv /etc/pacman.d/mirrorlist.temp /etc/pacman.d/mirrorlist
    fi
}


# @description Format disk before creating filesystem(s)
# @noargs
format_disk() {
    echo -ne "
-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------
"
    pacman -S --noconfirm --needed --color=always gptfdisk glibc

    echo -ne "
-------------------------------------------------------------------------
                    Formatting ${DISK}
-------------------------------------------------------------------------
"

    mkdir -p /mnt &>/dev/null
    umount -A --recursive /mnt &>/dev/null

    set -e

    # Preparar o disco
    sgdisk -Z "${DISK}"
    sgdisk -a 2048 -o "${DISK}"

    if [[ -d "/sys/firmware/efi" ]]; then
        echo -e "\nCriando partição EFI (UEFI Boot Partition)"
        sgdisk -n 1::+1G --typecode=1:ef00 --change-name=1:"EFIBOOT" "${DISK}"
        echo -e "\nCriando partição ROOT"
        sgdisk -n 2::-0 --typecode=2:8300 --change-name=2:"ROOT" "${DISK}"
    else
        echo -e "\nCriando partição BIOS Boot (sem filesystem)"
        sgdisk -n 1::+256M --typecode=1:ef02 --change-name=1:"BIOSBOOT" "${DISK}"
        echo -e "\nCriando partição ROOT"
        sgdisk -n 2::-0 --typecode=2:8300 --change-name=2:"ROOT" "${DISK}"
        sgdisk -A 1:set:2 "${DISK}"
    fi

    partprobe "${DISK}"

    set +e
}


# @description Create the filesystem on the drive selected for installation
# @noargs
create_filesystems() {
    echo -ne "
-------------------------------------------------------------------------
                    Creating Filesystems
-------------------------------------------------------------------------
"
    set -e

    if [[ "${DISK}" =~ "nvme" || "${DISK}" =~ "mmc" ]]; then
        if [[ -d "/sys/firmware/efi" ]]; then
            boot_partition="${DISK}p1"
            root_partition="${DISK}p2"
        else
            boot_partition=""
            root_partition="${DISK}p2"
        fi
    else
        if [[ -d "/sys/firmware/efi" ]]; then
            boot_partition="${DISK}1"
            root_partition="${DISK}2"
        else
            boot_partition=""
            root_partition="${DISK}1"
            [[ $(sgdisk -p "${DISK}" | grep -c "BIOSBOOT") -gt 0 ]] && root_partition="${DISK}2"
        fi
    fi

    if [[ -n "${boot_partition}" ]]; then
        echo "Creating FAT32 EFI boot filesystem on ${boot_partition}"
        mkfs.vfat -F32 -n "EFIBOOT" "${boot_partition}"
    fi

    if [[ "${FS}" == "btrfs" ]]; then
        do_btrfs "ROOT" "${root_partition}"

    elif [[ "${FS}" == "ext4" ]]; then
        echo "Creating EXT4 root filesystem on ${root_partition}"
        mkfs.ext4 -L ROOT "${root_partition}"
        mount -t ext4 "${root_partition}" /mnt

    elif [[ "${FS}" == "luks" ]]; then
        echo "Configuring LUKS on ${root_partition}"
        echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${root_partition}" -
        echo -n "${LUKS_PASSWORD}" | cryptsetup open "${root_partition}" ROOT -
        do_btrfs "ROOT" "/dev/mapper/ROOT"
        echo ENCRYPTED_PARTITION_UUID="$(blkid -s UUID -o value "${root_partition}")" >>"$CONFIGS_DIR"/setup.conf
    fi

    set +e
}


# @description Perform the btrfs filesystem configuration
# @noargs
do_btrfs() {
    echo -ne "
-------------------------------------------------------------------------
                    Creating btrfs filesystem and subvolumes
-------------------------------------------------------------------------
"
    echo -e "Creating btrfs device $1 on $2 \n"
    mkfs.btrfs -L "$1" "$2" -f

    echo -e "Mounting $2 on $MOUNTPOINT \n"
    mount -t btrfs "$2" "$MOUNTPOINT"

    echo "Creating subvolumes and directories"
    for x in "${SUBVOLUMES[@]}"; do
        btrfs subvolume create "$MOUNTPOINT"/"${x}"
    done

    umount "$MOUNTPOINT"

    # Mount the root subvolume (@) to the mountpoint
    mount -o "$MOUNT_OPTIONS",subvol=@ "$2" "$MOUNTPOINT"

    # Mount the remaining subvolumes in their respective directories
    for z in "${SUBVOLUMES[@]:1}"; do
        case "$z" in
            "@docker")
                w="var/lib/docker"
                ;;
            "@flatpak")
                w="var/lib/flatpak"
                ;;
            "@snapshots")
                w=".snapshots"
                ;;
            "@var_cache")
                w="var/cache"
                ;;
            "@var_log")
                w="var/log"
                ;;
            "@var_tmp")
                w="var/tmp"
                ;;
            *)
                w="${z//@/}"
                ;;
        esac

        mkdir -p /mnt/"${w}"
        echo -e "\nMounting subvolume $z at /mnt/${w}"
        mount -o "$MOUNT_OPTIONS",subvol="${z}" "$2" "/mnt/${w}"

        if [[ "$z" == "@var_cache" || "$z" == "@var_log" || "$z" == "@var_tmp" ]]; then
            echo "Disabling copy-on-write on /mnt/${w}"
            chattr +C "/mnt/${w}"
        fi
    done
}


# @description Configure zram for systems with low memory
# @noargs
low_memory_config() {
    echo -ne "
-------------------------------------------------------------------------
          Configuring ZRAM (compressed swap) for <8G RAM
-------------------------------------------------------------------------
"
    TOTAL_MEM=$(grep -i 'memtotal' /proc/meminfo | grep -o '[[:digit:]]*')
    if [[ "$TOTAL_MEM" -lt 8000000 ]]; then
        echo "Installing zram-generator..."
        arch-chroot /mnt pacman -S zram-generator --noconfirm

        echo "Configuring zram-generator..."
        mkdir -p /mnt/etc/systemd/
        cat <<EOF > /mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * 2
swap-priority = 100
compression-algorithm = zstd
EOF

        echo "Loading zram module..."
        modprobe zram

        echo "Regenerating initramfs..."
        arch-chroot /mnt mkinitcpio -P

        echo "Enabling systemd-zram-setup@zram0.service..."
        arch-chroot /mnt systemctl enable systemd-zram-setup@zram0.service

        echo "ZRAM configured to use 200% of RAM as compressed swap (zstd algorithm)"
    fi
}


# @description Configures makepkg settings dependent on cpu cores
# @noargs
cpu_config() {
    nc=$(grep -c ^processor /proc/cpuinfo)
    echo -ne "
-------------------------------------------------------------------------
                    You have $nc cores. And
            changing the makeflags for $nc cores. Aswell as
                changing the compression settings.
-------------------------------------------------------------------------
"
    TOTAL_MEM=$(grep </proc/meminfo -i 'memtotal' | grep -o '[[:digit:]]*')
    if [[ "$TOTAL_MEM" -gt 8000000 ]]; then
        sed -i "s/^#\(MAKEFLAGS=\"-j\)2\"/\1$nc\"/;
        /^COMPRESSXZ=(xz -c -z -)/s/-c /&-T $nc /" /etc/makepkg.conf
    fi
}


# @description Set locale, timezone, keymap, and vconsole configuration
# @noargs
locale_config() {
    echo -ne "
-------------------------------------------------------------------------
                    Setting Locale, Timezone, and Keymap
-------------------------------------------------------------------------
"
    # Enable selected locale and create /etc/locale.conf file with complete settings
    sed -i "s/^#\(${LOCALE}.*\)/\1/" /etc/locale.gen
    {
        echo "LANG=${LOCALE}"
        echo "LC_ADDRESS=${LOCALE}"
        echo "LC_IDENTIFICATION=${LOCALE}"
        echo "LC_MEASUREMENT=${LOCALE}"
        echo "LC_MONETARY=${LOCALE}"
        echo "LC_NAME=${LOCALE}"
        echo "LC_NUMERIC=${LOCALE}"
        echo "LC_PAPER=${LOCALE}"
        echo "LC_TELEPHONE=${LOCALE}"
        echo "LC_TIME=${LOCALE}"
    } > /etc/locale.conf
    echo "Generating locales..."
    locale-gen || { echo "ERROR: Failed to generate locales."; exit 1; }
    localectl --no-ask-password set-locale LANG="${LOCALE}" LC_TIME="${LOCALE}"
    echo "Locales generated successfully."

    # Configure timezone and synchronize hours
    timedatectl --no-ask-password set-timezone "${TIMEZONE}"
    timedatectl --no-ask-password set-ntp 1
    ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime
    hwclock --systohc
    echo "Timezone configured: ${TIMEZONE}"

    # Configure keymap and remap keys
    pacman -S --noconfirm --needed --color=always kbd xkeyboard-config
    localectl --no-ask-password set-keymap "${KEYMAP}"
    echo "Keymap configured: ${KEYMAP}"

    # Create /etc/vconsole.conf for console keymap configuration
    echo -e "KEYMAP=${KEYMAP}\nFONT=Lat2-Terminus16\nFONT_MAP=" > /etc/vconsole.conf

    echo -ne "
    Locale, Timezone, Keymap, and VConsole configuration completed.
    "
}


# @description Adds multilib and chaotic-aur repo to get precompiled aur packages
# @noargs
extra_repos() {
    echo -ne "
-------------------------------------------------------------------------
                    Adding additional repos
-------------------------------------------------------------------------
"

    # Enable multilib
    echo -e "\n Enabling multilib"
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

    # echo -e "\n Importing chaotic aur keyring"
    # Enable chaotic-aur
    # pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
    # pacman-key --lsign-key FBA220DFC880C036
    # pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    # echo -e "\n Adding chaotic aur to pacman.conf"
    # echo '' | sudo tee -a /etc/pacman.conf
    # echo '[chaotic-aur]' | sudo tee -a /etc/pacman.conf
    # echo 'Include = /etc/pacman.d/chaotic-mirrorlist ' | sudo tee -a /etc/pacman.conf

    echo -e "\n -|SYNCING REPOS|-"
    pacman -Sy --noconfirm --needed --color=always
}


# @description Adds user that was setup prior to installation
# @noargs
add_user() {
    echo -ne "
-------------------------------------------------------------------------
                    Adding User
-------------------------------------------------------------------------
"
    if [ "$(whoami)" = "root" ]; then
        # Create groups
        for group in libvirt vboxusers gamemode docker; do
            groupadd -f "$group"
        done

        # Add new user and full name
        useradd -m -G wheel,libvirt,vboxusers,gamemode,docker -s /bin/bash -c "$REAL_NAME" "$USERNAME"
        if [[ $? -ne 0 ]]; then
            echo "ERROR! Failed to create user $USERNAME."
            exit 1
        fi
        echo "$USERNAME created with full name '$REAL_NAME', added to groups."

        # Define a user's password
        if echo "$USERNAME:$PASSWORD" | chpasswd; then
            echo "$USERNAME password set."
        else
            echo "ERROR! Failed to set password for $USERNAME."
            exit 1
        fi

        # Copies the installation directory to home directory.
        if cp -R "$HOME/archinstaller" /home/"$USERNAME"/; then
            chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/archinstaller
            echo "archinstaller copied to home directory."
        else
            echo "ERROR! Failed to copy archinstaller to /home/$USERNAME."
            exit 1
        fi

        # Define hostname
        echo "$NAME_OF_MACHINE" >/etc/hostname
        echo "Hostname set to $NAME_OF_MACHINE."

        # Setup hosts file
        cat >> /etc/hosts << EOF
127.0.0.1  localhost
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
# This host address
127.0.1.1  archlinux
EOF

    else
        echo "You are already a user, proceed with AUR installs."
    fi
}


# @description Configure GRUB and set a wallpaper (if not SERVER installation)
# @noargs
grub_config() {
    echo -ne "
-------------------------------------------------------------------------
               Configuring GRUB Boot Menu
-------------------------------------------------------------------------
"
    if [[ "${FS}" == "luks" ]]; then
        sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
    fi
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' /etc/default/grub

    echo -e "\n Backing up Grub config..."
    cp -an /etc/default/grub /etc/default/grub.bak

    if [[ "$INSTALL_TYPE" != "SERVER" ]]; then
        echo -e "\nSetting wallpaper for GRUB..."
        # WALLPAPER_PATH="/usr/share/backgrounds/archlinux/archwave.png"
        # sed -Ei "s|^#GRUB_BACKGROUND=.*|GRUB_BACKGROUND=\"$WALLPAPER_PATH\"|" /etc/default/grub
    else
        echo -e "\nSkipping wallpaper setup for SERVER installation."
    fi

    echo -e "\nUpdating GRUB configuration..."
    grub-mkconfig -o /boot/grub/grub.cfg
    echo -e "\nGRUB configuration complete."
}


# @description Install and enable display manager depending on desktop environment chosen
# @noargs
display_manager() {
    echo -ne "
-------------------------------------------------------------------------
               Enabling (and Theming) Login Display Manager
-------------------------------------------------------------------------
"
    if [[ "${DESKTOP_ENV}" == "kde" ]]; then
        systemctl enable sddm.service
        if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
            echo -e "Setting SDDM Theme..."
            echo "[Theme]" >>/etc/sddm.conf
            echo "Current=Nordic" >>/etc/sddm.conf
        fi

    elif [[ "${DESKTOP_ENV}" == "gnome" ]]; then
        systemctl enable gdm.service

    elif [[ "${DESKTOP_ENV}" == "lxde" ]]; then
        systemctl enable lxdm.service

    elif [[ "${DESKTOP_ENV}" == "openbox" ]]; then
        systemctl enable lightdm.service
        if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
            echo -e "Setting LightDM Theme..."
            # Set default lightdm-webkit2-greeter theme to Litarvan
            sed -i 's/^webkit_theme\s*=\s*\(.*\)/webkit_theme = litarvan #\1/g' /etc/lightdm/lightdm-webkit2-greeter.conf
            # Set default lightdm greeter to lightdm-webkit2-greeter
            sed -i 's/#greeter-session=example.*/greeter-session=lightdm-webkit2-greeter/g' /etc/lightdm/lightdm.conf
        fi

    elif [[ "${DESKTOP_ENV}" == "awesome" ]]; then
        systemctl enable lightdm.service
        if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
            echo -e "Setting LightDM Theme..."
            cp ~/archinstaller/configs/awesome/etc/lightdm/slick-greeter.conf /etc/lightdm/slick-greeter.conf
            sed -i 's/#greeter-session=example.*/greeter-session=lightdm-slick-greeter/g' /etc/lightdm/lightdm.conf
        fi

    elif [[ "${DESKTOP_ENV}" == "i3-wm" ]]; then
        systemctl enable lightdm.service
        echo -e "Configuring LightDM for i3-wm..."
        # Set lightdm greeter to lightdm-gtk-greeter
        sed -i 's/#greeter-session=example.*/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf

        CONFIG_FILE="/etc/lightdm/lightdm-gtk-greeter.conf"
        declare -A greeter_config=(
            ["background"]="/usr/share/backgrounds/archlinux/geolanes.png"
            ["user-background"]="true"
            ["font-name"]="Ubuntu 12"
            ["xft-antialias"]="true"
            ["icon-theme-name"]="Pop"
            ["cursor-theme-name"]="Pop"
            ["transition-duration"]="1000"
            ["transition-type"]="linear"
            ["screensaver-timeout"]="60"
            ["show-clock"]="false"
            ["theme-name"]="Yaru-blue-dark"
            ["default-user-image"]="#archlinux"
            ["xft-hintstyle"]="hintfull"
            ["clock-format"]=""
            ["panel-position"]="top"
            ["xft-dpi"]="96"
            ["xft-rgba"]="rgb"
            ["active-monitor"]="1"
            ["round-user-image"]="false"
            ["indicators"]="~host;~spacer;~clock;~spacer;~language;~session;~a11y;~power"
        )

        for key in "${!greeter_config[@]}"; do
            if grep -q "^#${key}=" "$CONFIG_FILE"; then
                sed -i "s|^#${key}=.*|${key}=${greeter_config[$key]}|" "$CONFIG_FILE"
            else
                echo "${key}=${greeter_config[$key]}" >> "$CONFIG_FILE"
            fi
        done

    # If none of the above, use lightdm as fallback
    else
        if [[ ! "${INSTALL_TYPE}" == "SERVER" ]]; then
            pacman -S --noconfirm --needed --color=always lightdm lightdm-gtk-greeter
            systemctl enable lightdm.service
        fi
    fi
}


# @description Configure snapper default setup
# @noargs
snapper_config() {
    echo -ne "
-------------------------------------------------------------------------
                    Creating Snapper Config
-------------------------------------------------------------------------
"

    SNAPPER_CONF="$HOME"/archinstaller/configs/base/etc/snapper/configs/root
    mkdir -p /etc/snapper/configs/
    cp -rfv "${SNAPPER_CONF}" /etc/snapper/configs/

    SNAPPER_CONF_D="$HOME"/archinstaller/configs/base/etc/conf.d/snapper
    mkdir -p /etc/conf.d/
    cp -rfv "${SNAPPER_CONF_D}" /etc/conf.d/

    sed -i "s/ALLOW_USERS=\".*\"/ALLOW_USERS=\"$(whoami)\"/" /etc/snapper/configs/root
    sed -i "s/ALLOW_GROUPS=\".*\"/ALLOW_GROUPS=\"$(whoami)\"/" /etc/snapper/configs/root
    systemctl enable snapper-timeline.timer
    systemctl enable snapper-cleanup.timer
    systemctl enable grub-btrfsd.service
    snapper -c root create --description "Initial snapshot"
    chown :users /.snapshots
}


# @description Configures TLP for power management on laptops.
# @noargs
configure_tlp() {
    if [ -d "/sys/class/power_supply/BAT0" ] || acpi -b &>/dev/null; then
        echo "Battery detected. Installing and configuring TLP..."

        sudo pacman -S --noconfirm tlp tlp-rdw
        sudo systemctl enable tlp.service

        sudo systemctl mask systemd-rfkill.service
        sudo systemctl mask systemd-rfkill.socket

        # Apply recommended configurations
        TLP_CONF="/etc/tlp.conf"

        sudo sed -i 's/^#\?USB_AUTOSUSPEND=.*/USB_AUTOSUSPEND=0/' "$TLP_CONF"
        sudo sed -i 's/^#\?RUNTIME_PM_ON_AC=.*/RUNTIME_PM_ON_AC=auto/' "$TLP_CONF"
        sudo sed -i 's/^#\?CPU_ENERGY_PERF_POLICY_ON_AC=.*/CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance/' "$TLP_CONF"
        sudo sed -i 's/^#\?CPU_ENERGY_PERF_POLICY_ON_BAT=.*/CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power/' "$TLP_CONF"

        echo "TLP installed and configured successfully."
    else
        echo "No battery detected. Skipping TLP configuration."
    fi
}


# @description Install plymouth splash
# @noargs
plymouth_config() {
    echo -ne "
-------------------------------------------------------------------------
            Enabling (and Theming) Plymouth Boot Splash
-------------------------------------------------------------------------
"
    PLYMOUTH_THEMES_DIR="$HOME"/archinstaller/configs/base/usr/share/plymouth/themes
    PLYMOUTH_THEME="arch-glow" # can grab from config later if we allow selection
    mkdir -p "/usr/share/plymouth/themes"

    echo -e "Installing Plymouth theme... \n"

    cp -rf "${PLYMOUTH_THEMES_DIR}"/"${PLYMOUTH_THEME}" /usr/share/plymouth/themes
    if [[ "${FS}" == "luks" ]]; then
        sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf             # add plymouth after base udev
        sed -i 's/HOOKS=(base udev \(.*block\) /&plymouth-/' /etc/mkinitcpio.conf # create plymouth-encrypt after block hook
    else
        sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf # add plymouth after base udev
    fi
    plymouth-set-default-theme -R arch-glow # sets the theme and runs mkinitcpio

    echo -e "\n Plymouth theme installed"
}
