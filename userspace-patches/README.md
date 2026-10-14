# Userspace patches shipped in the v0.5 Ubuntu images

🌐 **English** · [Español](README.es.md)

These are not kernel patches. They are the source of the two Ubuntu 26.04 packages
the **Kubuntu** and **Cinnamon** images ship patched, so that anyone can check
exactly what was changed and rebuild them. Each one is pinned in the images
(`/etc/apt/preferences.d/aurealnix-patched-packages`) so that an Ubuntu update
without the fix can't silently bring the bug back.

## `xwayland/` — Xwayland 24.1.10 crash (Kubuntu, Cinnamon)

- **Package:** `xwayland 2:24.1.10-1aurealnix1` = Ubuntu's `2:24.1.10-1` plus one
  patch.
- **Bug:** Xwayland 24.1.10 dereferences a NULL window in `damage_report()`
  (`hw/xwayland/xwayland-window.c`) and crashes as soon as a session starts its
  X11 helpers. The Cinnamon Wayland session simply gave up. Introduced in
  24.1.10 by commit `34934c37`; Debian 13 (Xwayland 24.1.6) is not affected.
- **Fix:** upstream, by Olivier Fourdan:
  [xserver MR 2190](https://gitlab.freedesktop.org/xorg/xserver/-/merge_requests/2190),
  released in **Xwayland 24.1.11**. The patch here is that fix, unchanged.
- **Ubuntu bug:** [LP #2166607](https://bugs.launchpad.net/ubuntu/+source/xwayland/+bug/2166607).
- **When it goes away:** the pin allows any Ubuntu `xwayland` **24.1.11 or later**,
  so a normal `apt upgrade` replaces it once Ubuntu ships the fix.

## `muffin/` — Cinnamon Wayland on the GPU instead of llvmpipe (Cinnamon)

- **Package:** `muffin 6.4.1-1build1aurealnix1` (and `libmuffin0t64`,
  `muffin-common`, `gir1.2-meta-muffin-0.0`) = Ubuntu's `6.4.1-1build1` plus
  these four patches.
- **Bug:** Muffin 6.4.1 only offers the dma-buf protocol v3 and no `wl_drm`. With
  current Mesa (no `EGL_WL_bind_wayland_display`) every Wayland app fell back to
  software rendering: glmark2 **52**. With the patches: **~610**.

| Patch | Origin | What it does |
|---|---|---|
| `0001` wl_drm | upstream Muffin `11d90f79` (Clement Lefebvre) | advertise the render node over `wl_drm` |
| `0002` MetaAnonymousFile | backport of the helper from upstream `6ea2c8c8` | needed by the dma-buf v4 format table |
| `0003` dma-buf v4 | upstream Muffin `4e4de5ff` (Michael Webster) | `zwp_linux_dmabuf_v1` feedback (v4) |
| `0004` render node | **new** (this project) | when the KMS device has no render node (display controller and GPU are separate devices, as on Allwinner, Rockchip, Amlogic…), advertise the GPU's render node instead |

`0004` also affects current upstream Muffin, which looks up the render node
of the KMS device and finds none on these boards. It will be proposed upstream to
[linuxmint/muffin](https://github.com/linuxmint/muffin).

- **When it goes away:** the pin blocks every Ubuntu `muffin` until these fixes
  are in Ubuntu's package. The trade-off is that a Muffin security update won't
  arrive automatically. To go back to Ubuntu's packages, delete the pin file and
  run `sudo apt update && sudo apt full-upgrade`.

## Rebuilding

```sh
apt source muffin=6.4.1-1build1          # or xwayland=2:24.1.10-1
cd muffin-6.4.1
for p in /path/to/userspace-patches/muffin/*.patch; do patch -p1 < "$p"; done
dch -v 6.4.1-1build1aurealnix1 "Apply the patches from orangepi-4a-mainline"
dpkg-buildpackage -b -uc -us
```

Built natively on the board (arm64), with Ubuntu's own build flags.
