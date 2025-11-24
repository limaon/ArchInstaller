# ~/.profile - Profile for root user (compatible with all POSIX shells)
# Based on ArchWiki: https://wiki.archlinux.org/title/Command-line_shell

################################################################################
##  ENVIRONMENT VARIABLES                                                    ##
################################################################################

# Editor preferences
export EDITOR=nvim
export VISUAL=nvim

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Color support
export TERM=xterm-256color

# Path (add custom paths if needed)
# export PATH="$PATH:/usr/local/sbin:/usr/local/bin"

################################################################################
##  SHELL-SPECIFIC CONFIGURATION                                             ##
################################################################################

# If bash is being used, source .bashrc
if [ -n "$BASH_VERSION" ]; then
    # Include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# If zsh is being used, source .zshrc
if [ -n "$ZSH_VERSION" ]; then
    if [ -f "$HOME/.zshrc" ]; then
        . "$HOME/.zshrc"
    fi
fi

################################################################################
##  END OF CONFIGURATION                                                     ##
################################################################################

