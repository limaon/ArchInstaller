#!/usr/bin/env bash
#github-action genshdoc
#
# @file Installer Helper
# @brief Contains the functions used to facilitate the installer
# @stdout Output routed to install.log
# @stderror Output routed to install.log


# @description Exits script if previous command fails
# @arg $1 string Exit code of previous command
# @arg $2 string Previous command
exit_on_error() {
    exit_code=$1
    last_command=${*:2}
    if [ "$exit_code" -ne 0 ]; then
        echo >&2 "\"${last_command}\" command failed with exit code ${exit_code}."
        exit "$exit_code"
    fi
}


# @description display archinstaller logo
# @noargs
show_logo() {
    echo -e "
                        _      _              _          _  _
                       | |    (_)            | |        | || |
       ____  _ __  ___ | |__   _  _ __   ___ | |_  ____ | || |
      / _  || '__|/ __|| '_ \ | || '_ \ / __|| __|/ _  || || |
     | (_| || |  | (__ | | | || || | | |\__ \| |_| (_| || || |
      \__,_||_|   \___||_| |_||_||_| |_||___/ \__|\__,_||_||_|

        SCRIPTHOME: $SCRIPT_DIR
"
}


# @description Select multiple options
# @noargs
function multiselect {

    # little helpers for terminal print control and key input
    ESC=$(printf "\033")
    cursor_blink_on() { printf "%s[?25h" "$ESC"; }
    cursor_blink_off() { printf "%s[?25l" "$ESC"; }
    cursor_to() { printf "%s[$1;${2:-1}H" "$ESC"; }
    print_inactive() { printf "%s   %s " "$2" "$1"; }
    print_active() { printf "$2  %s[7m $1 %s[27m" "$ESC" "$ESC"; }
    get_cursor_row() {
        IFS=';' read -rsdR -p $'\E[6n' ROW COL
        echo "${ROW#*[}"
    }
    get_cursor_col() {
        IFS=';' read -rsdR -p $'\E[6n' ROW COL
        echo "${COL#*[}"
    }
    key_input() {
        local key
        IFS= read -rsn1 key 2>/dev/null >&2
        if [[ $key = "" ]]; then echo enter; fi
        if [[ $key = $'\x20' ]]; then echo space; fi
        if [[ $key = $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key = [A ]]; then echo up; fi
            if [[ $key = [B ]]; then echo down; fi
        fi
    }
    toggle_option() {
        local arr_name=$1
        eval "local arr=(\"\${${arr_name}[@]}\")"
        local option=$2
        if [[ ${arr[option]} == true ]]; then
            arr[option]=
        else
            arr[option]=true
        fi
        eval "$arr_name"='("${arr[@]}")'
    }

    local retval=$1
    local options
    local defaults

    IFS=';' read -r -a options <<<"$2"
    if [[ -z $3 ]]; then
        defaults=()
    else
        IFS=';' read -r -a defaults <<<"$3"
    fi
    local selected=()

    for ((i = 0; i < ${#options[@]}; i++)); do
        selected+=("${defaults[i]}")
        printf "\n"
    done

    # determine current screen position for overwriting the options
    local lastrow
    lastrow=$(get_cursor_row)
    local startrow=$((lastrow - ${#options[@]}))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for option in "${options[@]}"; do
            local prefix="[ ]"
            if [[ ${selected[idx]} == true ]]; then
                prefix="[x]"
            fi

            cursor_to $((startrow + idx))
            if [ $idx -eq $active ]; then
                print_active "$option" "$prefix"
            else
                print_inactive "$option" "$prefix"
            fi
            ((idx++))
        done

        # user key control
        case $(key_input) in
        space) toggle_option selected $active ;;
        enter) break ;;
        up)
            ((active--))
            if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi
            ;;
        down)
            ((active++))
            if [ $active -ge ${#options[@]} ]; then active=0; fi
            ;;
        esac
    done

    # cursor position back to normal
    cursor_to "$lastrow"
    printf "\n"
    cursor_blink_on

    eval "$retval"='("${selected[@]}")'
}


# @description Sequence to call scripts
# @noargs
sequence() {
    . "$SCRIPTS_DIR"/0-preinstall.sh
    arch-chroot /mnt "$HOME"/archinstaller/scripts/1-setup.sh
    if [[ ! "$INSTALL_TYPE" == SERVER ]]; then
        arch-chroot /mnt /usr/bin/runuser -u "$USERNAME" -- /home/"$USERNAME"/archinstaller/scripts/2-user.sh
    fi
    arch-chroot /mnt "$HOME"/archinstaller/scripts/3-post-setup.sh
}


# @description set options in setup.conf
# @arg $1 string Configuration variable.
# @arg $2 string Configuration value.
set_option() {
    local key="$1"
    local value="$2"

    grep -Eq "^${key}.*" "$CONFIG_FILE" && sed -i "/^${key}.*/d" "$CONFIG_FILE"

    if [[ "$key" == "REAL_NAME" && "$value" =~ \  ]]; then
        echo "${key}=\"${value}\"" >>"$CONFIG_FILE"
    else
        echo "${key}=${value}" >>"$CONFIG_FILE"
    fi
}


# Renders a text-based list of options that can be selected by the
# user using up, down, and enter keys and returns the chosen option.
#
#   Arguments   : number_of_options colmax "opt1" "opt2" ...
#                 or: $? colmax "opt1" "opt2" ... (old style)
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
select_option() {

    # Helpers for terminal print control and key input
    ESC=$(printf "\033")
    cursor_blink_on() { printf '%s[?25h' "$ESC"; }
    cursor_blink_off() { printf '%s[?25l' "$ESC"; }
    cursor_to() { printf '%s[%s;%sH' "$ESC" "$1" "${2:-1}"; }
    print_option() { printf '%s   %s ' "$2" "$1"; }
    print_selected() { printf '%s  %s[7m %s %s[27m' "$2" "$ESC" "$1" "$ESC"; }
    get_cursor_row() {
        IFS=';' read -rsdR -p $'\E[6n' ROW COL
        echo "${ROW#*[}"
    }
    get_cursor_col() {
        IFS=';' read -rsdR -p $'\E[6n' ROW COL
        echo "${COL#*[}"
    }
    key_input() {
        local key
        IFS= read -rsn1 key 2>/dev/null >&2
        [[ $key == "" ]] && echo "enter"
        [[ $key == $'\x20' ]] && echo "space"
        [[ $key == "k" ]] && echo "up"
        [[ $key == "j" ]] && echo "down"
        [[ $key == "h" ]] && echo "left"
        [[ $key == "l" ]] && echo "right"
        [[ $key == "a" ]] && echo "all"
        [[ $key == "n" ]] && echo "none"
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            [[ $key == "[A" || $key == "k" ]] && echo "up"
            [[ $key == "[B" || $key == "j" ]] && echo "down"
            [[ $key == "[C" || $key == "l" ]] && echo "right"
            [[ $key == "[D" || $key == "h" ]] && echo "left"
        fi
    }
    print_options_multicol() {
        local curr_col=$1
        local curr_row=$2
        local idx=0
        local row=0
        local col=0
        local curr_idx=$((curr_col + curr_row * colmax))

        for option in "${local_options[@]}"; do
            row=$((idx / colmax))
            col=$((idx % colmax))
            cursor_to $((startrow + row + 1)) $((offset * col + 1))
            if [[ $idx -eq $curr_idx ]]; then
                print_selected "$option"
            else
                print_option "$option"
            fi
            ((idx++))
        done
    }

    # Extract options from arguments (skip first 2 arguments: count/return_code and colmax)
    # $1 = number of options or return code (can be ignored)
    # $2 = number of columns (colmax)
    # $3+ = options
    local local_options=("${@:3}")
    local colmax=$2

    # Initialize with blank lines for each option
    for _ in "${local_options[@]}"; do printf '\n'; done

    # Determine current screen position for overwriting options
    local lastrow
    local lastcol
    local startrow
    local lines
    local cols
    local offset

    # Assign values separately
    lastrow=$(get_cursor_row)
    lastcol=$(get_cursor_col)
    startrow=$((lastrow - ${#local_options[@]}))
    lines=$(tput lines)
    cols=$(tput cols)
    offset=$((cols / colmax))

    # Ensure proper cleanup on Ctrl+C
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active_row=0
    local active_col=0

    while true; do
        print_options_multicol "$active_col" "$active_row"
        case "$(key_input)" in
            enter) break ;;
            up)
                ((active_row--))
                [[ $active_row -lt 0 ]] && active_row=0
                ;;
            down)
                ((active_row++))
                local max_row=$(( (${#local_options[@]} - 1) / colmax ))
                [[ $active_row -gt $max_row ]] && active_row=$max_row
                ;;
            left)
                ((active_col--))
                [[ $active_col -lt 0 ]] && active_col=0
                ;;
            right)
                ((active_col++))
                [[ $active_col -ge colmax ]] && active_col=$((colmax - 1))
                ;;
        esac
    done

    cursor_to "$lastrow"
    printf '\n'
    cursor_blink_on

    return $((active_col + active_row * colmax))
}


# @description Sources file to be used by the script
# @arg $1 File to source
# shellcheck disable=SC1090
source_file() {
    if [[ -f "$1" ]]; then
        source "$1" || { echo "ERROR! Failed to source file: $1"; exit 1; }
    else
        echo "ERROR! Missing file: $1"
        exit 1
    fi
}


# @description Copy logs to installed system and exit script
# @noargs
end_script() {
    echo "Copying logs"
    if [[ "$(find /mnt/var/log -type d | wc -l)" -ne 0 ]]; then
        cp -v "$LOG_FILE" /mnt/var/log/install.log
    else
        echo -ne "ERROR! Log directory not found"
        exit 0
    fi
}
