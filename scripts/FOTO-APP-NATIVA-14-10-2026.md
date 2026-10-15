# Foto de la app nativa de Ojo Guard (14/10/2026)

Regla de este trabajo: **el funcionamiento no cambia**. Solo cambia el "maquillaje": dónde está cada cosa y cómo se ve. Esta foto
lista todo lo que la app tiene hoy, con los nombres exactos de cada botón, campo e interruptor, para tildarlo después de cada
paso del reordenamiento y no perder nada.

Sacada del código de trabajo (versión 0.9.1, build 160 de Android; el iPhone tiene una build anterior sin "Dr. Ojo Guard"). El
script `foto-app.ps1` hace una copia comprimida de la carpeta de la app y confirma que el código de Lu es igual al que se
describe acá.

## 1. Cómo se navega hoy

`App.tsx` tiene cinco estados de pantalla: `loading` → `access` → `setup` → `guard` ⇄ `settings`.

| Pantalla | Cuándo aparece | Cómo se sale |
|---|---|---|
| Carga | al arrancar | automático |
| Acceso ("Elegí cómo ingresar") | teléfono sin vincular | vincula y pasa a `setup` |
| Preparar este teléfono (`setup`) | primer arranque | "Activar Ojo Guard" → `guard` |
| **Guardia** (pantalla de reposo) | uso normal | tocar → teclado de clave |
| Configuración (`settings`) | clave de administrador correcta en el teclado | "Guardar cambios" o "Volver sin guardar" → `guard` |

Las pantallas `setup` y `settings` son el mismo componente (`SetupScreen`): en el primer arranque se llama "Preparar este
teléfono" y el botón final dice "Activar Ojo Guard".

## 2. Pantalla de guardia (la principal hoy)

- Fondo: imagen del ojo, o la que Lu eligió en Apariencia, con velo oscuro. Pantalla negra de reposo encima.
- Reloj grande con la hora.
- Tocar en cualquier parte abre el **teclado de clave**: "Ingresá el código", 6 puntos, teclas 1 a 9 y 0, "Cancelar", "Borrar".
  - Clave de administrador → abre Configuración (nunca saca foto).
  - Intento de entrada con foto, ubicación y audio opcional: el primer intento se registra solo si usa la clave señuelo; desde el
    segundo, se registra cualquier clave incorrecta.
- Cartel "MODO PERDIDO ACTIVO" con el mensaje, el contacto y la recompensa (si está activado el Modo perdido).
- Etiqueta de estado: "Verificando…", "Evidencia enviada", "Evidencia guardada para enviar", "Código incorrecto".
- Texto chico "VERSIÓN · build" (solo con el teclado o el Modo perdido).
- Botón flotante "?" (ayuda).

## 3. Pantalla de acceso ("Elegí cómo ingresar")

Marca "OJO GUARD®", versión, título y una línea: el acceso no usa contraseña, llega un código de seis números por correo.
1. **Tipo de acceso** (dos opciones a elegir): "Empresa" y "Prueba de 3 días".
2. **Correo de ingreso** (campo) y botón "Enviar código".
3. Con el código pedido: campo "Código de seis números", "El código vence 15 minutos después de su envío", botón "Abrir Ojo Guard",
   enlaces "Reenviar código" y "Cambiar correo".
- Mensaje de estado y botón flotante "?".

## 4. Ayuda ("?") — diálogo "Ayuda y soporte"

Texto de ayuda según la pantalla, aviso de no compartir la clave, caja "¿Necesitás soporte humano?" (todavía sin canal),
**interruptor "Fondo claro"** (cambia el tema claro/oscuro de la app; la guardia sigue oscura), botón "Entendido" y la versión/build.
Atención: **el cambio de tema vive escondido acá.**

## 5. Configuración: bloques en el orden actual

Cada ítem lleva su texto exacto. (A) = solo Android, (i) = solo iPhone.

0. **Encabezado**: botón ✕ (volver sin guardar), "OJO GUARD®", "VERSIÓN 0.9.1", título "Configuración" (en el primer arranque:
   "Preparar este teléfono"), texto de presentación.
1. **Cartel "MODO ADMINISTRADOR"**: "Esta pantalla solo se abre con la clave correcta. La clave de administrador nunca activa la
   cámara ni registra una evidencia."
2. **Diagnóstico de captura** (solo si hay): texto del diagnóstico y botón "Abrir configuración de Android".
3. **Estado del dispositivo** (tarjeta): "En línea / Sin internet / Comprobando", nombre de fábrica del teléfono, y seis datos:
   Modo (Preventivo/Normal), Cercanía (Activa · N m / Desactivada), Pantalla (OLED/Estándar), Ubicación (Habilitada/Desactivada),
   Batería (%), "Última conexión: fecha".
4. **Guía: evitá que Android bloquee Ojo Guard** (A; abierta): intro y cinco pasos, cada uno con su estado y su botón:
   1. Avisos de pantalla completa — "Activar los avisos de pantalla completa".
   2. Apps sin usar — "Abrir Ajustes de Ojo Guard" (más un interruptor de "ya lo hice").
   3. Batería sin restricciones — "Abrir el ajuste de batería".
   4. Bloqueo de pantalla del teléfono — "Poner un código de bloqueo".
   5. Mostrar sobre otras apps (opcional) — "Permitir mostrar sobre otras apps".
   Y un cierre: "Los cuatro en orden…".
5. **Protegé tu iPhone contra robo** (i; abierta en el primer arranque): dos ajustes del iPhone, en texto (Protección de dispositivo
   robado, y apagar Centro de control/lo que se usa con el iPhone bloqueado).
6. **Familia y amigos** (no en el primer arranque; ver sección 6).
7. **Datos del teléfono**: campos "Nombre de este teléfono" y "Correo privado de alertas".
8. **Modo perdido — mensaje de recuperación**: cartel "AVISO DE RECUPERACIÓN OPCIONAL" (solo estos datos se muestran a quien lo
   encuentre) y tres campos: "Mensaje para quien encuentre el teléfono", "Contacto público de recuperación", "Recompensa opcional".
9. **Apariencia** ("Fondo de pantalla y teclado"): botones "Elegir imagen" (o "Abriendo galería…") y "Fondo original".
10. **Claves de acceso**: campos "Clave de administrador — 6 números" y "Clave señuelo — 6 números".
11. **Evidencia y ubicación**: interruptores "Adjuntar ubicación" y "Audio ambiental breve (opcional)".
12. **Modo cercanía**: interruptor "Modo cercanía" y, si está activo, campo "Radio seguro de cercanía — metros".
13. **Preferencias generales**: interruptores "Modo preventivo" y "Pantalla OLED".
14. **Preparar autonomía para Modo perdido** (en iPhone se ve también, solo con los botones comunes; lo de Android va dentro de un bloque solo Android; "Batería, alarmas exactas, avisos de pantalla completa y diagnóstico"): botones
    "Permitir actividad en segundo plano sin restricciones", "Abrir ahorro de batería", "Permitir alarmas exactas", "Permitir avisos
    de pantalla completa", "Revisar permisos", "Probar aviso en este teléfono"; y **registros técnicos**: rastro del aviso de pantalla
    completa, "Historial de segundo plano — versión … build …" (líneas por fecha) y "Diagnóstico nativo de cámara" (líneas crudas).
15. **Detección de intentos de desbloqueo (opcional)** (A; "Saca una foto sola si alguien insiste en entrar sin lograrlo"): botones
    "Activar detección de PIN fallido", "Activar detección de pantalla repetida", "Probar lectura de pantalla ahora", más textos de
    límites (Android no informa Face ID/huella fallidos).
16. **Modo personalizado (Android)** (A): texto de cómo armar un "Modo" de Android que deja pasar solo a Ojo Guard, y botón
    "Abrir Modos de Android".
17. **Personas, dispositivos y artículos** (hoy se ve como un bloque suelto, no como desplegable): pestañas "Personas /
    Dispositivos / Artículos"; lista de lo agregado (nombre, tipo, estado, "Cercanía Bluetooth … · Batería …", "Última
    actualización"); en auriculares, botones "Sonar izquierdo" y "Sonar derecho"; alta con campos "Nombre" (ej. "Teléfono de
    Luciano") y "Tipo" (con opciones: Persona; Teléfono, Computadora, Reloj, Auriculares; Vehículo, Mochila, Otro objeto), casilla de
    autorización y botón "Agregar con autorización"; "Buscar accesorio Bluetooth" (8 segundos) con "Es mío · agregar" / "No es mío
    · ocultar" y "Mostrar nuevamente N accesorios descartados".
18. **Protección sin internet** ("Al día" o "N pendientes"; abierta si hay pendientes): texto y botón "Intentar enviar ahora" /
    "Enviando…", mensaje del resultado.
19. **Intentos de entrada** ("Ninguno" o "N registrados"): botón "Borrar historial"; lista horizontal de fotos con fecha y "Con
    ubicación GPS/Sin ubicación"; texto de la regla de intentos. Tocar una foto abre el **detalle de evidencia** (sección 7).
20. **Ojo Guard MS · Teléfono principal** (abierta si no está vinculado; estado "Sin vincular / Buscando… / Orden ejecutada / Sin
    conexión / Conectado"): identidad estable (últimos 8 caracteres), botones "Enviar código de vinculación", "Vincular teléfono",
    "Sincronizar órdenes ahora", "Abrir Ojo Guard MS →", "Crear acceso seguro a MS" (passkey).
21. **Botones finales**: "Guardar cambios" (o "Activar Ojo Guard" en el primer arranque) y "Volver sin guardar".

## 6. "Familia y amigos" (archivo aparte: FamilySection.tsx)

Subtítulo "N personas comparten su ubicación con vos". Adentro, de arriba abajo:
- Sin vincular: "Vinculá este teléfono con Ojo Guard MS (más abajo) para usar Familia."
- Mapa de Apple (solo iPhone) con las personas.
- Lista de personas: inicial, nombre, rol (ADULTO/MENOR/AMIGO), "hace X · dirección" o "Ubicación pausada", "Mapa ›" (Android abre Google Maps).
- Aviso de ubicación "Siempre" (iPhone): botón "Permitir siempre".
- Texto "Todavía no hay nadie…" si está vacío.
- **Unirme con un código**: campo (ej. ABC234) y botón "Unirme".
- Pausa de ubicación (adultos y amigos): "Pausar 1 hora" y "Reanudar".
- "Salir de la familia de <nombre>" (una por familia).
- **Dr. Ojo Guard** (desplegable; título con el porcentaje): botón "Hacer chequeo" / "Volver a hacer el chequeo"; detalle de los
  ítems (Conexión con Ojo Guard MS, Avisos, Ubicación «Siempre», Gesto de volumen (A), Sirena del SOS (A), Auriculares Bluetooth
  (A), Batería sin restricciones (A), Atajo del SOS (i)); botón de arreglo por ítem; notas; "Probar la sirena" (A).
- **Pedir ayuda (SOS)**: botón rojo (mantener 3 segundos); en curso: "SOS enviado… Estoy bien".
- **Pedir ayuda sin abrir la app** (desplegable). Android: "Activar el gesto de volumen", "El interruptor está gris", texto de
  "configuración restringida", "Que la sirena suene con No interrumpir". iPhone: pasos del atajo, enlace `ojoguard://sos?k=…`
  y "Copiar o compartir el enlace".
- Botón "Actualizar".

## 7. Detalle de evidencia (ventana al tocar una foto)

Pestañas "Delantera" / "Trasera", foto, fecha y datos, ubicación con mapa ("Mostrar mapa en Ojo Guard" / "Ocultar mapa", "Mapa" /
"Satelital"), audio ("Audio de evidencia", "Reproducir"/"Pausar") y "Buscar coincidencia" (búsqueda de caras en la galería).

## 8. Lo que corre sin pantalla (no se ve, pero hay que no romper)

- **Canales de aviso (Android)**: `ojo-alertas`, `ojo-familia-aviso`, `ojo-sos` (sirena del SOS) y `ojo-busqueda-v2` ("Hacer sonar").
- **Tareas de fondo**: `ojo-guard-background-fetch-v1` (cada ~15 min, también vigila el gesto del SOS), `ojo-guard-remote-command-v1`
  (órdenes remotas), `ojo-guard-live-location-v1` (ubicación en vivo), `ojo-guard-family-location-v1` (ubicación de familia, iPhone),
  geocercos de familia (iPhone), tarea del SOS `OjoGuardSosTask` y alarmas exactas `OjoGuardExactAlarmTask`.
- **Módulos nativos de Android** (`modules/`): audio-route, exact-alarm, face-filter, full-screen-alert (pantalla del Modo perdido),
  native-capture (foto silenciosa), screen-pinning, sos-trigger (gesto de volumen, SOS), theft-detection (PIN fallido, pantalla repetida).
- **Permisos Android**: cámara, ubicación (también en segundo plano), notificaciones, Bluetooth, vibración, micrófono, servicios en
  primer plano (cámara, micrófono, ubicación), wake lock, audio. **iPhone**: cámara, ubicación, micrófono, Bluetooth, Face ID; modos
  de fondo "remote-notification" y "location"; aviso urgente (Time Sensitive).
- **Servicios de la app**: servidor `ojo-guard-ms-api` (vincular, órdenes, evidencia, familia, SOS, lugares), cola sin conexión
  (evidencia pendiente), cada aviso de SOS registrado en el servidor.

## 9. Lista para tildar después de cada paso

Después de mover o rediseñar algo, comprobar a mano:

- [ ] La guardia abre el teclado; la clave de administrador entra a Configuración sin sacar foto; la clave señuelo/incorrecta saca foto.
- [ ] Se puede cambiar el tema (Fondo claro) desde "?".
- [ ] Todos los campos de las secciones 7, 8 y 10 se guardan (probar cambiar uno y "Guardar cambios").
- [ ] Interruptores: Adjuntar ubicación, Audio ambiental, Modo cercanía (+ radio), Modo preventivo, Pantalla OLED.
- [ ] Fondo de pantalla: elegir imagen y "Fondo original".
- [ ] Modo perdido: el mensaje se ve en la guardia al activarlo desde el panel.
- [ ] Permisos de Android: los cinco botones de la guía y los de "Preparar autonomía" siguen abriendo su pantalla de Ajustes.
- [ ] Detección de PIN fallido y de pantalla repetida: se pueden activar y probar.
- [ ] Personas, dispositivos y artículos: se puede dar de alta, buscar un accesorio Bluetooth y hacer sonar un auricular.
- [ ] Intentos de entrada: se ven las fotos, "Borrar historial", y el detalle (delantera/trasera, mapa, audio, "Buscar coincidencia").
- [ ] Protección sin internet: "Intentar enviar ahora".
- [ ] Vinculación con Ojo Guard MS: enviar código, vincular, sincronizar, abrir el panel, crear acceso seguro.
- [ ] Familia: ver personas, "Mapa ›", unirme con un código, pausar/reanudar, salir de una familia.
- [ ] SOS: botón rojo, "Estoy bien", gesto de volumen (Android), atajo (iPhone), tocar el aviso abre el mapa.
- [ ] Dr. Ojo Guard: chequeo, botones de arreglo, "Probar la sirena", aviso de Bluetooth.
- [ ] "Guardar cambios" y "Volver sin guardar" funcionan (y "Activar Ojo Guard" en el primer arranque).
