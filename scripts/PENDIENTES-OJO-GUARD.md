# Pendientes de Ojo Guard (app + Ojo Guard MS)

Actualizado: 12/10/2026.

## En curso

- [x] **Avisos de llegada y salida por persona: geocercos en iPhone**
  (12/10/2026, aplicado, publicado y probado: con la build 26 de iPhone y
  los dos avisos de Casa, "salió de Casa" y "llegó a Casa" llegaron al
  Android al salir y al volver). Causa del "no me avisó": el
  envío del aviso funciona (servidor, Expo, Google y Android; el aviso de
  prueba "LB iPhone llegó a Casa." quedó en la bandeja del Android), pero el
  iPhone manda un punto cada 150 m, cada ~5 min, y se pausa solo al quedar
  quieto: el 11/10 el último punto del viaje quedó a 245 m de casa y la
  llegada nunca se reportó. Arreglo: `aplicar-familia-geocercos-panel.ps1`
  (dirección `GET /api/native/family/regions` con los lugares a vigilar y un
  solo aviso aunque lleguen dos ubicaciones a la vez; antes salía duplicado)
  y `aplicar-familia-geocercos-app.ps1` (`src/familyGeofence.ts`: dos
  geocercos del sistema por lugar, uno que avisa al entrar y otro más grande
  que avisa al salir; iPhone despierta a la app al cruzarlos aunque esté
  cerrada). Límites: 10 lugares por iPhone, 1 a 3 minutos de demora, un aviso
  nuevo vale cuando ese teléfono renueva la lista (al abrir la app o al
  moverse), solo iPhone. LB iPhone ya está de nuevo como Adulto y el aviso
  de Casa quedó rehecho con "Donde está LB iPhone ahora". Tabla `push_log` (anota lo que contesta
  Expo en cada aviso de lugar, 7 días) y los scripts `probar-aviso-*.ps1` y
  `ver-registro-avisos.ps1` son de diagnóstico: se pueden borrar cuando el
  aviso ande. Aparte: el cron de 15 min sigue creando pedidos `auto-locate`
  para el iPhone y nunca se ejecutan (hay más de 300 vencidos en `pending`):
  conviene no crearlos para iPhone y marcar los vencidos.
- [x] **Panel: nombre de cada teléfono con su marca** (12/10/2026): en el
  mapa y la tarjeta dice "Mi teléfono · Android", "Notebook LB · Windows"; en
  la lista lateral va como etiqueta chica (ANDROID, IPHONE, WINDOWS) para que
  no se corte el nombre (`actualizar-mapa.ps1`, solo panel, sin build).
- [ ] **SOS (Familia, etapa C)** (12/10/2026, armado y probado con bases de
  prueba; falta aplicar, publicar, hacer las builds y probar con los dos
  teléfonos). Servidor y panel (`aplicar-familia-sos-panel.ps1` + dos tablas,
  `family_sos` y `family_sos_to`): le llega al titular y a los adultos (a un
  amigo, solo al titular); push con sirena, mail, SMS si lo tiene activado y
  ubicación en vivo 10 min; "Estoy bien" lo cancela y avisa; cartel rojo en el
  mapa con "Ver en el mapa" y "Atendido". App (`aplicar-familia-sos-app.ps1`,
  próxima build de Android y iPhone): botón SOS en Configuración > Familia
  (mantener 3 s, vibra, muestra a quién se le avisó, "Estoy bien"); Android
  sin abrir la app: mantener los DOS botones de volumen 3 s (servicio de
  accesibilidad "Ojo Guard SOS", módulo nativo `modules/sos-trigger`, tarea
  headless `OjoGuardSosTask`; solo mira el volumen; se activa a mano en
  Ajustes y en Android 13+ hay que permitir "configuración restringida"
  porque la app va por APK); iPhone: enlace `ojoguard://sos?k=<clave>` (la
  clave es de cada teléfono, para que nadie mande un SOS falso con un link
  de afuera) que se pone en un atajo "Abrir URL" y se dispara con Siri, el
  toque en la espalda o un control de la pantalla de bloqueo. Límites: con el
  iPhone bloqueado el atajo pide Face ID; el código de Kotlin no se pudo
  compilar en el entorno de trabajo (solo se revisó la sintaxis y se siguió
  el molde de `theft-detection`): si falla la build de Android, mirar el log
  de EAS. Probar con los dos teléfonos de Lu (SOS desde el iPhone al Android y
  al revés) y después con el iPhone de Mariana. Más adelante, si lo del Face
  ID molesta: App Intent nativo en Swift (corre sin desbloquear).
  **Probado el 12/10/2026:** el gesto de volumen en Android funciona (con la
  pantalla bloqueada sale "SOS enviado" y le avisa a LB iPhone). Fallas
  encontradas: (1) el bloque SOS no se ve en el Android del titular porque
  `visible={me.memberships > 0}` cuenta solo a quien se unió a una familia;
  tiene que ser `me.memberships > 0 || people.length > 0` (sin el bloque no
  hay "Estoy bien" ni el botón para activar el gesto; se canceló por la base
  con `UPDATE family_sos SET status='cancelado'`); (2) en el iPhone el aviso
  del SOS llega en silencio si hay un modo de concentración activo (le pasó a
  Lu con "Yo"): para atravesarlo hace falta aviso "urgente" (Time Sensitive:
  `interruptionLevel: "time-sensitive"` en el push y el permiso
  `com.apple.developer.usernotifications.time-sensitive` en la build de
  iPhone) o, mejor, Critical Alerts (pendiente de Apple, ID 7R4MM73U2Y).
  **Arreglos del 13/10/2026** (`aplicar-familia-sos-mejoras-app.ps1` y
  `aplicar-sos-sirena-panel.ps1`; aplicados, publicados y build 157 de Android
  instalada: el botón rojo se ve en el Android del titular y suena la sirena;
  falta la build de iPhone con el aviso urgente y probar el atajo de Atajos/Siri/
  toque en la espalda): bloque SOS
  también para el titular; canal Android `ojo-sos` con la sirena
  (`ojo_sirena.wav`), volumen de alarma y `bypassDnd` + botón que abre esa
  pantalla; SOS al iPhone como aviso urgente (`interruptionLevel:
  "time-sensitive"` + permiso en `app.json`; si la build de iPhone falla por
  credenciales, sacar ese permiso). El script del panel se corre DESPUÉS de
  instalar la app nueva en el Android (el canal se crea al abrirla).
  Lo de Play Protect: la app con el servicio de accesibilidad se bloquea al
  instalar por APK; se instaló apagando un momento Play Protect (en Play
  Store habría que justificar la accesibilidad o cambiar el gesto por un botón
  en la bandeja o un widget).
- [x] **Familia, menores, parte 1** (aplicado y publicado el 09/10/2026;
  probado: el iPhone como menor recibió "Luciano pidió tu ubicación desde Ojo
  Guard MS" con el teléfono bloqueado). Desde el panel, el titular y los adultos de la
  familia pueden usar **Ubicar ahora**, **Hacer sonar** (y Detener) y
  **Seguir en vivo** sobre el teléfono de una persona con rol MENOR. Los
  amigos no. Cada pedido le avisa al menor por push y por correo ("Luciano
  pidió tu ubicación"), sin modo oculto.
- [x] **Panel: gestionar a las personas de la familia** (publicado y probado
  el 10/10/2026: "LB iPhone" pasó a Amigo desde el mapa). En la tarjeta de la
  persona, "Cambiar rol o quitar" (solo el titular). También arregla la X de
  las invitaciones sin usar, que no anulaba.
- [x] **Familia, menores, parte 2: foto y audio** (publicado y probado el
  10/10/2026: con "LB iPhone" como Menor, la foto y el audio llegaron a la
  tarjeta del panel al abrir Ojo Guard en el iPhone; falta la build con
  "Salir de la familia" en la app). Panel: `aplicar-menores-evidencia.ps1` +
  dos columnas nuevas en `commands` (`requested_by`, `requested_by_name`).
  En la tarjeta del menor, "Pedir foto y audio": el menor recibe el aviso
  ("Luciano pidió una foto y un audio de tu teléfono") y un mail; el teléfono
  los saca como la evidencia de siempre (en iPhone, cuando abre Ojo Guard);
  le llegan por mail solo a quien los pidió y los ve en la tarjeta.
  Cuidados, para que nadie quede como Menor sin saberlo: aviso por push y mail
  cuando a alguien le cambian el rol, y "Salir de esta familia" en el panel y
  en la app (`aplicar-familia-salir-app.ps1`, próxima build); si sale, al
  titular le llega un mail.

## iPhone

- [x] **"Hacer sonar" con la app abierta y la perilla en silencio** (build 22,
  probado el 09/10/2026: con la perilla en silencio, la sirena sonó al abrir la
  app).
- [x] **Sirena propia de 28 s en la notificación de "Hacer sonar"** (build 23,
  probado el 09/10/2026: con el iPhone bloqueado, la app cerrada y la perilla
  con sonido, la sirena sonó unos 30 s). En silencio no suena: para eso hacen
  falta las Alertas críticas.
- [ ] **Alertas críticas de Apple.** **Enviado el 09/10/2026 a las 17:3x.
  Request ID: 7R4MM73U2Y.** Esperar el mail de Apple (puede tardar semanas);
  si en 2 o 3 semanas no hay respuesta, volver a enviarlo con los mismos
  textos (página "Pedido de Alertas críticas",
  https://claude.ai/artifact/KWJeEVMrjYhSTELXtJwpRc). Si lo aprueban: permiso
  `com.apple.developer.usernotifications.critical-alerts`, sonido de alarma
  propio en el push y pedir el permiso al usuario. Con eso suena en silencio,
  con volumen bajo y con la app cerrada, como "Buscar".
- [ ] **Probar la build 21 en la calle:** app cerrada, caminar unas cuadras y
  ver si "LB iPhone" se mueve solo en el panel.
- [ ] **iPhone de Mariana (la mujer de Lu):** darla de alta en TestFlight
  (pruebas internas), cuenta propia con "Empresa", unirla a la familia como
  Adulto. El 09/10 quedó sin hacer porque parecía complicado; los pasos para
  copiar y pegar están en la página "Mariana en TestFlight",
  https://claude.ai/artifact/6VoD48tDTYG4hTg2VqHsA4.
- [ ] **Consejos de seguridad en la configuración inicial (iPhone)** (hecho el
  10/10/2026 en `aplicar-consejos-y-subida.ps1`; falta la build): activar
  "Protección de dispositivo robado" y desactivar el Centro de control con el
  iPhone bloqueado (Ajustes → Face ID y código → "Acceso con el iPhone
  bloqueado"), para que no puedan poner el modo avión sin desbloquearlo.
- [ ] **Avisos repetidos de "Hacer sonar"** (arreglado en `aplicar-build22.ps1`:
  la app no vuelve a ejecutar una orden en curso; en simulación, de 31
  ejecuciones a 1; falta la build y probarlo): el 08/10 a las 20:29 llegaron unas 20
  notificaciones iguales en el mismo minuto. Probablemente la app vuelve a
  mostrar el aviso cada vez que revisa la orden mientras la sirena suena.
  Revisar en la próxima build (un solo aviso por orden).
- [ ] **Preferencias de mails** (hecho el 10/10/2026 en
  `aplicar-avisos-correo.ps1` + columna `email_off` en `notification_prefs`;
  falta aplicarlo, publicarlo y probarlo). En Cuenta > Avisos de seguridad se
  pueden apagar: confirmaciones de órdenes (salvo Modo perdido), el resultado
  de Ubicar y "salió de tu familia". Siempre llegan: intentos de entrada,
  Modo perdido, dispositivos, accesos y los avisos de familia que protegen.
  Nuevo aviso obligatorio: "Ingreso desde un equipo nuevo" (cookie `ojo_eq`;
  la primera vez que se entre desde cada navegador después de publicarlo,
  llega uno).
- [ ] **Audio de la evidencia: unos 10 segundos reales** (probado el 11/10/2026
  en Android con la versión de 10 s: el panel dice "Audio 10 s"; la v2 de
  `aplicar-audio-10s.ps1`, con 11 s grabados, va en la próxima build): se graban 11 s porque el grabador pierde casi un
  segundo al arrancar y cortar (con 6 s el reproductor mostraba 0:05). Con la
  app abierta el audio arranca junto con las fotos y los primeros segundos
  traen el ruido de las cámaras.
- [ ] Botón **"Compartir de nuevo"** cortado en Configuración → Familia y
  amigos (en `aplicar-build22.ps1` pasa a decir "Reanudar"; falta la build).
- [ ] `eas.json` con `submit.production` (ascAppId 6812533689), en
  `aplicar-consejos-y-subida.ps1`: desde la próxima build de iPhone,
  `eas.cmd build --platform ios --profile production --auto-submit` la sube
  sola a TestFlight. Falta probarlo.

## Antirrobo (app)

- [ ] **Probar en la calle el "Modo cercanía"** (Configuración → Modo cercanía:
  "alerta si un accesorio autorizado con Bluetooth o UWB sale del radio
  seguro"). Idea: avisar en el momento del arrebato usando los auriculares o
  el reloj que la persona ya lleva, sin vender un llavero (a diferencia de
  PhoneGuard). Confirmar que funciona con el teléfono bloqueado y en segundo
  plano, en Android y en iPhone. Próxima build.

## Android

- [x] **La build 152 se cerraba sola al abrir** (arreglado en la build
  siguiente, probado el 10/10/2026). Causa: el mapa de Familia usa Google
  Maps, que en Android pide una clave que la app no tiene. Con
  `aplicar-mapa-android.ps1`, en Android no se muestra ese mapa (ni el del
  detalle de un intento) y cada persona se toca para abrirla en Google Maps.
- [ ] Más adelante, si se quiere el mapa adentro de la app en Android: crear
  una clave de Google Maps para Android (Google Cloud) y ponerla en `app.json`.
- [ ] **Modo perdido: al enchufar el cargador**, mandar la ubicación y la
  evidencia al instante (Android avisa a la app cuando lo conectan). Idea
  tomada de un atajo de iPhone que circula en redes, que con el teléfono
  bloqueado probablemente no funciona; Ojo Guard sí puede hacerlo.
- [ ] Instalar y probar la última build de Android (en vivo caminando).
- [ ] **Canal de notificación "ojo-familia-aviso" sin sonido** (creado en
  `aplicar-build22.ps1`; falta la build de Android). El servidor ya manda en silencio "Luciano vio dónde estás"
  (`aplicar-familia-avisos.ps1`); mientras la app no cree ese canal, Android
  lo muestra por su canal general, con sonido.

## Familia, más adelante

- [ ] **Etapa B: avisos de ubicación por persona** (publicado el 11/10/2026).
  **Falla en la prueba:** al caminar con el iPhone NO llegó el aviso de
  "salió de Casa" / "llegó a Casa" (Lu lo avisó; antes lo había anotado como
  probado por error). A investigar: ver en la base si el iPhone mandó
  ubicaciones mientras caminaba (la ubicación en segundo plano del iPhone
  nunca se probó en la calle) y si el aviso cambió de estado. Hecho en
  `aplicar-familia-avisos-persona.ps1` + tabla `family_alerts`; reemplaza a
  "lugares que avisan" tras la idea de Lu de hacerlo como Buscar de Apple.
  Desde la tarjeta de
  alguien de la familia: "Avisarme cuando X llegue o salga de...", con el
  lugar (guardado, donde está X ahora, donde estoy yo, u otro con la mira y
  la calle y altura), tamaño de 100 a 500 m y una vez o cada vez. Los avisos
  de esa persona se listan en su tarjeta (con ✕). La persona recibe un push
  cuando se lo ponen; el aviso le llega a quien lo armó; cualquiera que vea a
  la persona en su mapa puede armarlo (los amigos solo ven al titular).
  Margen de 50 m para salir, ignora ubicaciones con más de 300 m de error, no
  repite en 5 min, no avisa con la ubicación en pausa y se borra solo si la
  persona sale de la familia. Más adelante: que la persona vea en su app quién
  tiene avisos sobre ella, y verlos en la app.
- [ ] Etapa C: SOS del menor.

## Negocio e inversores

Devolución de Axel Abulafia (09/10/2026, "Ojo Guard - mirada preliminar"): el
deck es un pitch de visión; antes de invertir quiere ver el producto andando,
tracción y la economía del negocio.

- [x] **Responderle a Axel** (Lu le respondió el 10/10/2026): gracias,
  qué funciona hoy y qué es roadmap, por qué Ojo Guard aunque exista Buscar,
  privacidad de menores, y ofrecer una **demo en vivo de 15 minutos**.
- [ ] **Deck nuevo**:
  - capturas reales en lugar de "escena ilustrativa";
  - "funciona hoy" separado de "próximo" (pulsera SOS, auto, tags y collar
    son roadmap);
  - slide de equipo;
  - competencia: Buscar de Apple, Samsung y Google, Life360, Prey,
    PhoneGuard, AngelSense/Jiobit, y por qué Ojo Guard igual;
  - modelo de negocio, cuánto se busca y para qué.
- [ ] **Definir cuánto pedir y para qué** (fue una de sus críticas fuertes).
- [ ] **Tracción mínima:** beta cerrada con 20 a 50 familias conocidas, para
  tener los primeros números reales (usuarios activos, retención).
- [ ] **Canal B2B2C:** explorar aseguradoras (seguros de celular) y empresas
  de seguridad o monitoreo. Es la sugerencia de Axel, y el caso de PhoneGuard
  muestra que llegar a la gente de a uno es lo difícil.
- [ ] **Cuidar la información:** marcar el deck como "Confidencial", mandarlo
  como link de solo lectura y mostrar el "qué", no el "cómo".

**PhoneGuard** (competidor local, datos de prensa de enero de 2026): de Leandro
Campopiano y Néstor Muñoz (Rock Software). App gratis más un llavero Bluetooth
de unos $5.000; si el teléfono se aleja del llavero (de 10 a 150 m), pregunta
tres veces y avisa a la familia, a los vecinos en 3 km y a las fuerzas de
seguridad, y suena una sirena con PIN. Invirtieron más de USD 155.000; tenían
unas 900 descargas y más de 30 alertas; se dieron de alta como proveedores del
Estado, pero el avance se frenó. Diferencia con Ojo Guard: ellos cubren el
momento del arrebato y dependen del llavero y de que haya muchos vecinos con la
app; Ojo Guard cubre el después (evidencia, Modo perdido, panel) y la familia,
solo con el teléfono. Decisión: por ahora no contactarlos; una alianza queda
como opción más adelante.

## Panel y otros

- [ ] Ubicación automática de la notebook cada 15 minutos.
- [ ] Encabezado del panel en el celular, apretado.
- [ ] Actualizar la presentación con una captura del mapa.
- [ ] Tiempo de viaje en auto en "Cómo llegar" (es pago: decide Lu).
