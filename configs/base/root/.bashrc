# ~/.bashrc - Basic bash configuration for root user
# Based on ArchWiki: https://wiki.archlinux.org/title/Bash

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Source global bashrc if it exists
[[ -f /etc/bash.bashrc ]] && . /etc/bash.bashrc

################################################################################
##  ENVIRONMENT VARIABLES                                                    ##
################################################################################

# Editor preferences
export EDITOR=nvim
export VISUAL=nvim

# History configuration (ArchWiki: Bash#History)
export HISTSIZE=5000
export HISTFILESIZE=10000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT="%F %T "

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Color support
export TERM=xterm-256color

################################################################################
##  SHELL OPTIONS                                                            ##
################################################################################

# Check window size after each command
shopt -s checkwinsize

# Append to history file, don't overwrite it
shopt -s histappend

# Save multi-line commands as one command
shopt -s cmdhist

# Prevent overwrite of files
set -o noclobber

################################################################################
##  COLOR DEFINITIONS                                                         ##
################################################################################

# Reset
Color_Off='\e[0m'

# Regular Colors
Red='\e[0;31m'
Green='\e[0;32m'
Yellow='\e[0;33m'
Blue='\e[0;34m'
Cyan='\e[0;36m'
White='\e[0;37m'

# Bold
BRed='\e[1;31m'
BGreen='\e[1;32m'
BYellow='\e[1;33m'
BBlue='\e[1;34m'
BCyan='\e[1;36m'
BWhite='\e[1;37m'

################################################################################
##  PROMPT CUSTOMIZATION                                                     ##
################################################################################

# Root prompt with warning color (red)
# Format: [ROOT] user@host:directory #
PS1='\[\033[1;31m\][ROOT]\[\033[0m\] \[\033[1;32m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\]:\[\033[1;36m\]\w\[\033[0m\] \[\033[1;31m\]#\[\033[0m\] '

# Set window title
PS1="\[\e]0;ROOT@\h: \w\a\]$PS1"

################################################################################
##  ALIASES                                                                   ##
################################################################################

# Color support for ls and grep
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# List aliases
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# System information
alias df='df -h'
alias du='du -h'
alias free='free -h'

# Arch Linux specific
alias update='pacman -Syu'
alias upgrade='pacman -Syu'
alias install='pacman -S'
alias remove='pacman -Rs'
alias search='pacman -Ss'
alias info='pacman -Si'

# Safety aliases for root
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Text processing
alias c='clear'
alias cls='clear'
alias h='history'

################################################################################
##  FUNCTIONS                                                                 ##
################################################################################

# Show system information
sysinfo() {
    echo -e "\n${BWhite}System Information${Color_Off}"
    echo -e "${BGreen}Hostname:${Color_Off} $(hostname)"
    echo -e "${BGreen}Kernel:${Color_Off} $(uname -r)"
    echo -e "${BGreen}Uptime:${Color_Off} $(uptime -p)"
    echo -e "${BGreen}Memory:${Color_Off} $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo -e "${BGreen}Disk:${Color_Off} $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
}

# Quick search in history
histgrep() {
    history | grep "$1"
}

################################################################################
##  COMPLETION                                                                ##
################################################################################

# Enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Custom completions
complete -cf sudo
complete -cf man

################################################################################
##  READLINE CONFIGURATION                                                   ##
################################################################################

# History search with arrow keys
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

################################################################################
##  STARTUP MESSAGES                                                         ##
################################################################################

# Warning message for root
if shopt -q login_shell; then
    echo -e "${BRed}WARNING: You are logged in as ROOT!${Color_Off}"
    echo -e "${BYellow}Be careful with your commands.${Color_Off}"
    echo ""
fi

# Load additional aliases if they exist
[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases

################################################################################
##  END OF CONFIGURATION                                                     ##
################################################################################

