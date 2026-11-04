# dolphin-linux-freeze-fixer

Small shell script to fix system-wide freezes when running Dolphin Emulator on Linux (Ubuntu/Wayland) with Intel integrated graphics (`i915` / Iris Xe).

## Background

Up until Dolphin 2606 (before upstream [PR #14835](https://github.com/dolphin-emu/dolphin/pull/14835)), Dolphin defaulted to the OpenGL backend on Linux.

On Intel integrated GPUs (such as Tiger Lake / Iris Xe using the `i915` kernel driver and Mesa `iris`), heavy shader compilation or EFB-to-RAM reads under OpenGL frequently trigger a GPU hang (`ring timeout`). When the kernel attempts to reset the GPU, the Wayland compositor (Mutter/KWin) loses its DRM context and locks up the entire display, forcing a hard reboot via the power button.

Switching the backend to Vulkan (Mesa ANV), enabling EFB-to-texture, and using asynchronous shader compilation prevents the GPU hang.

## Usage

Close Dolphin and run:

```bash
git clone https://github.com/jpferraz-git/dolphin-linux-freeze-fixer.git
cd dolphin-linux-freeze-fixer
./fix-dolphin-linux.sh
```

The script automatically locates your Dolphin config folder (Flatpak, native `~/.config/dolphin-emu`, or Snap), creates `.bak` backups of `Dolphin.ini` and `GFX.ini`, and sets:

- `Dolphin.ini`:
  - `GFXBackend = Vulkan`
  - `OverclockEnable = False`
- `GFX.ini`:
  - `ShaderCompilationMode = 3` (Async / Skip Drawing)
  - `WaitForShadersBeforeStarting = True`
  - `EFBToTextureEnable = True`

## License

MIT
