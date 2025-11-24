# ~/.bashrc - Bash configuration for all environments
# Based on ArchWiki: https://wiki.archlinux.org/title/Bash
# Prompt customization: https://wiki.archlinux.org/title/Bash/Prompt_customization

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

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# History configuration (ArchWiki: Bash#History)
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:ll:la:cd:cd -:pwd:exit:date:* --help"
export HISTTIMEFORMAT="%F %T "

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Less configuration
export LESS='-R -M --shift 5'

# Color support for various commands
export TERM=xterm-256color

################################################################################
##  SHELL OPTIONS                                                            ##
################################################################################

# Check window size after each command (ArchWiki: Bash#Line wrap on window resize)
shopt -s checkwinsize

# Enable extended globbing
shopt -s extglob

# Enable autocd (auto "cd" when entering just a path - ArchWiki: Bash#Auto "cd")
shopt -s autocd

# Append to history file, don't overwrite it
shopt -s histappend

# Save multi-line commands as one command
shopt -s cmdhist

# Correct minor spelling errors in directory names
shopt -s dirspell

# Enable case-insensitive filename globbing
shopt -s nocaseglob

# Prevent overwrite of files (ArchWiki: Bash#Prevent overwrite of files)
set -o noclobber

################################################################################
##  COLOR DEFINITIONS                                                         ##
################################################################################

# Reset
Color_Off='\e[0m'

# Regular Colors
Black='\e[0;30m'
Red='\e[0;31m'
Green='\e[0;32m'
Yellow='\e[0;33m'
Blue='\e[0;34m'
Purple='\e[0;35m'
Cyan='\e[0;36m'
White='\e[0;37m'

# Bold
BBlack='\e[1;30m'
BRed='\e[1;31m'
BGreen='\e[1;32m'
BYellow='\e[1;33m'
BBlue='\e[1;34m'
BPurple='\e[1;35m'
BCyan='\e[1;36m'
BWhite='\e[1;37m'

# Background
On_Black='\e[40m'
On_Red='\e[41m'
On_Green='\e[42m'
On_Yellow='\e[43m'
On_Blue='\e[44m'
On_Purple='\e[45m'
On_Cyan='\e[46m'
On_White='\e[47m'

################################################################################
##  PROMPT CUSTOMIZATION                                                     ##
################################################################################

# Check if terminal supports colors
# This checks if we're in an interactive terminal and if it supports colors
if [[ -t 1 ]] && [[ -n "$TERM" ]]; then
    # Check if terminal supports colors (at least 8 colors)
    if command -v tput &> /dev/null && tput colors &> /dev/null && [[ $(tput colors) -ge 8 ]]; then
        COLOR_PROMPT=true
    # Check common color-capable terminal types
    elif [[ "$TERM" =~ ^(xterm|screen|tmux|linux|vt100|rxvt).* ]] || [[ "$TERM" =~ ^(.*256color.*|.*color.*) ]]; then
        COLOR_PROMPT=true
    else
        COLOR_PROMPT=false
    fi
else
    # If we can't determine (e.g., via SSH without proper TERM), assume no colors for safety
    COLOR_PROMPT=false
fi

# Git branch function (if git is installed) - simple output without color
git_branch() {
    if command -v git &> /dev/null; then
        local branch=$(git branch 2>/dev/null | sed -n '/\* /s///p')
        if [[ -n "$branch" ]]; then
            # Return branch name without colors (simple, Ubuntu-style)
            echo "(${branch}) "
        fi
    fi
}

# Exit code function (show exit code if non-zero) - simple output without color
exit_code() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        # Return exit code without colors (simple, Ubuntu-style)
        echo "[$exit_code] "
    fi
}

# Prompt with colors - Ubuntu-style simple and clean
# Format: [exit_code] user@host:directory (git_branch) $
# Ubuntu-style colors: green for user@host, blue for directory
# Note: All escape sequences must be wrapped in \[ and \] for proper prompt length calculation
if [[ "$COLOR_PROMPT" == "true" ]]; then
    # Ubuntu-style prompt: simple colors
    # - Green (bold) for username and hostname
    # - Blue (bold) for current directory
    # - Exit code and git branch appear in default color for a cleaner look
    PS1='$(exit_code)\[\033[1;32m\]\u@\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\] $(git_branch)\$ '
else
    # No colors - simple prompt without escape sequences
    PS1='$(exit_code)\u@\h:\w $(git_branch)\$ '
fi

# Set window title (for terminal emulators that support it)
PS1="\[\e]0;\u@\h: \w\a\]$PS1"

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
alias lh='ls -lh'
alias lt='ls -lhtr'
alias l.='ls -d .* --color=auto'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# System information
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias meminfo='free -mlth'
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias pscpu='ps auxf | sort -nr -k 3'
alias pscpu10='ps auxf | sort -nr -k 3 | head -10'

# Arch Linux specific
alias update='sudo pacman -Syu'
alias upgrade='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rs'
alias search='pacman -Ss'
alias info='pacman -Si'
alias orphans='pacman -Qtdq'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'

# AUR helper aliases (if yay or paru is installed)
if command -v yay &> /dev/null; then
    alias aur-update='yay -Syu'
    alias aur-install='yay -S'
    alias aur-search='yay -Ss'
    alias aur-remove='yay -Rs'
fi

if command -v paru &> /dev/null; then
    alias aur-update='paru -Syu'
    alias aur-install='paru -S'
    alias aur-search='paru -Ss'
    alias aur-remove='paru -Rs'
fi

# System control
alias reboot='systemctl reboot'
alias poweroff='systemctl poweroff'
alias suspend='systemctl suspend'
alias hibernate='systemctl hibernate'
alias lock='i3lock -c 000000'

# Network
alias ping='ping -c 5'
alias ports='netstat -tulanp'
alias myip='curl -s https://api.ipify.org'

# File operations
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -pv'
alias rmdir='rmdir -p'

# Text processing
alias cls='clear'
alias h='history'
alias path='echo -e ${PATH//:/\\n}'

# Archive extraction
alias extract='extract_archive'

# Git aliases (if git is installed)
if command -v git &> /dev/null; then
    alias gs='git status'
    alias ga='git add'
    alias gc='git commit'
    alias gp='git push'
    alias gl='git log --oneline --graph --decorate'
    alias gd='git diff'
    alias gb='git branch'
    alias gco='git checkout'
fi

################################################################################
##  FUNCTIONS                                                                 ##
################################################################################

# Extract various archive formats
extract_archive() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"      ;;
            *.rar)       unrar x "$1"      ;;
            *.gz)        gunzip "$1"       ;;
            *.tar)       tar xf "$1"       ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"        ;;
            *.Z)         uncompress "$1"   ;;
            *.7z)        7z x "$1"         ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Find files by name
ff() {
    find . -type f -iname "*$1*"
}

# Find directories by name
fd() {
    find . -type d -iname "*$1*"
}

# Show disk usage of a directory
duf() {
    du -sh "$1" 2>/dev/null || echo "Directory not found"
}

# Show top 10 largest files/directories
largest() {
    du -h | sort -rh | head -n "${1:-10}"
}

# Create a backup of a file
bak() {
    cp "$1" "$1.bak"
}

# Show weather (requires curl)
weather() {
    local city="${1:-}"
    if [ -z "$city" ]; then
        curl -s "wttr.in"
    else
        curl -s "wttr.in/$city"
    fi
}

# Quick search in history (ArchWiki: Bash#History completion)
histgrep() {
    history | grep "$1"
}

# Show system information
sysinfo() {
    echo -e "\n${BWhite}System Information${Color_Off}"
    echo -e "${BGreen}Hostname:${Color_Off} $(hostname)"
    echo -e "${BGreen}Kernel:${Color_Off} $(uname -r)"
    echo -e "${BGreen}Uptime:${Color_Off} $(uptime -p)"
    echo -e "${BGreen}Memory:${Color_Off} $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo -e "${BGreen}Disk:${Color_Off} $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
}

# Show colors
colors() {
    for i in {0..255}; do
        printf "\x1b[38;5;${i}mcolor%-5i\x1b[0m" $i
        if ! (( ($i + 1) % 8)); then
            echo
        fi
    done
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

# History search with arrow keys (ArchWiki: Bash#History completion)
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Mimic Zsh run-help ability (ArchWiki: Bash#Mimic Zsh run-help ability)
run-help() {
    help "$READLINE_LINE" 2>/dev/null || man "$READLINE_LINE"
}
bind -m vi-insert -x '"\eh": run-help'
bind -m emacs -x     '"\eh": run-help'

################################################################################
##  STARTUP MESSAGES                                                         ##
################################################################################

# Show system information on login (only in login shells)
if shopt -q login_shell; then
    # Welcome message
    echo -e "${BGreen}Welcome, ${BWhite}$USER${BGreen}!${Color_Off}"
    echo -e "${BCyan}System:${Color_Off} $(uname -sr)"
    echo -e "${BCyan}Uptime:${Color_Off} $(uptime -p | sed 's/up //')"
    echo ""
fi

# Load additional aliases if they exist
[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases

# Load additional functions if they exist
[[ -f ~/.bash_functions ]] && . ~/.bash_functions

################################################################################
##  END OF CONFIGURATION                                                     ##
################################################################################

