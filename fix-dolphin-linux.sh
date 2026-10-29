#!/usr/bin/env bash
# ==============================================================================
# Dolphin Emulator - Linux / Ubuntu Hard-Freeze Fixer (Intel i915 & Wayland)
# ==============================================================================
# Prevents GPU Hang / Ring Timeout on Intel Iris Xe (i915) + Mesa OpenGL under
# Wayland compositors (GNOME/Mutter, KDE/KWin) that lock up the entire system.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_banner() {
    echo -e "${BLUE}==================================================================${NC}"
    echo -e "${BLUE}   Dolphin Emulator Linux Freeze Fixer (Intel i915 / Wayland)     ${NC}"
    echo -e "${BLUE}==================================================================${NC}"
}

detect_system() {
    echo -e "\n${YELLOW}[1/4] Analyzing system environment...${NC}"
    SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
    GPU_INFO=$(lspci -k 2>/dev/null | grep -EA3 'VGA|3D|Display' || true)
    KERNEL_VER=$(uname -r)

    echo -e "  • Kernel:         ${GREEN}${KERNEL_VER}${NC}"
    echo -e "  • Display Server: ${GREEN}${SESSION_TYPE}${NC}"
    if echo "$GPU_INFO" | grep -qi "i915\|intel"; then
        echo -e "  • Detected GPU:   ${YELLOW}Intel Integrated Graphics (i915/xe)${NC}"
    else
        echo -e "  • Detected GPU:   ${GREEN}$(echo "$GPU_INFO" | head -n 1)${NC}"
    fi
}

find_dolphin_configs() {
    CONFIG_DIRS=()
    # Flatpak
    if [ -d "$HOME/.var/app/org.DolphinEmu.dolphin-emu/config/dolphin-emu" ]; then
        CONFIG_DIRS+=("$HOME/.var/app/org.DolphinEmu.dolphin-emu/config/dolphin-emu")
    fi
    # Native XDG
    if [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/dolphin-emu" ]; then
        CONFIG_DIRS+=("${XDG_CONFIG_HOME:-$HOME/.config}/dolphin-emu")
    fi
    # Snap
    if [ -d "$HOME/snap/dolphin-emulator/current/.config/dolphin-emu" ]; then
        CONFIG_DIRS+=("$HOME/snap/dolphin-emulator/current/.config/dolphin-emu")
    fi
    # Legacy
    if [ -d "$HOME/.dolphin-emu/Config" ]; then
        CONFIG_DIRS+=("$HOME/.dolphin-emu/Config")
    fi
}

set_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    local val="$4"

    touch "$file"

    # Check if section exists
    if ! grep -q "^\[${section}\]" "$file"; then
        echo -e "\n[${section}]\n${key} = ${val}" >> "$file"
        return
    fi

    # Check if key exists inside section
    if awk "/^\[${section}\]/{f=1; next} /^\[/{f=0} f && /^${key}[[:space:]]*=/" "$file" | grep -q .; then
        # Update existing key in section
        awk -v sec="[${section}]" -v k="$key" -v v="$val" '
            $0 == sec { in_sec=1; print; next }
            /^\[/ { in_sec=0 }
            in_sec && $0 ~ "^" k "[[:space:]]*=" { print k " = " v; next }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    else
        # Insert key right after section header
        awk -v sec="[${section}]" -v k="$key" -v v="$val" '
            $0 == sec { print; print k " = " v; next }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    fi
}

apply_dolphin_fixes() {
    local dir="$1"
    local dolphin_ini="${dir}/Dolphin.ini"
    local gfx_ini="${dir}/GFX.ini"
    local ts
    ts=$(date +"%Y%m%d-%H%M%S")

    echo -e "\n${YELLOW}[2/4] Backing up configuration in: ${dir}${NC}"
    [ -f "$dolphin_ini" ] && cp "$dolphin_ini" "${dolphin_ini}.bak.${ts}" && echo -e "  • Backup created: ${dolphin_ini}.bak.${ts}"
    [ -f "$gfx_ini" ] && cp "$gfx_ini" "${gfx_ini}.bak.${ts}" && echo -e "  • Backup created: ${gfx_ini}.bak.${ts}"

    echo -e "\n${YELLOW}[3/4] Applying anti-freeze configuration fixes...${NC}"

    # 1. Use Vulkan instead of OpenGL (avoids Mesa Iris OpenGL ring timeouts)
    set_ini_value "$dolphin_ini" "Core" "GFXBackend" "Vulkan"
    echo -e "  ✓ [Dolphin.ini] GFXBackend = Vulkan"

    # 2. Disable Emulated CPU Overclock (prevents thermal/iGPU context starvation)
    set_ini_value "$dolphin_ini" "Core" "OverclockEnable" "False"
    echo -e "  ✓ [Dolphin.ini] OverclockEnable = False"

    # 3. Asynchronous (Skip Drawing) Shader Compilation + Pre-compile Shaders
    set_ini_value "$gfx_ini" "Settings" "ShaderCompilationMode" "3"
    set_ini_value "$gfx_ini" "Settings" "WaitForShadersBeforeStarting" "True"
    echo -e "  ✓ [GFX.ini]     ShaderCompilationMode = 3 (Async / Skip Drawing)"
    echo -e "  ✓ [GFX.ini]     WaitForShadersBeforeStarting = True"

    # 4. Store EFB Copies to Texture Only (avoids heavy EFB-to-RAM stalls)
    set_ini_value "$gfx_ini" "Hacks" "EFBToTextureEnable" "True"
    echo -e "  ✓ [GFX.ini]     EFBToTextureEnable = True"
}

show_grub_tip() {
    echo -e "\n${YELLOW}[4/4] Optional Kernel Mitigation (Intel i915):${NC}"
    echo -e "  If Wayland still freezes under heavy load, add the following to /etc/default/grub:"
    echo -e "  ${GREEN}GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash i915.enable_psr=0 i915.reset=1\"${NC}"
    echo -e "  Then run: ${GREEN}sudo update-grub && sudo reboot${NC}"
}

main() {
    print_banner

    if pgrep -x "dolphin-emu" >/dev/null 2>&1; then
        echo -e "${RED}[ERROR] Dolphin is currently running! Please close it before running this script.${NC}"
        exit 1
    fi

    detect_system
    find_dolphin_configs

    if [ "${#CONFIG_DIRS[@]}" -eq 0 ]; then
        echo -e "\n${RED}[!] No Dolphin configuration directory found.${NC}"
        echo -e "    Please launch Dolphin at least once and try again."
        exit 1
    fi

    for dir in "${CONFIG_DIRS[@]}"; do
        apply_dolphin_fixes "$dir"
    done

    show_grub_tip

    echo -e "\n${GREEN}==================================================================${NC}"
    echo -e "${GREEN}  All done! Launch Dolphin and enjoy crash-free gaming on Linux!  ${NC}"
    echo -e "${GREEN}==================================================================${NC}"
}

main "$@"
