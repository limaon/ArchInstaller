# Issue Reporting Guide - ArchInstaller

This guide explains how to report ArchInstaller problems efficiently, helping us diagnose and resolve issues more quickly.

## Writing a Good Issue Report

A good issue report should contain the information needed for us to reproduce, diagnose, and resolve the problem. Use this format:

### Reporting Template

```markdown
## Problem Description
[Brief clear description of what happened]

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
[What you expected to happen]

## Current Behavior
[What actually happened]

## Installation Environment
- ArchInstaller version: [commit hash or branch used]
- Installation type: FULL/MINIMAL/SERVER
- Desktop Environment: [name and version]
- Filesystem: [btrfs/ext4/luks]
- Hardware: [VM/Baremetal, relevant specs]

## Diagnostic Information

### 1. Installation Configuration
```bash
# Remove passwords before sharing!
cat ~/.archinstaller/setup.conf | grep -v PASSWORD
```

### 2. Installation Log (Error Section)
```bash
grep -A 10 -B 10 "ERROR_MESSAGE" ~/.archinstaller/install.log
```

### 3. Verification Script
```bash
~/.archinstaller/verify-installation.sh
```

### 4. System Information
```bash
# Basic system
uname -a
free -h
lsblk
df -h

# Failed services
systemctl --failed

# Swap status
swapon --show
free -h
```

### 5. Commit/Branch Used
```bash
cd ~/.archinstaller
git log -1 --oneline
git branch --show-current
```

## Screenshots (If Applicable)
[Add relevant screenshots, especially for visual errors]

## Additional Context
[Any additional information that might be helpful]
```

---

## Essential Information Always Required

### 1. Specific Commit or Branch
Always specify exactly which version of ArchInstaller you used:

```bash
cd ~/.archinstaller
git log -1 --oneline
git branch --show-current
```

### 2. Installation Log (Relevant)
**NEVER share complete logs** - always extract only relevant sections:

```bash
# Search for specific errors
grep -i "error\|failed\|critical" ~/.archinstaller/install.log

# Search for specific messages
grep -A 10 -B 10 "ERROR_MESSAGE" ~/.archinstaller/install.log

# Search for specific stage logs
grep -A 5 -B 5 "user-creation" ~/.archinstaller/install.log
```

### 3. Configuration File (Safe)
**NO PASSWORDS!** Always remove sensitive information:

```bash
# Remove passwords before sharing
cat ~/.archinstaller/setup.conf | grep -v PASSWORD
```

---

## How to Extract Specific Information

### Critical Log Verification

```bash
# Most common errors
grep -i "error\|failed\|fail" /var/log/install.log | tail -20

# Pacman problems
grep -i "pacman\|package" /var/log/install.log | grep -i "error\|failed"

# Service problems
grep -i "systemd\|service\|enable\|start" /var/log/install.log | grep -i "fail"

# Swap problems
grep -i "swap\|zram" /var/log/install.log

# Boot problems
grep -i "grub\|boot\|kernel" /var/log/install.log
```

### System Verification

```bash
# System state
systemctl --failed

# Disk space
df -h

# Memory usage
free -h

# Swap
swapon --show

# Network
systemctl status NetworkManager

# Desktop environment
systemctl status lightdm  # or sddm/gdm
```

### Feature-Specific Verification

#### For i3-wm Issues:
```bash
# Specific scripts
ls -la /usr/local/bin/auto-suspend-hibernate
ls -la /usr/local/bin/check-swap-for-hibernate
ls -la /usr/local/bin/battery-*

# xidlehook status
ps aux | grep xidlehook

# GRUB configuration
grep resume /etc/default/grub

# Battery status
acpi -b
```

#### For Btrfs Issues:
```bash
# Snapshots
sudo snapper -c root list

# Subvolumes
btrfs subvolume list /

# Space
sudo btrfs filesystem df /
```

#### For Swap Issues:
```bash
# Complete status
swapon --show
free -h
zramctl

# Swap file location
ls -lh /swap/swapfile 2>/dev/null || ls -lh /swapfile 2>/dev/null

# Check script
/usr/local/bin/check-swap-for-hibernate --verbose 2>/dev/null
```

---

## How to Report on GitHub

When reporting issues on [GitHub Issues](https://github.com/limaon/ArchInstaller/issues):

### 1. Use Standard Template
The issue template already includes all necessary fields. Fill in each section.

### 2. Be Specific in Title
```markdown
BAD: "Doesn't work"
BAD: "Installation problem"
GOOD: "KDE desktop environment doesn't start after FULL installation"
GOOD: "Swap script fails on system with 8GB RAM and SSD"
GOOD: "Error creating user in SERVER installation"
```

### 3. Include Relevant Logs
Use ````bash code blocks for logs. Clean logs to show only relevant parts.

### 4. Provide Complete Environment
- Hardware model (if VM: VMware, VirtualBox, QEMU/KVM)
- Specifications (if VM: RAM, CPU, disk)
- Architecture (x86_64, arm64, etc.)
- Installation type (FULL/MINIMAL/SERVER)
- Selected desktop environment

---

## Common Errors and How to Avoid Them

### 1. Not Including Enough Information
**Problem:** "The script froze during installation"

**Solution:** Always include:
- Exactly where it froze (which stage)
- Specific error message
- Relevant log at that moment

### 2. Sharing Complete Logs
**Problem:** Pasting complete 1000+ line logs

**Solution:** Extract only relevant sections using grep

### 3. Not Specifying Script Version
**Problem:** "I'm using the latest script"

**Solution:** Always specify commit hash or specific branch

### 4. Not Describing the Environment
**Problem:** "Can't get it to work"

**Solution:** Inform hardware type, VM or bare metal, system specs

---

## Format for Critical Bugs

For serious problems that prevent installation completion:

```markdown
## [CRITICAL] Btrfs Partition Creation Failed

**Symptom:** System stops during disk formatting with "Invalid argument" error

**Environment:**
- Hardware: QEMU/KVM VM, 2GB RAM, 20GB SSD
- ArchInstaller: commit abc1234 (main branch)
- Installation type: FULL

**Error Log:**
```bash
[ 12:34:56] ERROR: mkfs.btrfs failed with exit code 1
[ 12:34:57] ERROR: Invalid argument '/dev/sda1'
```

**Commands Executed:**
```bash
sudo fdisk -l
sudo mkfs.btrfs /dev/sda1
```

**Manual Diagnosis:**
```bash
sudo fdisk -l  # Device exists
sudo file -s /dev/sda1  # Device type: DOS/MBR
```

**Reproducible:** Yes, always fails on QEMU/KVM VMs with legacy BIOS

**Workaround:** Using MINIMAL installation type works without issues
```

---

## Format for Improvements

For improvement suggestions or new features:

```markdown
## Feature Request: Add ZFS Support

**Motivation:**
- ZFS offers built-in snapshots similar to btrfs
- Data integrity checking support
- Compatibility with OpenZFS on other systems

**Proposed Solution:**
- Add ZFS filesystem option in menu
- Integration with verification scripts
- Maintain compatibility with existing btrfs/ext4

**Impact:**
- Increases ISO size (ZFS packages)
- Adds script complexity
- But provides robust alternative

**Priority:** Low - btrfs already covers most use cases
```

---

## Pre-Reporting Checklist

Before creating an issue, check:

- [ ] Checked [Quick Checklist](./QUICK-CHECK.md) and your problem isn't there
- [ ] Consulted [Common Problems](./COMMON-PROBLEMS.md) and [Specific Features](./SPECIFIC-FEATURES.md)
- [ ] Searched [GitHub Issues](https://github.com/limaon/ArchInstaller/issues) for similar issues
- [ ] Can reproduce the problem consistently
- [ ] Collected all necessary information (logs, environment, etc.)
- [ **Important** ] Removed sensitive information (passwords, private keys)

---

## Contact and Support

- **GitHub Issues:** [Report Bug or Improvement](https://github.com/limaon/ArchInstaller/issues)
- **Discussions:** [Discussions and Questions](https://github.com/limaon/ArchInstaller/discussions)
- **Wiki:** [Complete Documentation](../../docs/README.md)

## Acknowledgments

Thank you for your time in reporting and helping to improve ArchInstaller! Your feedback is essential to making this project more robust and easier to use.

### 2. Log de Instalação (Seção do Erro)
```bash
grep -A 10 -B 10 "MENSAGEM_DE_ERRO" ~/.archinstaller/install.log
```

### 3. Script de Verificação
```bash
~/.archinstaller/verify-installation.sh
```

### 4. Informações do Sistema
```bash
# Sistema básico
uname -a
free -h
lsblk
df -h

# Serviços falhando
systemctl --failed

# Status de swap
swapon --show
free -h
```

### 5. Commit/Branch Usado
```bash
cd ~/.archinstaller
git log -1 --oneline
git branch --show-current
```

## Screenshots (Se Aplicável)
[Adicionar screenshots relevantes, especialmente de erros visuais]

## Additional Context
[Qualquer informação adicional que possa ser útil]
```

---

## Informações Essenciais Sempre Necessárias

### 1. Commit ou Branch Específico
Sempre informe exatamente qual versão do ArchInstaller você usou:

```bash
cd ~/.archinstaller
git log -1 --oneline
git branch --show-current
```

### 2. Log de Instalação (Relevant)
**NEVER compartilhe logs completos** - sempre extraia apenas as seções relevantes:

```bash
# Buscar erros específicos
grep -i "error\|failed\|critical" ~/.archinstaller/install.log

# Buscar mensagens específicas
grep -A 10 -B 10 "MENSAGEM_DE_ERRO" ~/.archinstaller/install.log

# Buscar logs específicos de etapa
grep -A 5 -B 5 "user-creation" ~/.archinstaller/install.log
```

### 3. Arquivo de Configuração (Seguro)
**SEM SENHAS!** Remova sempre informações sensíveis:

```bash
# Remover senhas antes de compartilhar
cat ~/.archinstaller/setup.conf | grep -v PASSWORD
```

---

## Como Extrair Informações Específicas

### Verificação de Logs Críticos

```bash
# Erros mais comuns
grep -i "error\|failed\|fail" /var/log/install.log | tail -20

# Problemas de pacman
grep -i "pacman\|package" /var/log/install.log | grep -i "error\|failed"

# Problemas de serviço
grep -i "systemd\|service\|enable\|start" /var/log/install.log | grep -i "fail"

# Problemas de swap
grep -i "swap\|zram" /var/log/install.log

# Problemas de boot
grep -i "grub\|boot\|kernel" /var/log/install.log
```

### Verificação do Sistema

```bash
# Estado do sistema
systemctl --failed

# Espaço em disco
df -h

# Uso de memória
free -h

# Swap
swapon --show

# Network
systemctl status NetworkManager

# Desktop environment
systemctl status lightdm  # ou sddm/gdm
```

### Verificação Específica por Feature

#### Para Problemas com i3-wm:
```bash
# Scripts específicos
ls -la /usr/local/bin/auto-suspend-hibernate
ls -la /usr/local/bin/check-swap-for-hibernate
ls -la /usr/local/bin/battery-*

# Status do xidlehook
ps aux | grep xidlehook

# Configuração do GRUB
grep resume /etc/default/grub

# Status da bateria
acpi -b
```

#### Para Problemas com Btrfs:
```bash
# Snapshots
sudo snapper -c root list

# Subvolumes
btrfs subvolume list /

# Espaço
sudo btrfs filesystem df /
```

#### Para Problemas de Swap:
```bash
# Status completo
swapon --show
free -h
zramctl

# Local do arquivo de swap
ls -lh /swap/swapfile 2>/dev/null || ls -lh /swapfile 2>/dev/null

# Check script
/usr/local/bin/check-swap-for-hibernate --verbose 2>/dev/null
```

---

## Como Reportar no GitHub

Quando reportar issues no [GitHub Issues](https://github.com/limaon/ArchInstaller/issues):

### 1. Use Template Padrão
O template de issue já inclui todos os campos necessários. Preencha cada seção.

### 2. Seja Específico no Título
```markdown
RUIM: "Não funciona"
RUIM: "Problema com instalação"
BOM: "Desktop environment KDE não inicia após FULL installation"
BOM: "Script de swap falha em sistema com 8GB RAM e SSD"
BOM: "Erro ao criar usuário em instalação SERVER"
```

### 3. Inclua Logs Relevantes
Use blocos de código ````bash para logs. Limpe os logs para mostrar apenas o relevante.

### 4. Forneça Ambiente Completo
- Modelo do hardware (se VM: VMware, VirtualBox, QEMU/KVM)
- Especificações (se VM: RAM, CPU, disco)
- Arquitetura (x86_64, arm64, etc.)
- Tipo de instalação (FULL/MINIMAL/SERVER)
- Desktop environment escolhido

---

## Erros Comuns e Como Evitá-los

### 1. Não Incluir Informações Suficientes
**Problema:** "O script travou durante a instalação"

**Solução:** Sempre inclua:
- Exatamente onde travou (qual etapa)
- Mensagem de erro específica
- Log relevante naquele momento

### 2. Compartilhar Logs Completos
**Problema:** Colar log completo de 1000+ linhas

**Solução:** Extraia apenas as seções relevantes usando grep

### 3. Não Especificar Versão do Script
**Problema:** "Estou usando o script mais recente"

**Solução:** Sempre informe o commit hash ou branch específico

### 4. Não Descrever o Ambiente
**Problema:** "Não consigo fazer funcionar"

**Solução:** Informe tipo de hardware, VM ou bare metal, specs do sistema

---

## Formato para Bugs Críticos

Para problemas graves que impedem a conclusão da instalação:

```markdown
## [CRITICAL] Falha ao Criar Partição Btrfs

**Sintoma:** Sistema pára durante formatação de disco com erro "Invalid argument"

**Ambiente:**
- Hardware: QEMU/KVM VM, 2GB RAM, 20GB SSD
- ArchInstaller: commit abc1234 (main branch)
- Tipo de instalação: FULL

**Log de Erro:**
```bash
[ 12:34:56] ERROR: mkfs.btrfs failed with exit code 1
[ 12:34:57] ERROR: Invalid argument '/dev/sda1'
```

**Comandos Executados:**
```bash
sudo fdisk -l
sudo mkfs.btrfs /dev/sda1
```

**Diagnóstico Manual:**
```bash
sudo fdisk -l  # Dispositivo existe
sudo file -s /dev/sda1  # Tipo de dispositivo: DOS/MBR
```

**Reproduzível:** Sim, sempre falha em VMs com QEMU/KVM e BIOS legacy

**Workaround:** Usando tipo de instalação MINIMAL funciona sem problemas
```

---

## Formato para Melhorias

Para sugestões de melhorias ou novas features:

```markdown
## Feature Request: Adicionar Suporte a ZFS

**Motivação:**
- ZFS oferece snapshots integrados similar ao btrfs
- Suporte a data integrity checking
- Compatibilidade com OpenZFS em outros sistemas

**Solução Proposta:**
- Adicionar opção de filesystem ZFS no menu
- Integração com scripts de verificação
- Manter compatibilidade com btrfs/ext4 existentes

**Impacto:**
- Aumenta tamanho do ISO (pacotes ZFS)
- Adiciona complexidade ao script
- Mas fornece alternativa robusta

**Prioridade:** Baixa - btrfs já cobre maioria dos casos de uso
```

---

## Pré Checklist Antes de Reportar

Antes de criar um issue, verifique:

- [ ] Verificou [Checklist Rápido](./QUICK-CHECK.md) e seu problema não está lá
- [ ] Consultou [Problemas Comuns](./COMMON-PROBLEMS.md) e [Recursos Específicos](./SPECIFIC-FEATURES.md)
- [ ] Buscou no [GitHub Issues](https://github.com/limaon/ArchInstaller/issues) por issues similares
- [ ] Consegue reproduzir o problema consistentemente
- [ ] Coletou todas as informações necessárias (logs, ambiente, etc.)
- [ **Importante** ] Removeu informações sensíveis (senhas, chaves privadas)

---

## Contato e Suporte

- **GitHub Issues:** [Reportar Bug ou Melhoria](https://github.com/limaon/ArchInstaller/issues)
- **Discussions:** [Discussões e Perguntas](https://github.com/limaon/ArchInstaller/discussions)
- **Wiki:** [Documentação Completa](../../docs/README.md)

## Agradecimentos

Agradecemos seu tempo em reportar e ajudar a melhorar o ArchInstaller! Seu feedback é essencial para tornar este projeto mais robusto e fácil de usar.
