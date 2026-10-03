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
CONFIG_FILE=$(config_file_for_context root) || {
    echo "ERROR: Could not resolve root configuration path"
    exit 1
}
export CONFIG_FILE
if ! source "$CONFIG_FILE"; then
    echo "ERROR: Could not load root configuration: $CONFIG_FILE"
    exit 1
fi

CONFIG_FILE=$(config_file_for_context shared "$USERNAME") || {
    echo "ERROR: Could not resolve shared configuration path"
    exit 1
}
export CONFIG_FILE
if ! source "$CONFIG_FILE"; then
    echo "ERROR: Could not load shared configuration: $CONFIG_FILE"
    exit 1
fi

show_logo

echo -ne "
  Final Setup and Configurations
  GRUB Bootloader Install & Check
"

# Configure kernel parameters and generate the GRUB boot menu.
# Function from 'system-config.sh'.
# This must be called BEFORE grub-install when using LUKS encryption
if ! grub_config; then
    echo "ERROR: GRUB configuration failed; stopping post-setup"
    exit 1
fi

# Configure crypttab for LUKS if needed
if [[ "${FS}" == "luks" ]]; then
    echo "Configuring /etc/crypttab for LUKS..."
    cat >/etc/crypttab <<EOF
# Configuration for encrypted block devices.
# See crypttab(5) for details.

# <name>       <device>                                     <password>              <options>
ROOT          UUID=${ENCRYPTED_PARTITION_UUID}             none                    luks,discard
EOF
    echo "crypttab configured successfully"

    # Remove duplicate root= parameter from GRUB_CMDLINE_LINUX_DEFAULT
    # btrfs auto-generates root=UUID=... which conflicts with root=/dev/mapper/ROOT
    sed -i 's/root=UUID=[^ ]* //' /etc/default/grub
fi

# Rebuild every installed initramfs after all package and boot settings are final.
echo "Rebuilding initramfs presets..."
if [[ "${FS}" == "btrfs" || "${FS}" == "luks" ]] && ! command -v btrfs &>/dev/null; then
    echo "ERROR: btrfs-progs is required before rebuilding initramfs"
    exit 1
fi

configure_nvidia_kernel_modules
configure_nvidia_power_management

if ! mkinitcpio -P; then
    echo "ERROR: Failed to rebuild initramfs presets"
    exit 1
fi

# Install GRUB bootloader based on system type (UEFI or Legacy BIOS)
if ! grub_install_bootloader; then
    echo "ERROR: GRUB bootloader installation failed; stopping post-setup"
    exit 1
fi

# Function to enable and theme the appropriate display manager
# based on the selected desktop environment function from 'system-config.sh'
display_manager

# Function to enable essential services based on installation
# type, including NetworkManager, periodic trim, and additional
# services for full installations function from 'software-install.sh'
if ! essential_services; then
    echo "ERROR: Essential services configuration failed; stopping post-setup" >&2
    exit 1
fi

# Function to configure PAM password attempts (allow 5 attempts before lockout)
# function from 'system-config.sh'
configure_pam_faillock

# Function to configure PipeWire audio server and remove PulseAudio
# function from 'system-config.sh'
if ! configure_pipewire; then
    echo "ERROR: PipeWire configuration failed; stopping post-setup" >&2
    exit 1
fi

# Configure root user shell
echo -ne "
-------------------------------------------------------------------------
                    Configuring Root User Shell
-------------------------------------------------------------------------
"
# Copy root configuration files if they exist
if [[ -d "$HOME"/archinstaller/configs/base/root ]]; then
    ROOT_CONFIG_DIR="$HOME"/archinstaller/configs/base/root

    # Copy all root shell configuration files at once
    # Using cp -a to preserve permissions and copy recursively
    if cp -a "$ROOT_CONFIG_DIR"/. /root/ 2>/dev/null; then
        echo "Root user shell configuration complete"
    else
        echo "Warning: Some root configuration files may not have been copied"
    fi
else
    echo "Root shell configuration directory not found, skipping"
fi

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
cat <<EOF >/etc/ssh/sshd_config
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
