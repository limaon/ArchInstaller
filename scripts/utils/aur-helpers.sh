#!/usr/bin/env bash
#github-action genshdoc
#
# @file AUR Helpers
# @brief Functions for managing AUR helpers installation and configuration
# @stdout Output routed to install.log
# @stderror Output routed to install.log

# @description Validate AUR helper prerequisites
# @arg $1 AUR helper name
# @return 0 if all prerequisites are met, 1 otherwise
validate_aur_helper_prerequisites() {
    local helper="$1"

    if [[ -z "$helper" ]] || [[ "$helper" == "NONE" ]]; then
        return 0
    fi

    local helpers_json="$HOME/archinstaller/packages/aur-helpers.json"

    if [[ ! -f "$helpers_json" ]]; then
        echo "Error: AUR helpers configuration not found at $helpers_json"
        return 1
    fi

    if ! jq -e ".helpers.\"$helper\"" "$helpers_json" &>/dev/null; then
        echo "Error: AUR helper '$helper' not found in configuration"
        return 1
    fi

    if ! jq -e ".helpers.\"$helper\".enabled" "$helpers_json" | grep -q "true"; then
        echo "Error: AUR helper '$helper' is disabled"
        return 1
    fi

    local deps=$(jq -r ".helpers.\"$helper\".dependencies[]" "$helpers_json" 2>/dev/null)

    if [[ -z "$deps" ]]; then
        return 0
    fi

    local missing=()
    for dep in $deps; do
        if ! pacman -Qi "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Warning: Missing dependencies for $helper: ${missing[*]}"
        echo "Installing missing dependencies..."
        if ! pacman -S "${missing[@]}" --noconfirm --needed --color=always; then
            echo "Error: Failed to install missing dependencies"
            return 1
        fi
    fi

    return 0
}

# @description Get AUR helper metadata from configuration
# @arg $1 AUR helper name
# @arg $2 Metadata key (e.g., "aur_url", "build_cmd", "install_cmd")
# @stdout The requested metadata value
get_aur_helper_metadata() {
    local helper="$1"
    local key="$2"

    if [[ -z "$helper" ]] || [[ -z "$key" ]]; then
        echo "Error: Helper name and metadata key are required"
        return 1
    fi

    local helpers_json="$HOME/archinstaller/packages/aur-helpers.json"

    if [[ ! -f "$helpers_json" ]]; then
        echo "Error: AUR helpers configuration not found at $helpers_json"
        return 1
    fi

    jq -r ".helpers.\"$helper\".\"$key\"" "$helpers_json" 2>/dev/null
}

# @description Install AUR helper from AUR
# @arg $1 AUR helper name
# @return 0 on success, 1 on failure
install_aur_helper() {
    local helper="$1"

    if [[ -z "$helper" ]] || [[ "$helper" == "NONE" ]]; then
        echo "No AUR helper selected"
        return 0
    fi

    echo "Installing AUR helper: $helper"

    if ! validate_aur_helper_prerequisites "$helper"; then
        echo "Error: Failed to validate prerequisites for $helper"
        return 1
    fi

    local aur_url=$(get_aur_helper_metadata "$helper" "aur_url")
    local build_cmd=$(get_aur_helper_metadata "$helper" "build_cmd")

    if [[ -z "$aur_url" ]] || [[ "$aur_url" == "null" ]]; then
        echo "Error: AUR URL not found for $helper"
        return 1
    fi

    if [[ -z "$build_cmd" ]] || [[ "$build_cmd" == "null" ]]; then
        echo "Error: Build command not found for $helper"
        return 1
    fi

    echo "Cloning $helper from $aur_url..."
    if ! git clone "$aur_url" ~/"$helper"; then
        echo "Error: Failed to clone $helper"
        return 1
    fi

    cd ~/"$helper" || return 1
    echo "Building $helper..."
    if ! eval "$build_cmd"; then
        echo "Error: Failed to build $helper"
        return 1
    fi

    echo "[OK] $helper installed successfully"
    return 0
}

# @description Install packages via AUR helper
# @arg $1 Package name
# @return 0 on success, 1 on failure
install_package_via_aur() {
    local package="$1"

    if [[ -z "$package" ]]; then
        echo "Error: Package name is required"
        return 1
    fi

    if [[ "$AUR_HELPER" == NONE ]]; then
        echo "Error: AUR helper not configured"
        return 1
    fi

    echo "Installing $package via $AUR_HELPER..."
    if "$AUR_HELPER" -S "$package" --noconfirm --needed --color=always; then
        echo "[OK] $package installed successfully"
        return 0
    else
        echo "Error: Failed to install $package"
        return 1
    fi
}

# @description List available AUR helpers
# @stdout List of available helpers
list_aur_helpers() {
    local helpers_json="$HOME/archinstaller/packages/aur-helpers.json"

    if [[ ! -f "$helpers_json" ]]; then
        echo "Error: AUR helpers configuration not found"
        return 1
    fi

    echo "Available AUR helpers:"
    jq -r '.helpers | to_entries[] | "\(.key): \(.value.description)"' "$helpers_json"
}

# @description Get default AUR helper
# @stdout Default helper name
get_default_aur_helper() {
    local helpers_json="$HOME/archinstaller/packages/aur-helpers.json"

    if [[ ! -f "$helpers_json" ]]; then
        echo "Error: AUR helpers configuration not found"
        return 1
    fi

    jq -r '.default' "$helpers_json"
}

# @description Get fallback AUR helper
# @stdout Fallback helper name
get_fallback_aur_helper() {
    local helpers_json="$HOME/archinstaller/packages/aur-helpers.json"

    if [[ ! -f "$helpers_json" ]]; then
        echo "Error: AUR helpers configuration not found"
        return 1
    fi

    jq -r '.fallback' "$helpers_json"
}
