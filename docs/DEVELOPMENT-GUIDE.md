# Guia de Desenvolvimento

Este documento é para desenvolvedores que querem adicionar features, corrigir bugs ou contribuir para o ArchInstaller.

---

## 🎯 Começando

### Pré-requisitos

- Conhecimento de Bash scripting
- Familiaridade com Arch Linux
- Git
- VM para testes (VirtualBox, VMware, QEMU, etc.)

### Setup de Desenvolvimento

1. **Fork e Clone**:
   ```bash
   git clone https://github.com/seu-usuario/ArchInstaller
   cd ArchInstaller
   ```

2. **Criar Branch**:
   ```bash
   git checkout -b feature/minha-feature
   ```

3. **Testar em VM**:
   - Criar VM com 20GB+ disco
   - Boot ISO do Arch Linux
   - Clonar seu fork dentro da VM

---

## 📁 Estrutura do Código

### Hierarquia de Responsabilidades

```
archinstall.sh (orchestrator)
    ↓
configuration.sh (user input)
    ↓
sequence() (phase manager)
    ├── 0-preinstall.sh (disk setup)
    ├── 1-setup.sh (system config)
    ├── 2-user.sh (user apps)
    └── 3-post-setup.sh (finalization)
         ↓
    utils/*.sh (helper functions)
```

### Quando Modificar Cada Arquivo

**archinstall.sh**: Raramente. Apenas se mudar orchestration geral.

**configuration.sh**: Adicionar/remover perguntas de configuração.

**0-preinstall.sh**: Modificar particionamento, filesystem creation.

**1-setup.sh**: Adicionar configurações de sistema, novos repos.

**2-user.sh**: Mudar ordem de instalação de desktop/AUR.

**3-post-setup.sh**: Adicionar serviços, mudar cleanup.

**utils/\*.sh**: Adicionar funções reutilizáveis.

**packages/\*.json**: Adicionar/remover pacotes.

---

## ✨ Adicionando Features

### Feature: Novo Desktop Environment

#### 1. Criar JSON de Pacotes

`packages/desktop-environments/meu-de.json`:

```json
{
  "minimal": {
    "pacman": [
      {"package": "meu-de-core"},
      {"package": "terminal-emulator"},
      {"package": "file-manager"},
      {"package": "display-manager"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "meu-de-full"},
      {"package": "apps-extras"}
    ],
    "aur": [
      {"package": "temas-aur"}
    ]
  }
}
```

#### 2. Configurar Display Manager

Em `scripts/utils/system-config.sh`, adicione em `display_manager()`:

```bash
elif [[ "${DESKTOP_ENV}" == "meu-de" ]]; then
    systemctl enable meu-dm.service
    
    if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
        # Configurações de tema
        echo "theme=meu-tema" >> /etc/meu-dm/meu-dm.conf
    fi
```

#### 3. (Opcional) Theming

Se tem dotfiles em `configs/meu-de/`, adicione em `scripts/utils/software-install.sh -> user_theming()`:

```bash
elif [[ "$DESKTOP_ENV" == "meu-de" ]]; then
    cp -r ~/archinstaller/configs/meu-de/home/. ~/
    # Aplicar configurações adicionais
```

#### 4. Testar

```bash
./archinstall.sh
# Selecionar "meu-de" na lista
```

---

### Feature: Nova Opção de Configuração

#### 1. Adicionar Função de Coleta

Em `scripts/utils/user-options.sh`:

```bash
minha_opcao() {
    echo -ne "
Por favor selecione opção:
"
    options=("Opção A" "Opção B" "Opção C")
    select_option $? 3 "${options[@]}"
    minha_escolha="${options[$?]}"
    set_option MINHA_OPCAO "$minha_escolha"
}
```

#### 2. Adicionar ao Workflow de Configuração

Em `scripts/configuration.sh`:

```bash
# Após outras configurações
minha_opcao
clear
```

#### 3. Adicionar ao Show Configurations

Em `scripts/utils/user-options.sh -> show_configurations()`:

```bash
# No menu
10) Minha Opção
...

# No case
case $choice in
    ...
    10) minha_opcao ;;
    ...
esac
```

#### 4. Usar a Configuração

Em qualquer script posterior:

```bash
source "$HOME"/archinstaller/configs/setup.conf

if [[ "$MINHA_OPCAO" == "Opção A" ]]; then
    # Fazer algo
fi
```

---

### Feature: Detecção de Hardware

Exemplo: Detectar se tem touchpad.

#### 1. Adicionar Função de Detecção

Em `scripts/utils/software-install.sh`:

```bash
touchpad_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Detecting Touchpad
-------------------------------------------------------------------------
"
    # Detectar touchpad
    if xinput list | grep -i "touchpad"; then
        echo "Touchpad detected, installing libinput"
        pacman -S --noconfirm --needed xf86-input-libinput
        
        # Configuração adicional
        cat > /etc/X11/xorg.conf.d/30-touchpad.conf <<EOF
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
EndSection
EOF
    else
        echo "No touchpad detected, skipping"
    fi
}
```

#### 2. Chamar a Função

Em `scripts/1-setup.sh` ou `scripts/2-user.sh`:

```bash
# Após graphics_install()
touchpad_install
```

---

### Feature: Novo Filesystem

Exemplo: Suporte a XFS.

#### 1. Adicionar Opção

Em `scripts/utils/user-options.sh -> filesystem()`:

```bash
options=("btrfs" "ext4" "xfs" "luks" "exit")
select_option $? 1 "${options[@]}"

case $? in
0) set_btrfs; set_option FS btrfs ;;
1) set_option FS ext4 ;;
2) set_option FS xfs ;;  # Nova opção
3) set_password "LUKS_PASSWORD"; set_option FS luks ;;
4) exit ;;
esac
```

#### 2. Implementar Criação

Em `scripts/utils/system-config.sh -> create_filesystems()`:

```bash
if [[ "${FS}" == "btrfs" ]]; then
    do_btrfs "ROOT" "${root_partition}"
elif [[ "${FS}" == "ext4" ]]; then
    mkfs.ext4 -L ROOT "${root_partition}"
    mount -t ext4 "${root_partition}" /mnt
elif [[ "${FS}" == "xfs" ]]; then
    # Nova implementação
    mkfs.xfs -L ROOT "${root_partition}"
    mount -t xfs "${root_partition}" /mnt
elif [[ "${FS}" == "luks" ]]; then
    # ...
fi
```

---

## 🐛 Debugging

### Logs

Tudo é registrado em `install.log`:

```bash
# Durante instalação, em outro terminal (Ctrl+Alt+F2)
tail -f /root/ArchInstaller/install.log

# Após instalação, no sistema instalado
less /var/log/install.log
```

### Adicionar Debug Output

```bash
echo "DEBUG: variavel=$variavel" >> "$LOG_FILE"
```

### Testar Fase Específica

```bash
# Pular direto para fase 1 (assumindo fase 0 já rodou)
arch-chroot /mnt /root/archinstaller/scripts/1-setup.sh
```

### Shell Interativo no Chroot

```bash
# Após fase 0
arch-chroot /mnt
# Agora você está dentro do sistema instalado
# Pode testar comandos manualmente
```

### Dry Run (Simular)

Adicione flag `-n` em comandos críticos:

```bash
# Não executa, apenas mostra o que faria
pacman -S firefox --needed -n
```

---

## 🧪 Testes

### Checklist de Testes

Antes de fazer PR, teste:

- [ ] MINIMAL install com ext4
- [ ] FULL install com btrfs
- [ ] SERVER install
- [ ] LUKS encryption
- [ ] Diferentes DEs (pelo menos KDE e GNOME)
- [ ] Em UEFI
- [ ] Em BIOS legacy (se aplicável)

### Setup de Teste Rápido

#### VirtualBox

```bash
# Criar VM
VBoxManage createvm --name "ArchTest" --ostype "ArchLinux_64" --register
VBoxManage modifyvm "ArchTest" --memory 4096 --vram 128 --cpus 2
VBoxManage createhd --filename "ArchTest.vdi" --size 20480
VBoxManage storagectl "ArchTest" --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach "ArchTest" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "ArchTest.vdi"
VBoxManage storageattach "ArchTest" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "archlinux.iso"
```

#### QEMU

```bash
# Criar disco
qemu-img create -f qcow2 arch-test.qcow2 20G

# Boot ISO
qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 2 \
    -cdrom archlinux.iso \
    -boot d \
    -drive file=arch-test.qcow2,format=qcow2
```

### Automatizar Testes

Criar `test-install.sh`:

```bash
#!/bin/bash
# Auto-responder para testes

cat > test-config.txt <<EOF
João Silva
joao
senha123
senha123
archtest
EOF

# Mock input
./archinstall.sh < test-config.txt
```

---

## 📝 Convenções de Código

### Bash Style Guide

#### 1. Indentação

- 4 espaços (não tabs)
- Blocos if/for/while indentados

```bash
if [[ condition ]]; then
    comando
    if [[ outra_condition ]]; then
        outro_comando
    fi
fi
```

#### 2. Nomenclatura

- Funções: `snake_case`
- Variáveis locais: `snake_case`
- Variáveis globais (setup.conf): `UPPER_CASE`
- Constantes: `UPPER_CASE`

```bash
# Função
install_packages() {
    local package_list="$1"  # Local
    echo "Installing to $INSTALL_DIR"  # Global
}
```

#### 3. Aspas

- Sempre usar aspas em variáveis: `"$VAR"`
- Arrays: `"${ARRAY[@]}"`

```bash
# BOM
if [[ "$USERNAME" == "root" ]]; then

# RUIM
if [[ $USERNAME == "root" ]]; then
```

#### 4. Condicionais

- Usar `[[ ]]` ao invés de `[ ]`
- Preferir `&&` e `||` para lógica curta

```bash
# BOM
[[ -f "$FILE" ]] && echo "Existe"

# ACEITÁVEL
if [[ -f "$FILE" ]]; then
    echo "Existe"
fi
```

#### 5. Comandos

- Sempre verificar `$?` em comandos críticos
- Usar `--noconfirm` em pacman para não-interativo

```bash
pacman -S package --noconfirm --needed
exit_on_error $? "pacman -S package"
```

#### 6. Comentários

- Comentários em seções importantes
- Documentar funções complexas

```bash
# Detecta tipo de CPU e instala microcode apropriado
microcode_install() {
    proc_type=$(lscpu)
    # Intel tem "GenuineIntel" na saída
    if grep -E "GenuineIntel" <<<"${proc_type}"; then
        pacman -S intel-ucode
    fi
}
```

---

## 🔄 Git Workflow

### Branches

- `main`: Código estável
- `develop`: Desenvolvimento ativo
- `feature/nome`: Nova feature
- `fix/nome`: Bug fix

### Commits

```bash
# Mensagens descritivas
git commit -m "Add support for XFS filesystem"
git commit -m "Fix touchpad detection on laptops"
git commit -m "Update KDE packages to latest"
```

### Pull Requests

1. Fork o repositório
2. Crie feature branch
3. Faça commits pequenos e focados
4. Teste completamente
5. Abra PR com descrição detalhada

**Template de PR**:

```markdown
## Descrição
Breve descrição da mudança.

## Tipo de Mudança
- [ ] Bug fix
- [ ] Nova feature
- [ ] Breaking change
- [ ] Documentação

## Checklist
- [ ] Testei em VM (UEFI)
- [ ] Testei MINIMAL e FULL
- [ ] Atualizei documentação
- [ ] Código segue style guide

## Screenshots (se aplicável)
```

---

## 🔍 Code Review Checklist

Ao revisar PRs:

- [ ] Código segue convenções
- [ ] Funções tem propósito claro
- [ ] Sem hardcoded values (usar variáveis)
- [ ] Error handling adequado
- [ ] Logs adicionados onde necessário
- [ ] Sem código duplicado
- [ ] Documentação atualizada
- [ ] Testes mencionados

---

## 📚 Recursos Úteis

### Documentação Oficial

- [Arch Wiki](https://wiki.archlinux.org)
- [Bash Manual](https://www.gnu.org/software/bash/manual/)
- [JQ Manual](https://stedolan.github.io/jq/manual/)
- [systemd](https://www.freedesktop.org/software/systemd/man/)

### Ferramentas

- **shellcheck**: Linter para bash
  ```bash
  shellcheck archinstall.sh
  ```
  
- **shfmt**: Formatter para bash
  ```bash
  shfmt -i 4 -w archinstall.sh
  ```

### Debugging Tools

- `set -x`: Debug mode (mostra comandos executados)
- `set -e`: Exit on error
- `set -u`: Exit on undefined variable
- `trap`: Catch erros e sinais

```bash
#!/bin/bash
set -euo pipefail  # Modo estrito
trap 'echo "Error on line $LINENO"' ERR
```

---

## 🎯 Roadmap de Features

### Planejadas

- [ ] Suporte a Wayland (além de X11)
- [ ] Mais DEs (Sway, Hyprland, etc.)
- [ ] Suporte a ZFS
- [ ] Instalação dual-boot automática
- [ ] Pre-sets de configuração (Gaming, Developer, Server)
- [ ] Instalação remota via SSH
- [ ] GUI para configuração (ncurses)

### Em Consideração

- [ ] Suporte a outros bootloaders (systemd-boot)
- [ ] Suporte a outras distribuições Arch-based
- [ ] Sistema de plugins
- [ ] Backup automático antes de instalação

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Leia este guia completo
2. Teste suas mudanças extensivamente
3. Siga as convenções de código
4. Documente novas features
5. Seja respeitoso em discussões

---

## 📧 Contato

Para dúvidas sobre desenvolvimento:
- Abra uma issue no GitHub
- Participe das discussions

---

Happy coding! 🚀
