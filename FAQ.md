# FAQ — Orange Pi 4A mainline (Debian 13 image + kernel patches)

🌐 **English** · [Español](FAQ.es.md)

Honest answers, in the same spirit as the rest of this project: only what has
been verified on real hardware is stated as fact. Untested things are marked
untested. If you find any answer here that doesn't match your experience,
please open an issue.

---

## Flashing & first boot

**How do I flash the image?**
Write the `.img.xz` to a microSD card (8GB or larger) with balenaEtcher, or:

```
xz -dc aurealnix-opi4a-debian13-v0.1.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
```

Verify the download first: `sha256sum -c` against the published checksum.

**Default user and password?**
`user` / `user`. Root login is locked; use `sudo`. **Change the password right
away** (`passwd`) — SSH is enabled and a default password on a network-facing
device is how boards end up in botnets.

**Is SSH enabled?**
Yes, from the first boot. SSH host keys are regenerated on first boot, so your
board's keys are unique. The board gets its address via DHCP.

**The first boot takes long / the screen stays on the boot logo — is it dead?**
No. The desktop comes up in roughly **half a minute** from power-on. The very
first boot is longer — it resizes the filesystem to fill your card and
generates fresh SSH keys — so give it a minute the first time and don't pull
the power.

**The desktop appears with everything huge (wrong scale).**
KDE may auto-pick a display scale on the very first session. Fix in one click:
System Settings → Display → set Scale to 100% (keep the native resolution).

## Display

**Which resolutions/monitors are known to work?**
Tested on real hardware: 1280x720, 1360x768 (native panel of my test monitor),
and 1920x1080. VSU scaling is clean on these modes. Other standard modes should
work via the monitor's EDID.

HDMI hotplug detection works natively: the connector reports "connected" at
boot and follows the cable when you plug/unplug it (no force needed). If your
monitor still shows nothing, try a different HDMI cable/input first, then open
an issue with the monitor model.

**Does Vulkan work?**
Not yet. OpenGL / OpenGL ES are accelerated through Panfrost (Mesa); Vulkan
falls back to llvmpipe (software) — the Panfrost Vulkan driver (panvk) doesn't
support the Mali-G57 well enough yet. GL ES is what the desktop and most apps
use, so day-to-day this isn't a problem.

**Hardware video decode (VPU)?**
Not available — there is no VPU driver in mainline 6.18 for this SoC, and
writing one is not on my roadmap. Video plays through software decoding,
which works fine for typical desktop use. If mainline (cedrus) gains support
for this SoC family someday, I'll integrate it.

**YouTube?**
Works with software decoding (there's no hardware VPU). In a window, 720p is
smooth — around 1% dropped frames in my testing. Fullscreen leans harder
because the video gets scaled up (~6% dropped), so it holds up but isn't
flawless. Fine for casual viewing either way; the board stays cool doing it
(~55–60 °C, with half the CPU still idle). Higher resolutions lean harder still.

## Hardware support

See the full status table in the README. Short version — working: HDMI KMS +
audio + native HPD/hotplug, Mali-G57 via Panfrost (accelerated Plasma
Wayland), WiFi 2.4/5 GHz, Bluetooth, gigabit ethernet, the 4 rear USB 2.0
ports (all USB 2.0 — the SoC's USB3 lane is not wired on this board; HID +
storage, hotplug), the THS thermal sensors (5 zones: cpu_l/cpu_b/gpu/npu/ddr),
CPU cpufreq/DVFS and GPU devfreq (both with thermal throttling),
reboot/poweroff, AFBC scanout.

**Known not working / untested:**

- **4GB variant: expected to work, unconfirmed on real hardware.** The
  bootloader auto-detects the RAM size and fills in `/memory` at boot
  (mechanism verified over UART on the 2GB board). I only own the 2GB
  variant — if you have the 4GB one, please confirm with `free -h` and open
  an issue either way. (The board ships only in 2GB and 4GB — there is no 1GB.)
- Suspend/hibernate: untested.
- Boot from eMMC / NVMe SSD: completely untested — I don't own an eMMC module
  or an NVMe drive, so everything has only been tested **from microSD**. If
  you try either, please report back (works or not). Getting the hardware to
  support this properly is the kind of thing the Ko-fi tips go towards.
- GPIO header / I2C / SPI: untested.
- NPU: the etnaviv driver recognizes it, but it is blacklisted by default
  (when loaded it registered itself as the main render device and broke GPU
  acceleration for regular apps). Load it on demand with `modprobe etnaviv`
  if you want to experiment. There is no inference userspace stack for it yet.

## Performance & thermals

**How fast is it?**
It's an octa-core Cortex-A55 with a Mali-G57 — a modest but honest desktop.
glmark2-es2 (Wayland) scores in the ~500s with Panfrost. The Plasma Wayland
desktop is smooth at 1080p; Chromium runs with GPU acceleration including WebGL.

**Does it need a heatsink? Does it throttle?**
CPU frequency scaling (cpufreq/DVFS) works: OPPs from 480 MHz up to
1.416 GHz on the little cluster (cpu0-3) and up to 1.8 GHz on the big
cluster (cpu4-7), schedutil governor, with the A523 thermal sensors (THS) and
CPU cooling maps wired — under sustained load the chip throttles itself
gracefully instead of cooking. The GPU scales too (Panfrost devfreq,
150–600 MHz, simple_ondemand): it idles at 150 MHz and has its own cooling
map on the GPU thermal zone. In normal desktop use it runs cool, and
development was done with no heatsink and no fan.
Measured (bare board, no cooling): ~47 °C idle, ~60 °C under a full 8-core CPU
load — nowhere near the 90 °C throttle trip. You don't need a heatsink for
desktop use; add one only if you plan to hammer all cores for long stretches.

**Is there swap / zram?**
No — both are disabled by default. The board ships in different RAM sizes
(2 GB / 4 GB), so swap/zram is left for you to set up to taste (`zram-tools`,
a swapfile, whatever suits your variant). On the 2GB board, with Baloo off, it
runs fine without swap for normal desktop use.

## Desktop session & image tuning

**Wayland or X11?**
Wayland only. The image ships a Plasma **Wayland** session and everything is
tested under it. The **X11 session is not supported** — I couldn't get it to
work reliably on this stack.

**Why is file indexing (Baloo) disabled? Why doesn't Discover check for updates
automatically?**
To keep RAM free on the 2GB board. Two Plasma background services are off by
default:

- **Baloo** — Plasma's file indexer (scans your `$HOME` to speed up searches).
  Off; it costs RAM this board would rather spend elsewhere.
- **Discover's automatic update check** — off; polling for updates alone eats
  **>150 MB of RAM**. Updating still works normally via `apt` or by opening
  Discover by hand.

Re-enable either from System Settings if you have the 4GB variant and want them.

## Kernel & updates

**Why is the kernel pinned? Can I `apt upgrade` safely?**
Yes — userspace is **pure Debian 13** (built with debootstrap, standard repos
+ trixie-backports for Mesa) and updates normally through apt/Discover. Only
the kernel lives outside dpkg: an apt pin prevents Debian's `linux-image-*`
from installing, because a stock Debian kernel would not boot this board (it
lacks the ~106 patches this port needs, and the boot chain expects a specific
uImage).

**How do kernel updates arrive?**
With new image releases (release notes will say what changed), or manually:
replace `uImage` + modules from the repo's built artifacts. Instructions in
the README.

**Can I build the kernel myself?**
Yes — the repo has the full patch series (~106 patches on vanilla 6.18.38), the
defconfig and the board `.dts`. Build instructions included.

**Which U-Boot does it use?**
The vendor (BSP) U-Boot for now, with documented workarounds. Moving to
mainline U-Boot is on the roadmap — it removes several workarounds at once
(including the 4GB memory issue).

## The project

**Are these patches going upstream?**
That's the goal. The README classifies every patch by destination: generic
sunxi fixes (pinctrl, watchdog, AXP717, an mmc-pwrseq bug that affects any
sunxi board with SDIO WiFi) are being prepared for the mailing lists; the
display series builds on the minimyth2/Suess H728 work and needs more
maturing/feedback first.

**Did you write all these patches from scratch?**
No — and the series says so explicitly. The HDMI/display stack is largely a
port/adaptation of the **minimyth2 / Suess** H728 community series to the
A523/T527; some patches are adaptations of code from newer kernel trees or
the vendor BSP; the rest (IOMMU fixes, DE/RCQ/AFBC work, board DTS,
integration) is original work for this board. Where a patch derives from
someone else's work, the original authorship is preserved in the patch
headers. If you spot a missing or wrong attribution, tell me and I'll fix it
immediately.

**Parts of this were done with AI assistance — should I trust it?**
Fair question. The method: the vendor BSP 5.15 was used as the hardware
source of truth (no invented register semantics), and every change was
validated on real hardware. But that's exactly why the patches are published:
review them, break them, tell me what's wrong. Bug reports and corrections
are the point.

**Does it work on other T527/A523 boards (Avaota A1, Cubie A5E, ...)?**
Same SoC family, so the SoC-level work should carry over; the board-specific
parts (DTS: regulators, pinmux, PHY) need adapting. Not tested on anything
except the Orange Pi 4A (2GB). If you port it to another board, I'd love to
hear about it.

**Where do I report bugs?**
GitHub issues. Please include: board variant (2GB/4GB), monitor model, what
you did, and if it's a boot problem, a serial-console log if you can get one
(UART0, 115200) — it's the single most useful thing you can attach.

**How can I support this?**
It's free either way. If it saved you time: ☕ [ko-fi.com/aurealnix](https://ko-fi.com/aurealnix)
— tips, or the membership tiers get you early access to new image releases
and a vote on what gets worked on next.
