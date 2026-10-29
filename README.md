# 🐬 Dolphin Emulator Linux Freeze Fixer (Intel Iris Xe / `i915` / Wayland)

An automated configuration tool and troubleshooting guide that fixes hard system lockups (where the entire Ubuntu/Linux display freezes and requires holding the physical power button) while playing games on **Dolphin Emulator**.

---

## 🔍 The Problem: Why Does Dolphin Freeze the Entire Linux Desktop?

Many Linux users running **Ubuntu, Linux Mint, Fedora, or Arch** with **Intel Integrated Graphics (Iris Xe / Tiger Lake / Alder Lake / UHD — `i915` kernel driver)** under a **Wayland** session experience severe system lockups during gameplay:

1. **GPU Overload:** During heavy emulation workloads (e.g., *Super Mario Galaxy*, *Mario Kart Wii*, *Metroid Prime*), Dolphin compiles complex shaders and performs Embedded Framebuffer (EFB) copies.
2. **Driver Stall:** By default, Dolphin uses the **OpenGL** backend (`iris` Mesa driver). When combined with **EFB to RAM** (`EFBToTextureEnable = False`), synchronous shader compilation spikes, or CPU overclocking, the Intel render ring stalls for too long.
3. **Kernel GPU Reset:** The Linux `i915` kernel driver detects a **GPU Hang** (`ring timeout`) and attempts an on-the-fly hardware **GPU Reset**.
4. **Wayland Compositor Crash:** Because the Wayland display server (GNOME Mutter / KDE KWin) runs directly inside the active GPU context, resetting the GPU causes a `Pageflip timed out` fault. The compositor loses control of the screen buffer and freezes the image permanently, forcing a hard power-off.

---

## 🚀 Quick Fix (Automated 1-Command Script)

Close Dolphin Emulator and run the following commands in your terminal:

```bash
git clone https://github.com/jpferraz-git/dolphin-linux-freeze-fixer.git
cd dolphin-linux-freeze-fixer
chmod +x fix-dolphin-linux.sh
./fix-dolphin-linux.sh
```

### What the Script Does:
The script automatically detects your Dolphin installation (**Flatpak**, **Native `.deb`/AppImage**, or **Snap**), creates a timestamped **backup** of your `Dolphin.ini` and `GFX.ini` files, and applies the following stability settings:

| File | Setting | Safe Value | Why It Fixes the Freeze |
| :--- | :--- | :--- | :--- |
| `Dolphin.ini` | `GFXBackend` | `Vulkan` | Switches from Mesa OpenGL (`iris`) to Vulkan (`ANV`), which handles pipeline synchronization much better on Intel `i915`. |
| `Dolphin.ini` | `OverclockEnable` | `False` | Prevents unnecessary thermal and execution starvation on integrated CPU/iGPU chips. |
| `GFX.ini` | `ShaderCompilationMode` | `3` (Async / Skip Drawing) | Prevents shader compilation spikes from stalling the GPU render ring and triggering an `i915` timeout. |
| `GFX.ini` | `WaitForShadersBeforeStarting` | `True` | Pre-compiles cached shaders before starting the game. |
| `GFX.ini` | `EFBToTextureEnable` | `True` | Uses *EFB to Texture* instead of *EFB to RAM*, eliminating the #1 cause of integrated GPU hangs in games like *Super Mario Galaxy*. |

---

## 🛠️ Manual Configuration (Via Dolphin GUI)

If you prefer to apply these settings manually inside Dolphin:

1. Open Dolphin -> **Graphics** -> **General** tab:
   * **Backend:** Change from `OpenGL` to **`Vulkan`**.
   * **Shader Compilation:** Select **`Asynchronous (Skip Drawing)`** (or *Hybrid Ubershaders*).
   * Check **`Compile Shaders Before Starting`**.
2. Go to the **Hacks** tab:
   * Check **`Store EFB Copies to Texture Only`**.
3. Open **Config** -> **Advanced** tab:
   * Uncheck **`Enable Emulated CPU Clock Override`**.

---

## 🛡️ Extra Layer (Optional): Kernel Driver Protection (`i915`)

If your Intel Tiger Lake / Iris Xe GPU still experiences occasional hangs under Wayland due to Panel Self-Refresh (PSR), you can add kernel parameters to GRUB:

```bash
sudo nano /etc/default/grub
# Update the line below to include i915.enable_psr=0 and i915.reset=1:
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_psr=0 i915.reset=1"

sudo update-grub
sudo reboot
```

*Tip: You can also switch your login session from **Ubuntu (Wayland)** to **Ubuntu on Xorg** via the gear icon on the login screen, as Xorg recovers from `i915` GPU resets without freezing the entire display.*

---

## 🤝 Contributing Upstream to Dolphin

See [UPSTREAM_CONTRIBUTION.md](./UPSTREAM_CONTRIBUTION.md) for the technical bug report and C++ `DriverDetails` proposal for the official [`dolphin-emu/dolphin`](https://github.com/dolphin-emu/dolphin) repository.

## 📄 License
MIT License
