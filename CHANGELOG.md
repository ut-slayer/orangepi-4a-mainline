# Changelog

🌐 **English** · [Español](CHANGELOG.es.md)

## v0.4 — Kernel 6.18.44, WireGuard/NAT, and a polished GNOME

*Released 2026-08-23.* Kernel: Linux **6.18.44** (`6.18.44-g8c30dd587626`), up
from 6.18.38 in v0.3 — 1073 upstream commits, mostly hardening across drm, net,
wifi and media.

### 🔐 New: WireGuard, nftables and iptables NAT
Requested in [issue #4](https://github.com/ut-slayer/orangepi-4a-mainline/issues/4):
the config had no way to do NAT or run a VPN. Now it does, as modules — nothing
loads unless you configure it:

- **WireGuard** (`CONFIG_WIREGUARD=m`).
- **nftables** with the ct/log/limit/masq/redir/nat/fib expressions, plus
  `NFT_COMPAT` — which is what `iptables-nft`, Debian's actual default iptables
  backend, needs.
- **The legacy xtables path** too (`NETFILTER_XTABLES_LEGACY=y`), so
  `iptables-legacy` scripts keep working. Since kernel 6.12 that symbol is what
  gates `IP_NF_FILTER` / `IP_NF_NAT` / `IP_NF_TARGET_MASQUERADE`; without it they
  do not exist at all.

Validated on the board: a rule added with `iptables` shows up under `nft` as a
native rule, and `iptables-legacy` runs in parallel in its own table.

### ⚠️ Known issue: the board can hang under sustained WireGuard saturation
Worth knowing if you plan to use WireGuard heavily.

A WireGuard tunnel pushed to **~880 Mbps** with `iperf3` can **hang the board**,
which then reboots. It is intermittent: it has survived 25 runs in a row and it
has also died on the 2nd.

What we know after a full day of testing: it is **not** thermal (it dies at
62 °C, throttling starts at 90), **not** power (`openssl chacha20` on 8 cores
reaches load 7.18 and 77 °C without falling), **not** CPU frequency scaling, and
**not** the network on its own (unencrypted `iperf3` sustains 925 Mbps fine).
With every lockup detector enabled *and* a serial console recording, the kernel
dies without printing a single line.

**Only `iperf3` has ever triggered it.** Pushing the same tunnel with `netcat`
moved **22.8 GB with no crash at all**, and copying a real 2 GB file over `scp`
(SSH on top of WireGuard) went through fine. That is not proof that iperf3 is at
fault — the failure is too intermittent to conclude that from these samples —
but it does mean no ordinary workload has reproduced it so far.

**In normal use it works**: 44 GB moved through the tunnel during testing, file
transfers included, and it is rock solid at 100 and 300 Mbps. You need to
saturate close to gigabit with a synthetic benchmark to trigger it — unusual for
a home VPN. The investigation is documented in the repo and continues.

### 🖥️ GNOME: it now behaves like a normal desktop
- **Logs straight in** — no password prompt (autologin).
- **Starts on the desktop**, not in the Activities overview.
- **ArcMenu**: a Windows/Plasma-style application menu, replacing GNOME's
  Activities and app-grid buttons in the panel.
- **No more GNOME Tour** — that "Welcome to Debian, take a tour?" dialog no
  longer opens on top of our own welcome page.
- **The welcome page opens in its own window** instead of launching Epiphany.
  Same page, same live board metrics, but it appears in about a second instead
  of several, with no browser toolbar and no first-run dialog. It shows **once**;
  you can reopen it any time from the menu ("AurealNix Welcome").

### 🔧 Under the hood
- **All images are now fully up to date**: the builder runs `apt dist-upgrade`
  before packaging. It never did before, so images shipped with packages frozen
  at the date the base was built. This release picks up security updates for
  `libexpat1`, `libnss3`, `libde265`, `libheif`, `libaom3` and `libssh-4`,
  among others.
- **`ping` is included.** It was missing from every image, desktops included.
- **Lockup detectors enabled** in the kernel (`SOFTLOCKUP`, `HARDLOCKUP` buddy,
  `DETECT_HUNG_TASK`, `WQ_WATCHDOG`, `MAGIC_SYSRQ`). They were all off, so a hang
  left no evidence whatsoever. Debian and Ubuntu ship them for the same reason.
- **Every zram compression backend is built** (`lz4`, `lz4hc`, `deflate`, `842`
  alongside `zstd` and `lzo`), so the algorithm can be switched at runtime via
  `/sys/block/zram0/comp_algorithm`. Default is still zstd.
- **Fixed: `/etc/skel` never reached the user's home.** It is only copied when
  the account is created, and the account dates from July — so changes made
  since then (the welcome page, these changelogs) stayed in the skel and the
  real home kept the old copies. **This affected v0.3 as well.**

### 🩹 Kernel: everything else that landed since v0.3

52 patches between 2026-07-21 and 2026-08-21, on top of the jump from 6.18.38 to
6.18.44. Most of it is robustness work found by auditing our own series — the
kind of thing that does not show up in a screenshot but decides whether the
board survives a week of uptime.

- **PCIe / NVMe (13 patches, 21-24 Jul)** — the biggest block. The DMA-mapped
  MSI target is now reprogrammed on resume (it silently lost interrupts after a
  suspend/resume cycle), INTx and eDMA masks are restored on resume, the eDMA
  cookie is cleared on release and the channel state serialised, IRQ domains
  unwind in reverse order on error, and register access is kept ahead of clock
  gating in `remove()`.
- **Clocks / CCU (9 patches, 21-24 Jul)** — the `CLEAR_MOD` poll moved out of the
  CCU spinlock, a stale update bit is never written back, `maskdiv` honours the
  bounds `determine_rate()` was given, and `pll-cpu0`'s N factor is bounded so a
  consumer with tight limits cannot be handed an out-of-range rate.
- **Video decode / cedar-ve (6 patches, 21-25 Jul)** — **a heap overflow fixed**:
  the debugfs `proc_info_len` was unbounded. Also the userspace mmap is now
  bounded to the VE register window, the `STOP_PROC_INFO` channel id is checked,
  a lock the caller never took is no longer released, and the engine is quiesced
  when a client dies mid-job instead of leaving it running.
- **Display / DE (7 patches, 21-24 Jul)** — hardware overlay and cursor planes,
  plus the hardening that came out of auditing them: only the primary plane
  advertises AFBC modifiers, overlays are re-checked when the primary moves or
  resizes, and the inert alpha property was dropped from the RCQ primary.
- **Combo PHY (4 patches, 21-24 Jul)** — the power notifier is registered only
  after a successful probe and unregistered before exit (**it was a
  use-after-free**), and the notifier chain is now blocking.
- **DTS and frequencies (5 patches, 29 Jul - 1 Aug)** — the **696 MHz GPU OPP**
  validated on this board's SID bin, a **voltage range for the little cluster's
  OPPs** (DCDC1 also feeds the DSU, and a single fixed voltage per OPP makes it
  impossible for a second consumer to raise the rail), the DSU clock and its PLL,
  the A523 pin voltage-withstand encoding, and PJ10 out of the rgmii1 pin group.
- **Audio (1 patch, 22 Jul)** — the jack detection work is cancelled if probe
  fails.
- **Infrared** — receiver nodes and the common protocol decoders. Note that this
  board has **no IR receiver fitted**; this is for anyone wiring one to the
  header.

### 📊 Numbers
- glmark2: **847** at 800x600 (v0.3: 790), GPU at 696 MHz
- Boot: 16.5 s (CLI), 43 s (GNOME)
- Images: CLI 197 MB · GNOME 710 MB (compressed)

### 🎉 And for Plasma fans: Kubuntu 26.04!

Saved the fun one for last. This release adds a **brand-new image for everyone
who loves KDE Plasma: Kubuntu 26.04 (Resolute Raccoon)** — and it's **fantastic**
on this board.

- Plasma **6.6.6** on pure **Wayland** (KWin, zero X11), and it flies: glmark2
  **880** at 800x600, even a hair above GNOME, with the GPU at 696 MHz. Boots to
  the desktop in **26 seconds**.
- **Autologin** straight into Plasma, its **own boot splash**, and the welcome
  page in a **native Qt window** (using the QtWebEngine Plasma already ships — no
  second web engine bloating the image).
- KDE's **Info Center** even reads the Mali-G57 and the Orange Pi 4A straight
  from the device-tree.

First image of the project on an Ubuntu base. One caveat: **Plasma is hungrier
with RAM** than GNOME (~880 MB plus swap with just a terminal open), so on 2 GB
it leans on zram — great for light use, tighter with a browser and several apps
at once. Want the leanest desktop? GNOME. Love Plasma? This one's for you.

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
