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
xz -dc aurealnix-opi4a-debian13-v0.2.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
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
No. From a microSD, the GNOME desktop takes **about a minute** to come up from
power-on — SD cards have slow random I/O and the desktop loads a lot of small
files. It'll be noticeably quicker from eMMC or NVMe once those are supported.
The very **first** boot is longer still: it resizes the filesystem to fill your
card and generates fresh SSH keys — give it a couple of minutes that first time
and don't pull the power.

**The desktop appears with everything huge (wrong scale).**
GNOME may auto-pick a display scale on the very first session. Fix it in
Settings → Displays → set Scale to 100% (keep the native resolution).

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
Partly — **H.264 and H.265 hardware decode work; VP8/VP9 don't yet.** The
kernel half is in this patch series (the `cedar-ve` shim, its device-tree node
and the IOMMU mappings for the video-engine masters). Paired with Allwinner's
own userspace (libcedarc + `gstreamer1.0-omx`), H.264/H.265 decode in hardware
— YouTube plays smoothly in a WebKit browser (tested with Cog) on this board.
**VP8/VP9 I haven't managed to get working yet**: that engine never raises its
interrupt, so those codecs are capped in our setup and YouTube negotiates H.264
instead. The datasheet lists VP9 decode up to 4K@60, so it stays on the list —
no ETA, no promises. (AV1 is not supported in hardware by any Allwinner SoC.)

Note the **published Debian images don't ship the userspace half yet** — on
them video still plays through software decoding, which works fine for typical
desktop use. A refreshed image will fold the full stack in.

One important caveat on the approach: it uses **Allwinner's own userspace** (the
CedarX / libcedarc libraries). On this SoC the codec programming logic lives in
that closed vendor blob rather than in the kernel, so this is **not** a
fully open mainline V4L2 / cedrus driver — it's the vendor stack. If you want a
fully open path, that's a different (and much larger) job.

**YouTube?**
On the published images it plays with software decoding: in a window, 720p is
smooth — around 1% dropped frames in my testing. Fullscreen leans harder
because the video gets scaled up (~6% dropped), so it holds up but isn't
flawless. Fine for casual viewing either way; the board stays cool doing it
(~55–60 °C, with half the CPU still idle). With the VPU stack above (this
kernel series + the vendor userspace), YouTube plays with **H.264 hardware
decode** and is smooth — that's the plan for the next image.

## Hardware support

See the full status table in the README. Short version — working: HDMI KMS +
audio + native HPD/hotplug, the **3.5 mm headphone jack** (analog codec, with
jack detection/hotplug), Mali-G57 via Panfrost (accelerated GNOME on
Wayland), WiFi 2.4/5 GHz, Bluetooth, gigabit ethernet, the 4 rear USB 2.0
ports (all USB 2.0 — see "Why is there no USB 3.0?" below; HID +
storage, hotplug), the THS thermal sensors (5 zones: cpu_l/cpu_b/gpu/npu/ddr),
CPU cpufreq/DVFS and GPU devfreq (both with thermal throttling),
reboot/poweroff, AFBC scanout.

**Why is there no USB 3.0? All the USB-A ports are 2.0.**
Board design, not a software limitation. The T527 has a **single high-speed
SerDes lane**, driven by a combo PHY that can operate either as USB 3.0 *or*
as PCIe — one or the other, never both at once. Orange Pi wired that lane to
the **M.2 slot**, so the 4A spends it on NVMe instead of USB 3.0. Every USB
port on the board is USB 2.0 (480 Mbps); the vendor Android/BSP images have
the same limitation, and no kernel update can change it. If you need fast
external storage on this board, the M.2 NVMe slot is the way.

**Known not working / untested:**

- **4GB variant: confirmed working.** The bootloader auto-detects the RAM
  size and fills in `/memory` at boot — verified over UART on the 2GB board,
  and confirmed on a 4GB board by a tester (`free -m` reported ~3.8 GB).
  (The board ships only in 2GB and 4GB — there is no 1GB.)
- Analog line-out and microphone capture: wired in the codec driver but **not
  bench-tested yet** (the board has no onboard speaker/mic to try them on).
  The 3.5 mm **headphone** output and jack detection do work.
- **Suspend / hibernate: disabled by default.** The mainline resume path on this
  SoC still needs work — the system doesn't reliably come back after the screen
  powers off — so automatic suspend *and* idle screen-blanking are turned off in
  the image, and the display stays on. Re-enable either in *Settings → Power* if
  you want to test it.
- eMMC: the module is **detected and works at HS200** (read/write) — confirmed
  on real hardware by a tester (a 58 GB eMMC came up as `mmcblk2` and was used
  as storage — thanks to **JamesCL** for testing the eMMC and the 4 GB board! 🙏). **Booting from eMMC** is a separate step that isn't wired up yet
  — the image is set up to boot from microSD. **NVMe / M.2 SSD: untested with
  a real drive.** The patch series now brings up the PCIe controller and the
  combo PHY, and the root port enumerates — but that's verified only with an
  **empty** slot. Whether a real NVMe drive enumerates, works and stays stable
  is exactly the part I can't confirm yet. The published v0.2 images predate
  this, so nothing shows in `lspci` there (thanks to the tester who diagnosed
  exactly this and reported it!). I don't have an NVMe drive to test with —
  if you have one in the M.2 slot, a test report would be gold.
- GPIO header / I2C / SPI: untested.
- NPU: the etnaviv driver recognizes it, but it is blacklisted by default
  (when loaded it registered itself as the main render device and broke GPU
  acceleration for regular apps). Load it on demand with `modprobe etnaviv`
  if you want to experiment. There is no inference userspace stack for it yet.

## Performance & thermals

**How fast is it?**
It's an octa-core Cortex-A55 with a Mali-G57 — a modest but honest desktop.
glmark2-es2 (Wayland) scores in the ~500s with Panfrost. The GNOME Wayland
desktop is smooth at 1080p; the browser runs with GPU acceleration including WebGL.

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
**zram: yes, on by default. SD swap file: optional.** The image enables a
**1 GB compressed in-RAM swap (zram, zstd)**: on the 2 GB board a browser
playing video can exhaust the RAM, and swapping to the slow microSD used to
stall the desktop — zram absorbs that in RAM instead, compressed, without
touching the card. Its cost is close to zero while unused (it only takes
memory for pages that actually get swapped out), and you can turn it off any
time with `sudo systemctl disable --now zram-swap.service`.

There is still **no swap file on the SD by default**. If you want extra
headroom (worth it on the 2 GB variant for heavy desktop use), the gift script
in the home folder creates a 1 GB `/swapfile`, enables it and makes it
permanent (survives reboots):

```
sudo ./add-swapfile.sh
```

zram has the higher priority, so the SD file only catches the overflow once
zram is full.

## Desktop session & image tuning

**How does the board decide where sound comes out?**
By default the output **follows what's connected**: plug headphones into the
3.5 mm jack and sound moves to them; unplug and it returns to HDMI (the TV). If
both are present, the headphone jack wins — plugging in is treated as your
explicit choice. **Bluetooth headsets are respected**: the auto-switch only
reacts to the wired jack, so connecting a BT headset works normally and is never
overridden. This is done by a small user service (`aureal-audio-autoswitch`)
because PipeWire doesn't move the default between the separate analog and HDMI
cards on its own — verified on hardware. You can always pick the output manually
in the system tray or *System Settings → Audio*, and you can turn the behaviour
off with `systemctl --user disable --now aureal-audio-autoswitch`.

**Wayland or X11?**
Wayland only. The image ships a **GNOME Wayland** session and everything is
tested under it. No **X11 session** is shipped — Panfrost gives its best
accelerated experience under Wayland, and hardware video in the browser needs it.

**Why is file indexing (Tracker) disabled? Why is there no software store?**
To keep RAM free on the 2 GB board:

- **Tracker** — GNOME's file indexer (scans your `$HOME` to speed up in-file
  search). Off; it costs RAM this board would rather spend elsewhere. Re-enable
  it from a terminal if you have the 4 GB variant and want it.
- **GNOME Software** — the graphical app store is not installed; just polling for
  updates costs it **>150 MB of RAM**. Updating still works normally via `apt`
  (`sudo apt update && sudo apt upgrade`).

## Kernel & updates

**Why is the kernel pinned? Can I `apt upgrade` safely?**
Yes — userspace is **pure Debian 13** (built with debootstrap, standard repos
+ trixie-backports for Mesa) and updates normally through apt. Only
the kernel lives outside dpkg: an apt pin prevents Debian's `linux-image-*`
from installing, because a stock Debian kernel would not boot this board (it
lacks the 130 patches this port needs, and the boot chain expects a specific
uImage).

**How do kernel updates arrive?**
With new image releases (release notes will say what changed), or manually:
replace `uImage` + modules from the repo's built artifacts. Instructions in
the README.

**Can I build the kernel myself?**
Yes — the repo has the full patch series (130 patches on vanilla 6.18.38), the
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
It's free either way — everything lands here, for everyone. If it saved you
time: ☕ [ko-fi.com/aurealnix](https://ko-fi.com/aurealnix) — one-off tips or a
small monthly membership. Members get the behind-the-scenes dev notes; the code
and the images are never paywalled.
