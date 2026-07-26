# FAQ — Orange Pi 4A mainline (imagen Debian 13 + parches del kernel)

🌐 [English](FAQ.md) · **Español**

Respuestas honestas, en la misma línea que el resto del proyecto: solo se
afirma como un hecho lo que se ha verificado en hardware real. Lo no probado va
marcado como no probado. Si alguna respuesta no coincide con tu experiencia,
abre un *issue*.

---

## Flasheo y primer arranque

**¿Cómo grabo la imagen?**
Escribe el `.img.xz` en una microSD (8 GB o más) con balenaEtcher, o:

```
xz -dc aurealnix-opi4a-debian13-v0.2.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
```

Verifica antes la descarga: `sha256sum -c` contra el checksum publicado.

**¿Usuario y contraseña por defecto?**
`user` / `user`. El login de root está bloqueado; usa `sudo`. **Cambia la
contraseña cuanto antes** (`passwd`) — el SSH está activado, y una contraseña
por defecto en un dispositivo conectado a la red es como las placas acaban en
botnets.

**¿El SSH está activado?**
Sí, desde el primer arranque. Las host keys de SSH se regeneran en el primer
boot, así que las de tu placa son únicas. La placa coge su IP por DHCP.

**El primer arranque tarda / se queda en el logo — ¿está muerta?**
No. Desde microSD, el escritorio GNOME tarda **alrededor de un minuto** en
aparecer desde que enchufas — las tarjetas SD tienen I/O aleatoria lenta y el
escritorio carga muchos ficheros pequeños. Irá bastante más rápido desde eMMC o
NVMe cuando estén soportados. El primerísimo arranque tarda aún más:
redimensiona el filesystem para llenar tu tarjeta y genera claves SSH nuevas —
dale un par de minutos esa primera vez y no quites la corriente.

**El escritorio sale con todo enorme (escala mal).**
GNOME puede elegir mal la escala en la primerísima sesión. Se arregla en
Configuración → Pantallas → pon la Escala al 100% (mantén la resolución nativa).

## Pantalla

**¿Qué resoluciones/monitores se sabe que funcionan?**
Probado en hardware real: 1280x720, 1360x768 (panel nativo de mi monitor de
pruebas) y 1920x1080. El escalado VSU es limpio en estos modos. Otros modos
estándar deberían funcionar vía el EDID del monitor.

La detección de hotplug del HDMI funciona de forma nativa: el conector reporta
"connected" al arrancar y sigue al cable cuando lo enchufas/desenchufas (sin
forzar nada). Si aun así tu monitor no muestra nada, prueba primero otro cable
o entrada HDMI, y luego abre un *issue* con el modelo del monitor.

**¿Decodificación de vídeo por hardware (VPU)?**
En parte — **H.264 y H.265 decodifican por hardware; VP8/VP9 todavía no.** La
mitad kernel va en esta serie de parches (el shim `cedar-ve`, su nodo del
device-tree y los mapeos IOMMU de los masters del motor de vídeo). Con el
userspace propio de Allwinner encima (libcedarc + `gstreamer1.0-omx`),
H.264/H.265 decodifican por hardware — YouTube va fluido en un navegador WebKit
(probado con Cog) en esta placa. **VP8/VP9 no he conseguido que funcionen
todavía**: ese motor nunca dispara su interrupción, así que esos códecs están
capados en nuestro montaje y YouTube negocia H.264 en su lugar. El datasheet
lista VP9 hasta 4K@60, así que sigue en la lista — sin ETA y sin promesas.
(AV1 no va por hardware en ningún SoC de Allwinner.)

Ojo: las **imágenes Debian publicadas aún no llevan la mitad userspace** — en
ellas el vídeo sigue yendo por decodificación software, que va bien para uso de
escritorio normal. Una imagen renovada incorporará el stack completo.

Un matiz importante sobre el enfoque: usa el **userspace propio de Allwinner**
(las librerías CedarX / libcedarc). En este SoC la lógica de programación del
códec vive en ese blob cerrado del fabricante, no en el kernel, así que **no**
es un driver mainline V4L2 / cedrus totalmente abierto — es el stack del
fabricante. Si lo que quieres es una vía 100% abierta, eso es otro trabajo (y
mucho mayor).

**¿YouTube?**
En las imágenes publicadas va por decodificación software: en ventana, 720p va
fluido — en mis pruebas, en torno al 1% de frames perdidos. A pantalla completa
sufre más porque el vídeo se escala (~6% perdidos), así que aguanta pero no es
perfecto. Para visionado casual va bien en ambos casos; la placa se mantiene
fresca (~55–60 °C, con la mitad de la CPU ociosa). Con el stack VPU de arriba
(esta serie de kernel + el userspace del fabricante), YouTube reproduce con
**decodificación H.264 por hardware** y va fluido — ese es el plan para la
próxima imagen.

## Soporte de hardware

Consulta la tabla completa de estado en el README. Versión corta — funcionando:
HDMI KMS + audio + HPD/hotplug nativo, el **jack de auriculares de 3,5 mm**
(códec analógico, con detección/hotplug de jack), Mali-G57 por Panfrost (GNOME
sobre Wayland acelerado), WiFi 2.4/5 GHz, Bluetooth, ethernet gigabit, los 4 puertos USB 2.0
traseros (todos USB 2.0 — ver "¿Por qué no hay USB 3.0?" más abajo;
HID + almacenamiento, hotplug), los sensores térmicos THS (5 zonas:
cpu_l/cpu_b/gpu/npu/ddr), cpufreq/DVFS de CPU y devfreq de GPU (ambos con
throttling térmico), reboot/poweroff, AFBC scanout.

**¿Por qué no hay USB 3.0? Todos los puertos USB-A son 2.0.**
Es diseño de la placa, no una limitación del software. El T527 tiene **una
única lane SerDes de alta velocidad**, gobernada por un PHY combo que puede
funcionar como USB 3.0 *o* como PCIe — una cosa o la otra, nunca ambas a la
vez. Orange Pi cableó esa lane a la **ranura M.2**, así que la 4A la gasta en
NVMe en vez de en USB 3.0. Todos los puertos USB de la placa son USB 2.0
(480 Mbps); las imágenes Android/BSP del fabricante tienen la misma
limitación, y ninguna actualización del kernel puede cambiarlo. Si necesitas
almacenamiento externo rápido en esta placa, el camino es la ranura M.2 NVMe.

**No funciona / sin probar:**

- **Variante de 4 GB: confirmada funcionando.** El bootloader auto-detecta el
  tamaño de RAM y rellena `/memory` al arrancar — verificado por UART en la
  placa de 2 GB, y confirmado en una placa de 4 GB por un tester (`free -m`
  reportó ~3,8 GB). (La placa solo viene en 2 GB y 4 GB — no hay de 1 GB.)
- Line-out analógico y captura de micrófono: cableados en el driver del códec
  pero **aún sin probar en banco** (la placa no tiene altavoz/micro integrados
  donde probarlos). La salida de **auriculares** de 3,5 mm y la detección de
  jack sí funcionan.
- **Suspensión / hibernación: desactivadas por defecto.** La ruta de *resume* de
  mainline en este SoC aún necesita trabajo — el sistema no vuelve de forma fiable
  después de apagarse la pantalla — así que la suspensión automática *y* el
  apagado de pantalla por inactividad van apagados en la imagen, y la pantalla se
  mantiene encendida. Reactiva cualquiera de los dos en *Configuración → Energía*
  si quieres probarlo.
- eMMC: el módulo se **detecta y funciona a HS200** (lectura/escritura) —
  confirmado en hardware real por un tester (una eMMC de 58 GB apareció como
  `mmcblk2` y se usó como almacenamiento — ¡gracias a **JamesCL** por probar la eMMC y la placa de 4 GB! 🙏). **Arrancar desde eMMC** es un paso
  aparte que aún no está cableado — la imagen está preparada para arrancar
  desde microSD. **SSD NVMe / M.2: sin probar con un disco real.** La serie de
  parches ya levanta el controlador PCIe y la combo PHY, y el root port
  enumera — pero eso está verificado solo con el slot **vacío**. Si un SSD
  NVMe real enumera, funciona y es estable es justo la parte que aún no puedo
  confirmar. Las imágenes v0.2 publicadas son anteriores a esto, así que ahí
  no aparece nada en `lspci` (¡gracias al tester que diagnosticó exactamente
  esto y lo reportó!). Todavía no tengo un SSD NVMe con el que probar — si
  tienes uno en el slot M.2, un informe de prueba vale oro.
- Cabecera GPIO / I2C / SPI: sin probar.
- NPU: el driver etnaviv la reconoce, pero está en la blacklist por defecto
  (al cargarla se anunciaba como el dispositivo de render principal y rompía la
  aceleración de la GPU para las apps normales). Cárgala bajo demanda con
  `modprobe etnaviv` si quieres experimentar. Todavía no hay stack de
  inferencia en espacio de usuario para ella.

## Rendimiento y térmica

**¿Cómo va de rápida?**
Es un octa-core Cortex-A55 con una Mali-G57 — un escritorio modesto pero
honrado. glmark2-es2 (Wayland) ronda los ~500 con Panfrost. El escritorio
GNOME Wayland va fluido a 1080p; el navegador corre con aceleración GPU incluido
WebGL.

**¿Necesita disipador? ¿Hace throttling?**
El escalado de frecuencia de CPU (cpufreq/DVFS) funciona: OPPs desde 480 MHz
hasta 1.416 GHz en el cluster pequeño (cpu0-3) y hasta 1.8 GHz en el cluster
grande (cpu4-7), governor schedutil, con los sensores térmicos del A523 (THS) y
los cooling-maps de CPU cableados — bajo carga sostenida el chip hace throttling
solo, con elegancia, en vez de achicharrarse. La GPU también escala (Panfrost
devfreq, 150–600 MHz, simple_ondemand): reposa a 150 MHz y tiene su propio
cooling-map en la zona térmica de la GPU. En uso de escritorio normal va fresca,
y el desarrollo se hizo sin disipador y sin ventilador.
Medido (placa desnuda, sin refrigeración): ~47 °C en reposo, ~60 °C con los 8
cores a plena carga — lejísimos del trip de throttling de 90 °C. No necesitas
disipador para uso de escritorio; ponle uno solo si piensas machacar todos los
cores durante ratos largos.

**¿Hay swap / zram?**
**zram: sí, activado de serie. Swapfile en SD: opcional.** La imagen activa un
**intercambio comprimido en RAM de 1 GB (zram, zstd)**: en la placa de 2 GB
un navegador reproduciendo vídeo puede agotar la RAM, y tirar de la microSD
(lentísima) dejaba el escritorio pillado — el zram absorbe eso en RAM,
comprimido, sin tocar la tarjeta. Su coste es casi cero mientras no se usa
(solo ocupa memoria por las páginas que de verdad se intercambian), y puedes
apagarlo cuando quieras con `sudo systemctl disable --now zram-swap.service`.

Sigue **sin haber swapfile en la SD de serie**. Si quieres colchón extra
(merece la pena en la variante de 2 GB con uso de escritorio intenso), el
script de regalo de la carpeta home crea un `/swapfile` de 1 GB, lo activa y
lo deja permanente (sobrevive a los reinicios):

```
sudo ./add-swapfile.sh
```

El zram tiene la prioridad más alta, así que el fichero de la SD solo recoge
el desbordamiento cuando el zram se llena.

## Sesión de escritorio y ajustes de la imagen

**¿Cómo decide la placa por dónde sale el sonido?**
Por defecto la salida **sigue a lo que esté conectado**: enchufa unos auriculares
en el jack de 3,5 mm y el sonido pasa a ellos; quítalos y vuelve al HDMI (la TV).
Si están los dos, ganan los auriculares del jack — enchufar es tu elección
explícita. **Los auriculares Bluetooth se respetan**: el auto-switch solo
reacciona al jack de cable, así que conectar unos BT funciona con normalidad y no
se pisa. Lo hace un pequeño servicio de usuario (`aureal-audio-autoswitch`)
porque PipeWire por sí solo no mueve el sink por defecto entre las tarjetas
analógica y HDMI (separadas) — comprobado en hardware. Siempre puedes elegir la
salida a mano en la bandeja del sistema o en *Preferencias del sistema → Audio*, y
puedes desactivar el comportamiento con
`systemctl --user disable --now aureal-audio-autoswitch`.

**¿Wayland o X11?**
Solo Wayland. La imagen trae una sesión **GNOME Wayland** y todo está probado
sobre ella. No se incluye sesión **X11** — Panfrost da su mejor aceleración bajo
Wayland, y el vídeo por hardware en el navegador lo necesita.

**¿Por qué está desactivado el indexado de ficheros (Tracker)? ¿Por qué no hay
tienda de software?**
Para dejar RAM libre en la placa de 2 GB:

- **Tracker** — el indexador de ficheros de GNOME (rastrea tu `$HOME` para
  acelerar la búsqueda dentro de ficheros). Apagado; gasta RAM que esta placa
  prefiere usar en otras cosas. Reactívalo desde una terminal si tienes la
  variante de 4 GB y lo quieres.
- **GNOME Software** — la tienda gráfica de apps no está instalada; solo sondear
  actualizaciones se come **>150 MB de RAM**. Actualizar sigue funcionando con
  normalidad por `apt` (`sudo apt update && sudo apt upgrade`).

## Kernel y actualizaciones

**¿Por qué está fijado el kernel? ¿Puedo hacer `apt upgrade` con seguridad?**
Sí — el espacio de usuario es **Debian 13 puro** (construido con debootstrap,
repos estándar + trixie-backports para Mesa) y se actualiza con normalidad por
apt. Solo el kernel vive fuera de dpkg: un pin de apt impide que se
instale el `linux-image-*` de Debian, porque un kernel estándar de Debian no
arrancaría esta placa (le faltan los 130 parches que necesita este port, y la
cadena de arranque espera un uImage concreto).

**¿Cómo llegan las actualizaciones del kernel?**
Con nuevas *releases* de la imagen (las notas de versión dirán qué cambió), o a
mano: sustituir `uImage` + módulos desde los artefactos compilados del repo.
Instrucciones en el README.

**¿Puedo compilar el kernel yo mismo?**
Sí — el repo tiene la serie completa de parches (130 sobre 6.18.38 vanilla), el
defconfig y el `.dts` de la placa. Instrucciones de compilación incluidas.

**¿Qué U-Boot usa?**
El U-Boot del vendor (BSP) por ahora, con workarounds documentados. Pasar a
U-Boot mainline está en la hoja de ruta — quita varios workarounds de golpe
(incluido el tema de la memoria de 4 GB).

## El proyecto

**¿Estos parches van a upstream?**
Ese es el objetivo. El README clasifica cada parche por destino: los fixes
genéricos de sunxi (pinctrl, watchdog, AXP717, un bug de mmc-pwrseq que afecta a
cualquier placa sunxi con WiFi SDIO) se están preparando para las listas de
correo; la serie de display parte del trabajo de minimyth2/Suess (H728) y
necesita más madurez/feedback primero.

**¿Escribiste todos estos parches desde cero?**
No — y la serie lo dice explícitamente. El stack de HDMI/display es en gran
parte un port/adaptación de la serie comunitaria **minimyth2 / Suess** de H728
al A523/T527; algunos parches son adaptaciones de código de árboles de kernel
más nuevos o del BSP del vendor; el resto (fixes de IOMMU, trabajo de
DE/RCQ/AFBC, DTS de la placa, integración) es trabajo original para esta placa.
Cuando un parche deriva del trabajo de otra persona, la autoría original se
conserva en las cabeceras del parche. Si ves una atribución que falta o está
mal, dímelo y lo corrijo de inmediato.

**Partes de esto se hicieron con ayuda de IA — ¿me puedo fiar?**
Pregunta justa. El método: el BSP 5.15 del vendor se usó como fuente de verdad
del hardware (nada de inventar semánticas de registros), y cada cambio se
validó en hardware real. Pero es justo por eso por lo que se publican los
parches: revísalos, rómpelos, dime qué está mal. Los reportes de bugs y las
correcciones son la clave.

**¿Funciona en otras placas T527/A523 (Avaota A1, Cubie A5E, ...)?**
Misma familia de SoC, así que el trabajo a nivel de SoC debería trasladarse; las
partes específicas de placa (DTS: reguladores, pinmux, PHY) hay que adaptarlas.
Sin probar en nada que no sea la Orange Pi 4A (2 GB). Si lo portas a otra placa,
me encantaría saberlo.

**¿Dónde reporto bugs?**
En los *issues* de GitHub. Incluye por favor: variante de la placa (2GB/4GB),
modelo del monitor, qué hiciste, y si es un problema de arranque, un log de la
consola serie si puedes conseguirlo (UART0, 115200) — es lo más útil que puedes
adjuntar.

**¿Cómo puedo apoyar esto?**
Es gratis en cualquier caso — todo se publica aquí, para todos. Si te ahorró
tiempo: ☕ [ko-fi.com/aurealnix](https://ko-fi.com/aurealnix) — propinas sueltas
o una membresía mensual pequeña. Los miembros reciben las notas de desarrollo
entre bambalinas; el código y las imágenes nunca van detrás de un muro.
