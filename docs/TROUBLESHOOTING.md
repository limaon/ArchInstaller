# Troubleshooting Guide - Verifying Installation Success

## Automatic Verification After Reboot

After installation completes and you reboot the system, you can verify everything worked correctly:

### Option 1: Run Verification Script Locally

After logging into your new system:

```bash
# Run the verification script (as your user - it will use sudo when needed)
~/.archinstaller/verify-installation.sh

# Or if you're already in your home directory
./.archinstaller/verify-installation.sh
```

The script will automatically:
- Check installation logs for errors
- Verify system services
- Check network and SSH configuration
- Verify swap configuration
- Check user account and permissions
- Verify desktop environment installation
- Display SSH connection information

### Option 2: Connect via SSH and Run Verification

The installer automatically configures SSH for remote access. After reboot:

1. **Find the server IP address** (on the server):
   ```bash
   ip addr show
   # or
   hostname -I
   ```

2. **Connect remotely** (from another machine):
   ```bash
   ssh your-username@server-ip-address
   ```

3. **Run verification script**:
   ```bash
   ~/.archinstaller/verify-installation.sh
   ```

### Files Available After Installation

The installer automatically copies these files to `~/.archinstaller/`:

- `install.log` - Complete installation log
- `verify-installation.sh` - Verification script
- `setup.conf` - Installation configuration (password removed for security)

These files persist even after the installer cleans up temporary files.

---

## Quick Verification Checklist

After installation completes, verify everything worked correctly:

### 1. Check Installation Logs

All installation output is saved to `/var/log/install.log`:

```bash
# View complete log (scroll with arrow keys, press 'q' to quit)
less /var/log/install.log

# Search for errors (case-insensitive)
grep -i error /var/log/install.log

# Search for warnings
grep -i warning /var/log/install.log

# Search for failed operations
grep -i "failed\|fail\|error" /var/log/install.log

# View last 100 lines (most recent output)
tail -n 100 /var/log/install.log

# View last 50 lines and follow new output (if still installing)
tail -f /var/log/install.log
```

### 2. Common Error Patterns to Look For

```bash
# Check for package installation failures
grep -i "error: failed to install\|pacman.*error" /var/log/install.log

# Check for AUR helper failures
grep -i "aur.*error\|yay.*error\|paru.*error" /var/log/install.log

# Check for service failures
grep -i "failed to enable\|systemctl.*failed" /var/log/install.log

# Check for permission errors
grep -i "permission denied\|access denied" /var/log/install.log

# Check for disk/filesystem errors
grep -i "disk\|filesystem\|mount.*error" /var/log/install.log

# Check for network errors
grep -i "network\|connection.*failed\|timeout" /var/log/install.log
```

### 3. Verify System Services

```bash
# Check if critical services are enabled and running
systemctl status NetworkManager
systemctl status lightdm  # or sddm/gdm depending on DE
systemctl status zram-generator  # if ZRAM was configured

# List all enabled services
systemctl list-unit-files --state=enabled

# Check for failed services
systemctl --failed
```

### 4. Verify Installed Components

```bash
# Check desktop environment installation
# For KDE
pacman -Q | grep -i plasma

# For GNOME
pacman -Q | grep -i gnome

# For i3-wm
pacman -Q | grep -i i3

# Check AUR helper installation
which yay  # or paru, depending on choice
yay --version  # or paru --version

# Check swap configuration
swapon --show
free -h

# Check ZRAM (if configured)
zramctl
cat /proc/swaps
```

### 5. Verify Filesystem and Partitions

```bash
# Check mounted filesystems
df -h

# Check swap
swapon --show
free -h

# Check btrfs subvolumes (if btrfs was used)
btrfs subvolume list /

# Check disk partitions
lsblk -f
```

### 6. Verify User Configuration

```bash
# Check if user was created
id $USERNAME  # Replace $USERNAME with your username

# Check user groups
groups

# Check home directory
ls -la ~

# Check sudo access
sudo -v
```

### 7. Verify Network Configuration

```bash
# Check network connectivity
ping -c 3 google.com

# Check NetworkManager status
systemctl status NetworkManager

# List network interfaces
ip addr show
# or
nmcli device status
```

### 8. Verify Boot Configuration

```bash
# Check GRUB configuration
ls -la /boot/grub/

# Check kernel
uname -r

# Check initramfs
ls -la /boot/initramfs-*.img
```

### 9. Check Configuration File

```bash
# View installation configuration
cat /root/archinstaller/configs/setup.conf

# Verify all required variables are set
grep -E "^[A-Z_]+=" /root/archinstaller/configs/setup.conf
```

### 10. Common Issues and Solutions

#### Issue: Desktop Environment Not Starting

```bash
# Check display manager status
systemctl status lightdm  # or sddm/gdm

# Check X11/Wayland logs
journalctl -u lightdm -n 50  # or sddm/gdm

# Try starting manually
sudo systemctl start lightdm
```

#### Issue: Network Not Working

```bash
# Check NetworkManager
systemctl status NetworkManager
sudo systemctl start NetworkManager

# Check network interfaces
ip link show

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

#### Issue: Swap Not Working

```bash
# Check swap status
swapon --show
free -h

# Check ZRAM (if configured)
zramctl
cat /proc/swaps

# Check swap file (if created)
ls -lh /swapfile

# Check for failed systemd swap units
systemctl --failed | grep swap

# Fix swap file issues
# Option 1: Use the fix script (if available)
sudo ~/.archinstaller/fix-swap.sh

# Option 2: Manual fix
# Deactivate and remove old swap
sudo swapoff /swapfile 2>/dev/null || true
sudo rm -f /swapfile

# Remove systemd units
sudo systemctl stop swapfile.swap 2>/dev/null || true
sudo systemctl disable swapfile.swap 2>/dev/null || true
sudo rm -f /etc/systemd/system/swapfile.swap
sudo systemctl daemon-reload

# Remove from fstab
sudo sed -i '/\/swapfile/d' /etc/fstab

# Recreate swap file (4GB example, adjust as needed)
# For Btrfs:
sudo mkswap -U clear --size 4G --file /swapfile
sudo chmod 600 /swapfile
sudo chattr +C /swapfile
sudo btrfs property set /swapfile compression none

# For ext4:
sudo mkswap -U clear --size 4G --file /swapfile
sudo chmod 600 /swapfile

# Activate and add to fstab
sudo swapon /swapfile
echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
```

**Reference**: [ArchWiki - Swap](https://wiki.archlinux.org/title/Swap)

#### Issue: AUR Helper Not Working

```bash
# Check if installed
which yay  # or paru

# Reinstall if needed (as normal user, not root)
cd /tmp
git clone https://aur.archlinux.org/yay.git  # or paru
cd yay
makepkg -si
```

#### Issue: Packages Not Installed

```bash
# Check if package is installed
pacman -Q package-name

# Check installation log for that package
grep -i "package-name" /var/log/install.log

# Try installing manually
sudo pacman -S package-name
```

### 11. Generate Installation Report

Create a comprehensive report of your installation:

```bash
# Create report file
cat > ~/installation-report.txt << 'EOF'
=== ArchInstaller Installation Report ===
Date: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)

=== System Information ===
RAM: $(free -h | grep Mem | awk '{print $2}')
Disk: $(df -h / | tail -1)
CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2)

=== Installation Configuration ===
$(cat /root/archinstaller/configs/setup.conf)

=== Installed Services ===
$(systemctl list-unit-files --state=enabled | grep -E 'enabled|static')

=== Swap Configuration ===
$(swapon --show)
$(free -h)

=== Errors Found in Log ===
$(grep -i "error\|failed\|fail" /var/log/install.log | tail -20)

=== Warnings Found in Log ===
$(grep -i "warning" /var/log/install.log | tail -20)
EOF

# View report
cat ~/installation-report.txt
```

### 12. What to Report if Issues Found

If you encounter errors, gather this information:

1. **Configuration** (from `/root/archinstaller/configs/setup.conf`):
   ```bash
   cat /root/archinstaller/configs/setup.conf | grep -v PASSWORD
   ```

2. **Relevant log sections**:
   ```bash
   grep -A 10 -B 10 "ERROR_MESSAGE" /var/log/install.log
   ```

3. **System information**:
   ```bash
   uname -a
   free -h
   lsblk
   ```

4. **What commit/branch** you used:
   ```bash
   cd /root/archinstaller
   git log -1 --oneline
   git branch
   ```

5. **Installation environment**:
   - VM (VMware, VirtualBox, QEMU/KVM) or bare metal
   - If VM, what configuration (RAM, CPU, disk size)

---

## Auto Suspend/Hibernate (i3-wm)

### Como Testar a Implementação de Suspend/Hibernate

Após a instalação do sistema com i3-wm, você pode verificar se a implementação de suspend/hibernate automático está funcionando corretamente:

#### 1. Verificações Básicas

**Verificar se `xidlehook` está instalado**:
```bash
which xidlehook
xidlehook --version
```

**Se não estiver instalado** (porque escolheu `AUR_HELPER=NONE`):
```bash
# Instalar base-devel e git primeiro
sudo pacman -S base-devel git

# Clonar e compilar xidlehook manualmente
cd /tmp
git clone https://aur.archlinux.org/xidlehook.git
cd xidlehook
makepkg -si
```

**Verificar se os scripts estão instalados**:
```bash
ls -la /usr/local/bin/auto-suspend-hibernate
ls -la /usr/local/bin/check-swap-for-hibernate

# Testar scripts
/usr/local/bin/check-swap-for-hibernate --help
/usr/local/bin/auto-suspend-hibernate --help
```

**Verificar se o i3 config está configurado**:
```bash
grep -i "xidlehook" ~/.config/i3/config
# Deve mostrar algo como:
# exec --no-startup-id xidlehook \
#   --not-when-audio \
#   --not-when-fullscreen \
#   --timer 1800 \
#   'notify-send -u normal "Inatividade" "O sistema irá hibernar/suspender em 30 segundos..."' \
#   '' \
#   --timer 30 \
#   '/usr/local/bin/auto-suspend-hibernate' \
#   ''
```

**Verificar configuração do GRUB (resume=)**:
```bash
grep -i "resume" /etc/default/grub
# Deve mostrar algo como:
# GRUB_CMDLINE_LINUX_DEFAULT="... resume=UUID=..."
```

**Verificar swap**:
```bash
# Verificar swap ativo
swapon --show
free -h

# Verificar se swap é suficiente para hibernação
/usr/local/bin/check-swap-for-hibernate --verbose
```

**Verificar configuração do systemd logind**:
```bash
cat /etc/systemd/logind.conf.d/50-hibernate.conf
# Deve mostrar configurações de lid switch e power keys
```

#### 2. Testes Manuais

**Testar detecção de energia (AC/Bateria)**:
```bash
# Verificar status de energia
acpi -a  # Deve mostrar "on-line" ou "off-line"
acpi -b  # Deve mostrar status da bateria

# Testar script de suspend/hibernate (verbose para ver o que decide)
/usr/local/bin/auto-suspend-hibernate --verbose
```

**Testar hibernação manual**:
```bash
# Verificar swap primeiro
/usr/local/bin/check-swap-for-hibernate --verbose

# Se swap for suficiente, testar hibernação manual
# AVISO: Isso vai hibernar o sistema!
systemctl hibernate

# Após retornar, verificar se programas ainda estão abertos
```

**Testar suspensão manual**:
```bash
# Testar suspensão manual
# AVISO: Isso vai suspender o sistema!
systemctl suspend

# Após retornar, verificar se sistema retornou rapidamente
```

#### 3. Testar xidlehook Manualmente

**Testar xidlehook com tempo reduzido** (para teste rápido):
```bash
# Parar xidlehook se estiver rodando (do autostart do i3)
pkill xidlehook

# Testar com tempo reduzido (30 segundos até aviso, 10 segundos até ação)
xidlehook \
  --not-when-audio \
  --not-when-fullscreen \
  --timer 30 \
  'notify-send -u normal "Teste" "Aviso de inatividade!"' \
  '' \
  --timer 10 \
  '/usr/local/bin/auto-suspend-hibernate' \
  ''

# Agora não mexa no computador por 30 segundos
# Você deve ver uma notificação após 30 segundos
# O sistema deve suspender/hibernar após mais 10 segundos (40 segundos total)
```

**Verificar se xidlehook está rodando**:
```bash
ps aux | grep xidlehook
# Deve mostrar processo do xidlehook rodando
```

**Ver logs do xidlehook** (se houver):
```bash
# Verificar logs do systemd (se xidlehook foi iniciado via systemd)
journalctl --user -f | grep -i xidlehook
```

#### 4. Testar Comportamento Automático

**Reiniciar o i3** para garantir que xidlehook inicia:
```bash
# No i3-wm, pressione Mod+Shift+R (geralmente Alt+Shift+R)
# Ou reinciar o i3 manualmente
i3-msg restart
```

**Verificar se xidlehook iniciou automaticamente**:
```bash
# Aguardar alguns segundos após login no i3
ps aux | grep xidlehook
```

**Testar inatividade**:
1. Faça login no i3-wm
2. Não mexa no computador por **30 minutos e 30 segundos** (tempo padrão configurado)
3. Após 30 minutos, você deve ver uma notificação: "O sistema irá hibernar/suspender em 30 segundos..."
4. Se não mexer, após mais 30 segundos o sistema deve suspender ou hibernar

**Comportamento esperado**:
- **Com carregador conectado (AC)**: Sistema suspende (suspend to RAM)
- **Sem carregador (Bateria)**:
  - Se swap >= RAM: Sistema hiberna (suspend to disk)
  - Se swap < RAM: Sistema suspende (suspend to RAM, fallback)

**Durante áudio ou tela cheia**: xidlehook não executa (graças a `--not-when-audio` e `--not-when-fullscreen`)

#### 5. Verificações de Troubleshooting

**Problema: xidlehook não inicia automaticamente**

```bash
# Verificar i3 config
cat ~/.config/i3/config | grep -A 10 xidlehook

# Verificar se xidlehook está instalado
which xidlehook

# Tentar iniciar manualmente
xidlehook --help
```

**Problema: Script auto-suspend-hibernate não funciona**

```bash
# Testar script manualmente com verbose
/usr/local/bin/auto-suspend-hibernate --verbose

# Verificar permissões
ls -la /usr/local/bin/auto-suspend-hibernate
ls -la /usr/local/bin/check-swap-for-hibernate

# Verificar se acpi está instalado
which acpi
acpi -b
```

**Problema: Hibernação não funciona (sempre suspende)**

```bash
# Verificar swap
swapon --show
free -h
/usr/local/bin/check-swap-for-hibernate --verbose

# Verificar GRUB resume=
grep resume /etc/default/grub
# Se não houver resume=, regenerar GRUB:
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Verificar se swap file existe
ls -lh /swapfile

# Verificar UUID do swap
sudo findmnt -no UUID -T /swapfile
# Ou
sudo blkid | grep swap
```

**Problema: Sistema não retorna da hibernação**

```bash
# Verificar se resume= está no GRUB
grep resume /boot/grub/grub.cfg

# Verificar se UUID está correto
sudo blkid | grep swap
grep resume /etc/default/grub

# Regenerar initramfs (pode ajudar)
sudo mkinitcpio -P
```

**Problema: xidlehook executa mesmo com áudio/tela cheia**

```bash
# Verificar configuração no i3 config
grep -A 10 xidlehook ~/.config/i3/config
# Deve ter --not-when-audio e --not-when-fullscreen

# Reiniciar i3 para aplicar mudanças
i3-msg restart
```

#### 6. Comandos Úteis para Diagnóstico

```bash
# Verificar tudo de uma vez
echo "=== Verificando Auto Suspend/Hibernate ==="
echo ""
echo "1. xidlehook instalado:"
which xidlehook && xidlehook --version || echo "Não instalado"
echo ""
echo "2. Scripts instalados:"
ls -la /usr/local/bin/auto-suspend-hibernate /usr/local/bin/check-swap-for-hibernate 2>/dev/null || echo "Scripts não encontrados"
echo ""
echo "3. i3 config configurado:"
grep -q xidlehook ~/.config/i3/config && echo "✓ Configurado" || echo "✗ Não configurado"
echo ""
echo "4. GRUB resume=:"
grep -q resume /etc/default/grub && echo "✓ Configurado" || echo "✗ Não configurado"
echo ""
echo "5. Swap status:"
swapon --show
echo ""
echo "6. Swap suficiente para hibernação:"
/usr/local/bin/check-swap-for-hibernate --verbose 2>/dev/null || echo "Script não encontrado"
echo ""
echo "7. Status de energia:"
acpi -a 2>/dev/null || echo "acpi não disponível"
echo ""
echo "8. xidlehook rodando:"
ps aux | grep -v grep | grep xidlehook && echo "✓ Rodando" || echo "✗ Não está rodando"
```

#### 7. Personalização (Opcional)

**Alterar tempos de inatividade**:

Edite `~/.config/i3/config` e modifique os valores de `--timer`:
```bash
# Tempo padrão: 30 minutos (1800 segundos) até aviso, 30 segundos até ação
# Para testar mais rápido, use: --timer 60 (1 minuto) e --timer 10 (10 segundos)
exec --no-startup-id xidlehook \
  --not-when-audio \
  --not-when-fullscreen \
  --timer 1800 \  # Alterar para tempo desejado (em segundos)
  'notify-send ...' \
  '' \
  --timer 30 \  # Alterar para tempo desejado (em segundos)
  '/usr/local/bin/auto-suspend-hibernate' \
  ''
```

**Reiniciar i3** após alterar:
```bash
i3-msg restart
```

---

## Battery Notifications (i3-wm)

### Problem: Battery notifications not working

**Symptoms**: No notifications appear for battery level or charger connection.

**Diagnosis**:

```bash
# Check if timer is enabled
systemctl --user status battery-alert.timer

# Check if scripts exist
ls -la /usr/local/bin/battery-*

# Check if dependencies are installed
which acpi
which notify-send

# Check if dunst is running (notification daemon)
systemctl --user status dunst

# Test script manually
/usr/local/bin/battery-alert

# Check systemd unit files
ls -la ~/.config/systemd/user/battery-alert.*

# Check udev rules
ls -la /etc/udev/rules.d/60-battery-notifications.rules
```

**Solutions**:

#### Timer not enabled
```bash
# Enable and start timer
systemctl --user enable battery-alert.timer
systemctl --user start battery-alert.timer

# Reload systemd user daemon if needed
systemctl --user daemon-reload
```

#### Dependencies missing
```bash
# Install required packages
sudo pacman -S acpi libnotify

# Start notification daemon (dunst should be in i3 autostart)
dunst &
```

#### Scripts not found
```bash
# If configs are available, copy scripts manually
sudo cp ~/.archinstaller/configs/i3-wm/usr/local/bin/battery-* /usr/local/bin/
sudo chmod 755 /usr/local/bin/battery-*

# Copy systemd units
mkdir -p ~/.config/systemd/user/
cp ~/.archinstaller/configs/i3-wm/etc/skel/.config/systemd/user/* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable battery-alert.timer
```

#### Dunst not running
```bash
# Start dunst manually
dunst &

# Add to i3 config if not present
echo 'exec --no-startup-id dunst' >> ~/.config/i3/config

# Restart i3 (press Mod+Shift+R in i3)
```

#### Udev rules not working
```bash
# Check if udev rules exist
cat /etc/udev/rules.d/60-battery-notifications.rules

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=power_supply

# Test udev trigger manually
sudo udevadm trigger --action=change --subsystem-match=power_supply
```

#### Desktop system (no battery)
**Expected behavior**: Scripts exit silently if no battery is detected. This is normal.

```bash
# Check if battery exists
acpi -b

# If no output, system doesn't have a battery (desktop)
# Notifications won't work, but this is expected
```

### Problem: Too many notifications

**Solution**: Lock files prevent duplicate notifications. They are automatically managed, but you can clear them manually:

```bash
# Remove lock files (resets notification state)
rm -f /tmp/battery-$USER-*
```

### Problem: Want to customize notification levels

**Solution**: Edit the script:

```bash
# Edit warning/critical levels
sudo nano /usr/local/bin/battery-alert

# Change these lines:
# WARNING_LEVEL=20   # Change to your preferred level
# CRITICAL_LEVEL=5   # Change to your preferred level
```

### Problem: Want to change check interval

**Solution**: Edit the systemd timer:

```bash
# Edit timer unit
systemctl --user edit battery-alert.timer

# Or edit file directly
nano ~/.config/systemd/user/battery-alert.timer

# Change these lines:
# OnBootSec=5min      # Time after boot to first check
# OnUnitActiveSec=5min # Interval between checks
```

### Useful Commands

```bash
# View help for scripts
battery-alert --help
battery-charging --help
battery-udev-notify --help

# Check timer logs
journalctl --user -u battery-alert.service -f

# View timer status
systemctl --user status battery-alert.timer

# Disable notifications
systemctl --user disable battery-alert.timer
systemctl --user stop battery-alert.timer

# Re-enable notifications
systemctl --user enable battery-alert.timer
systemctl --user start battery-alert.timer
```

---

## Quick Commands Summary

```bash
# Most important checks
grep -i error /var/log/install.log | tail -20
systemctl --failed
swapon --show
systemctl status NetworkManager
pacman -Q | grep -i "your-desktop-env"
```

---

## Success Indicators

✅ **Installation was successful if:**
- No critical errors in `/var/log/install.log`
- All services start without errors (`systemctl --failed` shows nothing)
- Desktop environment starts correctly
- Network connectivity works
- Swap is configured and active
- User can log in
- All selected packages are installed

---

For more help, check:
- [Arch Linux Wiki](https://wiki.archlinux.org)
- [ArchInstaller Issues](https://github.com/limaon/ArchInstaller/issues)

