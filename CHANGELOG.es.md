# Registro de cambios

🌐 [English](CHANGELOG.md) · **Español**

## v0.4 — Kernel 6.18.44, WireGuard/NAT y un GNOME pulido

*Publicada el 23-08-2026.* Kernel: Linux **6.18.44** (`6.18.44-g8c30dd587626`),
desde el 6.18.38 de la v0.3 — 1073 commits de upstream, sobre todo *hardening*
en drm, red, wifi y media.

### 🔐 Nuevo: WireGuard, nftables e iptables NAT
Pedido en la [issue #4](https://github.com/ut-slayer/orangepi-4a-mainline/issues/4):
la configuración no permitía hacer NAT ni levantar una VPN. Ahora sí, todo como
módulos — no se carga nada si no lo configuras:

- **WireGuard** (`CONFIG_WIREGUARD=m`).
- **nftables** con las expresiones ct/log/limit/masq/redir/nat/fib, más
  `NFT_COMPAT`, que es lo que necesita `iptables-nft`: el backend que Debian usa
  de verdad cuando escribes `iptables`.
- **También la ruta legacy** (`NETFILTER_XTABLES_LEGACY=y`), para que los scripts
  de `iptables-legacy` sigan funcionando. Desde el kernel 6.12 ese símbolo es el
  que habilita `IP_NF_FILTER` / `IP_NF_NAT` / `IP_NF_TARGET_MASQUERADE`; sin él
  esas opciones sencillamente no existen.

Validado en la placa: una regla puesta con `iptables` aparece en `nft` como regla
nativa, y `iptables-legacy` funciona en paralelo en su propia tabla.

### ⚠️ Problema conocido: la placa puede colgarse saturando WireGuard
Tenlo en cuenta si vas a usar WireGuard de forma intensiva.

Un túnel WireGuard llevado a **~880 Mbps** con `iperf3` puede **colgar la placa**,
que entonces se reinicia. Es intermitente: ha aguantado 25 pruebas seguidas y
también ha caído en la segunda.

Lo que sabemos tras un día entero de pruebas: **no** es térmico (muere a 62 °C y
el *throttling* empieza a 90), **no** es consumo (`openssl chacha20` en 8 núcleos
llega a load 7,18 y 77 °C sin caerse), **no** es el escalado de frecuencia, y
**no** es la red por sí sola (`iperf3` sin cifrar sostiene 925 Mbps sin
problema). Con todos los detectores de cuelgue activos **y** una consola serie
grabando, el kernel muere sin imprimir una sola línea.

**Solo lo ha provocado `iperf3`.** Saturando el mismo túnel con `netcat` se
movieron **22,8 GB sin una sola caída**, y copiar un fichero real de 2 GB por
`scp` (SSH sobre WireGuard) fue bien. Eso no demuestra que la culpa sea de
iperf3 —el fallo es demasiado intermitente para concluirlo con estas muestras—
pero sí significa que **ninguna carga de uso normal lo ha reproducido**.

**En uso normal funciona**: durante las pruebas se movieron 44 GB por el túnel,
transferencias de ficheros incluidas, y a 100 y 300 Mbps va perfecto. Hay que
saturar cerca del gigabit **con un test sintético** para provocarlo, algo raro en
una VPN doméstica. La investigación está documentada en el repositorio y sigue
abierta.

### 🖥️ GNOME: por fin se comporta como un escritorio normal
- **Entra directo**, sin pedir contraseña (autologin).
- **Arranca en el escritorio**, no en la vista de Actividades.
- **ArcMenu**: menú de aplicaciones estilo Windows/Plasma, que sustituye en la
  barra a los botones de Actividades y de la cuadrícula de aplicaciones.
- **Se acabó el tour de GNOME**: ya no se abre el "Bienvenido a Debian, ¿quieres
  hacer un tour?" encima de nuestra propia bienvenida.
- **La bienvenida se abre en su propia ventana** en vez de lanzar Epiphany. La
  misma página y las mismas métricas en vivo, pero aparece en aproximadamente un
  segundo en lugar de varios, sin barra de navegador y sin diálogo de primer
  arranque. Se muestra **una sola vez**; puedes volver a abrirla cuando quieras
  desde el menú ("Bienvenida AurealNix").

### 🔧 Por dentro
- **Las imágenes salen totalmente al día**: el builder ejecuta `apt dist-upgrade`
  antes de empaquetar. Nunca lo había hecho, así que las imágenes se publicaban
  con los paquetes congelados en la fecha en que se creó la base. Esta versión
  recoge actualizaciones de seguridad de `libexpat1`, `libnss3`, `libde265`,
  `libheif`, `libaom3` y `libssh-4`, entre otras.
- **Se incluye `ping`.** Faltaba en todas las imágenes, escritorios incluidos.
- **Detectores de cuelgue activados** en el kernel (`SOFTLOCKUP`, `HARDLOCKUP`
  buddy, `DETECT_HUNG_TASK`, `WQ_WATCHDOG`, `MAGIC_SYSRQ`). Estaban todos
  apagados, así que un cuelgue no dejaba ninguna evidencia. Debian y Ubuntu los
  llevan activados por la misma razón.
- **Se compilan todos los backends de compresión de zram** (`lz4`, `lz4hc`,
  `deflate`, `842` junto a `zstd` y `lzo`), así que el algoritmo se puede cambiar
  en caliente con `/sys/block/zram0/comp_algorithm`. Por defecto sigue zstd.
- **Corregido: `/etc/skel` nunca llegaba al home del usuario.** Solo se copia al
  crear la cuenta, y la cuenta es de julio — así que lo que se cambiaba después
  (la página de bienvenida, estos changelogs) se quedaba en el skel mientras el
  home real conservaba las copias viejas. **Esto afectaba también a la v0.3.**

### 🩹 Kernel: todo lo demás que ha entrado desde la v0.3

52 parches entre el 21-07-2026 y el 21-08-2026, además del salto de 6.18.38 a
6.18.44. Casi todo es trabajo de robustez salido de auditar nuestra propia
serie: cosas que no se ven en una captura de pantalla pero que deciden si la
placa aguanta una semana encendida.

- **PCIe / NVMe (13 parches, 21-24 jul)** — el bloque más grande. El destino MSI
  mapeado por DMA se reprograma al reanudar (perdía interrupciones en silencio
  tras un ciclo de suspensión), las máscaras de INTx y eDMA se restauran al
  reanudar, la *cookie* de eDMA se limpia al liberar y se serializa el estado del
  canal, los dominios de IRQ se deshacen en orden inverso ante un error, y el
  acceso a registros se mantiene por delante del apagado de relojes en
  `remove()`.
- **Relojes / CCU (9 parches, 21-24 jul)** — el sondeo de `CLEAR_MOD` sale del
  spinlock del CCU, nunca se reescribe un bit de actualización obsoleto,
  `maskdiv` respeta los límites que le dio `determine_rate()`, y se acota el
  factor N de `pll-cpu0` para que a un consumidor con límites estrechos no se le
  entregue una frecuencia fuera de rango.
- **Decodificación de vídeo / cedar-ve (6 parches, 21-25 jul)** — **corregido un
  desbordamiento de montículo**: el `proc_info_len` de debugfs no tenía cota.
  Además el mmap desde espacio de usuario queda acotado a la ventana de
  registros de la VE, se comprueba el identificador de canal de
  `STOP_PROC_INFO`, ya no se libera un cerrojo que quien llama nunca tomó, y el
  motor se detiene si un cliente muere a mitad de trabajo en vez de quedarse
  funcionando.
- **Display / DE (7 parches, 21-24 jul)** — planos de overlay y cursor por
  hardware, más el endurecimiento que salió de auditarlos: solo el plano
  primario anuncia modificadores AFBC, los overlays se vuelven a comprobar
  cuando el primario se mueve o cambia de tamaño, y se retiró la propiedad alpha
  inerte del primario RCQ.
- **Combo PHY (4 parches, 21-24 jul)** — el notificador de energía se registra
  solo tras un probe correcto y se da de baja antes de salir (**era un
  use-after-free**), y la cadena de notificación pasa a ser bloqueante.
- **DTS y frecuencias (5 parches, 29 jul - 1 ago)** — el **OPP de 696 MHz de la
  GPU** validado para el bin del SID de esta placa, un **rango de tensión para
  los OPP del cluster pequeño** (DCDC1 alimenta también la DSU, y un voltaje fijo
  por OPP hace imposible que un segundo consumidor suba el raíl), el reloj de la
  DSU y su PLL, la codificación de aguante de tensión de los pines del A523, y
  PJ10 fuera del grupo de pines rgmii1.
- **Audio (1 parche, 22 jul)** — se cancela el trabajo de detección del jack si
  falla el probe.
- **Infrarrojos** — nodos del receptor y los decodificadores de protocolos
  comunes. Ojo: esta placa **no lleva receptor IR montado**; esto es para quien
  conecte uno al header.

### 📊 Cifras
- glmark2: **847** a 800x600 (v0.3: 790), GPU a 696 MHz
- Arranque: 16,5 s (CLI), 43 s (GNOME)
- Imágenes: CLI 197 MB · GNOME 710 MB (comprimidas)

### 🎉 Y para los fans de Plasma: ¡Kubuntu 26.04!

Lo mejor, para el final. En esta versión añadimos una **imagen nueva para todos
los que os gusta KDE Plasma: Kubuntu 26.04 (Resolute Raccoon)** — y en esta placa
va **¡fantástica!**

- Plasma **6.6.6** sobre **Wayland** puro (KWin, cero X11), y vuela: glmark2
  **880** a 800x600, incluso un pelín por encima de GNOME, con la GPU a 696 MHz.
  Arranca al escritorio en **26 segundos**.
- **Autologin** directo a Plasma, su **propio logo de arranque**, y la bienvenida
  en una **ventana Qt nativa** (aprovechando el QtWebEngine que Plasma ya trae,
  sin un segundo motor web engordando la imagen).
- El **Info Center** de KDE hasta lee el Mali-G57 y la Orange Pi 4A directamente
  del device-tree.

Es la primera imagen del proyecto sobre base Ubuntu. Un matiz: **Plasma es más
goloso con la RAM** que GNOME (~880 MB más swap con solo un terminal abierto),
así que en 2 GB se apoya en el zram — genial para uso ligero, más justo con un
navegador y varias apps a la vez. ¿Quieres el escritorio más ligero? GNOME. ¿Te
encanta Plasma? Esta es la tuya.

## v0.3 — Decodificación de vídeo por hardware + escritorio GNOME

Esta versión incorpora el trabajo de kernel del lote de parches del 2026-07-20
(que aún no tenía imagen) más el pulido de esta semana, y cambia el escritorio
de KDE Plasma a **GNOME**. Kernel: Linux **6.18.38**.

### 🎬 Novedad: decodificación de vídeo por hardware (VPU)
- El **motor de vídeo cedar ya decodifica por hardware**: **H.264** (validado en
  la placa — un clip de 10 s decodificado en 0,65 s), además de **HEVC / MPEG /
  MJPEG** por el mismo stack de GStreamer (`gst-omx` + `libcedarc`, portado del
  BSP del fabricante). **YouTube se reproduce con decodificación por hardware en
  Epiphany** (WebKit + GStreamer). La v0.2 solo llevaba decodificación por
  software — este es el gran cambio.
- **VP8/VP9 van capados** (ese motor nunca lanza su interrupción), así que
  YouTube negocia **H.264** — fluido, en vez de un VP9 por software que derrite
  la CPU.
- Se incluyen los permisos udev de `/dev/dma_heap` que el decodificador necesita.
- **Nota — navegador y vídeo por hardware:** la imagen lleva **WebKit 2.52.5**
  (la actualización de seguridad de Debian). Una build anterior fijaba la 2.52.3
  porque la 2.52.5 había regresado la ruta de vídeo DMA-BUF sobre Panfrost/Mali-G57
  (el proceso web cascaba con un "Oops"); reprobada en el stack actual (kernel +
  Wayland) reproduce vídeo por hardware sin problema —H.264/H.265, fullscreen
  incluido—, así que se quitó el pin y te llevas los parches de seguridad.

### 🖥️ Novedad: escritorio GNOME (sustituye a KDE Plasma)
- La imagen de escritorio es ahora **Debian 13 + GNOME sobre Wayland** — más
  ligera que Plasma completo, y Wayland es donde la Mali-G57 (Panfrost) da su
  mejor experiencia acelerada.
- La imagen **CLI / headless** continúa (SSH + NetworkManager, audio analógico
  funcionando sin escritorio) — ahora también con el stack de decodificación.

### ⚙️ Kernel y hardware (el lote del 2026-07-20, ya en imagen)
- **★ Frecuencias de GPU corregidas.** El reloj de la GPU del A523 es un divisor
  de *enmascarado de ciclos* (`rate = fuente × (16−M)/16`), no lineal. El modelo
  antiguo se pasaba en silencio: el punto de "150 MHz" corría en realidad a
  **487 MHz**, y el recorte térmico a "400 MHz" *subía* el reloj a **750 MHz**.
  Re-medido con el contador de ciclos de la Mali — ahora **149 / 199 / 300 / 399
  / 597 MHz**, exactas y desde los padres correctos. Crédito: **Chen-Yu Tsai**
  detectó el divisor fraccional.
- **★ Root port de PCIe / M.2.** El controlador DesignWare y el PHY combo
  USB3/PCIe de Innosilicon ya hacen probe, y el root port enumera (verificado con
  el slot **vacío**; NVMe con disco real aún sin probar). Los drivers base (combo
  PHY + PCIe RC/DMA) y el device-tree inicial vienen de la serie de Armbian de
  **Marvin Wewer** (autoría preservada). Sobre eso, este proyecto **arregló un
  use-after-free en el driver del combo PHY**: el power notifier se encadenaba en
  la lista del subsistema *antes* de comprobar el retorno del registro del
  provider, así que un fallo de probe dejaba un `notifier_block` liberado en la
  cadena — el siguiente evento de power dereferenciaba memoria liberada. Se
  registra solo tras publicar el provider (`Fixes:` el commit original del
  driver). Más el fix de 1-lane en el device-tree (del BSP) y la config del kernel.
- **Display: fix del "wedge" de scanout.** Todo el armado de planos se acota al
  intervalo de blanking y el temporizador se re-ancla a la línea de scan real del
  TCON — arregla un fotograma que podía quedarse pegado tras transiciones de
  scanout directo.
- **★ defconfig arreglado.** El `defconfig` publicado se había quedado sin
  opciones (audio analógico, PCIe, VPU, joydev) — las ediciones de config tras el
  13-jul iban al `.config` local en vez de al defconfig versionado. Regenerado
  desde la config validada en hardware (verificado que la reproduce exacta).
- **Mandos.** `INPUT_JOYDEV` + `INPUT_UINPUT` activados — los sticks analógicos
  estaban muertos en software que abre `/dev/input/jsN` primero.

### 🧹 Pulido de la imagen
- **Imágenes más ligeras y limpias.** Índices de paquetes de apt eliminados
  (~90 MB de caché desechable que se regenera en el primer `apt update`) y
  **`mesa-vulkan-drivers` fuera** (~144 MB instalados — la Mali-G57 **no tiene
  Vulkan** bajo Panfrost).
- **Página de bienvenida nueva** (en la imagen de escritorio): un panel en vivo
  con MHz/uso reales por núcleo, frecuencia de GPU, temperaturas y RAM/disco;
  identidad leída de `/etc/os-release` en tiempo de ejecución; consejos de vídeo
  por hardware.
- **zram de 1 GB activado de serie** — intercambio comprimido en RAM de 1 GB
  (zstd, con más prioridad que cualquier swap de SD): mantiene el escritorio ágil
  cuando un navegador llena la RAM de la placa de 2 GB, sin tocar la tarjeta (sin
  desgaste). Se desactiva con `systemctl disable --now zram-swap.service`. Para
  aún más colchón, el script de regalo `add-swapfile.sh` añade un swapfile de
  1 GB en la SD, usado solo como desbordamiento.

### 📌 Paquetes fijados (y por qué)

Todo se actualiza con normalidad por apt **salvo dos cosas que la imagen deja
fijadas a propósito**:

- **Kernels de Debian: bloqueados** (`/etc/apt/preferences.d/no-debian-kernel.pref`,
  prioridad -1 sobre `linux-image-*` / `linux-headers-*`). La placa arranca el
  `uImage` propio de este port (6.18.38 vanilla + la serie de parches); un kernel
  estándar de Debian no puede arrancarla, y un `apt upgrade` que instalase uno
  pisaría `/boot` y dejaría la placa sin arrancar. Las actualizaciones de kernel
  llegan con las releases de la imagen.
- **Mesa: anclada a trixie-backports** (`mesa-backports.pref`, prioridad 600
  sobre `src:mesa`). Debian 13 trae Mesa 25.0.x; backports tiene un soporte de
  Panfrost/Mali-G57 mucho mejor. El pin cubre el conjunto Mesa entero para que
  `libgbm1` / `libegl-mesa0` / `libgl1-mesa-dri` salgan siempre de la misma
  rama — sin él, una actualización mezclada puede acabar con apt "resolviendo"
  el conflicto borrando el escritorio.
**WebKitGTK ya no está retenida.** Una build anterior la fijaba a 2.52.3 porque
la actualización de seguridad 2.52.5 de Debian había regresado la ruta de vídeo
por hardware sobre Panfrost (el proceso web cascaba con un "Oops"). Reprobada
sobre el stack actual (este kernel + Wayland) reproduce vídeo por hardware sin
problema, así que se quitó la retención: la imagen ahora trae la **2.52.5** y te
llevas los arreglos de seguridad. Ver la nota "navegador y vídeo por hardware"
más arriba.

### Sigue desde la v0.2
El driver del códec analógico hecho desde cero (`sun55i-a523-codec`) con
**detección de jack / hotplug**, audio HDMI, display HDMI KMS con HPD nativo,
Ethernet gigabit, WiFi (AP6256) + Bluetooth, los puertos USB 2.0 traseros,
DVFS de CPU/GPU con recorte térmico, y el resto del soporte de hardware.

### Upstream
El fix de orden del `ccu_div` genérico recibió un **Reviewed-by de Chen-Yu Tsai**
en las listas linux-clk / linux-sunxi; la serie del reloj de GPU fue detrás. Ambos
son públicos en los archivos de las listas de correo del kernel.

## 2026-07-20 — actualización de la serie de parches (todavía sin imagen nueva)

130 parches (antes 106). Todo lo de abajo lleva un día entero corriendo en la
placa sin regresiones. **Aún no se publica imagen nueva** — esto son parches de
kernel; la próxima release de imagen los incorporará.

- **★ El reloj de la GPU: las frecuencias estaban mal, y ahora están bien.** El
  reloj de la GPU del A523 **no** es un divisor lineal: es de *enmascarado de
  ciclos*, `frecuencia = fuente × (16 − M) / 16` (manual del T527, GPU_CLK_REG).
  Con el modelo lineal, los puntos de operación "150/200/300/400/600 MHz" corrían
  en realidad a **487/648/560/750/599 MHz** — todos los puntos por debajo del
  máximo se overclockeaban en silencio, y el throttling térmico a "400 MHz" en
  realidad *subía* el reloj a 750 MHz. Medido en hardware con el contador de
  ciclos del Mali, antes y después. El fix añade un tipo de reloj `maskdiv`,
  cambia el reloj de la GPU a él, y quita el padre `pll-periph0-800M` (el BSP del
  fabricante también lo había quitado, alegando *job faults* de la GPU —
  coherente con este exceso de frecuencia). Re-medido: **149/199/300/399/597
  MHz**, exactas y desde los padres previstos. Crédito: **Chen-Yu Tsai** detectó
  lo del divisor fraccional revisando un parche enviado a upstream.
- **★ Bring-up de PCIe / M.2.** El controlador (RC DesignWare) y el PHY combo
  USB3/PCIe de Innosilicon hacen probe, y el root port enumera. Verificado aquí
  con la ranura **vacía**; NVMe con un disco real sigue sin probarse. La parte de
  kernel viene de la serie de Armbian de **Marvin Wewer** (autoría preservada),
  más un fix de 1 lane sacado del BSP y el cableado de device-tree de esta placa.
- **Display: fix del "wedge" de scanout** — el armado de todos los planos se
  restringe ahora al intervalo de blanking y el temporizador se re-ancla a la
  línea real del TCON, lo que ataca un fotograma que podía quedarse clavado tras
  transiciones de scanout directo.
- **★ VPU: la decodificación por hardware de H.264/H.265 funciona.** Esta entrega
  añade el shim `cedar-ve`, su nodo de device-tree y los mapeos de IOMMU de los
  masters del motor de vídeo. Con el userspace de Allwinner encima (libcedarc +
  `gstreamer1.0-omx`), **YouTube se reproduce fluido en un navegador WebKit (Cog)
  con decodificación por hardware** en esta placa. **VP8/VP9 siguen rotos** — ese
  motor nunca dispara su interrupción — así que esos códecs se capan y YouTube
  negocia H.264. La mitad de userspace no forma parte de esta serie de parches (ni
  está aún en las imágenes Debian publicadas); la mitad de kernel sí está aquí.
- **★ Arreglado: al `defconfig` publicado le faltaban opciones.** Los commits de
  configuración posteriores al 13-jul tocaron el `.config` local de compilación
  en vez del defconfig versionado, que es el que va en este bundle. Quien
  recompilara con él obtenía un kernel **sin audio analógico, sin PCIe, sin VPU
  y sin joydev**. El defconfig se ha regenerado desde la configuración validada
  en hardware (verificado que la reproduce exactamente). Si compilaste desde este
  repo antes de hoy, vuelve a compilar con el defconfig nuevo.
- **Mandos**: activados `INPUT_JOYDEV` e `INPUT_UINPUT` (los sticks analógicos no
  respondían en software que abre primero `/dev/input/jsN`).
- **Upstream**: el fix genérico de orden en `ccu_div` de este árbol se envió a
  las listas de clk / linux-sunxi y **recibió un `Reviewed-by` de Chen-Yu Tsai**;
  la serie del reloj de la GPU fue detrás. Ambas son públicas en los archivos de
  las listas del kernel.

## v0.2 — Audio analógico (jack de auriculares de 3,5 mm) + imagen CLI/headless

**Ahora hay dos imágenes:** la **Desktop** completa (KDE Plasma) y una nueva
**CLI / headless** (`...-cli-...`, ~146 MB, ~740 MB instalada, arranca en segundos)
— para uso servidor/headless o como base ligera, con SSH + NetworkManager (`nmtui`),
NTP activado de fábrica (la placa no tiene pila de RTC), consola de texto por HDMI, y
—exclusivo de esta placa— **audio analógico funcionando por PipeWire en headless**
(el jack va sin sesión de escritorio).

**Novedades**

- **El audio analógico ya funciona** — el **jack de auriculares** de 3,5 mm saca
  sonido, con **detección de jack / hotplug**. El códec analógico del Allwinner
  A523 **no tiene driver en mainline**, así que se incluye uno propio
  (`sun55i-a523-codec`) portado fielmente del BSP del fabricante. Validado en
  hardware real (auriculares + enchufar/desenchufar). El line-out y la captura de
  micrófono están cableados en el driver pero aún sin probar en banco (la placa no
  tiene altavoz/micro integrados).
- **La salida de audio sigue a lo conectado** — un pequeño servicio de usuario
  (`aureal-audio-autoswitch`) mueve la salida por defecto al jack de auriculares
  al enchufarlos, y de vuelta al HDMI al quitarlos. Si están los dos, gana el jack
  (enchufar es tu elección explícita). **Los auriculares Bluetooth se respetan**:
  el servicio solo reacciona al jack de cable y nunca pisa una elección Bluetooth
  o manual. PipeWire no lo hace solo aquí porque el códec analógico y el HDMI son
  dos tarjetas distintas (comprobado en hardware). Puedes cambiarlo en la bandeja,
  o desactivarlo con `systemctl --user disable --now aureal-audio-autoswitch`.

**Kernel:** `6.18.38-g59eb61929e89` (añade el driver del códec sobre el bring-up
de la v0.1; una auditoría de código del driver nuevo arregló un use-after-free en
el desmontaje del jack antes de publicar).

Todo lo del bring-up anterior sigue igual: display HDMI KMS + audio, HPD/hotplug
nativo, Mali-G57 (Panfrost), WiFi/Bluetooth, ethernet gigabit, USB, sensores
térmicos, cpufreq/DVFS de CPU + devfreq de GPU, AFBC scanout.

## v0.1 — Imagen inicial

Primera imagen Debian 13 (Plasma Wayland) para la Orange Pi 4A sobre kernel
mainline 6.18.38: HDMI KMS, Mali-G57 por Panfrost, WiFi/BT, ethernet, USB,
térmica + DVFS de CPU/GPU, audio HDMI.
