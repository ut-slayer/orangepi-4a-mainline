# Changelog

🌐 **English** · [Español](CHANGELOG.es.md)

## v0.3 — Hardware video decode + GNOME desktop

This release folds in the kernel work from the 2026-07-20 patch drop (which had
no image yet) plus this week's polish, and switches the desktop from KDE Plasma
to **GNOME**. Kernel: Linux **6.18.38**.

### 🎬 New: hardware video decode (VPU)
- The **cedar video engine now decodes in hardware**: **H.264** (validated on the
  board — a 10 s clip decoded in 0.65 s), plus **HEVC / MPEG / MJPEG** through the
  same GStreamer stack (`gst-omx` + `libcedarc`, ported from the vendor BSP).
  **YouTube plays with hardware decode in Epiphany** (WebKit + GStreamer).
  v0.2 shipped software decode only — this is the headline change.
- **VP8/VP9 are capped** (that engine never raises its interrupt), so YouTube
  negotiates **H.264** instead — smooth, instead of a CPU-melting software VP9.
- The `/dev/dma_heap` udev permissions the decoder needs are shipped.
- **Note — browser and hardware video:** the image ships **WebKit 2.52.5**
  (Debian's security update). An earlier build pinned 2.52.3 because 2.52.5 had
  regressed the DMA-BUF video path on Panfrost/Mali-G57 (the web process crashed
  with an "Oops"); re-tested on the current stack (kernel + Wayland) it now plays
  hardware video fine — H.264/H.265, fullscreen included — so the pin was dropped
  and you get the security fixes.

### 🖥️ New: GNOME desktop (replaces KDE Plasma)
- The desktop image is now **Debian 13 + GNOME on Wayland** — lighter than full
  Plasma, and Wayland is where the Mali-G57 (Panfrost) gives its best accelerated
  experience.
- The **CLI / headless** image continues (SSH + NetworkManager, analog audio
  running headless) — now with the hardware-decode stack included too.

### ⚙️ Kernel & hardware (the 2026-07-20 patch drop, now in an image)
- **★ GPU frequencies fixed.** The A523 GPU clock is a *cycle-masking* divider
  (`rate = src × (16−M)/16`), not linear. The old model silently overshot: the
  "150 MHz" operating point actually ran at **487 MHz**, and throttling to
  "400 MHz" *raised* the clock to **750 MHz**. Re-measured with the Mali cycle
  counter — now **149 / 199 / 300 / 399 / 597 MHz**, exact and from the intended
  parents. Credit: **Chen-Yu Tsai** spotted the fractional divider.
- **★ PCIe / M.2 root port.** The DesignWare controller and the Innosilicon
  USB3/PCIe combo PHY now probe, and the root port enumerates (verified with an
  **empty** slot; NVMe with a real drive still untested). The base drivers (combo
  PHY + PCIe RC/DMA) and the initial device-tree come from the Armbian series by
  **Marvin Wewer** (authorship preserved). On top of that, this project **fixed a
  use-after-free in the combo PHY driver**: the power notifier was chained onto
  the subsystem list *before* the provider registration return was checked, so a
  probe failure left a freed `notifier_block` on the chain — the next power event
  then dereferenced freed memory. Registered only after the provider is published
  (`Fixes:` the original driver commit). Plus the 1-lane device-tree fix (from the
  BSP) and the kernel config.
- **Display: scanout wedge fix.** All plane arming is gated to the blanking
  interval and the timer re-anchored to the real TCON scan line — fixes a frame
  that could get stuck after direct-scanout transitions.
- **★ defconfig fixed.** The shipped `defconfig` had been missing options
  (analog audio, PCIe, VPU, joydev) — config edits after 13 Jul went to the local
  `.config` instead of the versioned defconfig. Regenerated from the
  hardware-validated config (verified to reproduce it exactly).
- **Gamepads.** `INPUT_JOYDEV` + `INPUT_UINPUT` enabled — analog sticks were dead
  in software that opens `/dev/input/jsN` first.

### 🧹 Image polish
- **Slimmer, cleaner images.** apt package indices stripped (~90 MB of throwaway
  cache that regenerates on first `apt update`) and **`mesa-vulkan-drivers`
  dropped** (~144 MB installed — the Mali-G57 has **no Vulkan** under Panfrost).
- **New welcome page** (on the desktop image): a live panel with real per-core
  MHz/usage, GPU frequency, temperatures and RAM/disk; identity read from
  `/etc/os-release` at runtime; hardware-video tips.
- **1 GB zram swap on by default** — a 1 GB compressed in-RAM swap (zstd, higher
  priority than any SD swap): keeps the desktop responsive when a browser fills
  the 2 GB board's RAM, without touching the SD card (no wear). Disable with
  `systemctl disable --now zram-swap.service`. For even more room the optional
  `add-swapfile.sh` gift script adds a 1 GB SD swap file, used only as overflow.

### 📌 Pinned packages (and why)

Everything updates normally through apt **except two things the image fixes in
place on purpose**:

- **Debian kernels: blocked** (`/etc/apt/preferences.d/no-debian-kernel.pref`,
  priority -1 on `linux-image-*` / `linux-headers-*`). The board boots this
  port's own `uImage` (vanilla 6.18.38 + the patch series); a stock Debian
  kernel cannot boot it, and an `apt upgrade` that installed one would overwrite
  `/boot` and leave the board unbootable. Kernel updates arrive with image
  releases instead.
- **Mesa: pinned to trixie-backports** (`mesa-backports.pref`, priority 600 on
  `src:mesa`). Debian 13 ships Mesa 25.0.x; backports has much better
  Panfrost/Mali-G57 support. The pin covers the whole Mesa set so `libgbm1` /
  `libegl-mesa0` / `libgl1-mesa-dri` always come from the same suite — without
  it, a mixed upgrade can end with apt "solving" the conflict by removing the
  desktop.
**WebKitGTK is no longer pinned.** An earlier build held it at 2.52.3 because
Debian's 2.52.5 security update had regressed the hardware-video path on
Panfrost (the web process crashed with an "Oops"). Re-tested on the current
stack (this kernel + Wayland) it plays hardware video fine, so the hold was
dropped: the image now ships **2.52.5** and you get the security fixes. See the
"browser and hardware video" note above.

### Still here from v0.2
The from-scratch analog codec driver (`sun55i-a523-codec`) with **jack detection
/ hotplug**, HDMI audio, HDMI KMS display with native HPD, gigabit Ethernet, WiFi
(AP6256) + Bluetooth, the rear USB 2.0 ports, CPU/GPU DVFS with thermal
throttling, and the rest of the hardware support.

### Upstream
The generic `ccu_div` ordering fix got a **Reviewed-by from Chen-Yu Tsai** on the
linux-clk / linux-sunxi lists; the GPU clock series followed. Both are public in
the kernel mailing-list archives.

## 2026-07-20 — patch series update (no new image yet)

130 patches (was 106). Everything below has been running on the board for a full
day without regressions. **No new image is published yet** — these are kernel
patches; the next image release will fold them in.

- **★ GPU clock: the frequencies were wrong, and now they are right.** The A523
  GPU mod clock is **not** a linear divider: it is a *cycle-masking* one,
  `rate = source × (16 − M) / 16` (T527 manual, GPU_CLK_REG). With the linear
  model the "150/200/300/400/600 MHz" operating points were actually running at
  **487/648/560/750/599 MHz** — every point below the top silently overclocked,
  and thermal throttling to "400 MHz" actually *raised* the clock to 750 MHz.
  Measured on hardware with the Mali cycle counter, before and after. The fix
  adds a small `maskdiv` clock type, switches the GPU clock to it, and drops the
  `pll-periph0-800M` parent (the vendor BSP had removed it too, citing GPU job
  faults — consistent with this overshoot). Re-measured: **149/199/300/399/597
  MHz**, exact and from the intended parents. Credit: **Chen-Yu Tsai** spotted
  the fractional divider while reviewing an upstream patch.
- **★ PCIe / M.2 bring-up.** The controller (DesignWare RC) and the Innosilicon
  USB3/PCIe combo PHY now probe, and the root port enumerates. Verified here
  with an **empty** slot; NVMe with a real drive is still untested. The kernel
  side comes from the Armbian series by **Marvin Wewer** (authorship preserved),
  plus a 1-lane fix from the BSP and the device-tree wiring for this board.
- **Display: scanout wedge fix** — all plane arming is now gated to the blanking
  interval and the timer re-anchored to the real TCON scan line, which addresses
  a frame that could get stuck after direct-scanout transitions.
- **★ VPU: H.264/H.265 hardware decode works.** This drop adds the `cedar-ve`
  shim, its device-tree node and the IOMMU mappings for the video-engine
  masters. With the Allwinner userspace on top (libcedarc + `gstreamer1.0-omx`),
  **YouTube plays smoothly in a WebKit browser (Cog) with hardware decode** on
  this board. **VP8/VP9 remain broken** — that engine never raises its
  interrupt — so those codecs are capped and YouTube negotiates H.264 instead.
  The userspace half is not part of this patch set (and not in the published
  Debian images yet); the kernel half is here.
- **★ Fixed: the shipped `defconfig` was missing options.** Config commits after
  13 Jul edited the local build `.config` instead of the versioned defconfig —
  the one in this bundle. Anyone rebuilding from it got a kernel **without analog
  audio, PCIe, VPU or joydev**. The defconfig is now regenerated from the
  hardware-validated config (verified to reproduce it exactly). If you built from
  this repo before today, rebuild with the new defconfig.
- **Gamepads**: `INPUT_JOYDEV` and `INPUT_UINPUT` enabled (analog sticks were
  dead in software that opens `/dev/input/jsN` first).
- **Upstream**: the generic `ccu_div` ordering fix from this tree was sent to the
  Linux clk / linux-sunxi lists and **got a `Reviewed-by` from Chen-Yu Tsai**;
  the GPU clock series followed it. Both are public in the kernel mailing list
  archives.

## v0.2 — Analog audio (3.5 mm headphone jack) + CLI/headless image

**Two images now:** the full **Desktop** (KDE Plasma) and a new **CLI / headless**
one (`...-cli-...`, ~146 MB, ~740 MB installed, boots in seconds) — server/headless
use or a light base, with SSH + NetworkManager (`nmtui`), NTP on by default (no RTC
battery), a local HDMI text console, and — unique to this board — **working analog
audio via PipeWire running headless** (the jack works with no desktop session).

**Highlights**

- **Analog audio now works** — the 3.5 mm **headphone jack** outputs sound, with
  **jack detection / hotplug**. The Allwinner A523 analog codec has **no mainline
  driver**, so this ships a custom one (`sun55i-a523-codec`) ported faithfully
  from the vendor BSP. Validated on real hardware (headphones + plug/unplug).
  Line-out and microphone capture are wired in the driver but not bench-tested
  yet (the board has no onboard speaker/mic).
- **Audio output follows what's connected** — a small user service
  (`aureal-audio-autoswitch`) moves the default output to the headphone jack when
  you plug in, and back to HDMI when you unplug. If both are present the jack
  wins (plugging in is treated as your explicit choice). **Bluetooth headsets are
  respected** — the service only reacts to the wired jack and never overrides a
  Bluetooth or manual selection. This isn't automatic in PipeWire here because
  the analog codec and HDMI are two separate cards (verified on hardware). You
  can override in the tray, or disable it with
  `systemctl --user disable --now aureal-audio-autoswitch`.

**Kernel:** `6.18.38-g59eb61929e89` (adds the codec driver on top of the v0.1
bring-up; a code audit of the new driver fixed a use-after-free in the jack
teardown before release).

Everything from the previous bring-up is unchanged: HDMI KMS display + audio,
native HPD/hotplug, Mali-G57 (Panfrost), WiFi/Bluetooth, gigabit ethernet, USB,
thermal sensors, CPU cpufreq/DVFS + GPU devfreq, AFBC scanout.

## v0.1 — Initial image

First Debian 13 (Plasma Wayland) image for the Orange Pi 4A on a mainline
6.18.38 kernel: HDMI KMS, Mali-G57 via Panfrost, WiFi/BT, ethernet, USB, thermal
+ CPU/GPU DVFS, HDMI audio.
