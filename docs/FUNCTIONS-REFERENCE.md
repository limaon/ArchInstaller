# Referência Completa de Funções

Este documento lista todas as funções disponíveis no ArchInstaller, organizadas por módulo.

---

## 📁 installer-helper.sh

### exit_on_error()
```bash
exit_on_error $exit_code $last_command
```
**Descrição**: Verifica código de saída e termina script se falhou.

**Parâmetros**:
- `$1` - Código de saída do comando anterior (`$?`)
- `$2+` - Comando que foi executado (para mensagem de erro)

**Exemplo**:
```bash
pacstrap /mnt base
exit_on_error $? "pacstrap /mnt base"
```

**Uso**: Após comandos críticos que não podem falhar.

---

### show_logo()
```bash
show_logo
```
**Descrição**: Exibe logo ASCII do archinstall e path do script.

**Retorno**: Nenhum (apenas output visual)

**Exemplo**:
```bash
show_logo
# Exibe:
#                    _      _              _          _  _
#    archinstall
#    SCRIPTHOME: /root/ArchInstaller
```

---

### multiselect()
```bash
multiselect RESULT_VAR "opt1;opt2;opt3" "defaults"
```
**Descrição**: Menu interativo para seleção múltipla (checkbox).

**Parâmetros**:
- `$1` - Nome da variável para armazenar resultado (array)
- `$2` - Opções separadas por `;`
- `$3` - Valores padrão (opcional)

**Controles**:
- `↑/↓` - Navegar
- `Espaço` - Toggle seleção
- `Enter` - Confirmar

**Exemplo**:
```bash
options="Firefox;Chrome;Brave"
multiselect selected "$options"
# selected=(true false true) se Firefox e Brave selecionados
```

---

### select_option()
```bash
select_option num_options num_columns "${options[@]}"
return $?  # Índice selecionado
```
**Descrição**: Menu interativo para seleção única.

**Parâmetros**:
- `$1` - Número de opções
- `$2` - Número de colunas para exibir
- `$3+` - Array de opções

**Retorno**: Índice da opção selecionada (via `$?`)

**Controles**:
- `↑/↓/←/→` ou `k/j/h/l` - Navegar
- `Enter` - Confirmar

**Exemplo**:
```bash
options=(KDE GNOME XFCE)
select_option ${#options[@]} 3 "${options[@]}"
selected_index=$?
echo "Você escolheu: ${options[$selected_index]}"
```

---

### sequence()
```bash
sequence
```
**Descrição**: Orquestra a execução das 4 fases de instalação.

**Fluxo**:
1. Executa `0-preinstall.sh` (live ISO)
2. Chroot e executa `1-setup.sh` (como root)
3. Se não SERVER, executa `2-user.sh` (como usuário)
4. Executa `3-post-setup.sh` (como root novamente)

**Exemplo**:
```bash
# Chamado automaticamente por archinstall.sh
sequence
```

---

### set_option()
```bash
set_option KEY VALUE
```
**Descrição**: Salva configuração no arquivo `setup.conf`.

**Parâmetros**:
- `$1` - Nome da variável (chave)
- `$2` - Valor

**Comportamento**:
- Se chave existe, atualiza valor
- Se não existe, adiciona nova linha
- Aspas adicionadas automaticamente se valor contém espaços

**Exemplo**:
```bash
set_option USERNAME "joao"
set_option REAL_NAME "João Silva"  # Com aspas por causa do espaço
```

---

### source_file()
```bash
source_file /path/to/file.sh
```
**Descrição**: Carrega arquivo com verificação de existência.

**Parâmetros**:
- `$1` - Path do arquivo

**Comportamento**:
- Verifica se arquivo existe
- Tenta fazer source
- Sai com erro se falhar

**Exemplo**:
```bash
source_file "$CONFIG_FILE"  # /configs/setup.conf
```

---

### end_script()
```bash
end_script
```
**Descrição**: Copia logs para sistema instalado e finaliza.

**Comportamento**:
- Copia `install.log` para `/mnt/var/log/install.log`
- Verifica se diretório de logs existe
- Exibe mensagem de erro se falhar

**Exemplo**:
```bash
# No final de archinstall.sh
end_script
```

---

## 🔒 system-checks.sh

### root_check()
```bash
root_check
```
**Descrição**: Verifica se script está rodando como root.

**Comportamento**: Sai se não for root (UID ≠ 0)

---

### arch_check()
```bash
arch_check
```
**Descrição**: Verifica se está rodando em Arch Linux.

**Comportamento**: Sai se `/etc/arch-release` não existir

---

### pacman_check()
```bash
pacman_check
```
**Descrição**: Verifica se pacman está bloqueado.

**Comportamento**: Sai se `/var/lib/pacman/db.lck` existir

---

### docker_check()
```bash
docker_check
```
**Descrição**: Impede execução em container Docker.

**Comportamento**: Verifica `/.dockerenv` e `/proc/self/cgroup`

---

### mount_check()
```bash
mount_check
```
**Descrição**: Verifica se `/mnt` está montado.

**Comportamento**: Reinicia sistema se não estiver montado

**Uso**: Chamado antes das fases 1-3

---

### background_checks()
```bash
background_checks
```
**Descrição**: Executa todas as verificações de segurança.

**Chamadas**: `root_check`, `arch_check`, `pacman_check`, `docker_check`

**Uso**: No início de `configuration.sh`

---

## 👤 user-options.sh

### set_password()
```bash
set_password "PASSWORD"
```
**Descrição**: Coleta senha com confirmação.

**Parâmetros**: `$1` - Nome da variável no setup.conf

**Comportamento**:
- Pede senha (oculta)
- Pede confirmação
- Recursivo se não coincidir

---

### user_info()
```bash
user_info
```
**Descrição**: Coleta informações completas do usuário.

**Coleta**:
- Nome completo (validado: só letras e espaços)
- Username (validado: regex Linux)
- Senha (com confirmação)
- Hostname (validado com opção de forçar)

**Validações**:
- Nome: `[a-zA-Z ]`
- Username: `^[a-z_]([a-z0-9_-]{0,31})$`
- Hostname: `^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$`

---

### install_type()
```bash
install_type
```
**Descrição**: Escolha do tipo de instalação.

**Opções**: FULL, MINIMAL, SERVER

**Salva**: `INSTALL_TYPE` no setup.conf

---

### aur_helper()
```bash
aur_helper
```
**Descrição**: Escolha do AUR helper.

**Opções**: paru, yay, picaur, aura, trizen, pacaur, NONE

**Salva**: `AUR_HELPER` no setup.conf

---

### desktop_environment()
```bash
desktop_environment
```
**Descrição**: Escolha do ambiente desktop.

**Comportamento**:
- Lê arquivos JSON em `packages/desktop-environments/`
- Extrai nomes de arquivo (sem extensão e "pkgs")
- Exibe menu

**Salva**: `DESKTOP_ENV` no setup.conf

---

### disk_select()
```bash
disk_select
```
**Descrição**: Seleção de disco para instalação.

**Comportamento**:
- Lista discos com `lsblk`
- Exibe aviso de formatação
- Detecta SSD e define mount options

**Salva**: `DISK` e `MOUNT_OPTION` no setup.conf

---

### filesystem()
```bash
filesystem
```
**Descrição**: Escolha do sistema de arquivos.

**Opções**: btrfs, ext4, luks, exit

**Comportamento**:
- Se btrfs: chama `set_btrfs()`
- Se luks: chama `set_password("LUKS_PASSWORD")`

**Salva**: `FS` no setup.conf

---

### set_btrfs()
```bash
set_btrfs
```
**Descrição**: Define subvolumes btrfs.

**Comportamento**:
- Pede subvolumes customizados
- Se vazio, usa defaults
- Garante que `@` existe
- Remove duplicatas

**Padrões**: `@ @docker @flatpak @home @opt @snapshots @var_cache @var_log @var_tmp`

**Salva**: `SUBVOLUMES` e `MOUNTPOINT` no setup.conf

---

### timezone()
```bash
timezone
```
**Descrição**: Detecção e confirmação de timezone.

**Comportamento**:
- Detecta via `curl https://ipapi.co/timezone`
- Pede confirmação
- Permite inserção manual se incorreto

**Salva**: `TIMEZONE` no setup.conf

---

### locale_selection()
```bash
locale_selection
```
**Descrição**: Seleção de locale (idioma do sistema).

**Opções**: en_US.UTF-8, pt_BR.UTF-8, es_ES.UTF-8, fr_FR.UTF-8, etc.

**Salva**: `LOCALE` no setup.conf

---

### keymap()
```bash
keymap
```
**Descrição**: Seleção de layout de teclado.

**Opções**: us, br-abnt2, de, fr, es, etc. (28 opções)

**Salva**: `KEYMAP` no setup.conf

---

### show_configurations()
```bash
show_configurations
```
**Descrição**: Mostra resumo e permite refazer etapas.

**Comportamento**:
- Exibe conteúdo de `setup.conf`
- Menu numerado para refazer qualquer etapa
- Loop até usuário confirmar (Enter vazio)

**Menu**:
1. User info
2. Install type
3. AUR helper
4. Desktop environment
5. Disk
6. Filesystem
7. Timezone
8. Locale
9. Keymap

---

## 📦 software-install.sh

### arch_install()
```bash
arch_install
```
**Descrição**: Instala sistema base com pacstrap.

**Pacotes**: base, base-devel, linux, linux-firmware, linux-lts, jq, neovim, sudo, wget, libnewt

---

### bootloader_install()
```bash
bootloader_install
```
**Descrição**: Instala bootloader GRUB.

**Comportamento**:
- Detecta UEFI vs BIOS
- Se UEFI: instala efibootmgr

---

### network_install()
```bash
network_install
```
**Descrição**: Instala NetworkManager e ferramentas de rede.

**Pacotes**: NetworkManager, VPN clients, wireless tools, SSH

**Serviços**: Habilita NetworkManager.service

---

### install_fonts()
```bash
install_fonts
```
**Descrição**: Instala fontes do sistema.

**Fonte**: `packages/optional/fonts.json`

**Comportamento**: Pula se INSTALL_TYPE=SERVER

---

### base_install()
```bash
base_install
```
**Descrição**: Instala pacotes base do sistema.

**Fonte**: `packages/base.json`

**Filtros JQ**:
- MINIMAL: `.minimal.pacman[]`
- FULL: `.minimal.pacman[], .full.pacman[]`

---

### microcode_install()
```bash
microcode_install
```
**Descrição**: Detecta CPU e instala microcode.

**Detecção**: `lscpu | grep "GenuineIntel"` ou `"AuthenticAMD"`

**Pacotes**: `intel-ucode` ou `amd-ucode`

---

### graphics_install()
```bash
graphics_install
```
**Descrição**: Detecta GPU e instala drivers.

**Detecção**: `lspci`

**Drivers**:
- NVIDIA: `nvidia-dkms nvidia-settings`
- AMD: `xf86-video-amdgpu`
- Intel: `vulkan-intel libva-intel-driver`

---

### aur_helper_install()
```bash
aur_helper_install
```
**Descrição**: Clona e compila AUR helper.

**Comportamento**:
- Clona de `https://aur.archlinux.org/$AUR_HELPER.git`
- Compila com `makepkg -sirc`
- Instala pacotes AUR de `base.json`

---

### desktop_environment_install()
```bash
desktop_environment_install
```
**Descrição**: Instala pacotes do desktop environment.

**Fonte**: `packages/desktop-environments/$DESKTOP_ENV.json`

**Filtros**: Combina minimal + full, pacman + aur

---

### btrfs_install()
```bash
btrfs_install
```
**Descrição**: Instala ferramentas btrfs.

**Fonte**: `packages/btrfs.json`

**Condição**: Só se `FS=btrfs`

**Pacotes**: snapper, snap-pac, grub-btrfs, etc.

---

### user_theming()
```bash
user_theming
```
**Descrição**: Aplica temas e configurações do DE.

**Suportados**:
- KDE: Konsave profile
- Awesome: Dotfiles
- i3: Configs
- Openbox: Dotfiles do GitHub

---

### essential_services()
```bash
essential_services
```
**Descrição**: Habilita serviços essenciais.

**Sempre**:
- NetworkManager
- fstrim.timer (SSD)
- TLP (se bateria detectada)

**FULL apenas**:
- UFW firewall
- Cups (impressão)
- NTP
- Bluetooth
- Avahi
- Snapper (btrfs/luks)
- Plymouth

---

## ⚙️ system-config.sh

### mirrorlist_update()
```bash
mirrorlist_update
```
**Descrição**: Atualiza lista de mirrors.

**Método 1** (preferido): reflector
**Método 2** (fallback): rankmirrors manual

---

### format_disk()
```bash
format_disk
```
**Descrição**: Particiona disco com GPT.

**Layout UEFI**:
- Partição 1: 1GB EFI (ef00)
- Partição 2: Resto ROOT (8300)

**Layout BIOS**:
- Partição 1: 256MB BIOS boot (ef02)
- Partição 2: Resto ROOT (8300)

---

### create_filesystems()
```bash
create_filesystems
```
**Descrição**: Cria filesystems nas partições.

**EFI**: FAT32
**ROOT**: Depende de `$FS` (ext4/btrfs/luks)

---

### do_btrfs()
```bash
do_btrfs LABEL DEVICE
```
**Descrição**: Cria filesystem btrfs com subvolumes.

**Parâmetros**:
- `$1` - Label (ex: ROOT)
- `$2` - Device (ex: /dev/sda2)

**Comportamento**:
- Cria btrfs
- Monta temporariamente
- Cria todos os subvolumes de `$SUBVOLUMES`
- Desmonta
- Remonta @ como root
- Monta outros subvolumes nos lugares corretos

---

### low_memory_config()
```bash
low_memory_config
```
**Descrição**: Configura ZRAM se <8GB RAM.

**Comportamento**:
- Verifica memória total
- Se <8GB, instala zram-generator
- Configura zram0 com 200% RAM e zstd

---

### cpu_config()
```bash
cpu_config
```
**Descrição**: Ajusta makepkg para compilação paralela.

**Comportamento**:
- Conta cores da CPU
- Define `MAKEFLAGS="-j$cores"`
- Define compressão paralela XZ

---

### locale_config()
```bash
locale_config
```
**Descrição**: Configura locale, timezone e keymap.

**Passos**:
1. Descomenta locale em `/etc/locale.gen`
2. Cria `/etc/locale.conf` com todas as variáveis LC_*
3. Gera locales com `locale-gen`
4. Configura timezone com `timedatectl`
5. Cria symlink `/etc/localtime`
6. Sincroniza relógio hardware
7. Configura keymap
8. Cria `/etc/vconsole.conf`

---

### extra_repos()
```bash
extra_repos
```
**Descrição**: Habilita repositórios extras.

**Habilita**:
- multilib (pacotes 32-bit)
- (chaotic-aur comentado por padrão)

---

### add_user()
```bash
add_user
```
**Descrição**: Cria usuário do sistema.

**Passos**:
1. Cria grupos (libvirt, vboxusers, gamemode, docker)
2. Cria usuário com `useradd`
3. Define senha
4. Copia `/root/archinstaller` para `/home/$USERNAME/`
5. Define hostname
6. Cria `/etc/hosts`

---

### grub_config()
```bash
grub_config
```
**Descrição**: Configura GRUB.

**Comportamento**:
- Se LUKS: adiciona cryptdevice ao kernel cmdline
- Adiciona `splash` para Plymouth
- Desabilita OS prober
- Gera config final

---

### display_manager()
```bash
display_manager
```
**Descrição**: Habilita e tema display manager.

**Mapeamento**:
- KDE → SDDM (tema Nordic se FULL)
- GNOME → GDM
- LXDE → LXDM
- Openbox/Awesome/i3 → LightDM
- Outros → LightDM (fallback)

---

### snapper_config()
```bash
snapper_config
```
**Descrição**: Configura Snapper para snapshots.

**Passos**:
1. Copia config de `configs/base/etc/snapper/`
2. Ajusta permissões de usuário
3. Habilita timers (timeline, cleanup)
4. Habilita grub-btrfsd
5. Cria snapshot inicial

---

### configure_tlp()
```bash
configure_tlp
```
**Descrição**: Configura TLP para power management.

**Comportamento**:
- Detecta bateria (`/sys/class/power_supply/BAT0`)
- Se não tem bateria, pula
- Instala TLP
- Configura `/etc/tlp.conf` com defaults otimizados
- Configura logind para suspender ao fechar tampa

---

### plymouth_config()
```bash
plymouth_config
```
**Descrição**: Instala e configura Plymouth boot splash.

**Tema**: arch-glow

**Comportamento**:
- Copia tema de `configs/base/usr/share/plymouth/themes/`
- Adiciona plymouth aos hooks do mkinitcpio
- Se LUKS: adiciona plymouth-encrypt
- Regenera initramfs

---

## 🎯 Funções por Caso de Uso

### Adicionar Novo Desktop Environment

1. Criar `packages/desktop-environments/meu-de.json`
2. `desktop_environment()` detectará automaticamente
3. Opcionalmente, adicionar theming em `user_theming()`
4. Opcionalmente, configurar display manager em `display_manager()`

### Adicionar Validação Customizada

Em `user-options.sh`, use padrão:

```bash
minha_opcao() {
    while true; do
        read -rp "Pergunta: " resposta
        [[ validacao ]] && break
        echo "Erro: inválido"
    done
    set_option MINHA_OPCAO "$resposta"
}
```

### Adicionar Detecção de Hardware

Em `software-install.sh`:

```bash
meu_hardware_install() {
    deteccao=$(comando_deteccao)
    if grep -E "pattern" <<<"$deteccao"; then
        pacman -S meu-driver
    fi
}
```

---

Consulte o código fonte para detalhes de implementação!
