# Development Guide

This document is for developers who want to add features, fix bugs, or contribute to ArchInstaller.

---

## Getting Started

### Prerequisites

- Knowledge of Bash scripting
- Familiarity with Arch Linux
- Git
- VM for testing (VirtualBox, VMware, QEMU, etc.)

### Development Setup

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/your-username/ArchInstaller
   cd ArchInstaller
   ```

2. **Create Branch**:
   ```bash
   git checkout -b feature/my-feature
   ```

3. **Test in VM**:
   - Create VM with 20GB+ disk
   - Boot Arch Linux ISO
   - Clone your fork inside the VM

---

## Code Structure

### Hierarchy of Responsibilities

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

### When to Modify Each File

**archinstall.sh**: Rarely. Only if changing general orchestration.

**configuration.sh**: Add/remove configuration questions.

**0-preinstall.sh**: Modify partitioning, filesystem creation.

**1-setup.sh**: Add system configurations, new repos.

**2-user.sh**: Change desktop/AUR installation order.

**3-post-setup.sh**: Add services, modify cleanup.

**utils/\*.sh**: Add reusable functions.

**packages/\*.json**: Add/remove packages.

---

## Adding Features

### Feature: New Desktop Environment

#### 1. Create Package JSON

`packages/desktop-environments/my-de.json`:

```json
{
  "minimal": {
    "pacman": [
      {"package": "my-de-core"},
      {"package": "terminal-emulator"},
      {"package": "file-manager"},
      {"package": "display-manager"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "my-de-full"},
      {"package": "extra-apps"}
    ],
    "aur": [
      {"package": "aur-themes"}
    ]
  }
}
```

#### 2. Configure Display Manager

In `scripts/utils/system-config.sh`, add to `display_manager()`:

```bash
elif [[ "${DESKTOP_ENV}" == "my-de" ]]; then
    systemctl enable my-dm.service

    if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
        # Theme configuration
        echo "theme=my-theme" >> /etc/my-dm/my-dm.conf
    fi
```

#### 3. (Optional) Theming

If you have dotfiles in `configs/my-de/`, add to `scripts/utils/software-install.sh -> user_theming()`:

```bash
elif [[ "$DESKTOP_ENV" == "my-de" ]]; then
    cp -r ~/archinstaller/configs/my-de/home/. ~/
    # Apply additional configurations
```

#### 4. Test

```bash
./archinstall.sh
# Select "my-de" from list
```

---

### Feature: New Configuration Option

#### 1. Add Collection Function

In `scripts/utils/user-options.sh`:

```bash
my_option() {
    echo -ne "
Please select option:
"
    options=("Option A" "Option B" "Option C")
    select_option $? 3 "${options[@]}"
    my_choice="${options[$?]}"
    set_option MY_OPTION "$my_choice"
}
```

#### 2. Add to Configuration Workflow

In `scripts/configuration.sh`:

```bash
# After other configurations
my_option
clear
```

#### 3. Add to Show Configurations

In `scripts/utils/user-options.sh -> show_configurations()`:

```bash
# In menu
10) My Option
...

# In case
case $choice in
    ...
    10) my_option ;;
    ...
esac
```

#### 4. Use Configuration

In any later script:

```bash
source "$HOME"/archinstaller/configs/setup.conf

if [[ "$MY_OPTION" == "Option A" ]]; then
    # Do something
fi
```

---

### Feature: Hardware Detection

Example: Detect if touchpad exists.

#### 1. Add Detection Function

In `scripts/utils/software-install.sh`:

```bash
touchpad_install() {
    echo -ne "
-------------------------------------------------------------------------
                    Detecting Touchpad
-------------------------------------------------------------------------
"
    # Detect touchpad
    if xinput list | grep -i "touchpad"; then
        echo "Touchpad detected, installing libinput"
        pacman -S --noconfirm --needed xf86-input-libinput

        # Additional configuration
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

#### 2. Call Function

In `scripts/1-setup.sh` or `scripts/2-user.sh`:

```bash
# After graphics_install()
touchpad_install
```

---

### Feature: New Filesystem

Example: XFS support.

#### 1. Add Option

In `scripts/utils/user-options.sh -> filesystem()`:

```bash
options=("btrfs" "ext4" "xfs" "luks" "exit")
select_option $? 1 "${options[@]}"

case $? in
0) set_btrfs; set_option FS btrfs ;;
1) set_option FS ext4 ;;
2) set_option FS xfs ;;  # New option
3) set_password "LUKS_PASSWORD"; set_option FS luks ;;
4) exit ;;
esac
```

#### 2. Implement Creation

In `scripts/utils/system-config.sh -> create_filesystems()`:

```bash
if [[ "${FS}" == "btrfs" ]]; then
    do_btrfs "ROOT" "${root_partition}"
elif [[ "${FS}" == "ext4" ]]; then
    mkfs.ext4 -L ROOT "${root_partition}"
    mount -t ext4 "${root_partition}" /mnt
elif [[ "${FS}" == "xfs" ]]; then
    # New implementation
    mkfs.xfs -L ROOT "${root_partition}"
    mount -t xfs "${root_partition}" /mnt
elif [[ "${FS}" == "luks" ]]; then
    # ...
fi
```

---

## Debugging

### Logs

Everything is logged to `install.log`:

```bash
# During installation, in another terminal (Ctrl+Alt+F2)
tail -f /root/ArchInstaller/install.log

# After installation, in installed system
less /var/log/install.log
```

### Add Debug Output

```bash
echo "DEBUG: variable=$variable" >> "$LOG_FILE"
```

### Test Specific Phase

```bash
# Skip directly to phase 1 (assuming phase 0 already ran)
arch-chroot /mnt /root/archinstaller/scripts/1-setup.sh
```

### Interactive Shell in Chroot

```bash
# After phase 0
arch-chroot /mnt
# Now you're inside the installed system
# Can test commands manually
```

### Dry Run (Simulate)

Add `-n` flag to critical commands:

```bash
# Doesn't execute, just shows what it would do
pacman -S firefox --needed -n
```

---

## Testing

### Testing Checklist

Before making PR, test:

- [ ] MINIMAL install with ext4
- [ ] FULL install with btrfs
- [ ] SERVER install
- [ ] LUKS encryption
- [ ] Different DEs (at least KDE and GNOME)
- [ ] On UEFI
- [ ] On BIOS legacy (if applicable)

### Quick Test Setup

#### VirtualBox

```bash
# Create VM
VBoxManage createvm --name "ArchTest" --ostype "ArchLinux_64" --register
VBoxManage modifyvm "ArchTest" --memory 4096 --vram 128 --cpus 2
VBoxManage createhd --filename "ArchTest.vdi" --size 20480
VBoxManage storagectl "ArchTest" --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach "ArchTest" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "ArchTest.vdi"
VBoxManage storageattach "ArchTest" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "archlinux.iso"
```

#### QEMU

```bash
# Create disk
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

### Automate Tests

Create `test-install.sh`:

```bash
#!/bin/bash
# Auto-responder for testing

cat > test-config.txt <<EOF
John Smith
john
password123
password123
archtest
EOF

# Mock input
./archinstall.sh < test-config.txt
```

---

## Code Conventions

### Bash Style Guide

#### 1. Indentation

- 4 spaces (not tabs)
- Indented if/for/while blocks

```bash
if [[ condition ]]; then
    command
    if [[ other_condition ]]; then
        another_command
    fi
fi
```

#### 2. Naming

- Functions: `snake_case`
- Local variables: `snake_case`
- Global variables (setup.conf): `UPPER_CASE`
- Constants: `UPPER_CASE`

```bash
# Function
install_packages() {
    local package_list="$1"  # Local
    echo "Installing to $INSTALL_DIR"  # Global
}
```

#### 3. Quotes

- Always quote variables: `"$VAR"`
- Arrays: `"${ARRAY[@]}"`

```bash
# GOOD
if [[ "$USERNAME" == "root" ]]; then

# BAD
if [[ $USERNAME == "root" ]]; then
```

#### 4. Conditionals

- Use `[[ ]]` instead of `[ ]`
- Prefer `&&` and `||` for short logic

```bash
# GOOD
[[ -f "$FILE" ]] && echo "Exists"

# ACCEPTABLE
if [[ -f "$FILE" ]]; then
    echo "Exists"
fi
```

#### 5. Commands

- Always check `$?` on critical commands
- Use `--noconfirm` in pacman for non-interactive

```bash
pacman -S package --noconfirm --needed
exit_on_error $? "pacman -S package"
```

#### 6. Comments

- Comments on important sections
- Document complex functions

```bash
# Detects CPU type and installs appropriate microcode
microcode_install() {
    proc_type=$(lscpu)
    # Intel has "GenuineIntel" in output
    if grep -E "GenuineIntel" <<<"${proc_type}"; then
        pacman -S intel-ucode
    fi
}
```

---

## Git Workflow

### Recommended Branching Strategy

For the ArchInstaller project, we recommend a hybrid approach based on **GitHub Flow** with elements of **GitFlow**, optimized for our installation tool project context:

#### Main Branches

```bash
main          # Main branch - stable code ready for release
develop       # Development branch - continuous integration
feature/*     # Feature branches for new functionality
bugfix/*      # Bug fix branches for corrections
hotfix/*      # Emergency fixes for production
release/*     # Release preparation (optional)
```

#### Workflow

```bash
# 1. Start new feature
git checkout develop
git pull origin develop
git checkout -b feature/feature-name

# 2. Development with semantic commits
git add .
git commit -m "feat(installer): add support for XFS filesystem"

# 3. Push and Pull Request
git push origin feature/feature-name
# Create PR: feature/feature-name → develop

# 4. After merge, sync develop
git checkout develop
git pull origin develop

# 5. For release
git checkout main
git pull origin main
git merge develop
git tag v1.2.0
git push origin main --tags
```

### Semantic Commits (Conventional Commits)

We adopt the **Conventional Commits** specification for standardized and machine-readable commit messages.

#### Basic Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Commit Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(installer): add ZFS filesystem support` |
| `fix` | Bug fix | `fix(disk): resolve partition detection on NVMe` |
| `docs` | Documentation changes | `docs(readme): update installation requirements` |
| `style` | Formatting, style (no logic) | `style(utils): fix indentation in helper functions` |
| `refactor` | Code refactoring | `refactor(config): simplify user input validation` |
| `perf` | Performance improvements | `perf(bootstrap): reduce package download time` |
| `test` | Add/fix tests | `test(installer): add unit tests for filesystem detection` |
| `build` | Build/dependencies changes | `build(deps): update jq to latest version` |
| `ci` | CI/CD changes | `ci(github): add automated testing workflow` |
| `chore` | Maintenance tasks | `chore(deps): clean up unused dependencies` |
| `revert` | Revert previous commit | `revert: feat(installer): remove experimental feature` |

#### Common Scopes for ArchInstaller

- `installer`: Main installer functionality
- `disk`: Disk/partitioning operations
- `config`: User configurations and options
- `deps`: Dependency/package management
- `ui`: User interface
- `utils`: Utility functions
- `docs`: Documentation
- `ci`: Continuous integration

#### Semantic Commit Examples

```bash
# Simple new feature
git commit -m "feat(disk): add support for BTRFS filesystem"

# With explanatory body
git commit -m "feat(config): implement automatic hardware detection

Add comprehensive hardware detection for graphics cards, network cards,
and input devices. This eliminates manual configuration for most
common hardware setups.

Fixes #123"
```

```bash
# Breaking Change
git commit -m "feat!: change configuration file format to YAML

BREAKING CHANGE: Configuration files now use YAML format instead of
bash variables. Existing config files need to be migrated."
```

```bash
# With scope and body
git commit -m "fix(installer): resolve memory allocation on low-resource systems

Previously the installer would crash on systems with less than 512MB RAM.
Now implements memory-safe operations and graceful degradation.

Closes #456"
```

### Branch Naming

#### Recommended Pattern

```bash
# Feature branches
feature/install-zfs-support
feature/gui-wizard
feature/auto-partition

# Bugfix branches
bugfix/fix-nvme-detection
bugfix/resolve-memory-leak
bugfix/111-troubleshoot

# Hotfix branches (emergency)
hotfix/urgent-security-patch
hotfix/critical-installer-crash

# Release branches
release/v2.1.0
release/v2.1.1-rc1
```

#### Conventions

- Use **kebab-case** (hyphens, not underscores)
- Include **issue number** when applicable: `bugfix/456-fix-network-detection`
- Be **descriptive** but **concise**
- Avoid generic names like `feature/new-feature` or `fix/bug`

### Pull Requests (PRs)

#### Pull Request Structure

```markdown
## Description
Brief description of the implemented change.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Style/Refactoring
- [ ] Performance
- [ ] Tests

## Related Issue
Closes #123 (if applicable)

## Implemented Changes
- Detailed list of changes
- Include screenshots if visual change
- Explain important technical decisions

## Testing Checklist
- [ ] Tested in VM UEFI
- [ ] Tested in VM BIOS (if applicable)
- [ ] Tested MINIMAL installation
- [ ] Tested FULL installation
- [ ] Tested SERVER installation
- [ ] Tested with different filesystems (ext4, btrfs, xfs)
- [ ] Tested different DEs (KDE, GNOME, etc.)

## Quality Checklist
- [ ] Code follows style guide
- [ ] Commits follow Conventional Commits
- [ ] Documentation updated
- [ ] No hardcoded sensitive values
- [ ] Appropriate logs added
- [ ] Automated tests pass

## Release Notes (if applicable)
- Feature: X new functionality
- Fix: Y bug fixed
- Breaking: Z breaking change
```

#### Code Review

**For Reviewers:**
- [ ] Code follows conventions
- [ ] Functions have clear purpose
- [ ] No hardcoded values (use variables)
- [ ] Adequate error handling
- [ ] Logs added where necessary
- [ ] No duplicated code
- [ ] Documentation updated
- [ ] Tests mentioned/executed

**For Authors:**
- Respond to all comments
- Make requested corrections
- Keep PR updated with main
- Be respectful and constructive

### Continuous Integration

#### GitHub Actions (Recommended)

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Environment
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck jq

      - name: Lint Bash Scripts
        run: |
          find . -name "*.sh" -exec shellcheck {} \;

      - name: Check Commit Messages
        uses: commitizen-tools/commitizen@v0.21
        with:
          args: check

      - name: Validate JSON Files
        run: |
          find packages/ -name "*.json" -exec jq . {} \;
```

### Versioning

#### Semantic Versioning (SemVer)

```bash
# Format: MAJOR.MINOR.PATCH

MAJOR: Breaking changes
  ex: 1.2.3 → 2.0.0

MINOR: New features (backward compatible)
  ex: 1.2.3 → 1.3.0

PATCH: Bug fixes (backward compatible)
  ex: 1.2.3 → 1.2.4
```

#### Commit-based Auto-versioning

```bash
# Example script for version calculation
#!/bin/bash
# version.sh

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
COMMITS_SINCE_TAG=$(git rev-list --count $LAST_TAG..HEAD)

# Count commit types since last tag
FIXES=$(git log $LAST_TAG..HEAD --oneline | grep -c "^feat")
FEATURES=$(git log $LAST_TAG..HEAD --oneline | grep -c "^fix")
BREAKING=$(git log $LAST_TAG..HEAD --oneline | grep -c "BREAKING CHANGE")

BASE_VERSION=$(echo $LAST_TAG | sed 's/^v//')

if [ $BREAKING -gt 0 ]; then
    # Increment major
    MAJOR=$(echo $BASE_VERSION | cut -d. -f1)
    NEW_VERSION="$((MAJOR + 1)).0.0"
elif [ $FEATURES -gt 0 ]; then
    # Increment minor
    MAJOR=$(echo $BASE_VERSION | cut -d. -f1)
    MINOR=$(echo $BASE_VERSION | cut -d. -f2)
    NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
elif [ $FIXES -gt 0 ]; then
    # Increment patch
    MAJOR=$(echo $BASE_VERSION | cut -d. -f1)
    MINOR=$(echo $BASE_VERSION | cut -d. -f2)
    PATCH=$(echo $BASE_VERSION | cut -d. -f3)
    NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
else
    NEW_VERSION="$BASE_VERSION-$COMMITS_SINCE_TAG"
fi

echo $NEW_VERSION
```

### Additional Best Practices

#### Commit Hygiene

```bash
# Before committing
git add .
git status  # Check what will be committed
git diff --staged  # Review changes

# Atomic commits (one idea per commit)
# BAD: Multiple unrelated changes
git commit -m "feat: add ZFS support and fix disk detection and update docs"

# GOOD: Separate commits by purpose
git commit -m "feat(disk): add ZFS filesystem support"
git commit -m "fix(disk): resolve NVMe detection issue"
git commit -m "docs(readme): update installation instructions"
```

#### Branch Management

```bash
# Keep branches updated
git checkout feature/my-feature
git fetch origin
git rebase origin/develop

# Clean up local merged branches
git branch --merged | grep -v "main\|develop" | xargs git branch -d

# Branch protection on GitHub (recommended)
- Protect main branch
- Require PR review
- Require CI/CD status checks
- Disallow force pushes
```

#### Common Troubleshooting

```bash
# Resolve merge conflicts
git checkout develop
git pull origin develop
git checkout feature/my-feature
git merge develop
# Resolve conflicts manually
git add .
git commit -m "resolve: merge conflicts from develop"

# Revert wrong commit
git revert HEAD  # Creates new commit reverting the last one
# OR (if not yet pushed)
git reset --hard HEAD~1

# Squash commits before PR
git rebase -i HEAD~5  # Select "squash" for related commits
```

#### Fluxo de Trabalho

```bash
# 1. Iniciar nova funcionalidade
git checkout develop
git pull origin develop
git checkout -b feature/nome-da-funcionalidade

# 2. Desenvolvimento com commits semânticos
git add .
git commit -m "feat(installer): add support for XFS filesystem"

# 3. Push e Pull Request
git push origin feature/nome-da-funcionalidade
# Criar PR: feature/nome-da-funcionalidade → develop

# 4. Após merge, sincronizar develop
git checkout develop
git pull origin develop

# 5. Para release
git checkout main
git pull origin main
git merge develop
git tag v1.2.0
git push origin main --tags
```

### Commits Semânticos (Conventional Commits)

Adotamos a especificação **Conventional Commits** para mensagens de commit padronizadas e legíveis por máquina.

#### Formato Básico

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Tipos de Commit

| Tipo | Descrição | Exemplo |
|------|----------|---------|
| `feat` | Nova funcionalidade | `feat(installer): add ZFS filesystem support` |
| `fix` | Correção de bug | `fix(disk): resolve partition detection on NVMe` |
| `docs` | Mudanças na documentação | `docs(readme): update installation requirements` |
| `style` | Formatação, estilo (sem lógica) | `style(utils): fix indentation in helper functions` |
| `refactor` | Refatoração de código | `refactor(config): simplify user input validation` |
| `perf` | Melhorias de performance | `perf(bootstrap): reduce package download time` |
| `test` | Adicionar/corrigir testes | `test(installer): add unit tests for filesystem detection` |
| `build` | Mudanças no build/dependencies | `build(deps): update jq to latest version` |
| `ci` | Mudanças na CI/CD | `ci(github): add automated testing workflow` |
| `chore` | Tarefas de manutenção | `chore(deps): clean up unused dependencies` |
| `revert` | Reverter commit anterior | `revert: feat(installer): remove experimental feature` |

#### Escopos (Scopes) Comuns para ArchInstaller

- `installer`: Funcionalidades principais do instalador
- `disk`: Operações de disco/particionamento
- `config`: Configurações e opções do usuário
- `deps`: Gerenciamento de dependências/pacotes
- `ui`: Interface com o usuário
- `utils`: Funções utilitárias
- `docs`: Documentação
- `ci`: Integração contínua

#### Exemplos de Commits Semânticos

```bash
# Nova funcionalidade simples
git commit -m "feat(disk): add support for BTRFS filesystem"

# Com corpo explicativo
git commit -m "feat(config): implement automatic hardware detection

Add comprehensive hardware detection for graphics cards, network cards,
and input devices. This eliminates manual configuration for most
common hardware setups.

Fixes #123"
```

```bash
# Breaking Change
git commit -m "feat!: change configuration file format to YAML

BREAKING CHANGE: Configuration files now use YAML format instead of
bash variables. Existing config files need to be migrated."
```

```bash
# Com escopo e corpo
git commit -m "fix(installer): resolve memory allocation on low-resource systems

Previously the installer would crash on systems with less than 512MB RAM.
Now implements memory-safe operations and graceful degradation.

Closes #456"
```

### Nomenclatura de Branches

#### Padrão Recomendado

```bash
# Feature branches
feature/install-zfs-support
feature/gui-wizard
feature/auto-partition

# Bugfix branches
bugfix/fix-nvme-detection
bugfix/resolve-memory-leak
bugfix/111-troubleshoot

# Hotfix branches (emergenciais)
hotfix/urgent-security-patch
hotfix/critical-installer-crash

# Release branches
release/v2.1.0
release/v2.1.1-rc1
```

#### Convenções

- Use **kebab-case** (hífens, não underscores)
- Inclua **issue number** quando aplicável: `bugfix/456-fix-network-detection`
- Seja **descritivo** mas **conciso**
- Evite nomes genéricos como `feature/new-feature` ou `fix/bug`

### Pull Requests (PRs)

#### Estrutura de Pull Request

```markdown
## Descrição
Breve descrição da mudança implementada.

## Tipo de Mudança
- [ ] Bug fix
- [ ] Nova feature
- [ ] Breaking change
- [ ] Documentação
- [ ] Estilo/Refatoração
- [ ] Performance
- [ ] Testes

## Issue Relacionada
Closes #123 (se aplicável)

## Mudanças Implementadas
- Lista detalhada das mudanças
- Incluir screenshots se for mudança visual
- Explicar decisões técnicas importantes

## Checklist de Testes
- [ ] Testado em VM UEFI
- [ ] Testado em VM BIOS (se aplicável)
- [ ] Testado instalação MINIMAL
- [ ] Testado instalação FULL
- [ ] Testado instalação SERVER
- [ ] Testado com diferentes filesystems (ext4, btrfs, xfs)
- [ ] Testado diferentes DEs (KDE, GNOME, etc.)

## Checklist de Qualidade
- [ ] Código segue o style guide
- [ ] Commits seguem Conventional Commits
- [ ] Documentação atualizada
- [ ] Sem hardcode de valores sensíveis
- [ ] Logs apropriados adicionados
- [ ] Testes automatizados passam

## Notas de Release (se aplicável)
- Feature: X nova funcionalidade
- Fix: Y bug corrigido
- Breaking: Z mudança quebradora
```

#### Revisão de Código

**Para Revisores:**
- [ ] Código segue as convenções
- [ ] Funções têm propósito claro
- [ ] Sem valores hardcoded (use variáveis)
- [ ] Tratamento adequado de erros
- [ ] Logs adicionados onde necessário
- [ ] Sem código duplicado
- [ ] Documentação atualizada
- [ ] Testes mencionados/executados

**Para Autores:**
- Responda a todos os comentários
- Faça as correções solicitadas
- Mantenha o PR atualizado com o main
- Seja educado e construtivo

### Integração Contínua

#### GitHub Actions (Recomendado)

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Environment
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck jq

      - name: Lint Bash Scripts
        run: |
          find . -name "*.sh" -exec shellcheck {} \;

      - name: Check Commit Messages
        uses: commitizen-tools/commitizen@v0.21
        with:
          args: check

      - name: Validate JSON Files
        run: |
          find packages/ -name "*.json" -exec jq . {} \;
```

### Versionamento

#### Semantic Versioning (SemVer)

```bash
# Formato: MAJOR.MINOR.PATCH

MAIOR: Mudanças quebradoras (breaking changes)
  ex: 1.2.3 → 2.0.0

MENOR: Novas funcionalidades (backward compatible)
  ex: 1.2.3 → 1.3.0

PATCH: Correções de bugs (backward compatible)
  ex: 1.2.3 → 1.2.4
```

#### Auto-versionamento baseado em Commits

```bash
# Exemplo de script para calcular versão
#!/bin/bash
# version.sh

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
COMMITS_SINCE_TAG=$(git rev-list --count $LAST_TAG..HEAD)

# Contar tipos de commits desde o último tag
FIXES=$(git log $LAST_TAG..HEAD --oneline | grep -c "^feat")
FEATURES=$(git log $LAST_TAG..HEAD --oneline | grep -c "^fix")
BREAKING=$(git log $LAST_TAG..HEAD --oneline | grep -c "BREAKING CHANGE")

BASE_VERSION=$(echo $LAST_TAG | sed 's/^v//')

if [ $BREAKING -gt 0 ]; then
    # Incrementar major
    MAJOR=$(echo $BASE_VERSION | cut -d. -f1)
    NEW_VERSION="$((MAJOR + 1)).0.0"
elif [ $FEATURES -gt 0 ]; then
    # Incrementar minor
    MAJOR=$(echo $BASE_VERSION | cut -d. -f1)
    MINOR=$(echo $BASE_VERSION | cut -d. -f2)
    NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
elif [ $FIXES -gt 0 ]; then
    # Incrementar patch
    MAJOR=$(echo $BASE_VERSION | cut -d. -f1)
    MINOR=$(echo $BASE_VERSION | cut -d. -f2)
    PATCH=$(echo $BASE_VERSION | cut -d. -f3)
    NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
else
    NEW_VERSION="$BASE_VERSION-$COMMITS_SINCE_TAG"
fi

echo $NEW_VERSION
```

### Boas Práticas Adicionais

#### Commit Hygiene

```bash
# Antes de commitar
git add .
git status  # Verificar o que será commitado
git diff --staged  # Revisar mudanças

# Commits atômicos (uma ideia por commit)
# RUIM: Múltiplas mudanças não relacionadas
git commit -m "feat: add ZFS support and fix disk detection and update docs"

# BOM: Commits separados por propósito
git commit -m "feat(disk): add ZFS filesystem support"
git commit -m "fix(disk): resolve NVMe detection issue"
git commit -m "docs(readme): update installation instructions"
```

#### Branch Management

```bash
# Manter branches atualizados
git checkout feature/minha-feature
git fetch origin
git rebase origin/develop

# Limpar branches locais já merged
git branch --merged | grep -v "main\|develop" | xargs git branch -d

# Branch protection no GitHub (recomendado)
- Proteger branch main
- Exigir PR review
- Exigir CI/CD status checks
- Proibir force pushes
```

#### Troubleshooting Comum

```bash
# Resolver merge conflicts
git checkout develop
git pull origin develop
git checkout feature/minha-feature
git merge develop
# Resolver conflitos manualmente
git add .
git commit -m "resolve: merge conflicts from develop"

# Reverter commit errado
git revert HEAD  # Cria novo commit revertendo o último
# OU (se ainda não foi pushado)
git reset --hard HEAD~1

# Squash commits antes do PR
git rebase -i HEAD~5  # Selecionar "squash" para commits relacionados
```

---

## Code Review Checklist

When reviewing PRs:

- [ ] Code follows conventions
- [ ] Functions have clear purpose
- [ ] No hardcoded values (use variables)
- [ ] Adequate error handling
- [ ] Logs added where necessary
- [ ] No duplicated code
- [ ] Documentation updated
- [ ] Tests mentioned

---

## Useful Resources

### Official Documentation

- [Arch Wiki](https://wiki.archlinux.org)
- [Bash Manual](https://www.gnu.org/software/bash/manual/)
- [JQ Manual](https://stedolan.github.io/jq/manual/)
- [systemd](https://www.freedesktop.org/software/systemd/man/)

### Tools

- **shellcheck**: Bash linter
  ```bash
  shellcheck archinstall.sh
  ```

- **shfmt**: Bash formatter
  ```bash
  shfmt -i 4 -w archinstall.sh
  ```

### Debugging Tools

- `set -x`: Debug mode (shows executed commands)
- `set -e`: Exit on error
- `set -u`: Exit on undefined variable
- `trap`: Catch errors and signals

```bash
#!/bin/bash
set -euo pipefail  # Strict mode
trap 'echo "Error on line $LINENO"' ERR
```

---

## Feature Roadmap

### Planned

- [ ] Wayland support (in addition to X11)
- [ ] More DEs (Sway, Hyprland, etc.)
- [ ] ZFS support
- [ ] Automatic dual-boot installation
- [ ] Configuration presets (Gaming, Developer, Server)
- [ ] Remote installation via SSH
- [ ] Configuration GUI (ncurses)

### Under Consideration

- [ ] Support for other bootloaders (systemd-boot)
- [ ] Support for other Arch-based distributions
- [ ] Plugin system
- [ ] Automatic backup before installation

---

## Contributing

Contributions are welcome! Please:

1. Read this complete guide
2. Test your changes extensively
3. Follow code conventions
4. Document new features
5. Be respectful in discussions

---

## Contact

For development questions:
- Open an issue on GitHub
- Participate in discussions

---

Happy coding!
