# Changelog

🌐 **English** · [Español](CHANGELOG.es.md)

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
