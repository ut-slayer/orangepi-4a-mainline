# Parches de espacio de usuario de las imágenes Ubuntu v0.5

🌐 [English](README.md) · **Español**

No son parches del kernel. Son el código fuente de los dos paquetes de Ubuntu 26.04
que las imágenes **Kubuntu** y **Cinnamon** llevan parcheados. Están aquí para que
cualquiera pueda ver exactamente qué se cambió y recompilarlos. Cada uno está
fijado en las imágenes (`/etc/apt/preferences.d/aurealnix-patched-packages`) para
que una actualización de Ubuntu sin el arreglo no devuelva el fallo sin avisar.

## `xwayland/`: cuelgue de Xwayland 24.1.10 (Kubuntu, Cinnamon)

- **Paquete:** `xwayland 2:24.1.10-1aurealnix1` = el `2:24.1.10-1` de Ubuntu más un
  parche.
- **Fallo:** Xwayland 24.1.10 usa una ventana NULL en `damage_report()`
  (`hw/xwayland/xwayland-window.c`) y se cae en cuanto la sesión arranca sus
  ayudantes X11. La sesión Wayland de Cinnamon no llegaba a arrancar. Lo introdujo
  el commit `34934c37` en la 24.1.10; Debian 13 (Xwayland 24.1.6) no está afectada.
- **Arreglo:** upstream, de Olivier Fourdan:
  [xserver MR 2190](https://gitlab.freedesktop.org/xorg/xserver/-/merge_requests/2190),
  publicado en **Xwayland 24.1.11**. El parche de aquí es ese arreglo, sin cambios.
- **Bug en Ubuntu:** [LP #2166607](https://bugs.launchpad.net/ubuntu/+source/xwayland/+bug/2166607).
- **Cuándo deja de hacer falta:** el pin deja pasar cualquier `xwayland` de Ubuntu
  **24.1.11 o posterior**, así que un `apt upgrade` normal lo sustituye en cuanto
  Ubuntu publique el arreglo.

## `muffin/`: Cinnamon Wayland en la GPU en vez de llvmpipe (Cinnamon)

- **Paquete:** `muffin 6.4.1-1build1aurealnix1` (y `libmuffin0t64`,
  `muffin-common`, `gir1.2-meta-muffin-0.0`) = el `6.4.1-1build1` de Ubuntu más
  estos cuatro parches.
- **Fallo:** Muffin 6.4.1 solo ofrece el protocolo dma-buf v3 y no tiene `wl_drm`.
  Con la Mesa actual (sin `EGL_WL_bind_wayland_display`), todas las aplicaciones
  Wayland caían a renderizado por software: glmark2 **52**. Con los parches: **~610**.

| Parche | Origen | Qué hace |
|---|---|---|
| `0001` wl_drm | Muffin upstream `11d90f79` (Clement Lefebvre) | anuncia el render node por `wl_drm` |
| `0002` MetaAnonymousFile | backport del ayudante de upstream `6ea2c8c8` | lo necesita la tabla de formatos de dma-buf v4 |
| `0003` dma-buf v4 | Muffin upstream `4e4de5ff` (Michael Webster) | `zwp_linux_dmabuf_v1` con feedback (v4) |
| `0004` render node | **nuevo** (de este proyecto) | si el dispositivo KMS no tiene render node (controlador de pantalla y GPU separados, como en Allwinner, Rockchip, Amlogic…), anuncia el render node de la GPU |

El `0004` también afecta al Muffin upstream actual, que busca el render node en el
dispositivo KMS y en estas placas no lo encuentra. Se propondrá upstream en
[linuxmint/muffin](https://github.com/linuxmint/muffin).

- **Cuándo deja de hacer falta:** el pin bloquea cualquier `muffin` de Ubuntu hasta
  que estos arreglos estén en su paquete. A cambio, una actualización de seguridad
  de Muffin no llegará sola. Para volver a los paquetes de Ubuntu, borra el fichero
  del pin y ejecuta `sudo apt update && sudo apt full-upgrade`.

## Recompilar

```sh
apt source muffin=6.4.1-1build1          # o xwayland=2:24.1.10-1
cd muffin-6.4.1
for p in /ruta/a/userspace-patches/muffin/*.patch; do patch -p1 < "$p"; done
dch -v 6.4.1-1build1aurealnix1 "Aplicar los parches de orangepi-4a-mainline"
dpkg-buildpackage -b -uc -us
```

Compilado en la propia placa (arm64), con las opciones de compilación de Ubuntu.
