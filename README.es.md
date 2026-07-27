# Orange Pi 4A (Allwinner T527 / A523) — mainline Linux 6.18.38

🌐 [English](README.md) · **Español**

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Inv%C3%ADtame%20a%20un%20caf%C3%A9%20%E2%98%95-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/aurealnix)

Soporte **mainline** para la Orange Pi 4A (SoC Allwinner **T527**, familia A523 /
`sun55iw3`), sobre un kernel **6.18.38 vanilla**. Serie de 130 parches +
`defconfig` + device-tree de la placa. Los ports de la serie comunitaria
minimyth2 conservan la autoría original (Justin Suess, Jernej Škrabec) en las
cabeceras de los parches.

> Base del árbol de trabajo: `linux-6.18.38` vanilla. Estos parches se aplican
> encima. `git format-patch --base` incluye el hash base en cada `.patch`.

**Última imagen: v0.3** — decodificación de vídeo por hardware (VPU) + escritorio
**GNOME**. Historial en [CHANGELOG.es.md](CHANGELOG.es.md).

> **Aviso:** estos parches son el kernel que hay detrás de las **imágenes v0.3**
> (fix del reloj de la GPU, bring-up de PCIe, decodificación de vídeo por
> hardware). Las imágenes Debian actualizadas — una de escritorio **GNOME** y una
> **CLI / headless**, construidas sobre este kernel — están en la página de
> [Releases](../../releases). También puedes compilarte el kernel tú mismo con los
> parches de aquí.

## Qué funciona (confirmado en hardware)

| Bloque | Estado |
|---|---|
| **Display HDMI KMS** (DE33/DE3.5 + TCON-TV + DW-HDMI 2.0 + PHY Inno) | ✅ 720p/1080p, escalado VSU8 limpio |
| **Consola de arranque por HDMI** (fbcon vía `simple-framebuffer` sobre el FB de U-Boot) | ✅ con U-Boot BSP (con U-Boot mainline sobra; ver §4) |
| **HDMI HPD / hotplug** (detección nativa del conector) | ✅ connected al arrancar + hotplug (enchufar/desenchufar) sin forzar |
| **GPU Mali-G57** (Panfrost) | ✅ acelerada (GNOME sobre Wayland) |
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
(Epiphany / GNOME Web) en esta placa. **VP8/VP9 no** — ese motor nunca dispara su
interrupción, así que esos códecs se capan en nuestra configuración y YouTube
negocia H.264 en su lugar. Ojo: esto es la mitad de *kernel*; la pila de
decodificación de userspace no forma parte de esta serie de parches — pero las
**imágenes Debian v0.3 sí la incluyen** (libcedarc + `gst-omx`), así que ahí la
decodificación por hardware funciona de fábrica. Si solo compilas el kernel con
estos parches, el userspace lo pones tú. La **variante de 4 GB está confirmada
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
- **zram de 1 GB activado de serie; swapfile en SD opcional.** El zram (zstd)
  es un intercambio comprimido en RAM: mantiene el escritorio ágil cuando un
  navegador llena la RAM de la placa de 2 GB, no toca la SD y no cuesta casi
  nada mientras no se usa. Se desactiva con `systemctl disable --now
  zram-swap.service`. Para colchón extra, el script `add-swapfile.sh` de la
  carpeta home añade un swapfile opcional de 1 GB en la SD, usado solo como
  desbordamiento.
- **Sesión Wayland** — el escritorio es **GNOME sobre Wayland**. No se incluye
  sesión **X11**: Panfrost da su mejor aceleración bajo Wayland, y el vídeo por
  hardware en el navegador en concreto lo necesita.
- **Escritorio pensado para todos** — GNOME viene con una **barra de tareas**
  (Dash to Panel), soltura de bandeja del sistema / app-indicator y botones de
  minimizar/maximizar en las ventanas, todo activado por defecto para que el
  escritorio se comporte como la mayoría espera. Son extensiones estándar de
  GNOME — desactiva cualquiera desde la app *Extensiones* si prefieres el GNOME
  de serie.
- **Indexador de ficheros (Tracker) desactivado** — el indexador del `$HOME` de
  GNOME va apagado: consume RAM que en la placa de 2 GB hace falta. Reactívalo si
  tienes la variante de 4 GB y quieres búsquedas más rápidas dentro de ficheros.
- **Tienda de software quitada** — GNOME Software no está instalada; solo sondear
  actualizaciones le cuesta >150 MB de RAM. Las actualizaciones van por `apt`
  (ver la nota del pin del kernel más abajo).
- **Ahorro de energía / suspensión desactivados (a propósito, de momento)** — la
  suspensión automática *y* el apagado de pantalla por inactividad van los dos
  apagados por defecto. En este SoC la ruta de *resume* de mainline aún necesita
  pulido: el sistema no siempre vuelve una vez que la pantalla se ha apagado. Por
  eso la placa se mantiene despierta y la pantalla encendida, antes que arriesgar
  una sesión que no puedas despertar. Se reactivará cuando el *resume* esté
  sólido; mientras tanto puedes volver a activar la suspensión, o poner un tiempo
  de apagado de pantalla, en *Configuración → Energía*.
- **La salida de audio sigue a lo conectado** — un pequeño servicio de usuario
  (`aureal-audio-autoswitch`) mueve el sink por defecto al jack de auriculares de
  3,5 mm al enchufarlos, y de vuelta al HDMI al quitarlos. Los auriculares
  Bluetooth se respetan (el servicio solo reacciona al jack de cable, nunca pisa
  una elección BT o manual). PipeWire no lo hace solo aquí porque el códec
  analógico y el HDMI son dos tarjetas distintas. Puedes cambiarlo a mano en la
  bandeja; se desactiva con `systemctl --user disable --now aureal-audio-autoswitch`.

## Hoja de ruta

Es trabajo de tiempo libre, así que sin fechas prometidas — pero a la vista:

- **Actualización del kernel a 6.18.40.** He estado repasando los cambios stable
  desde la 6.18.38 y hay bastante que merece la pena: arreglos generales de
  seguridad y estabilidad por todo el árbol, más un puñado de **mejoras
  específicas del A523** — en particular un mejor manejo de las interrupciones de
  GPIO en este SoC. Estoy estudiando sacar próximamente una actualización de
  kernel por seguridad y mejoras para aprovecharlas.
- Siguen en pie los flecos de hardware de arriba: **NVMe con un disco real**
  (testers muy bienvenidos), **arranque desde eMMC**, y la captura de line-out /
  micrófono.

## Contenido

- `patches/` — serie `git format-patch` (0001–0130).
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

### 3. Workarounds del **U-Boot BSP** (NO enviar upstream)
Muletas para arrancar bajo el U-Boot propietario del BSP (no rellena `/memory`,
inyecta display en el FDT): stubs `/soc/{de,sunxi-drm}`, `/memory` estático,
regiones secure del firmware, `simple-framebuffer` sobre el FB de U-Boot, LED
heartbeat. Con **U-Boot mainline** sobran. Se incluyen para reproducir el
arranque tal cual, no como propuesta upstream.

## ☕ Apoya el proyecto

Esto es trabajo de habilitación de hardware (bring-up) en tiempo libre — display,
GPU, audio y red — basado en la documentación pública y el BSP de Allwinner junto
con parches de upstream y de la comunidad, con los parches propios del proyecto
validados en hardware real. Si te ha servido para tu Orange Pi 4A, puedes
invitarme a un café:

- **Ko-fi:** https://ko-fi.com/aurealnix

¿Prefieres apoyarlo de otra forma? Estoy disponible para trabajo freelance /
por contrato en Linux embebido (bring-up de placas, drivers, mainline) —
**juanmanuellopezcarrillo@gmail.com**.

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

## Nota del Autor

Espero que mi trabajo os ayude a disfrutar un poco más de vuestras placas. Porque
supongo que ya sabéis que no es mal hardware — un octa-core, aunque sea de A55,
puede dar mucho de sí, y es una pena perderse actualizaciones, parches de
seguridad y mejoras en el funcionamiento del sistema operativo solo porque el
fabricante ni se molesta. Estoy seguro de que, si el fabricante hubiera hecho un
mínimo esfuerzo y hubiera sacado al menos las longterm de vez en cuando, ya
estaríamos todos más contentos. Pero ni eso hizo. Es cierto que no lo hice todo
yo — pero puse lo que faltaba y le di la forma necesaria para poder disfrutarlo. Y
con vuestra colaboración pude mejorarlo. En fin, nada más. Gracias por vuestra
ayuda.

## Nota sobre el método

Parte de este trabajo se hizo **con ayuda de agentes de IA**. Es justo por eso por lo que se
mantiene honesto y se publica en abierto: la documentación y el BSP de Allwinner fueron, ambos, la fuente de verdad del
hardware — **no se inventó ninguna semántica de registros** — y **cada cambio se validó en
hardware real**. Los parches están aquí para revisarse: rómpelos, y manda reportes de bugs o
correcciones.
