# Sistema de Pacotes JSON

Este documento explica como funciona o sistema de gerenciamento de pacotes baseado em JSON do ArchInstaller.

---

## 🎯 Por que JSON?

### Vantagens

✅ **Separação de dados e lógica**: Listas de pacotes separadas do código  
✅ **Fácil manutenção**: Adicionar/remover pacotes sem tocar em bash  
✅ **Queries flexíveis**: JQ permite filtros complexos  
✅ **Hierarquia clara**: minimal vs full, pacman vs aur  
✅ **Comentários via descrição**: Cada pacote pode ter metadados  

### Alternativas Consideradas

- **Shell arrays**: Difícil de estruturar hierarquicamente
- **YAML**: Requer parser extra não disponível na ISO
- **TOML**: Mesma limitação do YAML
- **Texto simples**: Sem estrutura, difícil filtrar

**Escolhido**: JSON + JQ (já disponível na ISO do Arch)

---

## 📂 Estrutura de Diretórios

```
packages/
├── base.json                    # Pacotes base do sistema
├── btrfs.json                   # Ferramentas btrfs
├── desktop-environments/        # Um JSON por DE
│   ├── kde.json
│   ├── gnome.json
│   ├── xfce.json
│   ├── cinnamon.json
│   ├── i3-wm.json
│   ├── awesome.json
│   ├── openbox.json
│   ├── budgie.json
│   ├── deepin.json
│   ├── lxde.json
│   └── mate.json
└── optional/
    └── fonts.json               # Fontes do sistema
```

---

## 📋 Formato do JSON

### Template Básico

```json
{
  "minimal": {
    "pacman": [
      {"package": "nome-do-pacote"}
    ],
    "aur": [
      {"package": "pacote-aur"}
    ]
  },
  "full": {
    "pacman": [
      {"package": "pacote-extra"}
    ],
    "aur": [
      {"package": "pacote-aur-extra"}
    ]
  }
}
```

### Campos

- **minimal**: Instalação mínima (sempre instalado se não SERVER)
  - **pacman**: Pacotes oficiais
  - **aur**: Pacotes do AUR (só se AUR_HELPER ≠ NONE)
  
- **full**: Instalação completa (só se INSTALL_TYPE=FULL)
  - **pacman**: Pacotes oficiais extras
  - **aur**: Pacotes AUR extras

---

## 📦 base.json

Pacotes fundamentais do sistema (não desktop).

### Estrutura

```json
{
  "minimal": {
    "pacman": [
      {"package": "bash-completion"},
      {"package": "man-db"},
      {"package": "man-pages"},
      {"package": "git"},
      {"package": "curl"},
      {"package": "wget"},
      ...
    ],
    "aur": [
      {"package": "downgrade"}
    ]
  },
  "full": {
    "pacman": [
      {"package": "firefox"},
      {"package": "vlc"},
      {"package": "gimp"},
      {"package": "libreoffice-fresh"},
      ...
    ],
    "aur": [
      {"package": "google-chrome"},
      {"package": "visual-studio-code-bin"}
    ]
  }
}
```

### Categorias Comuns

**CLI Tools**: git, curl, wget, rsync, htop, neofetch  
**Compressão**: zip, unzip, p7zip, unrar  
**Desenvolvimento**: base-devel, gcc, make, cmake  
**Rede**: net-tools, bind-tools, nmap  
**Sistema**: man-db, man-pages, bash-completion  

**FULL adiciona**:  
**Browsers**: firefox, chromium  
**Mídia**: vlc, ffmpeg, imagemagick  
**Office**: libreoffice-fresh  
**Gráficos**: gimp, inkscape  

---

## 🖥️ Desktop Environments

Cada DE tem seu próprio JSON em `desktop-environments/`.

### Exemplo: kde.json

```json
{
  "minimal": {
    "pacman": [
      {"package": "plasma-desktop"},
      {"package": "plasma-nm"},
      {"package": "plasma-pa"},
      {"package": "konsole"},
      {"package": "dolphin"},
      {"package": "sddm"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "plasma-meta"},
      {"package": "kde-applications-meta"},
      {"package": "kdenlive"},
      {"package": "krita"},
      {"package": "ark"},
      {"package": "gwenview"},
      {"package": "okular"},
      {"package": "spectacle"}
    ],
    "aur": [
      {"package": "sddm-theme-nordic-git"}
    ]
  }
}
```

### Estrutura Recomendada

**minimal.pacman**:
- Meta-pacote ou pacotes core do DE
- Display manager (sddm, gdm, lightdm)
- Terminal emulator
- File manager
- Network manager applet
- Audio applet

**full.pacman**:
- Meta-pacote completo
- Aplicativos do ecossistema
- Ferramentas de produtividade
- Extras e plugins

**full.aur**:
- Temas customizados
- Plugins não-oficiais
- Apps específicos da comunidade

---

### Exemplo: i3-wm.json

```json
{
  "minimal": {
    "pacman": [
      {"package": "i3-wm"},
      {"package": "i3status"},
      {"package": "i3lock"},
      {"package": "dmenu"},
      {"package": "xorg-server"},
      {"package": "xorg-xinit"},
      {"package": "alacritty"},
      {"package": "thunar"},
      {"package": "lightdm"},
      {"package": "lightdm-gtk-greeter"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "rofi"},
      {"package": "polybar"},
      {"package": "picom"},
      {"package": "nitrogen"},
      {"package": "dunst"},
      {"package": "feh"},
      {"package": "scrot"}
    ],
    "aur": [
      {"package": "i3-gaps-git"},
      {"package": "autotiling"}
    ]
  }
}
```

---

## 🔤 fonts.json

Fontes do sistema (apenas FULL install).

### Estrutura

```json
{
  "pacman": [
    {"package": "ttf-dejavu"},
    {"package": "ttf-liberation"},
    {"package": "noto-fonts"},
    {"package": "noto-fonts-emoji"},
    {"package": "ttf-hack"},
    {"package": "ttf-fira-code"}
  ],
  "aur": [
    {"package": "ttf-ms-fonts"},
    {"package": "nerd-fonts-complete"}
  ]
}
```

**Nota**: Não tem separação minimal/full - ou instala tudo ou nada.

---

## 📁 btrfs.json

Ferramentas específicas para btrfs (só instala se FS=btrfs).

### Estrutura

```json
{
  "pacman": [
    {"package": "btrfs-progs"},
    {"package": "snapper"},
    {"package": "snap-pac"},
    {"package": "grub-btrfs"}
  ],
  "aur": [
    {"package": "snapper-gui-git"}
  ]
}
```

**Pacotes**:
- **btrfs-progs**: Utilitários btrfs
- **snapper**: Gerenciamento de snapshots
- **snap-pac**: Snapshots automáticos ao usar pacman
- **grub-btrfs**: Boot de snapshots via GRUB

---

## 🔍 Queries JQ

### Lógica de Instalação

```bash
# Exemplo de software-install.sh -> base_install()

# Define filtros baseado em INSTALL_TYPE
MINIMAL_PACMAN_FILTER=".minimal.pacman[].package"
FULL_PACMAN_FILTER=""

if [[ "$INSTALL_TYPE" == "FULL" ]]; then
    FULL_PACMAN_FILTER=", .full.pacman[].package"
fi

# Combina filtros e extrai pacotes
jq --raw-output "${MINIMAL_PACMAN_FILTER}${FULL_PACMAN_FILTER}" \
    "$PACKAGE_LIST_FILE" | while read -r package; do
    echo "Installing $package..."
    pacman -S "$package" --noconfirm --needed --color=always
done
```

### Queries Comuns

**Apenas pacman minimal**:
```bash
jq -r '.minimal.pacman[].package' base.json
```

**Pacman minimal + full**:
```bash
jq -r '.minimal.pacman[].package, .full.pacman[].package' base.json
```

**Tudo (pacman + aur)**:
```bash
jq -r '.minimal.pacman[].package, .minimal.aur[].package, 
       .full.pacman[].package, .full.aur[].package' base.json
```

**Apenas AUR**:
```bash
jq -r '.minimal.aur[].package, .full.aur[].package' base.json
```

---

## ➕ Adicionar Novo Desktop Environment

### Passo 1: Criar JSON

Crie `packages/desktop-environments/meu-de.json`:

```json
{
  "minimal": {
    "pacman": [
      {"package": "meu-de-core"},
      {"package": "display-manager"},
      {"package": "terminal"},
      {"package": "file-manager"}
    ],
    "aur": []
  },
  "full": {
    "pacman": [
      {"package": "meu-de-apps"},
      {"package": "extras"}
    ],
    "aur": [
      {"package": "temas-customizados"}
    ]
  }
}
```

### Passo 2: Configurar Display Manager

Em `system-config.sh -> display_manager()`:

```bash
elif [[ "${DESKTOP_ENV}" == "meu-de" ]]; then
    systemctl enable meu-display-manager.service
    
    if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
        echo "Configurando tema..."
        # Aplicar configurações de tema
    fi
```

### Passo 3: (Opcional) Adicionar Theming

Em `software-install.sh -> user_theming()`:

```bash
elif [[ "$DESKTOP_ENV" == "meu-de" ]]; then
    cp -r ~/archinstaller/configs/meu-de/home/. ~/
    # Aplicar dotfiles e configurações
```

### Passo 4: Testar

```bash
./archinstall.sh
# Escolher "meu-de" na lista
```

O instalador detectará automaticamente o novo JSON!

---

## 🔄 Fluxo de Instalação de Pacotes

```
┌─────────────────────────────────────────────────────────┐
│ 1. Determinar INSTALL_TYPE (MINIMAL, FULL, SERVER)     │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Determinar AUR_HELPER (yay, paru, NONE)             │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Construir filtros JQ                                │
│    MINIMAL: .minimal.pacman[].package                   │
│    FULL:    + .full.pacman[].package                    │
│    AUR:     + .minimal.aur[].package                    │
│             + .full.aur[].package (se FULL)             │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Ler JSON apropriado                                 │
│    - base.json                                          │
│    - desktop-environments/$DESKTOP_ENV.json             │
│    - fonts.json (se não SERVER)                         │
│    - btrfs.json (se FS=btrfs)                           │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Aplicar filtro JQ e extrair pacotes                 │
└───────────────────┬─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 6. Loop de instalação                                  │
│    for package in $(jq ...); do                         │
│        pacman -S $package  ou  $AUR_HELPER -S $package  │
│    done                                                 │
└─────────────────────────────────────────────────────────┘
```

---

## 📝 Melhores Práticas

### 1. Organização

- Um pacote por linha
- Ordem alfabética (facilita encontrar)
- Comentários via campo "description" se necessário

```json
{
  "pacman": [
    {"package": "firefox", "description": "Main browser"},
    {"package": "thunderbird", "description": "Email client"}
  ]
}
```

### 2. Dependências

JQ não valida dependências. Certifique-se de:
- Pacotes base antes de extras
- Display manager incluído no DE
- Drivers de áudio/vídeo no minimal

### 3. Tamanho

**minimal**: ~50-100 pacotes (instalação rápida)  
**full**: ~200-400 pacotes (completa)

### 4. Testes

Sempre teste ambos:
- MINIMAL install (rápido, funcional)
- FULL install (completo, pode ser lento)

---

## 🛠️ Manutenção

### Adicionar Pacote

```bash
# Editar JSON
vim packages/base.json

# Adicionar em minimal.pacman ou full.pacman
{
  "minimal": {
    "pacman": [
      ...
      {"package": "novo-pacote"}
    ]
  }
}
```

### Remover Pacote

Simplesmente delete a linha do JSON.

### Mudar de Categoria

Mova o pacote de `minimal` para `full` ou vice-versa.

### Verificar Validade do JSON

```bash
jq . packages/base.json > /dev/null && echo "JSON válido" || echo "JSON inválido"
```

---

## 🎯 Exemplos de Uso

### Listar Todos os Pacotes de um DE

```bash
jq -r '.minimal.pacman[].package, .full.pacman[].package' \
    packages/desktop-environments/kde.json
```

### Contar Pacotes

```bash
# Minimal
jq '.minimal.pacman | length' packages/base.json

# Full
jq '.full.pacman | length' packages/base.json

# Total
jq '[.minimal.pacman[], .full.pacman[]] | length' packages/base.json
```

### Procurar Pacote

```bash
# Em qual JSON está o firefox?
grep -r "firefox" packages/
```

### Validar Todos os JSONs

```bash
for json in packages/**/*.json; do
    jq . "$json" > /dev/null && echo "✓ $json" || echo "✗ $json"
done
```

---

Este sistema permite fácil customização e manutenção das listas de pacotes sem tocar no código bash!
