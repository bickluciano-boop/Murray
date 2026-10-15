# Foto de la consola (Ojo Guard MS) — 15/10/2026

Todo lo que hoy hace y muestra la consola, armado leyendo `panel-index.html`, `panel-app.txt` (la lógica) y `panel-mapa.css`
(el mapa), tal como están en la carpeta del panel. Sirve de **lista para tildar** después de cada cambio: ninguna utilidad se
pierde ni se mueve sin dejar dicho dónde queda. Los archivos leídos son `panel-index.html`, `panel-app.txt`, `panel-mapa.txt` y los cinco de estilos. Copia de respaldo: `FOTO-OJO-GUARD-PANEL-2026-10-15_1459.zip`.

## 1. Cómo se navega hoy

- **Dos estados:** *Acceso* (sin sesión) y *Panel* (con sesión). La sesión se pide con `/api/remote/session`; si no hay, aparece el acceso.
- **Barra de arriba:** logo "ojo guard MS", botón de tema ("Fondo blanco" / "Fondo oscuro", se recuerda en `localStorage`,
  clave `ojo_ms_tema`) y "Cerrar acceso" (borra la sesión).
- **Seis pestañas abajo** (barra flotante): Inicio · Mapa · Historial · Dispositivos · Pulseras · Cuenta. "Mapa" la agrega
  `panel-mapa.txt`; las otras cinco son de `panel-app.txt` (`data-view`: home, history, devices, watches, account).
  En *modo de emergencia* se esconde Cuenta.
- **Se redibuja solo cada 15 segundos** (no mientras haya un recorrido abierto a la vista) y con "Actualizar" o deslizando hacia
  abajo desde arriba (en el celular). Las órdenes también refrescan al terminar.
- **Modo demostración** (`demoMode`): cuenta de ejemplo, ninguna orden se envía de verdad.
- **Modo de emergencia:** se entra con la pregunta de emergencia; limita lo que se puede hacer (ver 9).
- **Acceso directo desde la app (nuevo):** `/auth/device?t=…` abre la consola ya adentro, desde el botón "Abrir Ojo Guard MS" de la
  app del teléfono vinculado (enlace de un solo uso de 1 minuto, con aviso por correo).

## 2. Pantalla de acceso (sin sesión)

1. Marca grande, "ACCESO SEGURO", título "Entrá a tu cuenta" y la frase del código por correo (funciona en iPhone, Android y
   computadora, sin QR).
2. **Correo registrado** + botón "Enviar código de 6 números". Después: campo "Código de 6 números" y "Entrar".
3. Desplegable **"Ya configuré acceso seguro en este dispositivo"**: correo + "Entrar con la credencial guardada" (passkey) y su aviso
   (solo si se configuró en el mismo dispositivo y navegador).
4. Desplegable **"Tengo un código de verificación configurado"**: correo + código de 6 números + "Entrar con el código de verificación".
5. Desplegable **"No puedo recibir el código: uso mi pregunta de emergencia"**: correo → "Ver mi pregunta" → tu respuesta →
   "Entrar en modo de emergencia" (no distingue mayúsculas, tildes ni espacios; sirve una sola vez).
6. **Crear acceso seguro** (aparece al venir desde el teléfono principal; vence en 15 minutos): pasos con huella, Face ID o PIN,
   aviso sobre elegir "Este iPhone" / Llavero de iCloud, botón "Crear acceso seguro", enlace "Volver a Ojo Guard y generar otro
   acceso", y un desplegable "Prefiero un código de verificación" (Generar código de verificación, secreto, "Abrir directo en la
   app de autenticación", código de 6 números, Confirmar).
7. Mensaje de estado del acceso.

## 3. Encabezado del panel (con sesión)

- Cartel **"Modo de emergencia"** (solo en emergencia): acceso limitado para localizar, hacer sonar, Modo perdido y evidencia.
- Título "Centro de protección" (en demo "Demostración de la cuenta"; en emergencia "Protección de emergencia") y el correo.
- Estado de la cuenta ("N equipos vinculados" o "Cuenta activa · falta vincular el teléfono") y botón **Actualizar**.
- **Resumen de cinco contadores** (solo en Inicio): Teléfonos · Actividad · Pulseras · Personas · Artículos; cada uno abre su sección.

## 4. Inicio

- **Última evidencia** (la más reciente; las anteriores van al Historial) con el botón "Ver historial" cuando hay más de una.
  La tarjeta de evidencia está descripta en el punto 6.

## 5. Mapa (`panel-mapa.txt`, leído completo)

- **Pestaña "Mapa"**: pantalla completa con Google Maps. En escritorio, lista a la izquierda; en celular, solo el mapa y una tarjeta
  que sube desde abajo (se pliega con una manija).
- **Lista lateral** "Familia y equipos" (o "Tus dispositivos"), con el resumen "N personas · N dispositivos" y el botón
  **"Invitar a la familia"**. Grupos **FAMILIA** y **DISPOSITIVOS**. Cada fila: foto o iniciales, nombre, etiqueta de rol
  (ADULTO / MENOR / AMIGO / TITULAR), marca de quién es, aviso de SOS, distancia "De vos" (o "Cerca"), estado (En vivo / hace cuánto),
  batería, dirección, y un botón redondo de sonido. Abajo: **INVITACIONES SIN USAR** (nombre, rol, código, copiar, compartir, quitar)
  y **LUGARES** (lista de lugares guardados y "Agregar lugar"), más la nota de que se actualiza sola.
- **Sobre el mapa:** selector **En vivo / Hoy / 7 días**; controles **+ / − / ◎ (ver todos o centrar)** y, en el celular, el botón
  de invitar; capas **Mapa / Satélite**; marcadores con foto o iniciales (halo que late si está en vivo; aro rojo si pidió SOS);
  el punto azul **"Vos"**; el **recorrido** y las **paradas** (con hora de llegada y salida); los círculos de los lugares y avisos.
- **Tarjeta de la persona o equipo elegido:** foto (se puede cambiar la de los teléfonos), nombre y rol, estado, dirección, datos
  **Margen de error · Batería · Hoy (km) · De vos**, las últimas 3 paradas y los botones:
  **Seguir en vivo / Dejar de seguir** (teléfonos con la app y menores), **Ubicar ahora**, **Hacer sonar** (pasa a **Detener
  sonido**; la alarma se corta sola al minuto), **Pedir foto y audio** (solo menores de tu familia: "ve cada pedido que hagas") y
  **Cómo llegar**. Debajo: **"Avisarme cuando llegue o salga"** (lista de avisos con frecuencia y quitar), la **evidencia** pedida
  (foto, audio y enlace), **"Cambiar rol o quitar"** (titular) y **"Salir de esta familia"**, y la lista de los otros equipos.
- **Diálogos:** *Invitar* (nombre, rol Adulto/Menor/Amigo, cómo te ve, código y enlace para copiar o compartir), *Administrar*
  (rol, guardar, quitar con confirmación), *Aviso de llegada/salida* (cuándo, dónde: lugar guardado / punto elegido con una mira
  sobre el mapa / dirección, radio, frecuencia), *Lugar* (ver, quitar) y *Salir de la familia* (confirmar).
- **SOS:** cartel rojo arriba del mapa con quién pidió ayuda y los botones **Ver** y **Atendido**.
- **Modo demostración** (`?demo=1`): datos de ejemplo, ninguna orden real.
- Dato a tener en cuenta: en el Mapa, **Pedir foto y audio** solo existe para menores; para los teléfonos propios esa acción
  ("Solicitar evidencia") está en Dispositivos. Los pedidos con confirmación de identidad piden hacerlos desde Dispositivos.

## 6. Historial (y la "Última evidencia" del Inicio)

Cada **tarjeta de evidencia**:
- Fotos **Cámara delantera** y **Cámara trasera** (tocar abre el visor; si falta una, un recuadro "No disponible" o "Registrada por
  correo").
- Fecha y hora de Buenos Aires, dispositivo y dirección (con "aprox."), y el piso estimado si lo hay (PB o número).
- Etiquetas "Delantera ✓/— · Trasera ✓/— · Audio N s ✓/—".
- **Audio de evidencia** (reproductor; si falla dice que se actualice la página) o la nota de que el audio fue por correo.
- **"Abrir ubicación"** (Google Maps).
- **Reconocimiento facial** ("Identificar a esta persona"): comparar con intentos anteriores o con fotos de la computadora
  (hasta 25), opción de usar la mejor captura del mismo episodio, resultados con las dos caras lado a lado, y **devolución** de
  la búsqueda (refund) si no sirvió. Cuesta 1 búsqueda.
- En la vista Historial: título "Historial de evidencias" y la lista completa ordenada de la más reciente (hasta 50).

## 7. Dispositivos

- Sección **Mis dispositivos** con **"+ Agregar dispositivo"** (panel "NUEVO EQUIPO / ¿Qué querés agregar?": *Teléfono o tablet* →
  "Abrir Ojo Guard"; *Auriculares o accesorio Bluetooth* → "Buscar desde Ojo Guard"; "Cerrar"). Sin equipos: bloque "Ingresá una vez en Ojo Guard".
- **Tarjeta de cada equipo:** ícono, etiqueta (TELÉFONO PRINCIPAL / EQUIPO AUTORIZADO / EQUIPO PENDIENTE), nombre, plataforma,
  y la grilla **Estado** (Conectado / Vinculado / Esperando autorización) · **Batería** · **Última conexión** (hora de Buenos Aires) ·
  **Ubicación** (dirección o coordenadas, "reciente" o "última ubicación", piso).
- **Siete acciones**, cada una con su explicación debajo: *Solicitar evidencia*, *Localizar ahora*, *Hacer sonar*,
  *Detener sonido*, *Detectar cerca*, *Activar Modo perdido*, *Desactivar Modo perdido*. El panel resalta la que corresponde
  apretar ahora (par sonar/detener y par Modo perdido/desactivar) según lo que se ejecutó en esa sesión.
- **Estado de la orden:** "Enviando…", "Orden enviada · esperando confirmación", seguimiento hasta 60 s (el Modo perdido puede
  tardar bastante: avisa que quedó guardada), "Evidencia registrada", "Ubicación recibida ± m", lista de accesorios cercanos.
- **Si es una computadora (Windows):** solo Solicitar evidencia, Localizar ahora, Hacer sonar y Detener sonido, con textos propios.
  **Si es iPhone:** textos sobre las reglas de iOS.
- **Con ubicación:** "Última ubicación … · dirección", **Ver mapa acá**, **Escanear ubicación** (vista de calle y satelital),
  guía de búsqueda, y **historial de ubicaciones** del equipo (lista, recorrido en el mapa, "enviar por correo").
- **Pendiente:** botón "Autorizar este dispositivo" (sin órdenes hasta autorizar). **"Quitar este dispositivo"** (lo desvincula sin
  borrar sus datos).
- Debajo: **Artículos y rastreadores** (lista: nombre, tipo, estado).

## 8. Pulseras

- "Pulseras vinculadas" con **"Ver presentación"** (video). Tarjeta de reloj GPS: Batería, Puesta, Última conexión, Señal,
  ubicación, **historial de alarmas** (SOS, Posible caída, Sin puesta, Batería baja) y **monitoreo de salud** con la etiqueta
  "NÚCLEO · EN VALIDACIÓN" y la nota de que la detección de caídas está implementada pero no probada en cada caso real.

## 9. Cuenta

Tarjetas de **Acceso y seguridad**:
1. **Correo del titular** y **Protección de ingreso** ("Protegido con passkey", cuántos accesos seguros hay).
2. **Código de verificación** (Google Authenticator / Authy): estado, Configurar / Generar uno nuevo, "Agregar en otro dispositivo
   (respaldo)", secreto, "Abrir directo en la app de autenticación", Confirmar.
3. **Avisos de seguridad:** Por correo · Por SMS (pide el número con código de país) · "Avisarme también si el teléfono deja de
   responder", y **Guardar**.
4. **Pregunta de emergencia:** estado, tu pregunta, tu respuesta (mín. 6, letras y números), **Guardar pregunta y respuesta**.
5. **Reconocimiento facial:** saldo de búsquedas, comprar **5 por USD 1** o **10 por USD 1,50**, etiqueta "NÚCLEO · EN VALIDACIÓN".
- Después: **Personas autorizadas** ("Invitaciones · próximamente") y **Artículos y rastreadores**.
- **En modo de emergencia** se esconden Cuenta, Agregar dispositivo, TOTP, avisos y reconocimiento facial, y se limita "Detectar cerca".

## 10. Ventanas que se abren encima

Visor de **foto** (con Cerrar), **video** de la presentación, **mapa** grande (Pantalla completa · Street View · Cerrar) y el
buscador de **vista de calle y satelital** ("Buscando imágenes…").

## 11. Lo que corre sin verse (hay que no romperlo)

- Redibujado cada 15 s y "deslizar para actualizar"; el Modo perdido y el resto de órdenes con su seguimiento.
- **Confirmar identidad** (passkey o código) cuando el servidor pide "step up" (acciones sensibles); el acceso vencido avisa.
- Tema claro/oscuro guardado; mapa de Google con su clave; avisos de equipo nuevo por correo (lado servidor).
- `panel-avisos.txt` **no existe** en tu carpeta: viene de `aplicar-avisos-correo.ps1` (elegir qué avisos por correo llegan), que
  todavía **no se aplicó**. Sigue pendiente (ver PENDIENTES).

## 12. Lista para tildar después de cada paso

- [ ] Acceso: correo + código, passkey, código de verificación, pregunta de emergencia, crear acceso seguro, acceso directo desde la app.
- [ ] Panel: banner de emergencia, estado de cuenta, Actualizar, los cinco contadores (o dónde quedaron).
- [ ] Mapa: lista, recorrido En vivo/Hoy/7 días, tarjeta, Seguir en vivo, Cómo llegar, sonar, avisos de llegada/salida, invitar, roles, lugares, SOS.
- [ ] Evidencias: fotos, audio, "Abrir ubicación", reconocimiento facial y devolución, historial de 50.
- [ ] Dispositivos: las siete acciones, estado de órdenes, ver mapa, escanear, historial de ubicaciones, enviar por correo, autorizar, quitar, agregar dispositivo, Windows e iPhone.
- [ ] Pulseras: alarmas, salud, presentación.
- [ ] Cuenta: passkey, código de verificación, avisos (correo/SMS/silencio), pregunta de emergencia, reconocimiento facial y compra, personas, artículos.
- [ ] Tema claro/oscuro y "Cerrar acceso".
