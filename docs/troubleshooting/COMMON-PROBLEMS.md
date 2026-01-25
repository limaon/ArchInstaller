# Common Problems - ArchInstaller

This document organizes the most frequent problems into categories for quick diagnosis and solution.

## Boot Issues

### Problem: Desktop Environment Doesn't Start

**Symptoms:**
- System boots but screen stays black or shows only prompt
- Display manager (lightdm/sddm/gdm) doesn't work

**Diagnosis:**
```bash
# Check display manager status
systemctl status lightdm  # or sddm/gdm

# Check X11/Wayland logs
journalctl -u lightdm -n 50  # or sddm/gdm

# Try to start manually
sudo systemctl start lightdm
```

**Solutions:**

#### Solution 1: Check Drivers
```bash
# Check installed graphics drivers
pacman -Q | grep -E "(nvidia|amd|intel|mesa)"

# Reinstall drivers based on your GPU
# For Intel:
sudo pacman -S intel-media-driver libva-intel-driver

# For AMD:
sudo pacman -S mesa-drm

# For NVIDIA:
sudo pacman -S nvidia
```

#### Solution 2: Check Display Manager Configuration
```bash
# Check lightdm configuration
cat /etc/lightdm/lightdm.conf

# Test simple configuration
sudo nano /etc/lightdm/lightdm.conf
# Add/modify:
# [Seat:*]
# greeter-session=lightdm-gtk-greeter
# user-session=your-desktop-env
```

#### Solution 3: Restart Xorg
```bash
# Kill Xorg
sudo pkill Xorg

# Restart display manager
sudo systemctl restart lightdm
```

---

### Problem: System Doesn't Boot

**Symptoms:**
- Grub doesn't appear
- System stops during boot

**Diagnosis:**
```bash
# Check GRUB
ls -la /boot/grub/
ls -la /boot/grub/grub.cfg

# Check kernel
uname -r
ls -la /boot/initramfs-*.img

# Check boot errors
journalctl -b -p err
```

**Solutions:**

#### Solution 1: Regenerate GRUB
```bash
# Regenerate GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg

# If using LUKS, use:
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

#### Solution 2: Regenerate Initramfs
```bash
# Regenerate initramfs
sudo mkinitcpio -P
```

---

## Network Problems

### Problem: Network Doesn't Work

**Symptoms:**
- No internet connection after boot
- NetworkManager doesn't start

**Diagnosis:**
```bash
# Check NetworkManager status
systemctl status NetworkManager

# Check network interfaces
ip link show
nmcli device status

# Check if wifi is blocked
rfkill list
```

**Solutions:**

#### Solution 1: Restart NetworkManager
```bash
# Start NetworkManager
sudo systemctl start NetworkManager

# Enable to start on boot
sudo systemctl enable NetworkManager

# Restart service
sudo systemctl restart NetworkManager
```

#### Solution 2: Unblock WiFi
```bash
# Check if WiFi is blocked
rfkill list

# If shows "Soft blocked: yes":
rfkill unblock wifi
```

#### Solution 3: Connect via iwctl (WiFi)
```bash
# Open iwctl
iwctl

# List devices
device list

# Scan networks
station [device-name] scan

# List found networks
station [device-name] get-networks

# Connect to network
station [device-name] connect [network-name]

# Exit iwctl
exit
```

---

### Problem: AUR Helper Doesn't Work

**Symptoms:**
- `yay` or `paru` commands not found
- Errors when installing AUR packages

**Diagnosis:**
```bash
# Check if installed
which yay  # or paru
yay --version  # or paru --version
```

**Solutions:**

#### Solution 1: Reinstall YAY
```bash
# Download and compile YAY
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

#### Solution 2: Reinstall Paru
```bash
# Download and compile Paru
cd /tmp
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

---

## Package Installation Problems

### Problem: Packages Don't Install

**Symptoms:**
- Errors when installing packages with `pacman -S`
- Packages marked as "not found"

**Diagnosis:**
```bash
# Check if package exists
pacman -Ss package-name

# Check repositories
cat /etc/pacman.conf

# Check mirrors
cat /etc/pacman.d/mirrorlist
```

**Solutions:**

#### Solution 1: Update Databases
```bash
# Update databases
sudo pacman -Sy
```

#### Solution 2: Check and Update Mirrors
```bash
# Update mirrors automatically
sudo pacman -S reflector
sudo reflector --latest 20 --country Brazil --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Update databases with new mirrors
sudo pacman -Sy
```

#### Solution 3: Clear Pacman Cache
```bash
# Clear pacman cache
sudo pacman -Scc

# Reinstall problem package
sudo pacman -S package-name
```

---

## Hardware Detection Problems

### Problem: Hardware Not Detected

**Symptoms:**
- Webcam, audio, or other devices don't work
- Hardware detectors show incorrect information

**Diagnosis:**
```bash
# Check video hardware
lspci | grep -i vga

# Check USB devices
lsusb

# Check audio devices
lspci | grep -i audio

# Check input devices
lsinput
```

**Solutions:**

#### Solution 1: Install Specific Drivers
```bash
# Webcam
sudo pacman -S v4l2-utils cheese

# Audio (for Intel)
sudo pacman -S alsa-utils pulseaudio pulseaudio-alsa

# Touchpad
sudo pacman -S xf86-input-synaptics
```

#### Solution 2: Check Kernel Modules
```bash
# Check loaded modules
lsmod | grep -E "(video|audio|usb)"

# Manually load module
sudo modprobe module-name

# Add to blacklist if necessary
echo "blacklist module-name" | sudo tee /etc/modprobe.d/blacklist.conf
```

---

## Common Verification Issues

### Problem: Swap Doesn't Work

**Symptoms:**
- System slow with high RAM usage
- Insufficient memory messages

**Diagnosis:**
```bash
# Check swap status
swapon --show
free -h
cat /proc/swaps
```

**Solutions:**
See the [Swap Guide](./SPECIFIC-FEATURES.md#swap-configuration) for specific solutions.

---

### Problem: Services Failing

**Symptoms:**
- `systemctl --failed` shows services not started

**Diagnosis:**
```bash
# Check failed services
systemctl --failed

# Check specific logs
journalctl -u service-name -n 50
```

**Solutions:**

#### Solution 1: Enable Service
```bash
# Enable to start on boot
sudo systemctl enable service-name

# Start manually
sudo systemctl start service-name
```

#### Solution 2: Check Dependencies
```bash
# Check service dependencies
systemctl status service-name
```

---

## General Troubleshooting Tips

### 1. Logs Are Your Friends
```bash
# System logs
journalctl -b -p err          # Errors since boot
journalctl -u service-name -f  # Specific service logs

# Installation logs
grep -i "error\|failed" /var/log/install.log
```

### 2. Permission Issues
```bash
# Check permissions
ls -la /path/to/file

# Fix permissions
sudo chown $USER:$USER /path/to/file
sudo chmod 755 /path/to/file
```

### 3. Disk Space
```bash
# Check disk space
df -h

# Clear pacman cache
sudo pacman -Scc
```

---

## References

- [Arch Linux Wiki - Troubleshooting](https://wiki.archlinux.org/Troubleshooting)
- [Arch Linux Wiki - Common Issues](https://wiki.archlinux.org/Common_issues)

Next: [Specific Features](./SPECIFIC-FEATURES.md)
```

**Soluções:**

#### Solução 1: Verificar Drivers
```bash
# Verificar drivers gráficos instalados
pacman -Q | grep -E "(nvidia|amd|intel|mesa)"

# Reinstalar drivers conforme seu GPU
# Para Intel:
sudo pacman -S intel-media-driver libva-intel-driver

# Para AMD:
sudo pacman -S mesa-drm

# Para NVIDIA:
sudo pacman -S nvidia
```

#### Solução 2: Verificar Configuração do Display Manager
```bash
# Verificar configuração do lightdm
cat /etc/lightdm/lightdm.conf

# Testar configuração simples
sudo nano /etc/lightdm/lightdm.conf
# Adicionar/alterar:
# [Seat:*]
# greeter-session=lightdm-gtk-greeter
# user-session=your-desktop-env
```

#### Solução 3: Reiniciar Xorg
```bash
# Matar Xorg
sudo pkill Xorg

# Reiniciar display manager
sudo systemctl restart lightdm
```

---

### Problema: Sistema Não Faz Boot

**Sintomas:**
- Grub não aparece
- Sistema para no meio do boot

**Diagnóstico:**
```bash
# Verificar GRUB
ls -la /boot/grub/
ls -la /boot/grub/grub.cfg

# Verificar kernel
uname -r
ls -la /boot/initramfs-*.img

# Verificar erros de boot
journalctl -b -p err
```

**Soluções:**

#### Solução 1: Regenerar GRUB
```bash
# Regenerar GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Se usar LUKS, usar:
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

#### Solução 2: Regenerar Initramfs
```bash
# Regenerar initramfs
sudo mkinitcpio -P
```

---

## Network Problems

### Problema: Rede Não Funciona

**Sintomas:**
- Sem conexão à internet após boot
- NetworkManager não inicia

**Diagnóstico:**
```bash
# Verificar status do NetworkManager
systemctl status NetworkManager

# Verificar interfaces de rede
ip link show
nmcli device status

# Verificar se wifi está bloqueado
rfkill list
```

**Soluções:**

#### Solução 1: Reiniciar NetworkManager
```bash
# Iniciar NetworkManager
sudo systemctl start NetworkManager

# Habilitar para iniciar no boot
sudo systemctl enable NetworkManager

# Reiniciar serviço
sudo systemctl restart NetworkManager
```

#### Solução 2: Desbloquear WiFi
```bash
# Verificar se WiFi está bloqueado
rfkill list

# Se mostrar "Soft blocked: yes":
rfkill unblock wifi
```

#### Solução 3: Conectar via iwctl (WiFi)
```bash
# Abrir iwctl
iwctl

# Listar dispositivos
device list

# Escanear redes
station [nome-do-dispositivo] scan

# Listar redes encontradas
station [nome-do-dispositivo] get-networks

# Conectar à rede
station [nome-do-dispositivo] connect [nome-da-rede]

# Sair do iwctl
exit
```

---

### Problema: AUR Helper Não Funciona

**Sintomas:**
- Comandos `yay` ou `paru` não encontrados
- Erros ao instalar pacotes AUR

**Diagnóstico:**
```bash
# Verificar se está instalado
which yay  # ou paru
yay --version  # ou paru --version
```

**Soluções:**

#### Solução 1: Reinstalar YAY
```bash
# Baixar e compilar YAY
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

#### Solução 2: Reinstalar Paru
```bash
# Baixar e compilar Paru
cd /tmp
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

---

## Package Installation Problems

### Problema: Pacotes Não Instalam

**Sintomas:**
- Erros ao instalar pacotes com `pacman -S`
- Pacotes marcados como "not found"

**Diagnóstico:**
```bash
# Verificar se pacote existe
pacman -Ss nome-do-pacote

# Verificar repositórios
cat /etc/pacman.conf

# Verificar mirrors
cat /etc/pacman.d/mirrorlist
```

**Soluções:**

#### Solução 1: Atualizar Databases
```bash
# Atualizar databases
sudo pacman -Sy
```

#### Solução 2: Verificar e Atualizar Mirrors
```bash
# Atualizar mirrors automaticamente
sudo pacman -S reflector
sudo reflector --latest 20 --country Brazil --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Atualizar databases com novos mirrors
sudo pacman -Sy
```

#### Solução 3: Limpar Cache do Pacman
```bash
# Limpar cache do pacman
sudo pacman -Scc

# Reinstalar problema
sudo pacman -S nome-do-pacote
```

---

## Hardware Detection Problems

### Problema: Hardware Não Detectado

**Sintomas:**
- Webcam, áudio ou outros dispositivos não funcionam
- Detectores de hardware mostram informações incorretas

**Diagnóstico:**
```bash
# Verificar hardware de vídeo
lspci | grep -i vga

# Verificar dispositivos USB
lsusb

# Verificar dispositivos de áudio
lspci | grep -i audio

# Verificar dispositivos de entrada
lsinput
```

**Soluções:**

#### Solução 1: Instalar Drivers Específicos
```bash
# Webcam
sudo pacman -S v4l2-utils cheese

# Áudio (para Intel)
sudo pacman -S alsa-utils pulseaudio pulseaudio-alsa

# Touchpad
sudo pacman -S xf86-input-synaptics
```

#### Solução 2: Verificar Kernel Modules
```bash
# Verificar módulos carregados
lsmod | grep -E "(video|audio|usb)"

# Carregar módulo manualmente
sudo modprobe nome-do-modulo

# Adicionar a blacklist se necessário
echo "blacklist nome-do-modulo" | sudo tee /etc/modprobe.d/blacklist.conf
```

---

## Problemas Comuns de Verificação

### Problema: Swap Não Funciona

**Sintomas:**
- Sistema lento com uso de RAM alto
- Mensagens de memória insuficiente

**Diagnóstico:**
```bash
# Verificar status do swap
swapon --show
free -h
cat /proc/swaps
```

**Soluções:**
Consulte o [Guia Swap](./SPECIFIC-FEATURES.md#swap-configuration) para soluções específicas.

---

### Problema: Serviços Falhando

**Sintomas:**
- `systemctl --failed` mostra serviços não iniciados

**Diagnóstico:**
```bash
# Verificar serviços falhando
systemctl --failed

# Verificar logs específicos
journalctl -u nome-do-servico -n 50
```

**Soluções:**

#### Solução 1: Habilitar Serviço
```bash
# Habilitar para iniciar no boot
sudo systemctl enable nome-do-servico

# Iniciar manualmente
sudo systemctl start nome-do-servico
```

#### Solução 2: Verificar Dependências
```bash
# Verificar dependências do serviço
systemctl status nome-do-servico
```

---

## Dicas Gerais de Troubleshooting

### 1. Logs São Seus Amigos
```bash
# Logs do sistema
journalctl -b -p err          # Erros desde boot
journalctl -u nome-servico -f  # Logs de serviço específico

# Logs de instalação
grep -i "error\|failed" /var/log/install.log
```

### 2. Problemas de Permissão
```bash
# Verificar permissões
ls -la /caminho/do/arquivo

# Corrigir permissões
sudo chown $USER:$USER /caminho/do/arquivo
sudo chmod 755 /caminho/do/arquivo
```

### 3. Espaço em Disco
```bash
# Verificar espaço em disco
df -h

# Limpar cache do pacman
sudo pacman -Scc
```

---

## Referências

- [Arch Linux Wiki - Troubleshooting](https://wiki.archlinux.org/Troubleshooting)
- [Arch Linux Wiki - Common Issues](https://wiki.archlinux.org/Common_issues)

Próximo: [Recursos Específicos](./SPECIFIC-FEATURES.md)
