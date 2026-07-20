# Registro de cambios

🌐 [English](CHANGELOG.md) · **Español**

## 2026-07-20 — actualización de la serie de parches (todavía sin imagen nueva)

131 parches (antes 106). Todo lo de abajo lleva un día entero corriendo en la
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
