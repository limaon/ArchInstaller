# Guia de Uso do ArchInstaller

Este guia detalha como usar o ArchInstaller para instalar Arch Linux em uma máquina virtual ou física.

---

## 🎯 Pré-requisitos

### Hardware Mínimo Recomendado
- **CPU**: x86_64 com 2+ cores
- **RAM**: 2GB mínimo (4GB+ recomendado)
- **Disco**: 20GB mínimo (40GB+ recomendado)
- **Rede**: Conexão ativa com internet

### Antes de Começar
1. Faça backup de todos os dados importantes
2. Baixe a ISO mais recente do Arch Linux: https://archlinux.org/download/
3. Crie USB bootável ou configure VM com a ISO
4. Boot na ISO do Arch Linux

---

## 📥 Instalação Passo a Passo

### Passo 1: Boot na ISO do Arch Linux

Você verá um prompt assim:
```
root@archiso ~ #
```

### Passo 2: Conectar à Internet

**Ethernet (cabeada)**: Geralmente funciona automaticamente

**Wi-Fi**:
```bash
# Listar interfaces
ip link

# Conectar usando iwctl
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "Nome_da_Rede"
[iwd]# exit

# Testar conexão
ping -c 3 archlinux.org
```

### Passo 3: Clonar o Repositório

```bash
# Instalar git se necessário (já está na ISO)
pacman -Sy git

# Clonar o repositório
git clone https://github.com/seu-usuario/ArchInstaller
cd ArchInstaller
```

### Passo 4: Executar o Instalador

```bash
# Dar permissão de execução
chmod +x archinstall.sh

# Executar
./archinstall.sh
```

---

## ⚙️ Processo de Configuração Interativa

O instalador fará uma série de perguntas. Vamos detalhar cada uma:

### 1️⃣ Informações do Usuário

```
Please enter your full name (e.g., David Brown):
```
Digite seu nome completo. Ex: `João Silva`

```
Please enter username:
```
Digite o nome de usuário (minúsculas, sem espaços). Ex: `joao`

```
Please enter password:
Please re-enter password:
```
Digite uma senha forte e confirme.

```
Please name your machine:
```
Nome do computador (hostname). Ex: `archlinux` ou `meu-pc`

---

### 2️⃣ Tipo de Instalação

```
Please select type of installation:
  Full Install: Installs full featured desktop environment
  Minimal Install: Installs only few selected apps
  Server Install: Installs only base system without desktop
```

**Escolha**:
- **FULL**: Desktop completo + apps (Firefox, LibreOffice, etc.) + temas + extras
- **MINIMAL**: Desktop básico + poucos apps essenciais
- **SERVER**: Apenas linha de comando (sem interface gráfica)

Use setas ↑↓ para navegar, Enter para confirmar.

---

### 3️⃣ AUR Helper (se não for SERVER)

```
Please select your desired AUR helper:
  paru
  yay
  picaur
  aura
  trizen
  pacaur
  NONE
```

**Recomendação**: `yay` ou `paru` (mais populares e atualizados)

**O que é?**: AUR (Arch User Repository) contém pacotes mantidos pela comunidade.

---

### 4️⃣ Ambiente Desktop (se não for SERVER)

```
Please select your desired Desktop Environment:
  kde
  gnome
  xfce
  cinnamon
  i3-wm
  awesome
  openbox
  budgie
  deepin
  lxde
  mate
```

**Recomendações**:
- **Iniciantes**: KDE Plasma ou GNOME (completos e polidos)
- **Leve**: XFCE, LXDE ou MATE
- **Avançado**: i3-wm ou Awesome (window managers)

---

### 5️⃣ Seleção de Disco

```
------------------------------------------------------------------------
    ⚠️  THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK!
    Please make sure you know what you are doing because
    after formatting your disk there is no way to get data back
------------------------------------------------------------------------

Select the disk to install on:
  /dev/sda  |  50G
  /dev/sdb  |  100G
```

**⚠️ ATENÇÃO**: O disco escolhido será COMPLETAMENTE APAGADO!

**Em VMs**: Geralmente `/dev/sda` ou `/dev/vda`
**Físico**: Verifique o tamanho para escolher o disco correto

Use setas para selecionar, Enter para confirmar.

---

### 6️⃣ Sistema de Arquivos

```
Please Select your file system for both boot and root
  btrfs
  ext4
  luks
  exit
```

**Escolha**:

- **ext4**: 
  - ✅ Simples, rápido, confiável
  - ❌ Sem snapshots nativos
  - **Use se**: Quer simplicidade

- **btrfs**:
  - ✅ Snapshots (backups incrementais)
  - ✅ Compressão transparente (economiza espaço)
  - ✅ Recuperação de falhas
  - ❌ Mais complexo
  - **Use se**: Quer recursos avançados

- **luks**:
  - ✅ Criptografia total do disco
  - ✅ Segurança máxima
  - ❌ Precisa senha ao boot
  - ❌ Performance levemente menor
  - **Use se**: Segurança é prioridade (laptops, dados sensíveis)

**Se escolher btrfs**:
```
Please enter your btrfs subvolumes separated by space.
Usually they start with @.
For example: @docker @flatpak @home @opt @snapshots @var_cache @var_log @var_tmp

Press enter to use the default subvolumes:
```

Recomendação: **Apenas pressione Enter** para usar os padrões.

**Se escolher luks**:
```
Please enter password:
Please re-enter password:
```
Digite uma senha FORTE para criptografia (diferente da senha do usuário).

---

### 7️⃣ Timezone

```
System detected your timezone to be 'America/Sao_Paulo'
Is this correct?
  Yes
  No
```

Se incorreto, escolha "No" e digite manualmente. Ex: `America/Fortaleza`, `Europe/London`

---

### 8️⃣ Idioma do Sistema (Locale)

```
Please select your system language (locale) from the list below:
  en_US.UTF-8
  pt_BR.UTF-8
  es_ES.UTF-8
  fr_FR.UTF-8
  de_DE.UTF-8
  ...
```

**Importante**: Isso afeta idioma do sistema, formatos de data/hora, moeda, etc.

---

### 9️⃣ Layout do Teclado

```
Please select keyboard layout from this list:
  us
  br-abnt2
  by
  ca
  de
  es
  fr
  ...
```

**Brasileiros**: Escolha `br-abnt2` (ABNT2) ou `us` (Internacional)

---

### 🔟 Revisão de Configurações

```
------------------------------------------------------------------------
                    Configuration Summary
------------------------------------------------------------------------
REAL_NAME=João Silva
USERNAME=joao
NAME_OF_MACHINE=archlinux
INSTALL_TYPE=FULL
AUR_HELPER=yay
DESKTOP_ENV=kde
DISK=/dev/sda
FS=btrfs
TIMEZONE=America/Sao_Paulo
LOCALE=pt_BR.UTF-8
KEYMAP=br-abnt2
------------------------------------------------------------------------
Do you want to redo any step? Select an option below, or press Enter to proceed:
1) Full Name, Username and Password
2) Installation Type
3) AUR Helper
4) Desktop Environment
5) Disk Selection
6) File System
7) Timezone
8) System Language (Locale)
9) Keyboard Layout
------------------------------------------------------------------------
```

**Revise TUDO cuidadosamente!**

- Se algo estiver errado, digite o número e refaça
- Se tudo estiver correto, **pressione Enter** para começar a instalação

---

## 🚀 Instalação Automática

Após confirmar, a instalação começa automaticamente. Isso pode levar de **15 a 60 minutos** dependendo da sua internet e hardware.

### O que acontece em cada fase:

#### FASE 0: Pré-Instalação (5-10 min)
```
-------------------------------------------------------------------------
                    Formatting /dev/sda
-------------------------------------------------------------------------
```
- Atualiza mirrors
- Particiona disco
- Cria filesystems
- Instala sistema base (kernel, pacotes essenciais)
- Instala bootloader GRUB

**Você verá**: Muitas linhas de pacotes sendo baixados e instalados

---

#### FASE 1: Setup do Sistema (10-20 min)
```
-------------------------------------------------------------------------
                    SYSTEM READY FOR 1-setup.sh
-------------------------------------------------------------------------
```
- Configura rede, locale, timezone
- Instala pacotes base
- Detecta e instala microcode (Intel/AMD)
- Detecta e instala drivers de GPU
- Cria seu usuário

**Você verá**: Configurações sendo aplicadas, mais pacotes instalados

---

#### FASE 2: Instalação de Usuário (15-30 min)
```
-------------------------------------------------------------------------
                    SYSTEM READY FOR 2-user.sh
-------------------------------------------------------------------------
```
- Compila e instala AUR helper (yay/paru)
- Instala fontes
- Instala ambiente desktop completo
- Instala temas e configurações

**Você verá**: Muitos pacotes do desktop sendo instalados, compilação do AUR helper

⚠️ **Esta é a fase mais demorada!**

---

#### FASE 3: Finalização (5-10 min)
```
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
```
- Configura GRUB (bootloader)
- Configura display manager (tela de login)
- Habilita serviços (rede, bluetooth, impressão, etc.)
- Configura snapshots (se btrfs)
- Cleanup de arquivos temporários

**Você verá**: Serviços sendo habilitados, configurações finais

---

### Conclusão

```
            Done - Please Eject Install Media and Reboot
```

Quando ver esta mensagem:

1. **Em VM**: Remova a ISO da VM
2. **USB físico**: Remova o pendrive
3. **Reinicie**:
   ```bash
   reboot
   ```

---

## 🎉 Primeiro Boot no Sistema Instalado

### 1. Tela de Login

Você verá a tela de login gráfica (SDDM, GDM ou LightDM).

- Digite seu **username** (não o nome completo)
- Digite sua **senha**
- Selecione a sessão desktop (já deve estar correta)
- Clique em "Login"

### 2. Primeiro Uso

**KDE Plasma**: Bem-vindo ao KDE! Explore o menu de aplicativos.
**GNOME**: Pressione Super (tecla Windows) para ver atividades.
**i3/Awesome**: Leia a documentação do WM (teclas customizadas).

### 3. Conectar Wi-Fi (se aplicável)

- **KDE/GNOME**: Clique no ícone de rede no painel
- **Terminal**: Use `nmtui` ou `nmcli`

---

## 🔧 Pós-Instalação Recomendada

### Atualizar o Sistema

```bash
# Atualizar tudo
sudo pacman -Syu

# Se tiver AUR helper
yay -Syu
```

### Instalar Apps Adicionais

```bash
# Browser alternativo
sudo pacman -S chromium

# Editor de código
yay -S visual-studio-code-bin

# Cliente de email
sudo pacman -S thunderbird

# Reprodutor de vídeo
sudo pacman -S vlc
```

### Configurar Firewall (se FULL install)

O UFW já está habilitado! Para modificar:

```bash
# Ver status
sudo ufw status

# Permitir porta específica
sudo ufw allow 8080/tcp

# Negar porta
sudo ufw deny 3000/tcp
```

### Verificar Serviços

```bash
# Ver serviços ativos
systemctl list-units --type=service --state=running

# Importante verificar:
systemctl status NetworkManager    # Rede
systemctl status bluetooth         # Bluetooth (FULL)
systemctl status sddm             # Display manager (KDE)
```

---

## 🐛 Solução de Problemas

### Problema: Boot direto no GRUB rescue

**Causa**: Bootloader não instalado corretamente

**Solução**:
1. Boot na ISO novamente
2. Monte as partições:
   ```bash
   mount /dev/sdaX /mnt  # Substitua X pela partição root
   mount /dev/sdaY /mnt/boot  # Se UEFI
   arch-chroot /mnt
   grub-install --target=x86_64-efi --efi-directory=/boot /dev/sda
   grub-mkconfig -o /boot/grub/grub.cfg
   exit
   reboot
   ```

---

### Problema: Tela preta após login

**Causa**: Driver de GPU incorreto ou display manager

**Solução**:
```bash
# Ctrl+Alt+F2 para terminal
# Login com seu usuário

# Reinstalar drivers
sudo pacman -S xf86-video-vesa  # Driver genérico

# Ou para Intel
sudo pacman -S xf86-video-intel

# Reiniciar display manager
sudo systemctl restart sddm  # ou gdm, lightdm
```

---

### Problema: Sem conexão de rede após instalação

**Solução**:
```bash
# Verificar se NetworkManager está ativo
sudo systemctl status NetworkManager

# Se não, ativar
sudo systemctl enable --now NetworkManager

# Conectar Wi-Fi via terminal
nmtui
```

---

### Problema: Snapshots não funcionam (btrfs)

**Verificar**:
```bash
# Ver configuração do Snapper
sudo snapper -c root list-configs

# Ver snapshots
sudo snapper -c root list

# Criar snapshot manual
sudo snapper -c root create --description "teste"
```

---

### Problema: Sistema lento em VM

**Otimizações**:

1. Aumentar RAM da VM para 4GB+
2. Dar mais cores de CPU (2-4)
3. Habilitar aceleração 3D na VM
4. Se VirtualBox, instalar guest additions:
   ```bash
   sudo pacman -S virtualbox-guest-utils
   sudo systemctl enable vboxservice
   ```

---

## 📊 Logs de Instalação

Todos os logs estão em `/var/log/install.log`:

```bash
# Ver log completo
less /var/log/install.log

# Buscar erros
grep -i error /var/log/install.log

# Últimas 50 linhas
tail -n 50 /var/log/install.log
```

---

## 🎓 Próximos Passos

1. **Aprenda sobre Arch**: https://wiki.archlinux.org
2. **Personalize seu desktop**: Temas, ícones, wallpapers
3. **Instale seus apps favoritos**: Steam, Discord, Spotify, etc.
4. **Configure snapshots automáticos** (se btrfs):
   ```bash
   sudo systemctl enable --now snapper-timeline.timer
   sudo systemctl enable --now snapper-cleanup.timer
   ```

---

Aproveite seu novo sistema Arch Linux! 🎉
