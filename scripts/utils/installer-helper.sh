#!/usr/bin/env bash
#github-action genshdoc
#
# @file Installer Helper
# @brief Contains the functions used to facilitate the installer
# @stdout Output routed to install.log
# @stderror Output routed to install.log

echo -e "installler-helper.sh loaded\n"

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

# @description Sources file to be used by the script
# @arg $1 File to source
source_file() {
    if [[ -f "$1" ]]; then
        source "$1"
    else
        echo "ERROR! Missing file: $1"
        exit 0
    fi
}


# @description Copy logs to installed system and exit script
# @noargs
end_script() {
    echo "Copying logs"
    # if [[ "$(find /mnt/var/log -type d | wc -l)" -ne 0 ]]; then
    #     # cp -v "$LOG_FILE" /mnt/var/log/install.log
    # else
    #     echo -ne "ERROR! Log directory not found"
    #     exit 0
    # fi
}
