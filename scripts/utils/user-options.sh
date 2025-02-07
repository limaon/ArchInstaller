#!/usr/bin/env bash
#github-action genshdoc
#
# @file User Options
# @brief User configuration functions to set variables to be used during installation
# @stdout Output routed to install.log
# @stderror Output routed to install.log


# @description Read and verify user password before setting
# @noargs
set_password() {
    read -rs -p "Please enter password: " PASSWORD1
    echo -ne "\n"
    read -rs -p "Please re-enter password: " PASSWORD2
    echo -ne "\n"
    if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
        set_option "$1" "$PASSWORD1"
    else
		echo -ne "ERROR! Passwords do not match. \n"
		sed -i '/&PASSWORD1=.*/d' "$CONFIG_FILE"
		set_password "$1"
    fi
}

# @description Gather username, real name, and password to be used for installation.
# @noargs
user_info() {

    # Loop through user input until the user gives a valid full name
    while true; do
        read -rp "Please enter your full name (e.g., David Brown): " real_name
        if [[ -z "$real_name" ]]; then
            echo "Full name cannot be empty."
        elif [[ "$real_name" =~ [^a-zA-Z\ ] ]]; then
            echo "Full name contains invalid characters. Only letters and spaces are allowed."
        else
            set_option REAL_NAME "$real_name"
            break
        fi
    done

    # Loop through user input until the user gives a valid username
    while true; do
        read -rp "Please enter username: " username
        # username regex per response here https://unix.stackexchange.com/questions/157426/what-is-the-regex-to-validate-linux-users
        # lowercase the username to test regex
        [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]] && break
        echo "Incorrect username."
    done
    set_option USERNAME "${username,,}" # convert to lower case

    # Ask for and set password
    set_password "PASSWORD"

    # Loop through user input until the user gives a valid hostname, but allow the user to force save
    while true; do
        read -rp "Please name your machine: " nameofmachine
        # hostname regex (!!couldn't find spec for computer name!!)
        [[ "${nameofmachine,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]] && break
        # if validation fails allow the user to force saving of the hostname
        read -rp "Hostname doesn't seem correct. Do you still want to save it? (y/n)" force
        [[ "${force,,}" = "y" ]] && break
    done
    set_option NAME_OF_MACHINE "$nameofmachine"
}


# @description Choose whether to do full or minimal installation.
# @noargs
install_type() {
    echo -ne "Please select type of installation:\n
  ${BOLD}${BRED}Full Install:${RESET} Installs full featured desktop enviroment, with added apps and themes needed for everyday use.
  ${BOLD}${BRED}Minimal Install:${RESET} Installs only apps few selected apps to get you started.
  ${BOLD}${BRED}Server Install${RESET} Installs only base system without a desktop environment.\n"
    options=(FULL MINIMAL SERVER)
    select_option $? 4 "${options[@]}"
    install_type="${options[$?]}"
    set_option INSTALL_TYPE "$install_type"
    export INSTALL_TYPE="$install_type"
}


# @description Choose AUR helper.
# @noargs
aur_helper() {
    # Let the user choose AUR helper from predefined list
    echo -ne "Please select your desired AUR helper:\n"
    options=(paru yay picaur aura trizen pacaur NONE)
    select_option $? 4 "${options[@]}"
    aur_helper="${options[$?]}"
    set_option AUR_HELPER "$aur_helper"
}


# @description Choose Desktop Environment
# @noargs
desktop_environment() {
    # Let the user choose Desktop Enviroment from predefined list
    echo -ne "Please select your desired Desktop Enviroment:\n"
    mapfile -t options < <(for f in packages/desktop-environments/*.json; do echo "$f" | sed -r "s/.+\/(.+)\..+/\1/;/pkgs/d"; done)
    select_option $? 4 "${options[@]}"
    desktop_env="${options[$?]}"
    set_option DESKTOP_ENV "$desktop_env"
}


# @description Disk selection for drive to be used with installation.
# @noargs
disk_select() {
    echo -ne "
------------------------------------------------------------------------
    ${BRED}${BOLD}THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK!${RESET}
    Please make sure you know what you are doing because
    after formatting your disk there is no way to get data back
------------------------------------------------------------------------

"

    PS3='
Select the disk to install on: '
    options=("$(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}')")

    select_option $? 1 "${options[@]}"
    disk="${options[$?]%|*}"

    echo -e "\n${disk%|*} selected \n"
    set_option DISK "${disk%|*}"
    if [[ "$(lsblk -n --output TYPE,ROTA | awk '$1=="disk"{print $2}')" -eq "0" ]]; then
        set_option "MOUNT_OPTION" "defaults,noatime,compress=zstd,ssd,commit=120"
    else
        set_option "MOUNT_OPTION" "defaults,noatime,compress=zstd,commit=120"
    fi

}


# @description This function will handle file systems. At this movement we are handling only
# btrfs and ext4. Others will be added in future.
# @noargs
filesystem() {
    echo -ne "
Please Select your file system for both boot and root
"
    options=("btrfs" "ext4" "luks" "exit")
    select_option $? 1 "${options[@]}"

    case $? in
    0)
        set_btrfs
        set_option FS btrfs
        ;;
    1) set_option FS ext4 ;;
    2)
        set_password "LUKS_PASSWORD"
        set_option FS luks
        ;;
    3) exit ;;
    *)
        echo "Wrong option please select again"
        filesystem
        ;;
    esac
}


# @description Set btrfs subvolumes to be used during install
# @noargs
set_btrfs() {
    echo "Please enter your btrfs subvolumes separated by space"
    echo "usualy they start with @."
    echo "like @home, [defaults are @home, @var, @tmp, @.snapshots]"
    echo " "
    read -r -p "press enter to use default: " -a ARR

    if [[ -z "${ARR[*]}" ]]; then
        set_option "SUBVOLUMES" "(@ @home @var @tmp @.snapshots)"
    else
        NAMES=(@)
        for i in "${ARR[@]}"; do
            if [[ $i =~ [@] ]]; then
                NAMES+=("$i")
            else
                NAMES+=(@"${i}")
            fi
        done
        IFS=" " read -r -a SUBS <<<"$(tr ' ' '\n' <<<"${NAMES[@]}" | awk '!x[$0]++' | tr '\n' ' ')"
        set_option "SUBVOLUMES" "${SUBS[*]}"
    fi

    set_option "MOUNTPOINT" "/mnt"
}


# @description Detects and sets timezone.
# @noargs
timezone() {
    # Added this from arch wiki https://wiki.archlinux.org/title/System_time
    time_zone="$(curl --fail https://ipapi.co/timezone)"
    echo -ne "
System detected your timezone to be '$time_zone' \n"
    echo -ne "Is this correct?
"
    options=("Yes" "No")
    select_option $? 1 "${options[@]}"

    case "${options[$?]}" in
    y | Y | yes | Yes | YES)
        echo "${time_zone} set as timezone"
        set_option TIMEZONE "$time_zone"
        ;;
    n | N | no | NO | No)
        echo "Please enter your desired timezone e.g. Europe/London :"
        read -r new_timezone
        echo "${new_timezone} set as timezone"
        set_option TIMEZONE "$new_timezone"
        ;;
    *)
        echo "Wrong option. Try again"
        timezone
        ;;
    esac
}


# @description Set system language (locale)
# @noargs
locale_selection() {
    echo -ne "
Please select your system language (locale) from the list below:
"
    # Lista de locais comumente usados
    options=("en_US.UTF-8" "pt_BR.UTF-8" "es_ES.UTF-8" "fr_FR.UTF-8" "de_DE.UTF-8" "it_IT.UTF-8" "ja_JP.UTF-8" "zh_CN.UTF-8")

    select_option $? 4 "${options[@]}"
    locale="${options[$?]}"

    echo -ne "Selected system language: ${locale} \n"
    set_option LOCALE "$locale"
}


# @description Set user's keyboard mapping.
# @noargs
keymap() {
    echo -ne "
Please select keyboard layout from this list:
"
    # These are default key maps as presented in official arch repo archinstall
    options=("us" "br-abnt2" "by" "ca" "cf" "cz" "de" "dk" "es" "et" "fa" "fi" "fr" "gr" "hu" "il" "it" "lt" "lv" "mk" "nl" "no" "pl" "ro" "ru" "sg" "ua" "uk")

    select_option $? 4 "${options[@]}"
    keymap="${options[$?]}"

    echo -ne "Your keyboards layout: ${keymap} \n"
    set_option KEYMAP "$keymap"
}


# @description Show all configurations set during the setup and allow user to redo any step.
# @noargs
show_configurations() {
    while true; do
        echo -e "
------------------------------------------------------------------------
                          Configuration Summary
------------------------------------------------------------------------
"
        if [[ -f "$CONFIG_FILE" ]]; then
            cat "$CONFIG_FILE"
        else
            echo "Configuration file not found. Please check if setup.conf was created."
        fi

        echo -e "
------------------------------------------------------------------------
Do you want to redo any step? Select an option below, or press Enter to proceed:
1) Full Name, Username and Password
2) Installation Type
3) AUR Helper
4) Desktop Environment
5) Disk Selection
6) File System
7) Timezone
8) System Language (Locale)
9) Keyboard Layout
------------------------------------------------------------------------
"
        read -rp "Enter the number of the step to redo, or press Enter to proceed: " choice

        if [[ -z "$choice" ]]; then
            echo "Proceeding with installation..."
            break
        fi

        # Processa a escolha do usuário
        case $choice in
            1) user_info ;;
            2) install_type ;;
            3) aur_helper ;;
            4) desktop_environment ;;
            5) disk_select ;;
            6) filesystem ;;
            7) timezone ;;
            8) locale_selection ;;
            9) keymap ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}
