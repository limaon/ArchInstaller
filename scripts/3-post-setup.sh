#!/usr/bin/env bash
#github-action genshdoc
#
# @file Post-Setup
# @brief Finalizing installation configurations and cleaning up after script.
# @stdout Output routed to install.log
# @stderror Output routed to install.log

# source utility scripts
for filename in "$HOME"/archinstaller/scripts/utils/*.sh; do
  [ -e "$filename" ] || continue
  # shellcheck source=./utils/*.sh
  source "$filename"
done
source "$HOME"/archinstaller/configs/setup.conf


show_logo


echo -ne "
  Final Setup and Configurations
  GRUB EFI Bootloader Install & Check
"

[[ -d "/sys/firmware/efi" ]] && grub-install --target=x86_64-efi --efi-directory=/boot "${DISK}" --bootloader-id='Arch Linux'


# Function to configure and theme the GRUB boot menu, including setting
# kernel parameters and installing the some theme, function from 'system-config.sh'
grub_config


# Function to enable and theme the appropriate display manager
# based on the selected desktop environment function from 'system-config.sh'
display_manager


# Function to enable essential services based on installation
# type, including NetworkManager, periodic trim, and additional
# services for full installations function from 'software-install.sh'
essential_services

echo -ne "
-------------------------------------------------------------------------
                    Configuring SSH
-------------------------------------------------------------------------
"

# Configure SSH for remote access
echo "Configuring SSH server..."

# Ensure openssh is installed
if ! pacman -Qi openssh &>/dev/null; then
    echo "Installing openssh..."
    pacman -S openssh --noconfirm --needed
fi

# Configure SSH daemon
cat <<EOF > /etc/ssh/sshd_config
# ArchInstaller SSH Configuration
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords no

# Security
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 0
ClientAliveCountMax 3
UsePAM yes

# Allow users in wheel group
AllowGroups wheel

# Logging
SyslogFacility AUTH
LogLevel INFO
EOF

# Generate SSH host keys if they don't exist
if [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Enable and start SSH service
echo "Enabling SSH service..."
systemctl enable sshd.service
systemctl start sshd.service

# Configure firewall to allow SSH (if UFW is installed)
if pacman -Qi ufw &>/dev/null; then
    echo "Configuring firewall for SSH..."
    ufw allow in 22/tcp comment 'SSH'
    ufw reload || true
fi

# Display SSH connection info
echo ""
echo "SSH Configuration Complete!"
echo "To connect remotely, use:"
echo "  ssh $USERNAME@<server-ip>"
echo ""
echo "To find the server IP address, run on the server:"
echo "  ip addr show"
echo "  or"
echo "  hostname -I"
echo ""

echo -ne "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------
"

echo "Cleaning up sudoers file"
# Remove no password sudo rights, add sudo rights
sed -Ei 's/^%wheel ALL=\(ALL(:ALL)?\) NOPASSWD: ALL/# &/;
s/^# (%wheel ALL=\(ALL(:ALL)?\) ALL)/\1/' /etc/sudoers

echo "Cleaning up installation files"
rm -r "$HOME"/archinstaller /home/"$USERNAME"/archinstaller
