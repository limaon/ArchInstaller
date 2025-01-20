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


# @description Format disk before creatign filesystem
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

    mkdir -p /mnt &>/dev/null              # Hiding error message if any
    umount -A --recursive /mnt &>/dev/null # make sure everything is unmounted before we start

    set -e

    # disk prep
    sgdisk -Z "${DISK}"         # zap all on disk
    sgdisk -a 2048 -o "${DISK}" # new gpt disk 2048 alignment

    # create partitions
    echo -e "\n Creating first partition: BIOSBOOT"
    sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' "${DISK}" # partition 1 (BIOS Boot Partition)

    echo -e "\n Creating second partition: EFIBOOT"
    sgdisk -n 2::+300M --typecode=2:ef00 --change-name=2:'EFIBOOT' "${DISK}" # partition 2 (UEFI Boot Partition)

    echo -e "\n Creating third partition: ROOT"
    sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' "${DISK}" # partition 3 (Root), default start, remaining

    [[ ! -d "/sys/firmware/efi" ]] && sgdisk -A 1:set:2 "${DISK}"

    partprobe "${DISK}" # reread partition table to ensure it is correct

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
        partition2="${DISK}"p2
        partition3="${DISK}"p3
    else
        partition2="${DISK}"2
        partition3="${DISK}"3
    fi

    echo "Creating FAT32 boot filesystem on ${partition2}"
    mkfs.vfat -F32 -n "EFIBOOT" "${partition2}"

    if [[ "${FS}" == "btrfs" ]]; then
        do_btrfs "ROOT" "${partition3}"

    elif [[ "${FS}" == "ext4" ]]; then
        echo "Creating EXT4 root filesystem on ${partition3}"
        mkfs.ext4 -L ROOT "${partition3}"
        mount -t ext4 "${partition3}" /mnt

    elif [[ "${FS}" == "luks" ]]; then
        # enter luks password to cryptsetup and format root partition
        echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -
        # open luks container and ROOT will be place holder
        echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" ROOT -

        do_btrfs "ROOT" "${partition3}"

        # store uuid of encrypted partition for grub
        echo ENCRYPTED_PARTITION_UUID="$(blkid -s UUID -o value "${partition3}")" >>"$CONFIGS_DIR"/setup.conf
    fi

    set +e
}


# @description Perform the btrfs filesystem configuration
# @noargs
do_btrfs() {
    echo -ne "
-------------------------------------------------------------------------
                    Creating btrfs device
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
    mount -o "$MOUNT_OPTIONS",subvol=@ "$2" "$MOUNTPOINT"

    for z in "${SUBVOLUMES[@]:1}"; do
        w="${z[*]//@/}"
        mkdir -p /mnt/"${w}"

        echo -e "\n Mounting $z at /$MOUNTPOINT/$w"
        mount -o "$MOUNT_OPTIONS",subvol="${z}" "$2" "$MOUNTPOINT"/"${w}"
    done
}


# @description Configure swap on low memory systems
# @noargs
low_memory_config() {
    echo -ne "
-------------------------------------------------------------------------
                    Checking for low memory systems <8G
-------------------------------------------------------------------------
"
    TOTAL_MEM=$(grep </proc/meminfo -i 'memtotal' | grep -o '[[:digit:]]*')
    if [[ "$TOTAL_MEM" -lt 8000000 ]]; then
        # Put swap into the actual system, not into RAM disk, otherwise there is no point in it, it'll cache RAM into RAM. So, /mnt/ everything.
        mkdir -p /mnt/opt/swap  # make a dir that we can apply NOCOW to to make it btrfs-friendly.
        chattr +C /mnt/opt/swap # apply NOCOW, btrfs needs that.
        dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
        chmod 600 /mnt/opt/swap/swapfile # set permissions.
        chown root /mnt/opt/swap/swapfile
        mkswap /mnt/opt/swap/swapfile
        swapon /mnt/opt/swap/swapfile
        # The line below is written to /mnt/ but doesn't contain /mnt/, since it's just / for the system itself.
        echo "/opt/swap/swapfile	none	swap	sw	0	0" >>/mnt/etc/fstab # Add swap to fstab, so it KEEPS working after installation.
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
    hwclock --systohc
    ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime
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

    else
        echo "You are already a user, proceed with AUR installs."
    fi
}


# @description Configure GRUB and set a wallpaper (if not SERVER installation)
# @noargs
grub_config() {
    echo -ne "
-------------------------------------------------------------------------
               Configuring Grub Boot Menu
-------------------------------------------------------------------------
"
    # Update GRUB parameters
    [[ "${FS}" == "luks" ]] && sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' /etc/default/grub

    # Apply wallpaper only if the installation type is not SERVER
    if [[ ! "$INSTALL_TYPE" != SERVER ]]; then
        echo -e "\n Setting wallpaper for GRUB..."

        # Define the wallpaper path
        WALLPAPER_PATH="/usr/share/backgrounds/distro-grub-wallpaper.png"

        # Update GRUB configuration to use the wallpaper
        sed -i "s/^#GRUB_BACKGROUND=.*/GRUB_BACKGROUND=\"$WALLPAPER_PATH\"/" /etc/default/grub

    else
        echo -e "\n Skipping wallpaper setup for SERVER installation."
    fi

    # Update grub configuration
    echo -e "\n Updating grub..."
    grub-mkconfig -o /boot/grub/grub.cfg
    echo -e "\n All set! GRUB configuration is complete."
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
            ["background"]="/usr/share/backgrounds/Wall100.jpg"
            ["theme-name"]="Materia-light-compact"
            ["icon-theme-name"]="Qogir-dark"
            ["font-name"]="Noto Sans 12"
            ["xft-antialias"]="true"
            ["xft-dpi"]="96"
            ["xft-hintstyle"]="hintfull"
            ["xft-rgba"]="rgb"
            ["show-clock"]="true"
            ["clock-format"]=" %I:%M:%S %p"
            ["active-monitor"]="1"
            ["screensaver-timeout"]="300"
            ["round-user-image"]="false"
            ["panel-position=bottom"]="top"
            ["indicators"]="~host;~spacer;~a11y;~language;~session;~power;~clock;~layout;sound;network"
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
