# Orange Pi 4A (Allwinner T527 / A523) — mainline Linux 6.18.38

🌐 **English** · [Español](README.es.md)

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee%20%E2%98%95-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/aurealnix)

**Mainline** support for the Orange Pi 4A (Allwinner **T527** SoC, A523 family /
`sun55iw3`), on a **vanilla 6.18.38** kernel. A 106-patch series + `defconfig` +
the board device-tree. The ports from the community minimyth2 series keep their
original authorship (Justin Suess, Jernej Škrabec) in the patch headers.

> Working-tree base: `linux-6.18.38` vanilla. These patches apply on top.
> `git format-patch --base` embeds the base hash in every `.patch`.

**Latest image: v0.2** — analog audio / 3.5 mm headphone jack now works. See
[CHANGELOG.md](CHANGELOG.md) for release history.

## What works (confirmed on hardware)

| Block | Status |
|---|---|
| **HDMI KMS display** (DE33/DE3.5 + TCON-TV + DW-HDMI 2.0 + Inno PHY) | ✅ 720p/1080p, clean VSU8 scaling |
| **HDMI boot console** (fbcon via `simple-framebuffer` over U-Boot's FB) | ✅ with the BSP U-Boot (not needed with mainline U-Boot; see §4) |
| **HDMI HPD / hotplug** (native connector detection) | ✅ connected at boot + hotplug (plug/unplug) without forcing |
| **Mali-G57 GPU** (Panfrost) | ✅ accelerated (Cinnamon / KDE Plasma Wayland) |
| **HDMI audio** (i2s2 → dw-hdmi) | ✅ PCM output to the TV |
| **Analog audio** (3.5 mm headphone jack + jack detect) | ✅ headphones + hotplug (custom `sun55i-a523-codec` driver ported from the BSP — no mainline driver exists otherwise). Line-out / mic capture wired but not yet bench-tested |
| **Ethernet GMAC1** (YT8531 PHY, RGMII) | ✅ RX/TX |
| **WiFi AP6256** (BCM43456, brcmfmac, SDIO) | ✅ 2.4/5 GHz scan, association |
| **reboot / poweroff** (sunxi_wdt / AXP717) | ✅ |
| **AFBC scanout** (v350 AFBD decoder) | ✅ |
| **USB** (4 rear Type-A ports — all USB 2.0: the board doesn't wire the SoC's USB3, the vendor leaves it disabled) | ✅ HID (keyboard/mouse) + mass storage + hotplug; the OTG pair works as host |
| **THS thermal sensors** (5 zones: cpu_l / cpu_b / gpu / npu / ddr) | ✅ sysfs/hwmon readout + 110 °C critical trip |
| **CPU cpufreq/DVFS** (little 480 MHz–1.416 GHz, big 480 MHz–1.8 GHz) + thermal throttling at 90 °C | ✅ |
| **Asymmetric CPU topology** (cpu-map + capacity-dmips-mhz 922/1024 + EAS energy model) | ✅ big cluster preferred for heavy tasks |
| **GPU devfreq/DVFS** (Panfrost, 150–600 MHz) + thermal throttling | ✅ |
| **eMMC** (MMC storage) | ✅ detected + HS200 read/write (confirmed by a tester); booting *from* eMMC not wired up yet |

Hardware video decode (VPU) is **not** included (no driver in 6.18). The **4 GB variant is confirmed working** (tested by **JamesCL** — thanks! — who also confirmed the eMMC; the bootloader auto-detects the RAM size).

## Image notes (Debian 13)

Decisions made in the distributed image (these are not kernel patches):

- **First boot auto-resizes the rootfs** to fill the microSD and regenerates the
  SSH host keys — so the first boot takes a bit longer. Don't pull the power.
- **SSH is enabled from first boot**; user/password are `user` / `user`.
  **Change the password immediately** (`passwd`) — a default password on a
  network-facing device is how boards end up in botnets.
- **zram and swap are disabled by default.** The board ships in different RAM
  sizes (2 GB / 4 GB), so swap/zram is left for you to configure to taste.
- **Wayland session** — the desktop is Plasma on **Wayland**. The **X11 session
  is not supported**: it hasn't been made to work well on this stack.
- **Baloo disabled** — Plasma's file indexer (crawls `$HOME` to speed up
  searches) is off: it uses RAM that the 2 GB board needs. Re-enable it if you
  have the 4 GB variant and want it.
- **Discover update auto-check disabled** — the process that polls for updates
  eats **>150 MB of RAM** just for that. Updates via `apt` / manual Discover
  still work normally.
- **Audio output follows what's connected** — a tiny user service
  (`aureal-audio-autoswitch`) moves the default sink to the 3.5 mm headphone
  jack when you plug in, and back to HDMI when you unplug. Bluetooth headsets
  are respected (the service only reacts to the wired jack, never overriding a
  BT or manual choice). PipeWire doesn't do this on its own here because the
  analog codec and HDMI are two separate cards. Override anytime in the tray;
  disable with `systemctl --user disable --now aureal-audio-autoswitch`.

## Contents

- `patches/` — `git format-patch` series (0001–0106).
- `opi4a_blindboot_defconfig` — for `arch/arm64/configs/`.
- `sun55i-t527-orangepi-4a.dts` — board device-tree.

## Applying

```sh
cd linux-6.18.38            # 6.18.38 vanilla
git am /path/to/share-orangepi-4a/patches/0*.patch
cp /path/to/opi4a_blindboot_defconfig arch/arm64/configs/
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- opi4a_blindboot_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs modules
```

## Breakdown by destination (for reviewers)

The patches aren't homogeneous. If you're going to integrate/forward them, this
is the classification by where each group belongs:

### 1. Generic SoC fixes → **linux-sunxi / mainline** (not board-specific)
- `pinctrl: sun55i-a523: withstand PIO banks from hw detection`
- `pinctrl: sunxi: inverted POW_MOD_SEL polarity on A523/T527`
- `watchdog: sunxi_wdt: restart priority 200 (beats PSCI)`
- `mfd: axp20x: AXP717 poweroff (OFF_CTRL range not writeable)`
- **Bug**: `RESET_GPIO` breaks `mmc-pwrseq-simple` with `#gpio-cells=3` — affects
  **any** sunxi board with SDIO WiFi. Here it's shipped as `config=n`; the real
  fix belongs in the driver, upstream.

### 2. A523/H616 KMS display (drm/sun4i, iommu/sun50i, clk sunxi-ng)
HDMI pipeline bring-up series. Much of it comes from the **minimyth2** community
work (H728) — marked `(minimyth2 NNNN)` — plus our A523 fixes (IOMMU
PHYS_OFFSET/PTE, DE v35x RCQ, VSU8, MBUS wedge, AFBC). Natural destination:
**dri-devel / linux-sunxi** as a series, crediting minimyth2.

### 2b. SoC power & thermal → **linux-sunxi / mainline**
A523 CPU CCU (clk sunxi-ng, ported from the BSP `ccu-sun55iw3-displl.c`), A523
THS (thermal sun8i, custom variant with 4-sensor calibration), CPU/GPU OPP
tables and cooling-maps. cpufreq (little up to 1.416 GHz, big up to 1.8 GHz) +
GPU devfreq 150–600 MHz, both as cooling devices. Asymmetric CPU topology
(cpu-map + capacity-dmips-mhz 922/1024 + dynamic-power-coefficient) so the
scheduler/EAS knows the big cluster is the more capable one — verbatim from the
BSP; without it the two clusters looked identical to the scheduler.

### 3. Board integration → **Armbian** (`armbian/build`, sun55iw3 family)
- `arch/arm64/boot/dts/allwinner/sun55i-t527-orangepi-4a.dts` (ethernet, audio,
  HDMI pipeline, low CMA).
- `opi4a_blindboot_defconfig`.

### 4. **BSP U-Boot** workarounds (do NOT send upstream)
Crutches to boot under the BSP's proprietary U-Boot (it doesn't fill `/memory`,
and injects display nodes into the FDT): `/soc/{de,sunxi-drm}` stubs, static
`/memory`, firmware secure regions, `simple-framebuffer` over U-Boot's FB,
heartbeat LED. Not needed with **mainline U-Boot**. Included to reproduce the
boot as-is, not as an upstream proposal.

## ☕ Support the project

This is reverse-engineering work done in spare time (display, GPU, audio and
network bring-up…). If it helped with your Orange Pi 4A, you can buy me a coffee:

- **Ko-fi:** https://ko-fi.com/aurealnix
- **GitHub Sponsors:** *Sponsor* button at the top of the repo (when active)

## Credits

- Mainline port, A523 fixes and integration: **Juan Manuel López Carrillo**
  (AurealNix).
- Display pipeline bring-up: based on the **minimyth2 / Suess** series for
  Allwinner H728 (ported and adapted to the A523) — original authorship by
  **Justin Suess** and **Jernej Škrabec** kept in the patches.
- **Allwinner 5.15 BSP** (vendor kernel, `sun55iw3`) used throughout as the hardware
  reference and guide: register semantics, device-tree values and sensor calibration were
  **taken from the BSP, not invented**; where mainline lacked support, driver logic was
  ported/adapted from it (CPU CCU, THS, DVFS/OPP tables, USB VBUS, poweroff, display).

## License

These patches derive from the Linux kernel and are distributed under the same
terms: **GNU General Public License, version 2 (GPL-2.0-only)** — full text in
[LICENSE](LICENSE). The Debian userspace in the image is stock Debian under its
own respective licenses.

## A note on method

Parts of this work were done **with the help of AI agents**. That is exactly why it stays
honest and is published in the open: the Allwinner BSP was the hardware source of truth —
**no register semantics were invented** — and **every change was validated on real
hardware**. The patches are here to be reviewed: break them, and send bug reports or
corrections.
