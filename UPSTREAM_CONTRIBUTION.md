# 🐬 Upstream Contribution Guide (`dolphin-emu/dolphin`)

The official Dolphin Emulator repository on GitHub ([`dolphin-emu/dolphin`](https://github.com/dolphin-emu/dolphin)) uses:
1. **[bugs.dolphin-emu.org](https://bugs.dolphin-emu.org/)** for Issue tracking.
2. **GitHub Pull Requests** (`Source/Core/VideoCommon/DriverDetails.cpp` and `VideoConfig.cpp`) for driver-specific workarounds (`DriverDetails`).

Below is the ready-to-submit **Upstream Issue Report** and the **C++ code proposal** for a Pull Request.

---

## 1. Ready-to-Submit Issue for `bugs.dolphin-emu.org`

**Title:**
`[Linux / Wayland / Intel i915] Hard system freeze (GPU Hang on Mesa Iris OpenGL) when EFBToTexture is disabled or compiling shaders`

**Description:**
```markdown
### What's the problem? Describe what went wrong.
On Linux distributions using Wayland (e.g., Ubuntu 24.04 LTS / GNOME Mutter) with Intel Integrated Graphics (Tiger Lake / Iris Xe GT2, kernel driver `i915`), running games with heavy EFB or shader workloads (such as *Super Mario Galaxy* RMGE01) under the default OpenGL backend (`iris` Mesa driver) triggers an `i915` GPU Hang / ring timeout, especially when `EFBToTextureEnable` is `False` or during synchronous shader compilation spikes.

When the `i915` kernel driver attempts a GPU reset, the Wayland compositor loses the DRM pageflip context, resulting in a complete system-wide display freeze requiring a hard power-off.

### What steps will reproduce the problem?
1. Use a Linux machine with Intel Iris Xe Graphics (`i915` driver) running a Wayland session.
2. Launch Dolphin (Flatpak `org.DolphinEmu.dolphin-emu` or native) with the OpenGL backend.
3. Have `EFBToTextureEnable = False` (EFB to RAM) or default Synchronous shader compilation in a game like *Super Mario Galaxy* (`RMGE01`).
4. Play for a few minutes until a heavy shader/EFB transition occurs; the GPU hangs and freezes the entire Wayland desktop.

### Which versions of Dolphin did you test on?
Dolphin 2606 (Flatpak stable) on Ubuntu 24.04.5 LTS (Kernel 7.0.0-38-generic, Intel TigerLake-LP GT2 Iris Xe Graphics).

### Workaround / Proposed Mitigation in Dolphin
Switching `GFXBackend` from `OpenGL` to `Vulkan` (Mesa ANV), enabling `EFBToTextureEnable = True`, and using Asynchronous shader compilation (`ShaderCompilationMode = 3` + `WaitForShadersBeforeStarting = True`) completely resolves the GPU hangs on Intel Iris Xe.

Could Dolphin consider:
1. Defaulting or recommending `Vulkan` over `OpenGL` on Linux when `VENDOR_INTEL` + `DRIVER_INTEL` (Mesa Iris/ANV) is detected on Gen12+/Xe hardware?
2. Or adding a `DriverDetails` bug flag (`BUG_BROKEN_I915_OPENGL_HANG`) to warn users on Intel `i915` + OpenGL when `EFBToTextureEnable` is disabled?
```

---

## 2. C++ Code Location for an Official Pull Request

In [`dolphin-emu/dolphin`](https://github.com/dolphin-emu/dolphin), driver-specific quirks and bugs are managed in:
* `Source/Core/VideoCommon/DriverDetails.h`
* `Source/Core/VideoCommon/DriverDetails.cpp`

In `DriverDetails.cpp`, the `m_known_bugs` array maps combinations of `(API, OS, Vendor, Driver, Family, Bug, VersionBegin, VersionEnd, HasBug)`:

```cpp
// Example entry in Source/Core/VideoCommon/DriverDetails.cpp
{API_OPENGL, OS_LINUX, VENDOR_INTEL, DRIVER_INTEL, Family::UNKNOWN,
 BUG_I915_RING_TIMEOUT_ON_HEAVY_SHADERS, -1.0, -1.0, true},
```
Adding a flag in `DriverDetails` allows Dolphin to display an OSD warning or prefer safer defaults when `OS_LINUX` + `VENDOR_INTEL` + `API_OPENGL` is detected.
