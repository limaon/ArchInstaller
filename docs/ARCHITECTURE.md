# Arquitetura do Sistema

Este documento descreve a arquitetura completa do ArchInstaller, incluindo decisões de design, fluxo de dados e estrutura modular.

---

## 📐 Visão Geral Arquitetural

### Princípios de Design

1. **Modularidade**: Cada script tem responsabilidade única e bem definida
2. **Separação de Fases**: Instalação dividida em 4 fases sequenciais
3. **Configuração Centralizada**: Único arquivo `setup.conf` como fonte de verdade
4. **Detecção Automática**: Hardware detectado automaticamente sempre que possível
5. **Idempotência**: Funções podem ser executadas múltiplas vezes com segurança
6. **Logging Completo**: Tudo registrado em `install.log` para debug

---

## 🔄 Modelo de Execução em 4 Fases

### Por que 4 Fases?

A instalação é dividida em fases devido aos diferentes contextos de execução:

```
┌──────────────────────────────────────────────────────────────┐
│ FASE 0: Live ISO Environment (Antes do Chroot)              │
│ - Sistema live do Arch ISO                                  │
│ - Acesso total ao hardware                                  │
│ - Sem sistema instalado ainda                               │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ FASE 1: Chroot como Root                                    │
│ - Dentro do sistema recém-instalado                         │
│ - Privilégios de root                                        │
│ - Configuração de sistema                                   │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ FASE 2: Como Usuário Normal                                 │
│ - Contexto do usuário criado                                │
│ - Instalação de AUR packages                                │
│ - Configurações de usuário                                  │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ FASE 3: Chroot como Root (Finalização)                      │
│ - Volta ao contexto root                                    │
│ - Configuração de serviços do sistema                       │
│ - Cleanup final                                             │
└──────────────────────────────────────────────────────────────┘
```

### Transição Entre Fases

```bash
# Em installer-helper.sh -> sequence()
sequence() {
    # FASE 0: Live ISO
    . "$SCRIPTS_DIR"/0-preinstall.sh
    
    # FASE 1: Root no chroot
    arch-chroot /mnt "$HOME"/archinstaller/scripts/1-setup.sh
    
    # FASE 2: Usuário no chroot (só se não for SERVER)
    if [[ ! "$INSTALL_TYPE" == SERVER ]]; then
        arch-chroot /mnt /usr/bin/runuser -u "$USERNAME" -- \
            /home/"$USERNAME"/archinstaller/scripts/2-user.sh
    fi
    
    # FASE 3: Root no chroot novamente
    arch-chroot /mnt "$HOME"/archinstaller/scripts/3-post-setup.sh
}
```

**Razão**: AUR packages não podem ser compilados como root. Precisamos mudar para contexto de usuário na FASE 2.

---

## 📦 Sistema de Módulos (Scripts Utilitários)

### 1. installer-helper.sh

**Responsabilidade**: Funções auxiliares genéricas

```
┌─────────────────────────────────────────────────────────┐
│ installer-helper.sh                                     │
├─────────────────────────────────────────────────────────┤
│ • exit_on_error()      → Tratamento de erros           │
│ • show_logo()          → Exibição visual                │
│ • multiselect()        → Menu multi-seleção             │
│ • select_option()      → Menu seleção única             │
│ • sequence()           → Orquestração das 4 fases       │
│ • set_option()         → Salva em setup.conf            │
│ • source_file()        → Carrega arquivo com validação  │
│ • end_script()         → Finaliza e copia logs          │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Helper/Utility Module - funções reutilizáveis sem estado.

---

### 2. system-checks.sh

**Responsabilidade**: Verificações de pré-condições

```
┌─────────────────────────────────────────────────────────┐
│ system-checks.sh                                        │
├─────────────────────────────────────────────────────────┤
│ • root_check()         → Verifica privilégios root      │
│ • arch_check()         → Verifica se é Arch Linux       │
│ • pacman_check()       → Verifica lock do pacman        │
│ • docker_check()       → Impede execução em container   │
│ • mount_check()        → Verifica montagem /mnt         │
│ • background_checks()  → Executa todas as verificações  │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Guard Clauses - falha rápida se pré-condições não satisfeitas.

**Quando Executar**:
- `background_checks()`: No início do `configuration.sh`
- `mount_check()`: Antes das fases 1-3 (que precisam de /mnt montado)

---

### 3. user-options.sh

**Responsabilidade**: Coleta interativa de configurações do usuário

```
┌─────────────────────────────────────────────────────────┐
│ user-options.sh                                         │
├─────────────────────────────────────────────────────────┤
│ • set_password()           → Coleta senha com confirmação│
│ • user_info()              → Nome, username, hostname   │
│ • install_type()           → FULL/MINIMAL/SERVER        │
│ • aur_helper()             → Escolha AUR helper         │
│ • desktop_environment()    → Lê JSONs disponíveis       │
│ • disk_select()            → Seleciona disco            │
│ • filesystem()             → btrfs/ext4/luks            │
│ • set_btrfs()              → Define subvolumes          │
│ • timezone()               → Detecta e confirma         │
│ • locale_selection()       → Idioma do sistema          │
│ • keymap()                 → Layout do teclado          │
│ • show_configurations()    → Resumo + permite refazer   │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Wizard/Step-by-Step Configuration

**Fluxo de Validação**:
```
Entrada → Validação → Retry se inválido → set_option() → Próxima etapa
```

**Show Configurations**: Permite ao usuário revisar TODAS as escolhas e refazer qualquer etapa antes de prosseguir. Isso evita reinstalações por erro de configuração.

---

### 4. software-install.sh

**Responsabilidade**: Instalação de software e drivers

```
┌─────────────────────────────────────────────────────────┐
│ software-install.sh                                     │
├─────────────────────────────────────────────────────────┤
│ INSTALAÇÃO BASE:                                        │
│ • arch_install()               → Pacstrap sistema base  │
│ • bootloader_install()         → GRUB UEFI/BIOS        │
│ • network_install()            → NetworkManager + VPNs │
│ • base_install()               → Lê base.json          │
│                                                         │
│ DETECÇÃO DE HARDWARE:                                   │
│ • microcode_install()          → Intel/AMD automático  │
│ • graphics_install()           → NVIDIA/AMD/Intel      │
│                                                         │
│ DESKTOP & TEMAS:                                        │
│ • install_fonts()              → Lê fonts.json         │
│ • desktop_environment_install()→ Lê DE JSON            │
│ • user_theming()               → Aplica configs/temas  │
│ • btrfs_install()              → Snapper, grub-btrfs   │
│                                                         │
│ AUR:                                                    │
│ • aur_helper_install()         → Compila AUR helper    │
│                                                         │
│ SERVIÇOS:                                               │
│ • essential_services()         → Habilita tudo         │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Repository Pattern (JSON como "repositórios" de pacotes)

**Hardware Auto-Detection**:
```bash
# Microcode
proc_type=$(lscpu)
if grep -E "GenuineIntel" <<<"${proc_type}"; then
    pacman -S intel-ucode
elif grep -E "AuthenticAMD" <<<"${proc_type}"; then
    pacman -S amd-ucode
fi

# GPU
gpu_type=$(lspci)
if grep -E "NVIDIA|GeForce" <<<"${gpu_type}"; then
    pacman -S nvidia-dkms nvidia-settings
elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
    pacman -S xf86-video-amdgpu
elif grep -E "Intel.*Graphics" <<<"${gpu_type}"; then
    pacman -S vulkan-intel libva-intel-driver
fi
```

---

### 5. system-config.sh

**Responsabilidade**: Configuração do sistema (disco, locale, usuários, bootloader)

```
┌─────────────────────────────────────────────────────────┐
│ system-config.sh                                        │
├─────────────────────────────────────────────────────────┤
│ DISCO E FILESYSTEM:                                     │
│ • mirrorlist_update()      → Reflector/rankmirrors     │
│ • format_disk()            → sgdisk particionamento    │
│ • create_filesystems()     → mkfs.vfat/ext4/btrfs      │
│ • do_btrfs()               → Subvolumes + montagem     │
│                                                         │
│ OTIMIZAÇÕES:                                            │
│ • low_memory_config()      → ZRAM se <8GB RAM          │
│ • cpu_config()             → Makeflags multicore       │
│                                                         │
│ SISTEMA:                                                │
│ • locale_config()          → Locale, timezone, keymap  │
│ • extra_repos()            → Multilib, chaotic-aur     │
│ • add_user()               → useradd + grupos          │
│                                                         │
│ BOOTLOADER:                                             │
│ • grub_config()            → Configura GRUB            │
│ • display_manager()        → SDDM/GDM/LightDM + temas  │
│                                                         │
│ AVANÇADO:                                               │
│ • snapper_config()         → Snapshots btrfs           │
│ • configure_tlp()          → Power management laptops  │
│ • plymouth_config()        → Boot splash               │
└─────────────────────────────────────────────────────────┘
```

**Design Pattern**: Configuration Management

**Particionamento GPT**:
```
UEFI:
┌─────────────┬──────────────────────────────────────┐
│ EFIBOOT     │ ROOT                                 │
│ 1GB (EF00)  │ Resto do disco (8300)                │
│ FAT32       │ ext4/btrfs/LUKS                      │
└─────────────┴──────────────────────────────────────┘

BIOS:
┌─────────────┬──────────────────────────────────────┐
│ BIOSBOOT    │ ROOT                                 │
│ 256MB(EF02) │ Resto do disco (8300)                │
│ (sem FS)    │ ext4/btrfs/LUKS                      │
└─────────────┴──────────────────────────────────────┘
```

**Subvolumes Btrfs**:
```
@              → /           (root)
@home          → /home       (dados de usuário)
@snapshots     → /.snapshots (snapshots do Snapper)
@var_log       → /var/log    (logs, CoW desabilitado)
@var_cache     → /var/cache  (cache, CoW desabilitado)
@var_tmp       → /var/tmp    (temp, CoW desabilitado)
@docker        → /var/lib/docker
@flatpak       → /var/lib/flatpak
```

**Razão**: Subvolumes separados permitem snapshots seletivos e melhor gerenciamento.

---

## 📄 Sistema de Configuração

### setup.conf - Arquivo Central

```bash
# Gerado por configuration.sh
# Lido por TODAS as fases

# Usuário
REAL_NAME="João Silva"
USERNAME=joao
PASSWORD=hash_senha
NAME_OF_MACHINE=meuarch

# Instalação
INSTALL_TYPE=FULL          # FULL, MINIMAL ou SERVER
AUR_HELPER=yay             # yay, paru, picaur, etc.
DESKTOP_ENV=kde            # kde, gnome, i3-wm, etc.

# Disco
DISK=/dev/sda
FS=btrfs                   # btrfs, ext4 ou luks
SUBVOLUMES=(@ @home @snapshots ...)
MOUNT_OPTION=defaults,noatime,compress=zstd,ssd,discard=async

# Localização
TIMEZONE=America/Sao_Paulo
LOCALE=pt_BR.UTF-8
KEYMAP=br-abnt2

# LUKS (se FS=luks)
LUKS_PASSWORD=***
ENCRYPTED_PARTITION_UUID=uuid-da-particao
```

**Padrão de Acesso**:
```bash
# Todos os scripts fazem:
source "$HOME"/archinstaller/configs/setup.conf

# E depois usam as variáveis diretamente:
useradd -m -s /bin/bash "$USERNAME"
```

---

## 📦 Sistema de Pacotes JSON

### Estrutura de Arquivos JSON

```json
{
  "minimal": {
    "pacman": [
      {"package": "firefox"},
      {"package": "vim"}
    ],
    "aur": [
      {"package": "yay"}
    ]
  },
  "full": {
    "pacman": [
      {"package": "libreoffice-fresh"},
      {"package": "gimp"}
    ],
    "aur": [
      {"package": "visual-studio-code-bin"}
    ]
  }
}
```

### Lógica de Instalação

```bash
# Define filtros JQ baseado no INSTALL_TYPE
if [[ "$INSTALL_TYPE" == "FULL" ]]; then
    FILTER=".minimal.pacman[].package, .full.pacman[].package"
else
    FILTER=".minimal.pacman[].package"
fi

# Se AUR helper instalado, inclui pacotes AUR
if [[ "$AUR_HELPER" != NONE ]]; then
    FILTER="$FILTER, .minimal.aur[].package"
    [[ "$INSTALL_TYPE" == "FULL" ]] && FILTER="$FILTER, .full.aur[].package"
fi

# Instala
jq -r "$FILTER" package.json | while read -r pkg; do
    pacman -S "$pkg" --noconfirm --needed
done
```

**Razão**: JQ permite queries flexíveis em JSON. Separar minimal/full permite instalações leves ou completas.

---

## 🔐 Segurança e Validações

### 1. Validação de Entrada do Usuário

```bash
# Username: regex validado
[[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]

# Hostname: regex validado
[[ "${hostname,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]

# Senha: confirmação obrigatória
set_password() {
    read -rs -p "Enter password: " PASS1
    read -rs -p "Re-enter password: " PASS2
    [[ "$PASS1" == "$PASS2" ]] || { echo "No match!"; set_password; }
}
```

### 2. Verificações Pré-Instalação

```bash
# Deve ser root
[[ "$(id -u)" != "0" ]] && exit 1

# Deve ser Arch
[[ ! -e /etc/arch-release ]] && exit 1

# Pacman não pode estar travado
[[ -f /var/lib/pacman/db.lck ]] && exit 1

# Não suporta Docker
[[ -f /.dockerenv ]] && exit 1
```

### 3. Error Handling

```bash
exit_on_error() {
    exit_code=$1
    last_command=${*:2}
    if [ "$exit_code" -ne 0 ]; then
        echo "\"${last_command}\" failed with code ${exit_code}."
        exit "$exit_code"
    fi
}

# Uso:
pacstrap /mnt base
exit_on_error $? pacstrap /mnt base
```

---

## 🎨 Temas e Configurações Personalizadas

### Sistema de Theming

```
configs/
├── base/                           # Configs compartilhadas
│   ├── etc/snapper/configs/root   # Config do Snapper
│   └── usr/share/plymouth/themes/ # Plymouth themes
├── kde/
│   ├── home/                       # Dotfiles do usuário
│   └── kde.knsv                    # Konsave profile
├── awesome/
│   ├── home/.config/awesome/       # Config Awesome WM
│   └── etc/xdg/awesome/            # Config global
└── i3-wm/
    └── etc/                        # Configs i3
```

**Aplicação de Temas**:
```bash
user_theming() {
    case "$DESKTOP_ENV" in
        kde)
            cp -r ~/archinstaller/configs/kde/home/. ~/
            pip install konsave
            konsave -i ~/archinstaller/configs/kde/kde.knsv
            konsave -a kde
            ;;
        awesome)
            cp -r ~/archinstaller/configs/awesome/home/. ~/
            sudo cp -r ~/archinstaller/configs/awesome/etc/xdg/awesome /etc/xdg/
            ;;
    esac
}
```

---

## 🚀 Otimizações Implementadas

### 1. Compilação Paralela

```bash
nc=$(grep -c ^processor /proc/cpuinfo)
sed -i "s/^#\(MAKEFLAGS=\"-j\)2\"/\1$nc\"/" /etc/makepkg.conf
```

### 2. Mirror Optimization

```bash
# Reflector: seleciona 20 mirrors mais rápidos do país
reflector -a 48 -c "$iso" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

# Fallback: rankmirrors manual
rankmirrors -n 5 /etc/pacman.d/mirrorlist
```

### 3. ZRAM (Sistemas com <8GB RAM)

```bash
TOTAL_MEM=$(grep -i 'memtotal' /proc/meminfo | grep -o '[[:digit:]]*')
if [[ "$TOTAL_MEM" -lt 8000000 ]]; then
    pacman -S zram-generator
    cat <<EOF > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * 2
compression-algorithm = zstd
EOF
fi
```

**Razão**: 2x RAM como ZRAM comprimido é mais eficiente que swap em disco.

### 4. Btrfs Mount Options

```bash
# SSD detectado
if [[ "$(lsblk -n --output ROTA)" -eq "0" ]]; then
    MOUNT_OPTION="defaults,noatime,compress=zstd,ssd,discard=async"
else
    MOUNT_OPTION="defaults,noatime,compress=zstd,discard=async"
fi
```

- `noatime`: Não atualiza access time (performance)
- `compress=zstd`: Compressão transparente
- `ssd`: Otimizações para SSD
- `discard=async`: TRIM assíncrono (melhor performance)

---

## 📊 Fluxo de Dados

```
┌──────────────────┐
│ Usuário          │
└────────┬─────────┘
         │ Entrada interativa
         ↓
┌──────────────────────────┐
│ configuration.sh         │
│ + user-options.sh        │
└────────┬─────────────────┘
         │ Salva
         ↓
┌──────────────────────────┐
│ configs/setup.conf       │ ← Fonte de verdade
└────────┬─────────────────┘
         │ Lido por todas as fases
         ↓
┌──────────────────────────┐
│ 0-preinstall.sh          │ → Cria partições + filesystem
└────────┬─────────────────┘
         │
┌──────────────────────────┐
│ 1-setup.sh               │ → Instala base + configura sistema
└────────┬─────────────────┘
         │
┌──────────────────────────┐
│ 2-user.sh                │ → AUR + Desktop + Temas
└────────┬─────────────────┘
         │
┌──────────────────────────┐
│ 3-post-setup.sh          │ → Serviços + Cleanup
└────────┬─────────────────┘
         │
         ↓
   Sistema Instalado
```

---

## 🎯 Decisões Arquiteturais Importantes

### 1. Por que JSON para Pacotes?

**Alternativas consideradas**: Shell arrays, TOML, YAML

**Escolhido**: JSON com JQ

**Razão**:
- JQ está disponível no Arch ISO
- Queries flexíveis (filtrar por minimal/full, pacman/aur)
- Fácil de editar manualmente
- Estrutura hierárquica clara

### 2. Por que 4 Fases Separadas?

**Alternativa**: Script monolítico

**Escolhido**: 4 fases distintas

**Razão**:
- AUR não pode ser instalado como root
- Separação de contextos (live ISO vs chroot)
- Melhor para debug (pode re-executar fases específicas)
- Logs separados por fase

### 3. Por que setup.conf?

**Alternativa**: Variáveis de ambiente, banco de dados

**Escolhido**: Arquivo texto simples

**Razão**:
- Simples de ler/escrever em bash
- Pode ser editado manualmente se necessário
- Sobrevive a mudanças de contexto (chroot)
- Humano-legível para debug

---

Esta arquitetura permite extensibilidade, manutenibilidade e robustez no processo de instalação do Arch Linux.
