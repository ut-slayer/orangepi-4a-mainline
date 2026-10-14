# Orange Pi 4A (Allwinner T527 / A523) — mainline Linux 6.18 (LTS)

🌐 **English** · [Español](README.es.md)

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee%20%E2%98%95-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/aurealnix)

**Mainline** support for the Orange Pi 4A (Allwinner **T527** SoC, A523 family /
`sun55iw3`), on a **vanilla 6.18.55** kernel. A 143-patch series + `defconfig` +
the board device-tree. Patches ported from other people's work keep their
original authorship in the patch headers (Justin Suess and Jernej Škrabec for the
display series from minimyth2, Marvin Wewer for PCIe).

> Working-tree base: `linux-6.18.55` vanilla. These patches apply on top.
> `git format-patch --base` embeds the base hash in every `.patch`.

**Latest images: v0.5**: kernel **6.18.55** (`6.18.55-g3f67628a8bff`, exactly
this patch series), four images: **CLI / headless**, **GNOME**, **Kubuntu 26.04
(KDE Plasma)** and, new and experimental, **Ubuntu 26.04 Cinnamon on Wayland**.
Download them from the [Releases](../../releases) page; see
[CHANGELOG.md](CHANGELOG.md) for what changed.

> **The patch series is now in sync with the images.** In v0.5 it was also
> cleaned up: experiments that a later patch reverted were dropped, and each
> feature that took several attempts is now a single patch with the final
> result (175 → 143 patches, same logic). Code comments and log messages are now in
> English too, and the series' defconfig is the one the images are built with.

## What works (confirmed on hardware)

| Block | Status |
|---|---|
| **HDMI KMS display** (DE33/DE3.5 + TCON-TV + DW-HDMI 2.0 + Inno PHY) | ✅ 720p/1080p, clean VSU8 scaling |
| **HDMI boot console** (fbcon via `simple-framebuffer` over U-Boot's FB) | ✅ with the BSP U-Boot (not needed with mainline U-Boot; see §4) |
| **HDMI HPD / hotplug** (native connector detection) | ✅ connected at boot + hotplug (plug/unplug) without forcing |
| **Mali-G57 GPU** (Panfrost) | ✅ accelerated (GNOME on Wayland) |
| **HDMI audio** (i2s2 → dw-hdmi) | ✅ PCM output to the TV |
| **Analog audio** (3.5 mm headphone jack + jack detect) | ✅ headphones + hotplug (custom `sun55i-a523-codec` driver ported from the BSP — no mainline driver exists otherwise). Line-out / mic capture wired but not yet bench-tested |
| **Ethernet GMAC1** (YT8531 PHY, RGMII) | ✅ RX/TX |
| **WiFi AP6256** (BCM43456, brcmfmac, SDIO) | ✅ 2.4/5 GHz scan, association |
| **reboot / poweroff** (sunxi_wdt / AXP717) | ✅ |
| **AFBC scanout** (v350 AFBD decoder) | ✅ |
| **USB** (4 rear Type-A ports — all USB 2.0: the SoC's single USB3/PCIe combo lane goes to the M.2 slot, so this board has no USB 3.0 at all; see the FAQ) | ✅ HID (keyboard/mouse) + mass storage + hotplug; the OTG pair works as host |
| **THS thermal sensors** (5 zones: cpu_l / cpu_b / gpu / npu / ddr) | ✅ sysfs/hwmon readout + 110 °C critical trip |
| **CPU cpufreq/DVFS** (little 480 MHz–1.416 GHz, big 480 MHz–1.8 GHz) + thermal throttling at 90 °C | ✅ |
| **Asymmetric CPU topology** (cpu-map + capacity-dmips-mhz 922/1024 + EAS energy model) | ✅ big cluster preferred for heavy tasks |
| **GPU devfreq/DVFS** (Panfrost, 150–696 MHz; 696 MHz is the vendor's operating point for this SoC, validated under game load on this board) + thermal throttling | ✅ and now **at the right frequencies** — the A523 GPU divider turned out to be a *cycle-masking* (fractional) one, `rate = source × (16−M)/16`, not a linear divider; measured with the Mali cycle counter |
| **eMMC** (MMC storage) | ✅ detected + HS200 read/write, and **booting from eMMC works**: a tester runs the CLI image entirely from the eMMC module (no SD card), with the first-boot auto-resize filling its 58 GiB. A step-by-step *install to eMMC* guide is still to be written |
| **PCIe / M.2 NVMe** (DesignWare RC + Innosilicon combo PHY) | ✅ **validated with real drives by two testers**: a KIOXIA KBG40ZNV256G and an Intel 760p-series SSD, both bound by the `nvme` driver, with `f3` integrity runs over the **full 256 GB (several passes)** and 50 GB — **0 corrupted sectors, clean dmesg**, ~130 MB/s write / ~275 MB/s read. Works as storage out of the box. Since v0.5 the `nvme` driver is **built into the kernel**, so you can boot from the SD card with the **root filesystem on the NVMe** (`root=` pointing at the NVMe partition, no initramfs needed). That setup has not been tested on a real drive yet: reports welcome |

**Hardware video decode (VPU) — partly working, kernel side included.** This tree
ships the `cedar-ve` shim with its device-tree node and the IOMMU mappings for the
video-engine masters. Paired with the Allwinner userspace (libcedarc +
`gstreamer1.0-omx`), **H.264 and H.265 decode work**: YouTube plays smoothly in a
WebKit browser (Epiphany / GNOME Web) on this board. **VP8/VP9 do not** — that
engine never raises its interrupt, so those codecs are capped in our setup, which
makes YouTube negotiate H.264 instead. Note this is the *kernel* half: the
userspace decoding stack is not part of this patch set — but the **Debian
images do ship it** (libcedarc + `gst-omx`, v0.3 onward), so hardware decode
works out of the box there. If you build only the kernel from these patches, you supply the
userspace yourself.
The **4 GB variant is confirmed working** (tested by **JamesCL** — thanks! — who
also confirmed the eMMC; the bootloader auto-detects the RAM size).

## Image notes

Decisions made in the distributed images (these are not kernel patches). Most
apply to all four images; the GNOME-specific ones are marked.

- **First boot auto-resizes the rootfs** to fill the microSD and regenerates the
  SSH host keys — so the first boot takes a bit longer. Don't pull the power.
- **SSH is enabled from first boot**; user/password are `user` / `user`.
  **Change the password immediately** (`passwd`) — a default password on a
  network-facing device is how boards end up in botnets.
- **1 GB zram swap on by default; SD swap file optional.** zram is a compressed
  in-RAM swap: it keeps the desktop responsive when a browser fills the 2 GB
  board's RAM, never touches the SD, and costs almost nothing while unused. It
  uses **lzo-rle**, the fastest of the kernel's compressors when benchmarked on
  this board. See it working with `sudo zramctl`; disable with
  `systemctl disable --now zram-swap.service`. For extra headroom, the
  `add-swapfile.sh` script in the home folder adds an optional 1 GB swap file on
  the SD, used only as overflow.
- **`/tmp` lives on the SD card, not in RAM**, so it doesn't compete with your
  apps for the 2 GB.
- **Wayland sessions.** GNOME and Kubuntu run on **Wayland** only: Panfrost
  gives its best accelerated experience there, and hardware video in the browser
  in particular needs it. Cinnamon boots into its (experimental) Wayland session
  and also ships the X11 session as a fallback.
- **Patched and pinned packages on the Ubuntu images.** Kubuntu and Cinnamon
  ship a patched Xwayland (Ubuntu's 24.1.10 crashes) and Cinnamon a patched
  Muffin (without it, Wayland apps render in software). Both are pinned so an
  Ubuntu update without the fix can't bring the bug back. Details and sources in
  [userspace-patches/](userspace-patches/).
- **Newcomer-friendly desktop** (GNOME) — GNOME ships with a **taskbar** (Dash to Panel),
  system-tray / app-indicator support and minimise/maximise window buttons, all
  on by default so the desktop behaves the way most people expect. These are
  standard GNOME extensions — turn any of them off in the *Extensions* app if you
  prefer stock GNOME.
- **File indexer (Tracker) disabled** (GNOME) — GNOME's `$HOME` indexer is off: it uses
  RAM that the 2 GB board needs. Re-enable it if you have the 4 GB variant and
  want faster in-file search.
- **Software store removed** (GNOME) — GNOME Software is not installed; just polling for
  updates costs it >150 MB of RAM. Updates go through `apt` (see the kernel-pin
  note below).
- **Suspend disabled on every image (on purpose, for now).** On mainline the
  A523 does not wake up from suspend yet: the board hangs completely (not even
  the heartbeat LED) until it is power-cycled. KDE Plasma and Cinnamon suspend on
  their own after a while idle, so suspend and hibernation are turned off
  system-wide (the sleep targets are masked and logind reports
  `CanSuspend=no`), and the desktops no longer offer them. Turning just the
  **screen** off when idle is fine: on Kubuntu it blanks and comes back without
  problems. GNOME keeps the screen on by default. This will be re-enabled once resume
  works.
- **Wi-Fi power saving off.** With it on, the on-board Wi-Fi (AP6256) could drop
  its connection for a few seconds now and then, enough to break an SSH session.
- **Audio output follows what's connected** — a tiny user service
  (`aureal-audio-autoswitch`) moves the default sink to the 3.5 mm headphone
  jack when you plug in, and back to HDMI when you unplug. Bluetooth headsets
  are respected (the service only reacts to the wired jack, never overriding a
  BT or manual choice). PipeWire doesn't do this on its own here because the
  analog codec and HDMI are two separate cards. Override anytime in the tray;
  disable with `systemctl --user disable --now aureal-audio-autoswitch`.

## Roadmap

Spare-time work, so no dates promised — but on the horizon:

- ~~Refreshed patch series~~ **done** in v0.5: the series here is exactly the
  kernel the images run.
- **Suspend / resume**: find out why the A523 doesn't come back from suspend
  (it enters the `deep` state through the firmware and never returns).
- Retire local patches that upstream has superseded (the PIO withstand fix now
  exists in mainline in a different form) once re-validated on the board.
- The open hardware items above still stand: a tested **root-on-NVMe** setup
  (the driver is built in now), an **install-to-eMMC guide**, and line-out /
  microphone capture.

## Contents

- `patches/` — `git format-patch` series (0001–0143).
- `opi4a_blindboot_defconfig` — for `arch/arm64/configs/`: the exact
  configuration the v0.5 images were built with (the last patch of the series
  installs the same file).
- `sun55i-t527-orangepi-4a.dts` — board device-tree.
- `userspace-patches/` — the Xwayland and Muffin patches shipped in the Ubuntu
  images (not kernel patches).

## Applying

```sh
cd linux-6.18.55            # 6.18.55 vanilla
git am /path/to/share-orangepi-4a/patches/0*.patch
cp /path/to/opi4a_blindboot_defconfig arch/arm64/configs/
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- opi4a_blindboot_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs modules
```

## Breakdown by destination (for reviewers)

The patches aren't homogeneous. If you're going to integrate/forward them, this
is the classification by where each group belongs:

### 1. Generic SoC fixes → **linux-sunxi / mainline** (not board-specific)
- `pinctrl: sun55i-a523: program the PIO bank withstand mode from the hardware
  detection` (mainline now has its own fix for the inverted polarity, by Andre
  Przywara; this one is due to be retired)
- `watchdog: sunxi_wdt: per-variant restart priority, 200 on the A523`
- `mfd: axp20x: power off the AXP717 through SOFT_PWROFF (0x27)`
- **Bug**: `RESET_GPIO` breaks `mmc-pwrseq-simple` with `#gpio-cells=3` — affects
  **any** sunxi board with SDIO WiFi. Here it's shipped as `config=n`. Already
  reported upstream by others
  ([fix proposal](https://lkml.iu.edu/2602.2/06168.html),
  [RFC](https://ratatoskr.run/lkml/2026/04/3526967/t)); still open.

### 2. A523/H616 KMS display (drm/sun4i, iommu/sun50i, clk sunxi-ng)
HDMI pipeline bring-up series. Much of it comes from the **minimyth2** community
work (H728) — marked `(minimyth2 NNNN)` — plus our A523 fixes (IOMMU
PHYS_OFFSET/PTE, DE v35x RCQ, VSU8, MBUS wedge, AFBC). Natural destination:
**dri-devel / linux-sunxi** as a series, crediting minimyth2.

### 2b. SoC power & thermal → **linux-sunxi / mainline**
A523 CPU CCU (clk sunxi-ng, ported from the BSP `ccu-sun55iw3-displl.c`), A523
THS (thermal sun8i, custom variant with 4-sensor calibration), CPU/GPU OPP
tables and cooling-maps. cpufreq (little up to 1.416 GHz, big up to 1.8 GHz) +
GPU devfreq 150–696 MHz, both as cooling devices. Asymmetric CPU topology
(cpu-map + capacity-dmips-mhz 922/1024 + dynamic-power-coefficient) so the
scheduler/EAS knows the big cluster is the more capable one — verbatim from the
BSP; without it the two clusters looked identical to the scheduler.

### 3. **BSP U-Boot** workarounds (do NOT send upstream)
Crutches to boot under the BSP's proprietary U-Boot (it doesn't fill `/memory`,
and injects display nodes into the FDT): `/soc/{de,sunxi-drm}` stubs, static
`/memory`, firmware secure regions, `simple-framebuffer` over U-Boot's FB,
heartbeat LED. Not needed with **mainline U-Boot**. Included to reproduce the
boot as-is, not as an upstream proposal.

## ☕ Support the project

This is spare-time hardware-enablement (bring-up) work — display, GPU, audio and
network — built on Allwinner's public documentation and vendor BSP together with
upstream and community patches, with the project's own patches validated on real
hardware. If it helped with your Orange Pi 4A, you can buy me a coffee:

- **Ko-fi:** https://ko-fi.com/aurealnix

Prefer to support it another way? I'm available for freelance / contract
embedded-Linux work (board bring-up, drivers, mainlining) —
**juanmanuellopezcarrillo@gmail.com**.

## Credits

- Mainline port, A523 fixes and integration: **Juan Manuel López Carrillo**
  (AurealNix).
- Display pipeline bring-up: based on the **minimyth2 / Suess** series for
  Allwinner H728 (ported and adapted to the A523) — original authorship by
  **Justin Suess** and **Jernej Škrabec** kept in the patches.
- PCIe controller + Innosilicon combo PHY: from the **Armbian** series by
  **Marvin Wewer** (forward-ported to 6.18 here, with a 1-lane fix from the
  BSP and this board's device-tree wiring) — his authorship kept in the patches.
- Userspace fixes in the Ubuntu images: the Xwayland fix is **Olivier
  Fourdan**'s (upstream xserver); the Muffin `wl_drm` and dma-buf v4 work is
  upstream Muffin's (**Clement Lefebvre**, **Michael Webster**), backported here
  to the 6.4 release that Ubuntu ships.
- The **cycle-masking GPU divider** was found thanks to **Chen-Yu Tsai**, who
  pointed out the fractional semantics while reviewing an upstream patch.
- **Allwinner 5.15 BSP** (vendor kernel, `sun55iw3`) used throughout as the hardware
  reference and guide: register semantics, device-tree values and sensor calibration were
  **taken from the BSP, not invented**; where mainline lacked support, driver logic was
  ported/adapted from it (CPU CCU, THS, DVFS/OPP tables, USB VBUS, poweroff, display).

## Thanks — testers & community

This project became real the day other people started putting it on their own
boards. Thank you:

- **JamesCL** (Armbian forum) — confirmed the **4 GB variant** and the
  **eMMC (HS200)** with detailed reports (dmesg, lsblk), then **booting from
  eMMC** (the CLI image running entirely from the module) and an **Intel NVMe**
  with `f3` integrity runs.
- **L. Jorge Soares** (Armbian forum) — first independent validation of both
  v0.2 images (CLI and KDE: Wi-Fi, HDMI, YouTube, audio), plus serial-console
  logs to help debug eMMC boot.
- **bickns** (Armbian forum) — early feedback on the patch series and testing
  it against Armbian builds, then the first **real NVMe** on this kernel (KIOXIA
  256 GB) with `f3` over the whole drive, several passes, zero corruption.
- **Nick_Sl** (Armbian forum) — asked for the CLI/headless image and
  volunteered to test it. It exists because of that.
- **defencedog** (GitHub) — maintainer of the other community repo for this
  board, for the generous offer to collaborate and for sharing his VPU/GStreamer
  work.

If you test an image or a patch and report back — success *or* failure — you
are doing bring-up with me, and your name belongs here too.

## Author's Note

I hope my work helps you enjoy your boards a bit more. Because I think you
already know this isn't bad hardware — an octa-core, even if it's just A55s, can
go a long way, and it's a shame to miss out on updates, security patches and
general OS improvements simply because the manufacturer can't be bothered. I'm
certain that if the vendor had made even a minimal effort and shipped at least
the longterm kernels now and then, we'd all be a lot happier. But they didn't
even do that. It's true I didn't do all of this myself — but I put in what was
missing and gave it the shape it needed so it can actually be enjoyed. And with
your collaboration I've been able to make it better. Anyway — that's all. Thanks
for your help.

## License

These patches derive from the Linux kernel and are distributed under the same
terms: **GNU General Public License, version 2 (GPL-2.0-only)** — full text in
[LICENSE](LICENSE). The Debian userspace in the image is stock Debian under its
own respective licenses.

## A note on method

Parts of this work were done **with the help of AI agents**. That is exactly why it stays
honest and is published in the open: Allwinner's documentation and BSP were both the hardware source of truth —
**no register semantics were invented** — and **every change was validated on real
hardware**. The patches are here to be reviewed: break them, and send bug reports or
corrections.
