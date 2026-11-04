#!/usr/bin/env bash
set -euo pipefail

if pgrep -x "dolphin-emu" >/dev/null 2>&1; then
    echo "Error: dolphin-emu is running. Close it before running this script." >&2
    exit 1
fi

CONFIG_DIRS=()
for dir in \
    "$HOME/.var/app/org.DolphinEmu.dolphin-emu/config/dolphin-emu" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/dolphin-emu" \
    "$HOME/snap/dolphin-emulator/current/.config/dolphin-emu" \
    "$HOME/.dolphin-emu/Config"; do
    if [ -d "$dir" ]; then
        CONFIG_DIRS+=("$dir")
    fi
done

if [ "${#CONFIG_DIRS[@]}" -eq 0 ]; then
    echo "Error: Dolphin config directory not found. Launch Dolphin once first." >&2
    exit 1
fi

set_ini() {
    local file="$1" section="$2" key="$3" val="$4"
    touch "$file"

    if ! grep -q "^\[${section}\]" "$file"; then
        printf "\n[%s]\n%s = %s\n" "$section" "$key" "$val" >> "$file"
        return
    fi

    if awk "/^\[${section}\]/{f=1; next} /^\[/{f=0} f && /^${key}[[:space:]]*=/" "$file" | grep -q .; then
        awk -v sec="[${section}]" -v k="$key" -v v="$val" '
            $0 == sec { in_sec=1; print; next }
            /^\[/ { in_sec=0 }
            in_sec && $0 ~ "^" k "[[:space:]]*=" { print k " = " v; next }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    else
        awk -v sec="[${section}]" -v k="$key" -v v="$val" '
            $0 == sec { print; print k " = " v; next }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    fi
}

for dir in "${CONFIG_DIRS[@]}"; do
    dolphin_ini="$dir/Dolphin.ini"
    gfx_ini="$dir/GFX.ini"

    [ -f "$dolphin_ini" ] && cp "$dolphin_ini" "${dolphin_ini}.bak"
    [ -f "$gfx_ini" ] && cp "$gfx_ini" "${gfx_ini}.bak"

    set_ini "$dolphin_ini" "Core" "GFXBackend" "Vulkan"
    set_ini "$dolphin_ini" "Core" "OverclockEnable" "False"
    set_ini "$gfx_ini" "Settings" "ShaderCompilationMode" "3"
    set_ini "$gfx_ini" "Settings" "WaitForShadersBeforeStarting" "True"
    set_ini "$gfx_ini" "Hacks" "EFBToTextureEnable" "True"

    echo "Updated config in: $dir (backups saved as .bak)"
done
