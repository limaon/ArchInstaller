# ArchInstaller - Documentação Completa

## 📖 Índice da Documentação

1. **[README.md](README.md)** - Este arquivo (visão geral)
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Arquitetura completa do sistema
3. **[USER-GUIDE.md](USER-GUIDE.md)** - Guia de uso e instalação
4. **[FUNCTIONS-REFERENCE.md](FUNCTIONS-REFERENCE.md)** - Referência de todas as funções
5. **[PACKAGE-SYSTEM.md](PACKAGE-SYSTEM.md)** - Sistema de pacotes JSON
6. **[DEVELOPMENT-GUIDE.md](DEVELOPMENT-GUIDE.md)** - Guia para desenvolvedores

---

## 🎯 O que é o ArchInstaller?

O **ArchInstaller** é um instalador automatizado e interativo do Arch Linux que transforma a instalação manual complexa em um processo guiado e simplificado. Ele instala um sistema Arch Linux completo com:

- ✅ Particionamento automático de disco
- ✅ Suporte a múltiplos filesystems (ext4, btrfs, LUKS)
- ✅ Detecção automática de hardware (CPU, GPU, bateria)
- ✅ Instalação de ambientes desktop completos
- ✅ Configuração de drivers, microcodes e otimizações
- ✅ Sistema de snapshots (btrfs + Snapper)
- ✅ Temas e configurações pré-aplicadas

---

## 🚀 Início Rápido

### Pré-requisitos
- Boot em uma ISO do Arch Linux
- Conexão com internet
- Privilégios de root

### Instalação

```bash
# 1. Clone o repositório
git clone https://github.com/seu-usuario/ArchInstaller
cd ArchInstaller

# 2. Execute o instalador
chmod +x archinstall.sh
./archinstall.sh
```

### Processo Interativo

O instalador irá perguntar:

1. **Nome completo, username e senha**
2. **Tipo de instalação**: FULL / MINIMAL / SERVER
3. **AUR Helper**: yay, paru, etc.
4. **Ambiente Desktop**: KDE, GNOME, i3, etc.
5. **Disco de instalação** (⚠️ será formatado!)
6. **Filesystem**: btrfs, ext4 ou LUKS
7. **Timezone** (detecta automaticamente)
8. **Idioma do sistema** (locale)
9. **Layout do teclado**

Após a revisão das configurações, a instalação automática começa!

---

## 📂 Estrutura do Projeto

```
ArchInstaller/
├── archinstall.sh              # Script principal (ponto de entrada)
├── configs/
│   └── setup.conf              # Arquivo de configuração gerado
├── scripts/
│   ├── configuration.sh        # Workflow interativo de configuração
│   ├── 0-preinstall.sh         # Fase 0: Particionamento e pacstrap
│   ├── 1-setup.sh              # Fase 1: Configuração do sistema
│   ├── 2-user.sh               # Fase 2: Instalação de usuário (AUR/DE)
│   ├── 3-post-setup.sh         # Fase 3: Finalização e serviços
│   └── utils/                  # Scripts utilitários
│       ├── installer-helper.sh # Funções auxiliares
│       ├── system-checks.sh    # Verificações de segurança
│       ├── user-options.sh     # Coleta de configurações
│       ├── software-install.sh # Instalação de software
│       └── system-config.sh    # Configuração do sistema
├── packages/                   # Definições de pacotes (JSON)
│   ├── base.json              # Pacotes base do sistema
│   ├── btrfs.json             # Ferramentas btrfs
│   ├── desktop-environments/  # Um JSON por DE
│   │   ├── kde.json
│   │   ├── gnome.json
│   │   ├── i3-wm.json
│   │   └── ...
│   └── optional/
│       └── fonts.json         # Fontes do sistema
└── docs/                      # Esta documentação
```

---

## 🔄 Fluxo de Execução

```
┌─────────────────────────────────────────────────────────────┐
│  1. archinstall.sh                                          │
│     - Carrega utilitários                                   │
│     - Executa configuration.sh (coleta dados)               │
│     - Inicia sequence() com as 4 fases                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  FASE 0: 0-preinstall.sh (Live ISO - antes do chroot)      │
│     - Atualiza mirrors                                      │
│     - Particiona disco (GPT)                                │
│     - Cria filesystems (ext4/btrfs/LUKS)                   │
│     - Pacstrap sistema base                                 │
│     - Gera fstab                                            │
│     - Instala bootloader                                    │
│     - Configura ZRAM se <8GB RAM                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  FASE 1: 1-setup.sh (Chroot como root)                     │
│     - Instala NetworkManager                                │
│     - Configura locale, timezone, keymap                    │
│     - Habilita multilib                                     │
│     - Instala pacotes base                                  │
│     - Detecta e instala microcode (Intel/AMD)               │
│     - Detecta e instala drivers GPU                         │
│     - Cria usuário e grupos                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  FASE 2: 2-user.sh (Como usuário normal)                   │
│     - Instala AUR helper (yay/paru)                         │
│     - Instala fontes                                        │
│     - Instala ambiente desktop                              │
│     - Instala ferramentas btrfs                             │
│     - Aplica temas                                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  FASE 3: 3-post-setup.sh (Chroot como root)                │
│     - Configura GRUB                                        │
│     - Configura display manager (SDDM/GDM/LightDM)         │
│     - Habilita serviços (NetworkManager, TLP, UFW, etc.)   │
│     - Configura Snapper (snapshots)                         │
│     - Configura Plymouth (boot splash)                      │
│     - Cleanup de arquivos temporários                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    🎉 INSTALAÇÃO COMPLETA!
                      Eject ISO e Reboot
```

---

## 🎨 Features Principais

### Detecção Automática de Hardware
- **CPU**: Detecta Intel ou AMD e instala microcode apropriado
- **GPU**: Detecta NVIDIA, AMD ou Intel e instala drivers
- **SSD/HDD**: Ajusta mount options automaticamente
- **Bateria**: Instala e configura TLP apenas em laptops
- **Memória**: Configura ZRAM se sistema tem <8GB RAM

### Suporte a Múltiplos Filesystems
- **ext4**: Simples e confiável
- **btrfs**: Com subvolumes (@, @home, @snapshots, @var_log, etc.)
- **LUKS**: Criptografia full-disk + btrfs

### Ambientes Desktop Suportados
KDE Plasma, GNOME, XFCE, Cinnamon, i3-wm, Awesome, Openbox, Budgie, Deepin, LXDE, MATE

### Tipos de Instalação
- **FULL**: Desktop completo + aplicativos + temas + serviços extras
- **MINIMAL**: Desktop básico sem apps extras
- **SERVER**: Apenas CLI (sem desktop environment)

### Otimizações Automáticas
- Compilação paralela baseada em número de cores
- Mirror selection otimizado (reflector/rankmirrors)
- Compressão zstd para btrfs
- Trim periódico para SSDs
- Firewall UFW pré-configurado (FULL)

---

## 📋 Configurações Salvas

Todas as escolhas do usuário são salvas em `configs/setup.conf`:

```bash
REAL_NAME="João Silva"
USERNAME=joao
PASSWORD=***
NAME_OF_MACHINE=archlinux
INSTALL_TYPE=FULL
AUR_HELPER=yay
DESKTOP_ENV=kde
DISK=/dev/sda
FS=btrfs
SUBVOLUMES=(@ @home @snapshots @var_log @var_cache)
TIMEZONE=America/Sao_Paulo
LOCALE=pt_BR.UTF-8
KEYMAP=br-abnt2
MOUNT_OPTION=defaults,noatime,compress=zstd,ssd,discard=async
```

Este arquivo é lido por todos os scripts subsequentes, garantindo consistência.

---

## 🛡️ Verificações de Segurança

Antes de executar, o instalador verifica:
- ✅ Está rodando como root
- ✅ Está em um sistema Arch Linux
- ✅ Pacman não está bloqueado
- ✅ Não está em container Docker
- ✅ Partições estão montadas (fases 1-3)

---

## 📦 Logs

Toda a saída é registrada em `install.log` e copiada para `/var/log/install.log` no sistema instalado para referência futura.

---

## 🎯 Próximos Passos

- Consulte **[ARCHITECTURE.md](ARCHITECTURE.md)** para entender a arquitetura em detalhes
- Veja **[FUNCTIONS-REFERENCE.md](FUNCTIONS-REFERENCE.md)** para lista completa de funções
- Leia **[DEVELOPMENT-GUIDE.md](DEVELOPMENT-GUIDE.md)** para adicionar novas features

---

## 📄 Licença

Este projeto é distribuído sob licença livre. Verifique o arquivo LICENSE para detalhes.
