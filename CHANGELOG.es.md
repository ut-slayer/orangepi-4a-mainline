# Registro de cambios

🌐 [English](CHANGELOG.md) · **Español**

## v0.2 — Audio analógico (jack de auriculares de 3,5 mm)

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
