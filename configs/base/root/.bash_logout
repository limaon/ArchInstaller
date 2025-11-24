# ~/.bash_logout - Executed when root user logs out
# Based on ArchWiki: https://wiki.archlinux.org/title/Bash

################################################################################
##  CLEANUP ON LOGOUT                                                         ##
################################################################################

# Clear the screen for security
clear

# Optional: Clear history (uncomment if desired)
# history -c
# history -w

# Optional: Remove temporary files (uncomment if desired)
# rm -f ~/.bash_history.tmp
# rm -f ~/.viminfo.tmp

################################################################################
##  LOGOUT MESSAGE                                                            ##
################################################################################

# Display logout message
echo ""
echo "Root session ended."
echo ""

################################################################################
##  END OF CONFIGURATION                                                     ##
################################################################################

