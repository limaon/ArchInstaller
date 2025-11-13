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

    # Format options as "device  |  size" with proper spacing
    mapfile -t options < <(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{printf "/dev/%s  |  %s\n", $2, $3}')

    echo -e "Select the disk to install on: \n"

    select_option ${#options[@]} 1 "${options[@]}"

    selected_index=$?
    disk="${options[$selected_index]%%|*}"
    disk="${disk// }"  # Remove trailing spaces

    echo -e "\n${disk} selected \n"
    set_option DISK "${disk}"

    # Ask for disk usage percentage
    echo -ne "${BOLD}Disk space usage:${RESET}\n\n"

    options_percent=("Use 100% of the disk" "Set custom percentage")
    select_option ${#options_percent[@]} 1 "${options_percent[@]}"
    percent_choice=$?

    if [[ $percent_choice -eq 0 ]]; then
        # Use 100%
        disk_percent=100
        echo -e "\nUsing 100% of ${disk}\n"
    else
        # Define custom percentage
        while true; do
            read -rp "Enter percentage to use (5-100): " user_percent

            # Validate input
            if [[ -z "$user_percent" ]]; then
                echo "Percentage cannot be empty. Using 100%."
                disk_percent=100
                break
            elif ! [[ "$user_percent" =~ ^[0-9]+$ ]]; then
                echo "Invalid input. Please enter a number."
            elif [[ "$user_percent" -lt 5 ]] || [[ "$user_percent" -gt 100 ]]; then
                echo "Percentage must be between 5 and 100."
            else
                disk_percent="$user_percent"

                # Calculate and show preview
                disk_size=$(lsblk -n -b -o SIZE "${disk}" | head -n1)
                disk_size_gb=$(( (disk_size / 1024 / 1024 / 1024) ))
                used_size_gb=$(( (disk_size * disk_percent) / 100 / 1024 / 1024 / 1024 ))

                echo -e "\n${BOLD}Preview:${RESET}"
                echo -e "Total disk size: ${disk_size_gb}GB"
                echo -e "Will use: ${used_size_gb}GB (${disk_percent}%)"
                echo -e "Remaining: $((disk_size_gb - used_size_gb))GB (unused)"

                read -rp "Confirm this percentage? (y/n): " confirm
                if [[ "${confirm,,}" == "y" ]]; then
                    break
                fi
            fi
        done
    fi

    # Save percentage
    set_option DISK_USAGE_PERCENT "${disk_percent}"

    # Detect disk type (SSD/HDD)
    if [[ "$(lsblk -n --output TYPE,ROTA "${disk}" | awk '$1=="disk"{print $2}')" -eq "0" ]]; then
        set_option "MOUNT_OPTION" "defaults,noatime,compress=zstd,ssd,discard=async,commit=120"
    else
        set_option "MOUNT_OPTION" "defaults,noatime,compress=zstd,discard=async,commit=120"
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
    echo "Please enter your btrfs subvolumes separated by space."
    echo "Usually they start with @."
    echo "For example, enter: @docker @flatpak @home @opt @snapshots @var_cache @var_log @var_tmp"
    echo " "
    read -r -p "Press enter to use the default subvolumes: " -a ARR

    # If no subvolumes are provided, use the defaults as per the article
    if [[ -z "${ARR[*]}" ]]; then
        set_option "SUBVOLUMES" "(@ @docker @flatpak @home @opt @snapshots @var_cache @var_log @var_tmp)"
    else
        NAMES=("@")
        for i in "${ARR[@]}"; do
            if [[ $i =~ ^@ ]]; then
                NAMES+=("$i")
            else
                NAMES+=("@${i}")
            fi
        done
        # Remove duplicates
        IFS=" " read -r -a SUBS <<<"$(tr ' ' '\n' <<<"${NAMES[@]}" | awk '!x[$0]++' | tr '\n' ' ')"
        set_option "SUBVOLUMES" "${SUBS[*]}"
    fi

    set_option "MOUNTPOINT" "/mnt"
}


# @description Detects and sets timezone interactively from system timezones.
# @noargs
timezone() {
    echo -ne "${BOLD}Timezone Selection${RESET}\n\n"

    local detected_tz=""
    if command -v curl &>/dev/null; then
        detected_tz="$(curl --fail --max-time 3 https://ipapi.co/timezone 2>/dev/null || echo "")"
    fi

    if [[ -n "$detected_tz" ]] && [[ -f "/usr/share/zoneinfo/$detected_tz" ]]; then
        echo -ne "System detected your timezone: ${BOLD}${detected_tz}${RESET}\n"
        echo -ne "Select timezone selection method:\n\n"
        local options=("Use detected timezone" "Select from list")
        select_option ${#options[@]} 1 "${options[@]}"
        local choice=$?

        if [[ $choice -eq 0 ]]; then
            echo -e "\nUsing detected timezone: ${detected_tz}"
            set_option TIMEZONE "$detected_tz"
            return 0
        fi
        echo ""
    fi

    # Build a flat list of ALL timezones
    if [[ ! -d "/usr/share/zoneinfo" ]]; then
        echo "Error: /usr/share/zoneinfo not found. Cannot list timezones."
        echo "Please enter timezone manually (e.g., America/New_York):"
        read -r manual_tz
        if [[ -n "$manual_tz" ]]; then
            set_option TIMEZONE "$manual_tz"
            return 0
        else
            echo "Error: No timezone provided"
            return 1
        fi
    fi

    echo -ne "${BOLD}Select timezone:${RESET}\n\n"

    local timezones=()
    while IFS= read -r tz_path; do
        local rel_tz="${tz_path#/usr/share/zoneinfo/}"
        timezones+=("$rel_tz")
    done < <(find /usr/share/zoneinfo -type f \
                ! -name "*.tab" ! -name "*.list" ! -name "*.zi" ! -name "*.leap" \
                | grep -v "/posix/" | grep -v "/right/" | sort)

    if [[ ${#timezones[@]} -eq 0 ]]; then
        echo "Error: No timezones found in /usr/share/zoneinfo"
        echo "Please enter timezone manually (e.g., America/New_York):"
        read -r manual_tz
        if [[ -n "$manual_tz" ]]; then
            set_option TIMEZONE "$manual_tz"
            return 0
        else
            echo "Error: No timezone provided"
            return 1
        fi
    fi

    # Columns set to 3 for readability; adjust if needed
    select_option_with_search ${#timezones[@]} 3 "${timezones[@]}"
    local selected_tz_index=$?
    local full_timezone="${timezones[$selected_tz_index]}"

    if [[ ! -f "/usr/share/zoneinfo/$full_timezone" ]]; then
        echo "Warning: Timezone file not found: /usr/share/zoneinfo/$full_timezone"
        echo "Using timezone anyway: $full_timezone"
    fi

    echo -e "\nSelected timezone: ${full_timezone}"
    set_option TIMEZONE "$full_timezone"
}


# @description Set system language (locale)
# @noargs
locale_selection() {
    echo -ne "
Please select your system language (locale) from the list below:
"
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
    # Load INSTALL_TYPE from config if not already set
    if [[ -f "$CONFIG_FILE" ]] && grep -q "^INSTALL_TYPE=" "$CONFIG_FILE"; then
        source "$CONFIG_FILE"
    fi

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
Do you want to redo any step? Select an option below, or press Enter to proceed:"

        echo "1) Full Name, Username and Password"
        echo "2) Installation Type"

        # Only show AUR Helper and Desktop Environment if not SERVER
        if [[ ! "$INSTALL_TYPE" == "SERVER" ]]; then
            echo "3) AUR Helper"
            echo "4) Desktop Environment"
            echo "5) Disk Selection and Usage Percentage"
            echo "6) File System"
            echo "7) Timezone"
            echo "8) System Language (Locale)"
            echo "9) Keyboard Layout"
        else
            echo "3) Disk Selection and Usage Percentage"
            echo "4) File System"
            echo "5) Timezone"
            echo "6) System Language (Locale)"
            echo "7) Keyboard Layout"
        fi

        echo "------------------------------------------------------------------------
"
        read -rp "Enter the number of the step to redo, or press Enter to proceed: " choice

        if [[ -z "$choice" ]]; then
            echo "Proceeding with installation..."
            break
        fi

        # Reload INSTALL_TYPE in case it was changed
        if [[ -f "$CONFIG_FILE" ]] && grep -q "^INSTALL_TYPE=" "$CONFIG_FILE"; then
            source "$CONFIG_FILE"
        fi

        case $choice in
            1) user_info ;;
            2)
                install_type
                # Reload INSTALL_TYPE after change
                if [[ -f "$CONFIG_FILE" ]] && grep -q "^INSTALL_TYPE=" "$CONFIG_FILE"; then
                    source "$CONFIG_FILE"
                fi
                ;;
            3)
                if [[ ! "$INSTALL_TYPE" == "SERVER" ]]; then
                    aur_helper
                else
                    disk_select
                fi
                ;;
            4)
                if [[ ! "$INSTALL_TYPE" == "SERVER" ]]; then
                    desktop_environment
                else
                    filesystem
                fi
                ;;
            5)
                if [[ ! "$INSTALL_TYPE" == "SERVER" ]]; then
                    disk_select
                else
                    timezone
                fi
                ;;
            6)
                if [[ ! "$INSTALL_TYPE" == "SERVER" ]]; then
                    filesystem
                else
                    locale_selection
                fi
                ;;
            7)
                if [[ ! "$INSTALL_TYPE" == "SERVER" ]]; then
                    timezone
                else
                    keymap
                fi
                ;;
            8)
                if [[ ! "$INSTALL_TYPE" == "SERVER" ]]; then
                    locale_selection
                else
                    echo "Invalid option. Please try again."
                fi
                ;;
            9)
                if [[ ! "$INSTALL_TYPE" == "SERVER" ]]; then
                    keymap
                else
                    echo "Invalid option. Please try again."
                fi
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}
