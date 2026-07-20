# Orange Pi 4A (Allwinner T527 / A523) — mainline Linux 6.18.38

🌐 [English](README.md) · **Español**

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Inv%C3%ADtame%20a%20un%20caf%C3%A9%20%E2%98%95-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/aurealnix)

Soporte **mainline** para la Orange Pi 4A (SoC Allwinner **T527**, familia A523 /
`sun55iw3`), sobre un kernel **6.18.38 vanilla**. Serie de 131 parches +
`defconfig` + device-tree de la placa. Los ports de la serie comunitaria
minimyth2 conservan la autoría original (Justin Suess, Jernej Škrabec) en las
cabeceras de los parches.

> Base del árbol de trabajo: `linux-6.18.38` vanilla. Estos parches se aplican
> encima. `git format-patch --base` incluye el hash base en cada `.patch`.

**Última imagen: v0.2** — el audio analógico / jack de auriculares de 3,5 mm ya
funciona. Historial en [CHANGELOG.es.md](CHANGELOG.es.md).

> **Aviso:** la serie de parches va bastante por delante de las imágenes
> publicadas (fix del reloj de la GPU, bring-up de PCIe, decodificación de vídeo
> por hardware…). **Se están preparando imágenes Debian actualizadas — Desktop y
> CLI — construidas sobre este kernel.** Sin fecha prometida: aparecerán en la
> página de [Releases](../../releases) cuando estén probadas. Mientras tanto
> puedes compilarte el kernel actual con los parches de aquí.

## Qué funciona (confirmado en hardware)

| Bloque | Estado |
|---|---|
| **Display HDMI KMS** (DE33/DE3.5 + TCON-TV + DW-HDMI 2.0 + PHY Inno) | ✅ 720p/1080p, escalado VSU8 limpio |
| **Consola de arranque por HDMI** (fbcon vía `simple-framebuffer` sobre el FB de U-Boot) | ✅ con U-Boot BSP (con U-Boot mainline sobra; ver §4) |
| **HDMI HPD / hotplug** (detección nativa del conector) | ✅ connected al arrancar + hotplug (enchufar/desenchufar) sin forzar |
| **GPU Mali-G57** (Panfrost) | ✅ acelerada (Cinnamon / KDE Plasma Wayland) |
| **Audio HDMI** (i2s2 → dw-hdmi) | ✅ salida PCM por la TV |
| **Audio analógico** (jack de auriculares 3,5 mm + detección de jack) | ✅ auriculares + hotplug (driver propio `sun55i-a523-codec` portado del BSP — no hay driver en mainline). Line-out / captura de micro cableados pero aún sin probar en banco |
| **Ethernet GMAC1** (PHY YT8531, RGMII) | ✅ RX/TX |
| **WiFi AP6256** (BCM43456, brcmfmac, SDIO) | ✅ scan 2.4/5 GHz, asociación |
| **reboot / poweroff** (sunxi_wdt / AXP717) | ✅ |
| **AFBC scanout** (decodificador AFBD del v350) | ✅ |
| **USB** (4 puertos-A traseros — todos USB 2.0: la única lane combo USB3/PCIe del SoC va a la ranura M.2, así que esta placa no tiene USB 3.0 en absoluto; ver FAQ) | ✅ HID (teclado/ratón) + almacenamiento masivo + hotplug; el par OTG funciona como host |
| **Sensores térmicos THS** (5 zonas: cpu_l / cpu_b / gpu / npu / ddr) | ✅ lectura en sysfs/hwmon + trip crítico 110 °C |
| **cpufreq/DVFS de CPU** (little 480 MHz–1.416 GHz, big 480 MHz–1.8 GHz) + throttling térmico a 90 °C | ✅ |
| **devfreq/DVFS de GPU** (Panfrost, 150–600 MHz) + throttling térmico | ✅ y ahora **a las frecuencias correctas** — el divisor de la GPU del A523 resultó ser de *enmascarado de ciclos* (fraccional), `frecuencia = fuente × (16−M)/16`, no un divisor lineal; medido con el contador de ciclos del Mali |
| **eMMC** (almacenamiento MMC) | ✅ detectada + lectura/escritura HS200 (confirmado por un tester); arrancar *desde* eMMC aún sin cablear |
| **PCIe / M.2** (RC DesignWare + PHY combo Innosilicon) | ✅ el controlador y el PHY hacen probe, el entrenamiento del enlace corre y el **root port enumera** — verificado aquí con la ranura **vacía**. **NVMe con un disco real sigue sin probarse** (no hay disco a mano — testers bienvenidos) |

**Decodificación de vídeo por hardware (VPU) — parcialmente funcionando, la parte
de kernel incluida.** Este árbol trae el shim `cedar-ve` con su nodo de
device-tree y los mapeos de IOMMU de los masters del motor de vídeo. Junto con el
userspace de Allwinner (libcedarc + `gstreamer1.0-omx`), **H.264 y H.265
decodifican por hardware**: YouTube se reproduce fluido en un navegador WebKit
(probado con Cog) en esta placa. **VP8/VP9 no** — ese motor nunca dispara su
interrupción, así que esos códecs se capan en nuestra configuración y YouTube
negocia H.264 en su lugar. Ojo: esto es la mitad de *kernel*; la pila de
decodificación de userspace no forma parte de esta serie de parches, y las
imágenes Debian publicadas aquí todavía no la incluyen. La **variante de 4 GB está confirmada
funcionando** (probada por **JamesCL** — ¡gracias! — que también confirmó la
eMMC; el bootloader auto-detecta el tamaño de RAM).

## Notas de la imagen (Debian 13)

Decisiones tomadas en la imagen distribuida (no son parches del kernel):

- **El primer arranque redimensiona el rootfs** para llenar la microSD y regenera
  las host keys de SSH — por eso el primer arranque tarda algo más. No cortes la
  corriente.
- **SSH activado desde el primer arranque**; usuario/contraseña `user` / `user`.
  **Cambia la contraseña de inmediato** (`passwd`) — una contraseña por defecto
  en un dispositivo en red es como acaban las placas en botnets.
- **zram y swap desactivados de serie.** La placa viene en distintos tamaños de
  RAM (2 GB / 4 GB), así que el swap/zram se deja para que lo configures a tu gusto.
- **Sesión Wayland** — el escritorio es Plasma sobre **Wayland**. La sesión
  **X11 no se soporta**: no se ha conseguido que funcione bien en este stack.
- **Baloo desactivado** — el indexador de ficheros de Plasma (rastrea el `$HOME`
  para acelerar búsquedas) va apagado: consume RAM que en la placa de 2 GB hace
  falta. Reactívalo si tienes la variante de 4 GB y lo quieres.
- **Auto-comprobación de actualizaciones de Discover desactivada** — el proceso
  que sondea si hay actualizaciones se come **>150 MB de RAM** solo para eso. Las
  actualizaciones por `apt` / Discover manual siguen funcionando con normalidad.
- **La salida de audio sigue a lo conectado** — un pequeño servicio de usuario
  (`aureal-audio-autoswitch`) mueve el sink por defecto al jack de auriculares de
  3,5 mm al enchufarlos, y de vuelta al HDMI al quitarlos. Los auriculares
  Bluetooth se respetan (el servicio solo reacciona al jack de cable, nunca pisa
  una elección BT o manual). PipeWire no lo hace solo aquí porque el códec
  analógico y el HDMI son dos tarjetas distintas. Puedes cambiarlo a mano en la
  bandeja; se desactiva con `systemctl --user disable --now aureal-audio-autoswitch`.

## Contenido

- `patches/` — serie `git format-patch` (0001–0131).
- `opi4a_blindboot_defconfig` — para `arch/arm64/configs/`.
- `sun55i-t527-orangepi-4a.dts` — device-tree de la placa.

## Aplicar

```sh
cd linux-6.18.38            # 6.18.38 vanilla
git am /ruta/share-orangepi-4a/patches/0*.patch
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
tablas OPP de CPU/GPU y cooling-maps. cpufreq (little hasta 1.416 GHz, big
hasta 1.8 GHz) + devfreq de
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

- Port a mainline, fixes A523 e integración: **Juan Manuel López Carrillo**
  (AurealNix).
- Bring-up del pipeline de display: basado en la serie de **minimyth2 / Suess**
  para Allwinner H728 (portada y adaptada al A523) — autoría original de
  **Justin Suess** y **Jernej Škrabec** conservada en los parches.
- Controlador PCIe + PHY combo Innosilicon: de la serie de **Armbian** de
  **Marvin Wewer** (aquí portada a 6.18, con un fix de 1 lane sacado del BSP y
  el cableado de device-tree de esta placa) — su autoría se conserva en los parches.
- El **divisor de la GPU por enmascarado de ciclos** se descubrió gracias a
  **Chen-Yu Tsai**, que señaló la semántica fraccional revisando un parche
  enviado a upstream.
- **BSP Allwinner 5.15** (kernel del vendor, `sun55iw3`) usado en todo momento como
  referencia y guía del hardware: las semánticas de registros, los valores del device-tree y
  la calibración de sensores **salen del BSP, no se inventaron**; donde a mainline le faltaba
  soporte, la lógica de los drivers se portó/adaptó de ahí (CCU de CPU, THS, tablas OPP/DVFS,
  VBUS de USB, poweroff, display).

## Agradecimientos — testers y comunidad

Este proyecto se hizo de verdad el día en que otras personas empezaron a ponerlo
en sus propias placas. Gracias:

- **JamesCL** (foro de Armbian) — confirmó la **variante de 4 GB** y la
  **eMMC (HS200)** con reportes detallados (dmesg, lsblk), y está ayudando a
  descifrar el arranque desde eMMC.
- **L. Jorge Soares** (foro de Armbian) — primera validación independiente de
  las dos imágenes v0.2 (CLI y KDE: Wi-Fi, HDMI, YouTube, audio), además de logs
  de consola serie para ayudar a depurar el arranque desde eMMC.
- **bickns** (foro de Armbian) — feedback temprano sobre la serie de parches y
  pruebas contra builds de Armbian.
- **Nick_Sl** (foro de Armbian) — pidió la imagen CLI/headless y se ofreció a
  probarla. Existe gracias a eso.
- **defencedog** (GitHub) — mantenedor del otro repo comunitario de esta placa,
  por su generosa oferta de colaborar y por compartir su trabajo de VPU/GStreamer.

Si pruebas una imagen o un parche y reportas — éxito *o* fallo — estás haciendo
bring-up conmigo, y tu nombre también pertenece aquí.

## Nota sobre el método

Parte de este trabajo se hizo **con ayuda de agentes de IA**. Es justo por eso por lo que se
mantiene honesto y se publica en abierto: el BSP de Allwinner fue la fuente de verdad del
hardware — **no se inventó ninguna semántica de registros** — y **cada cambio se validó en
hardware real**. Los parches están aquí para revisarse: rómpelos, y manda reportes de bugs o
correcciones.
