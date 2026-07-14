# Orange Pi 4A (Allwinner T527 / A523) — mainline Linux 6.18.38

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Inv%C3%ADtame%20a%20un%20caf%C3%A9%20%E2%98%95-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/aurealnix)

Soporte **mainline** para la Orange Pi 4A (SoC Allwinner **T527**, familia A523 /
`sun55iw3`), sobre un kernel **6.18.38 vanilla**. Serie de 106 parches +
`defconfig` + device-tree de la placa. Los ports de la serie comunitaria
minimyth2 conservan la autoría original (Justin Suess, Jernej Škrabec) en las
cabeceras de los parches.

> Base del árbol de trabajo: `linux-6.18.38` vanilla. Estos parches se aplican
> encima. `git format-patch --base` incluye el hash base en cada `.patch`.

## Qué funciona (confirmado en hardware)

| Bloque | Estado |
|---|---|
| **Display HDMI KMS** (DE33/DE3.5 + TCON-TV + DW-HDMI 2.0 + PHY Inno) | ✅ 720p/1080p, escalado VSU8 limpio |
| **HDMI HPD / hotplug** (detección nativa del conector) | ✅ connected al arrancar + hotplug (enchufar/desenchufar) sin forzar |
| **GPU Mali-G57** (Panfrost) | ✅ acelerada (Cinnamon / KDE Plasma Wayland) |
| **Audio HDMI** (i2s2 → dw-hdmi) | ✅ salida PCM por la TV |
| **Ethernet GMAC1** (PHY YT8531, RGMII) | ✅ RX/TX |
| **WiFi AP6256** (BCM43456, brcmfmac, SDIO) | ✅ scan 2.4/5 GHz, asociación |
| **reboot / poweroff** (sunxi_wdt / AXP717) | ✅ |
| **AFBC scanout** (decodificador AFBD del v350) | ✅ |
| **USB 2.0** (los 4 puertos traseros) | ✅ HID + almacenamiento, hotplug |
| **cpufreq/DVFS de CPU** (480 MHz–1.8 GHz, ambos clusters) + throttling térmico (THS) | ✅ |
| **devfreq/DVFS de GPU** (Panfrost, 150–600 MHz) + throttling térmico | ✅ |

Decodificación de vídeo por hardware (VPU) **no** incluida (no hay driver en 6.18).

## Contenido

- `patches/` — serie `git format-patch` (0001–0106).
- `opi4a_blindboot_defconfig` — para `arch/arm64/configs/`.
- `sun55i-t527-orangepi-4a.dts` — device-tree de la placa.

## Aplicar

```sh
cd linux-6.18.38            # 6.18.36 vanilla
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

### 2b. Energía y térmica del SoC → **linux-sunxi / mainline**
CCU de CPU del A523 (clk sunxi-ng, portado del BSP `ccu-sun55iw3-displl.c`),
THS del A523 (thermal sun8i, variante propia con calibración de 4 sensores),
tablas OPP de CPU/GPU y cooling-maps. cpufreq 480 MHz–1.8 GHz + devfreq de
GPU 150–600 MHz, ambos como cooling devices.

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

- **Ko-fi:** https://ko-fi.com/aurealnix
- **GitHub Sponsors:** botón *Sponsor* arriba en el repo (cuando esté activo)

## Créditos

- Bring-up del pipeline de display: basado en la serie de **minimyth2 / Suess**
  para Allwinner H728 (portada y adaptada al A523).
- BSP Allwinner 5.15 como fuente de verdad del hardware.
