# Orange Pi 4A (Allwinner T527 / A523) — mainline Linux 6.18.36

[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-☕-FFDD00?logo=buymeacoffee&logoColor=black)](https://www.buymeacoffee.com/TU-USUARIO-BMC)

Soporte **mainline** para la Orange Pi 4A (SoC Allwinner **T527**, familia A523 /
`sun55iw3`), sobre un kernel **6.18.36 vanilla**. Serie de 66 parches +
`defconfig` + device-tree de la placa.

> Base del árbol de trabajo: `linux-6.18.36` vanilla. Estos parches se aplican
> encima. `git format-patch --base` incluye el hash base en cada `.patch`.

## Qué funciona (confirmado en hardware)

| Bloque | Estado |
|---|---|
| **Display HDMI KMS** (DE33/DE3.5 + TCON-TV + DW-HDMI 2.0 + PHY Inno) | ✅ 720p/1080p, escalado VSU8 limpio |
| **GPU Mali-G57** (Panfrost) | ✅ acelerada (Cinnamon / KDE Plasma Wayland) |
| **Audio HDMI** (i2s2 → dw-hdmi) | ✅ salida PCM por la TV |
| **Ethernet GMAC1** (PHY YT8531, RGMII) | ✅ RX/TX |
| **WiFi AP6256** (BCM43456, brcmfmac, SDIO) | ✅ scan 2.4/5 GHz, asociación |
| **reboot / poweroff** (sunxi_wdt / AXP717) | ✅ |
| **AFBC scanout** (decodificador AFBD del v350) | ✅ |

Decodificación de vídeo por hardware (VPU) **no** incluida (no hay driver en 6.18).

## Contenido

- `patches/` — serie `git format-patch` (0001–0066) + `0000-cover-letter`.
- `opi4a_blindboot_defconfig` — para `arch/arm64/configs/`.
- `sun55i-t527-orangepi-4a.dts` — device-tree de la placa.

## Aplicar

```sh
cd linux-6.18.36            # 6.18.36 vanilla
git am /ruta/share-orangepi-4a/patches/00*.patch
cp /ruta/opi4a_blindboot_defconfig arch/arm64/configs/
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- opi4a_blindboot_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs modules
```

## Reparto por destino (para revisores)

Los parches no son homogéneos. Si vas a integrar/reenviar, esta es la
clasificación por dónde tiene sentido cada grupo:

### 1. Fixes genéricos del SoC → **linux-sunxi / mainline** (no específicos de placa)
- `pinctrl: sun55i-a523: withstand de bancos PIO desde la detección hw`
- `pinctrl: sunxi: polaridad invertida de POW_MOD_SEL en A523/T527`
- `watchdog: sunxi_wdt: prioridad de restart 200 (gana a PSCI)`
- `mfd: axp20x: poweroff del AXP717 (rango OFF_CTRL no writeable)`
- **Bug**: `RESET_GPIO` rompe `mmc-pwrseq-simple` con `#gpio-cells=3` — afecta a
  **cualquier** placa sunxi con WiFi SDIO. Aquí está como `config=n`; el fix real
  va al driver, upstream.

### 2. Display KMS del A523/H616 (drm/sun4i, iommu/sun50i, clk sunxi-ng)
Serie de bring-up del pipeline HDMI. Buena parte parte del trabajo de la
comunidad **minimyth2** (H728) — marcados `(minimyth2 NNNN)` — más nuestros
fixes de A523 (IOMMU PHYS_OFFSET/PTE, RCQ del DE v35x, VSU8, wedge MBUS, AFBC).
Destino natural: **dri-devel / linux-sunxi** como serie, acreditando a minimyth2.

### 3. Integración de la placa → **Armbian** (`armbian/build`, familia sun55iw3)
- `arch/arm64/boot/dts/allwinner/sun55i-t527-orangepi-4a.dts` (ethernet, audio,
  pipeline HDMI, CMA baja).
- `opi4a_blindboot_defconfig`.

### 4. Workarounds del **U-Boot BSP** (NO enviar upstream)
Muletas para arrancar bajo el U-Boot propietario del BSP (no rellena `/memory`,
inyecta display en el FDT): stubs `/soc/{de,sunxi-drm}`, `/memory` estático,
regiones secure del firmware, `simple-framebuffer` sobre el FB de U-Boot, LED
heartbeat. Con **U-Boot mainline** sobran. Se incluyen para reproducir el
arranque tal cual, no como propuesta upstream.

## ☕ Apoya el proyecto

Esto es trabajo de ingeniería inversa en tiempo libre (bring-up de display, GPU,
audio, red…). Si te ha servido para tu Orange Pi 4A, puedes invitarme a un café:

- **Buy me a Coffee:** https://www.buymeacoffee.com/TU-USUARIO-BMC
- **Ko-fi:** https://ko-fi.com/TU-USUARIO-KOFI
- **GitHub Sponsors:** botón *Sponsor* arriba en el repo

*(Sustituye los `TU-USUARIO-*` por tus handles reales; ver `.github/FUNDING.yml`.)*

## Créditos

- Bring-up del pipeline de display: basado en la serie de **minimyth2 / Suess**
  para Allwinner H728 (portada y adaptada al A523).
- BSP Allwinner 5.15 como fuente de verdad del hardware.
