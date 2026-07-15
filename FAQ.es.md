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
xz -dc aurealnix-opi4a-debian13-v0.1.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
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
No. En el primer arranque el sistema redimensiona el filesystem y genera las
claves SSH. Además, el driver de display carga como módulo del kernel, así que
el escritorio aparece <!-- TODO: medir --> **~XX segundos** después del logo.
Ten paciencia, no quites la corriente.

**El escritorio sale con todo enorme (escala mal).**
KDE puede elegir mal la escala en la primerísima sesión. Se arregla en un clic:
Preferencias del sistema → Pantalla → pon la Escala al 100% (mantén la
resolución nativa).

## Pantalla

**¿Qué resoluciones/monitores se sabe que funcionan?**
Probado en hardware real: <!-- TODO: lista exacta --> 1280x768, 1920x1080,
1360x768. El escalado VSU es limpio en estos modos.

La detección de hotplug del HDMI funciona de forma nativa: el conector reporta
"connected" al arrancar y sigue al cable cuando lo enchufas/desenchufas (sin
forzar nada). Si aun así tu monitor no muestra nada, prueba primero otro cable
o entrada HDMI, y luego abre un *issue* con el modelo del monitor.

**¿Decodificación de vídeo por hardware (VPU)?**
No disponible — no hay driver de VPU en mainline 6.18 para este SoC, y escribir
uno no está en mi hoja de ruta. El vídeo se reproduce por decodificación
software, que va bien para uso de escritorio normal. Si algún día mainline
(cedrus) gana soporte para esta familia de SoC, lo integraré.

**¿YouTube?**
Funciona por software. <!-- TODO: indicar lo verificado, p.ej. "720p fluido en
Chromium; 1080p depende del vídeo" -->

## Soporte de hardware

Consulta la tabla completa de estado en el README. Versión corta — funcionando:
HDMI KMS + audio + HPD/hotplug nativo, Mali-G57 por Panfrost (Plasma Wayland
acelerado), WiFi 2.4/5 GHz, Bluetooth, ethernet gigabit, los 4 puertos USB 2.0
traseros (todos USB 2.0 — la línea USB3 del SoC no está cableada en esta placa;
HID + almacenamiento, hotplug), los sensores térmicos THS (5 zonas:
cpu_l/cpu_b/gpu/npu/ddr), cpufreq/DVFS de CPU y devfreq de GPU (ambos con
throttling térmico), reboot/poweroff, AFBC scanout.

**No funciona / sin probar:**

- **Variante de 4 GB: se espera que funcione, sin confirmar en hardware real.**
  El bootloader auto-detecta el tamaño de RAM y rellena `/memory` al arrancar
  (mecanismo verificado por UART en la placa de 2 GB). Yo solo tengo la de
  2 GB — si tienes la de 4 GB, confírmalo con `free -h` y abre un *issue* en
  cualquier caso. (La placa solo viene en 2 GB y 4 GB — no hay de 1 GB.)
- Audio analógico (jack de auriculares de 3,5 mm / line-out / micros): **aún
  no — en progreso.** El códec analógico del A523 no tiene driver en mainline;
  se está portando desde el BSP del vendor ahora mismo. De momento el sonido
  sale solo por HDMI.
- Suspensión/hibernación: sin probar.
- Arranque desde eMMC / SSD NVMe: totalmente sin probar — no tengo módulo eMMC
  ni disco NVMe, así que todo se ha probado **solo desde microSD**. Si pruebas
  alguno, cuéntame (funcione o no). Conseguir el hardware para soportar esto
  bien es justo el tipo de cosa a la que van las propinas de Ko-fi.
- Cabecera GPIO / I2C / SPI: sin probar.
- NPU: el driver etnaviv la reconoce, pero está en la blacklist por defecto
  (al cargarla se anunciaba como el dispositivo de render principal y rompía la
  aceleración de la GPU para las apps normales). Cárgala bajo demanda con
  `modprobe etnaviv` si quieres experimentar. Todavía no hay stack de
  inferencia en espacio de usuario para ella.

## Rendimiento y térmica

**¿Cómo va de rápida?**
Es un octa-core Cortex-A55 con una Mali-G57 — un escritorio modesto pero
honrado. glmark2-es2 (Wayland) da ~531 con Panfrost <!-- TODO: re-medir con GPU
devfreq — 531 era al reloj fijo antiguo de 432 MHz, el pico ahora es 600 MHz -->.
El escritorio Plasma Wayland va fluido a 1080p; Chromium corre con aceleración
GPU incluido WebGL.

**¿Necesita disipador? ¿Hace throttling?**
El escalado de frecuencia de CPU (cpufreq/DVFS) funciona: OPPs desde 480 MHz
hasta 1.416 GHz en el cluster pequeño (cpu0-3) y hasta 1.8 GHz en el cluster
grande (cpu4-7), governor schedutil, con los sensores térmicos del A523 (THS) y
los cooling-maps de CPU cableados — bajo carga sostenida el chip hace throttling
solo, con elegancia, en vez de achicharrarse. La GPU también escala (Panfrost
devfreq, 150–600 MHz, simple_ondemand): reposa a 150 MHz y tiene su propio
cooling-map en la zona térmica de la GPU. En uso de escritorio normal va fresca;
el desarrollo se hizo <!-- TODO: confirmar --> sin refrigeración activa.
Temperaturas medidas: <!-- TODO: reposo XX°C / carga sostenida XX°C
(cat /sys/class/thermal/thermal_zone*/temp, stress-ng 10 min) -->

**¿Hay swap / zram?**
No — ambos van desactivados de serie (la placa viene en variantes de 2 GB y
4 GB, así que se deja a tu elección). Con Baloo apagado, la placa de 2 GB va
bien sin swap para uso de escritorio normal. Si quieres un colchón, hay un
pequeño script de regalo en la carpeta home — basta con ejecutar:

```
sudo ./add-swapfile.sh
```

Crea un `/swapfile` de 512 MB, lo activa, lo deja permanente (sobrevive a los
reinicios) y pone una *swappiness* suave para no machacar la SD. (¿Prefieres
zram o un swap más grande? Móntalo como quieras — el script es solo una
comodidad.)

## Sesión de escritorio y ajustes de la imagen

**¿Wayland o X11?**
Solo Wayland. La imagen trae una sesión Plasma **Wayland** y todo está probado
sobre ella. La **sesión X11 no está soportada** — no conseguí que funcionara de
forma fiable en este stack.

**¿Por qué está desactivado el indexado de ficheros (Baloo)? ¿Por qué Discover
no comprueba actualizaciones solo?**
Para dejar RAM libre en la placa de 2 GB. Dos servicios de fondo de Plasma van
apagados por defecto:

- **Baloo** — el indexador de ficheros de Plasma (rastrea tu `$HOME` para
  acelerar las búsquedas). Apagado; gasta RAM que esta placa prefiere usar en
  otras cosas.
- **La comprobación automática de actualizaciones de Discover** — apagada; solo
  sondear si hay actualizaciones se come **>150 MB de RAM**. Actualizar sigue
  funcionando con normalidad por `apt` o abriendo Discover a mano.

Reactiva cualquiera de los dos desde Preferencias del sistema si tienes la
variante de 4 GB y los quieres.

## Kernel y actualizaciones

**¿Por qué está fijado el kernel? ¿Puedo hacer `apt upgrade` con seguridad?**
Sí — el espacio de usuario es **Debian 13 puro** (construido con debootstrap,
repos estándar + trixie-backports para Mesa) y se actualiza con normalidad por
apt/Discover. Solo el kernel vive fuera de dpkg: un pin de apt impide que se
instale el `linux-image-*` de Debian, porque un kernel estándar de Debian no
arrancaría esta placa (le faltan los ~106 parches que necesita este port, y la
cadena de arranque espera un uImage concreto).

**¿Cómo llegan las actualizaciones del kernel?**
Con nuevas *releases* de la imagen (las notas de versión dirán qué cambió), o a
mano: sustituir `uImage` + módulos desde los artefactos compilados del repo.
Instrucciones en el README.

**¿Puedo compilar el kernel yo mismo?**
Sí — el repo tiene la serie completa de parches (~106 sobre 6.18.38 vanilla), el
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
Es gratis en cualquier caso. Si te ahorró tiempo: ☕ [ko-fi.com/aurealnix](https://ko-fi.com/aurealnix)
— propinas, o los niveles de membresía te dan acceso anticipado a las nuevas
*releases* de la imagen y un voto sobre en qué se trabaja a continuación.
