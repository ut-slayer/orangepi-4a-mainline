# FAQ — Orange Pi 4A mainline (Debian 13 image + kernel patches)

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
No. On first boot the system resizes the filesystem and generates SSH keys.
Also, the display driver loads as a kernel module, so the desktop appears
<!-- TODO: measure --> **~XX seconds** after the boot logo. Be patient, don't
pull the power.

**The desktop appears with everything huge (wrong scale).**
KDE may auto-pick a display scale on the very first session. Fix in one click:
System Settings → Display → set Scale to 100% (keep the native resolution).

## Display

**Which resolutions/monitors are known to work?**
Tested on real hardware: <!-- TODO: fill exact list --> 1280x720, 1920x1080,
1360x768. VSU scaling is clean on these modes.

HDMI hotplug detection works natively: the connector reports "connected" at
boot and follows the cable when you plug/unplug it (no force needed). If your
monitor still shows nothing, try a different HDMI cable/input first, then open
an issue with the monitor model.

**Hardware video decode (VPU)?**
Not available — there is no VPU driver in mainline 6.18 for this SoC, and
writing one is not on my roadmap. Video plays through software decoding,
which works fine for typical desktop use. If mainline (cedrus) gains support
for this SoC family someday, I'll integrate it.

**YouTube?**
Works with software decoding. <!-- TODO: state what you verified, e.g.
"720p is smooth in Chromium; 1080p depends on the video" -->

## Hardware support

See the full status table in the README. Short version — working: HDMI KMS +
audio + native HPD/hotplug, Mali-G57 via Panfrost (accelerated Plasma
Wayland), WiFi 2.4/5 GHz, Bluetooth, gigabit ethernet, the 4 rear USB 2.0
ports (HID + storage, hotplug), CPU cpufreq/DVFS and GPU devfreq (both with
thermal throttling), reboot/poweroff, AFBC scanout.

**Known not working / untested:**

- **4GB variant: expected to work, unconfirmed on real hardware.** The
  bootloader auto-detects the RAM size and fills in `/memory` at boot
  (mechanism verified over UART on the 2GB board). I only own the 2GB
  variant — if you have the 4GB one, please confirm with `free -h` and open
  an issue either way.
- Suspend/hibernate: untested.
- Boot from eMMC / NVMe: untested (v0.1 is SD-only). On the roadmap.
- GPIO header / I2C / SPI: untested.
- NPU: the etnaviv driver recognizes it, but it is blacklisted by default
  (when loaded it registered itself as the main render device and broke GPU
  acceleration for regular apps). Load it on demand with `modprobe etnaviv`
  if you want to experiment. There is no inference userspace stack for it yet.

## Performance & thermals

**How fast is it?**
It's an octa-core Cortex-A55 with a Mali-G57 — a modest but honest desktop.
glmark2-es2 (Wayland) scores ~531 with Panfrost <!-- TODO: re-measure with GPU
devfreq — 531 was at the old fixed 432 MHz clock, peak is now 600 MHz -->. The
Plasma Wayland desktop is smooth at 1080p; Chromium runs with GPU acceleration
including WebGL.

**Does it need a heatsink? Does it throttle?**
CPU frequency scaling (cpufreq/DVFS) works: OPPs from 480 MHz to 1.8 GHz on
both clusters (schedutil governor), with the A523 thermal sensors (THS) and
CPU cooling maps wired — under sustained load the chip throttles itself
gracefully instead of cooking. The GPU scales too (Panfrost devfreq,
150–600 MHz, simple_ondemand): it idles at 150 MHz and has its own cooling
map on the GPU thermal zone. In normal desktop use it runs cool;
development was done <!-- TODO: confirm --> without active cooling.
Measured temperatures: <!-- TODO: idle XX°C / sustained load XX°C
(cat /sys/class/thermal/thermal_zone*/temp, stress-ng 10 min) -->

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
you did, and if it's a boot problem, a serial console log if you can get one
(UART0, 115200) — it's the single most useful thing you can attach.

**How can I support this?**
It's free either way. If it saved you time: ☕ [ko-fi.com/aurealnix](https://ko-fi.com/aurealnix)
— tips, or the membership tiers get you early access to new image releases
and a vote on what gets worked on next.
