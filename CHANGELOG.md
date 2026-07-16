# Changelog

🌐 **English** · [Español](CHANGELOG.es.md)

## v0.2 — Analog audio (3.5 mm headphone jack)

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
