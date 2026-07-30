# Pendientes de Ojo GPS

## Completado en 16.4.31

- [x] **Primer bug real encontrado probando en una Mac real (MacBook Air de
  Marian): los scripts .command usaban un "python3" falso.** Abrió
  `Abrir-Ojo-GPS-Mac.command` sin haber corrido antes
  `1-Instalar-Python-Mac.command`. La detección de Python de los tres
  scripts (`Abrir-Ojo-GPS-Mac.command`, `Puente-WiFi-Administrador-
  Mac.command`, `Generar-Codigo-Demo-Mac.command`) era
  `command -v python3.13 || PYTHON_BIN=python3` — en una Mac sin Python
  propio instalado, `command -v python3` igual encuentra algo, porque
  macOS trae de fábrica un stub en `/usr/bin/python3` que no ejecuta
  Python: solo dispara "xcode-select: note: No developer tools were
  found, requesting install." y falla. El script asumía que ese
  `command -v` exitoso significaba un Python real disponible. Se
  reemplazó por `find_python()`, que además de comprobar que el nombre
  exista corre `"$candidate" -c "import sys"` para confirmar que arranca
  de verdad antes de usarlo; si ninguno funciona, avisa con el mismo
  mensaje que ya usaba `Abrir-Ojo-GPS-Mac.command` ("Ejecuta primero
  1-Instalar-Python-Mac.command") en vez de fallar con un error de Xcode
  que no tiene nada que ver. `1-Instalar-Python-Mac.command` no tenía este
  bug porque nunca caía al fallback de "python3" a secas.
- [x] Confirmado en la misma Mac: el bloqueo de Gatekeeper ("no se puede
  abrir porque proviene de un desarrollador no identificado") en macOS
  reciente no siempre ofrece "Abrir de todas formas" en el cartel del
  doble clic ni en clic derecho > Abrir — hace falta ir a Ajustes del
  Sistema > Privacidad y Seguridad y tocar "Abrir de todas formas" ahí,
  una vez por archivo. Ya se probó y funciona; falta sumar este detalle
  más claro al LEEME (hoy solo menciona clic derecho > Abrir).

## Completado en 16.4.30

- [x] **Soporte para Mac, arrancando por iPhone (pedido de Lu: "terminar la
  versión Windows, Android y Mac iPhone").** `pymobiledevice3` y Tkinter ya
  son multiplataforma, así que `ojo_gps_app.py` y `ojo_gps_bridge.py` casi
  no necesitaron tocarse en su lógica — el trabajo fue sacar todo lo que
  asumía Windows a secas:
  - `IS_WINDOWS`/`IS_MAC`/`PLATFORM_NAME` nuevos, calculados una sola vez
    desde `sys.platform`. `WIFI_TUNNEL` e `INSTALLER_SCRIPT_NAME` ahora
    apuntan al archivo correcto según el sistema (`.cmd`/`.vbs` en Windows,
    `.command` en Mac).
  - `_app_data_dir()` reemplaza los cinco lugares que armaban la carpeta de
    datos a mano con `%LOCALAPPDATA%`: en Windows sigue siendo la misma
    carpeta de siempre, en Mac pasa a `~/Library/Application Support/Ojo
    GPS` (la convención real de macOS, no un genérico `~/Ojo GPS`).
  - `ui_font(size, semibold=False)` reemplaza las 51 apariciones de
    `"Segoe UI"`/`"Segoe UI Semibold"` como family literal. En Windows
    devuelve exactamente lo mismo que antes (`"Segoe UI"` es una familia
    real ahí). En Mac/Linux esas dos familias no existen, así que devuelve
    `("Helvetica Neue", size, "bold")` en vez de inventar una familia
    "Helvetica Neue Semibold" que probablemente no exista con ese nombre
    exacto — variar el peso con el tercer elemento del tuple de Tk es la
    forma correcta de pedir bold sin depender de que el nombre de familia
    exista tal cual.
  - `_launch_wifi_tunnel` ahora bifurca: en Windows sigue usando
    `ctypes.windll.shell32.ShellExecuteW(..., "runas", ...)` sin cambios;
    en Mac no hay equivalente directo a elevar un proceso desde código, así
    que abre el `.command` en una Terminal nueva (`open -a Terminal ...`) y
    el `sudo` de adentro del script pide la contraseña ahí mismo — mismo
    resultado final (privilegios elevados, ventana visible del puente),
    pasos de UI distintos. El cartel que sigue explica "Aceptá el permiso
    de Windows" o "Ingresá tu contraseña de Mac" según corresponda.
  - `os.startfile(...)` (para abrir la carpeta del token de Mapillary
    vencido) solo existe en Windows; se agregó la rama Mac con
    `subprocess.run(["open", ...])`.
  - Título y subtítulo de la ventana principal ("... en Windows" / "...
    desde Windows") ahora arman esa parte con `PLATFORM_NAME`.
  - Cuatro scripts nuevos, equivalentes a los `.cmd`/`.vbs` de Windows:
    `1-Instalar-Python-Mac.command` (instala Python 3.13 con Homebrew si
    está disponible, si no explica cómo conseguirlo; instala
    pymobiledevice3/lzfse_stub/Pillow con reintento
    `--break-system-packages` si pip se queja de "externally-managed-
    environment", que es como viene el Python de Homebrew de fábrica),
    `Abrir-Ojo-GPS-Mac.command`, `Puente-WiFi-Administrador-Mac.command`
    (con `sudo`) y `Generar-Codigo-Demo-Mac.command`. Los cuatro quedaron
    con permiso de ejecución (`chmod +x`).
  - LEEME.txt suma "REQUISITOS EN MAC" y "COMO ABRIR EN MAC" en paralelo a
    las secciones de Windows, incluyendo el paso de click derecho > Abrir
    que macOS exige la primera vez para scripts sin firmar, y la
    advertencia de que en Mac queda una ventana de Terminal visible
    mientras Ojo GPS está abierto (a diferencia de Windows, que puede
    lanzar la app sin ventana con `pyw`/VBS) — es una limitación real de
    macOS con un script suelto, no algo que se pueda evitar sin empaquetar
    una `.app` de verdad (`py2app` o similar), que queda para una versión
    futura si hace falta.
  - Verificado con un smoke test en Linux con Xvfb (no hay Mac disponible
    en este entorno): la app arranca sin excepciones con el refactor
    completo, `ui_font()` con la familia de fallback (`DejaVu Sans` en este
    caso) renderiza bien, el panel de Administrador sigue generando y
    rechazando códigos igual que antes. Lo que NO se pudo verificar acá,
    por no tener una Mac real: que Homebrew instale Python 3.13 sin
    fricción, que `sudo` dentro de una Terminal abierta con `open -a
    Terminal` pida la contraseña como se espera, que los `.command` corran
    con doble clic después del paso de Gatekeeper, y el flujo Wi-Fi
    completo con un iPhone real. **Antes de repartir esta versión a
    alguien con Mac, hay que probar el circuito completo en una Mac real
    primero.**

## Evolución futura — Soporte Android

- [ ] **Diseño elegido (todavía sin construir): app-puente mínima +
  ADB, en vez de requerir root.** A diferencia de iOS, donde
  `pymobiledevice3` habla con un servicio de diagnóstico que ya trae el
  sistema (nada que instalar en el teléfono), Android no expone una forma
  de inyectar ubicación desde una PC sin que algo corra en el propio
  teléfono — es una limitación real de la plataforma, no algo que dependa
  de cómo se programe Ojo GPS. La opción que pidió Lu ("la más vanguardista
  y que funcione lo más real posible, como la opción PC") es la que menos
  fricción de setup tiene sin pedir root:
  - Una app Android chica (un `TestLocationProvider` registrado vía
    `LocationManager.addTestProvider`), pensada para instalarse sola desde
    Ojo GPS con `adb install -r` la primera vez que se conecta un Android
    por USB — sin pasar por Play Store.
  - Ojo GPS habilita el mock location de esa app con
    `adb shell appops set <paquete> android:mock_location allow` (requiere
    que el usuario tenga Depuración USB activada en Opciones de
    desarrollador, equivalente al Modo de desarrollador que ya se le pide
    para iPhone).
  - Actualización de posición en vivo: `adb forward` de un puerto TCP hacia
    un socket que la app-puente escucha adentro del teléfono, mismo patrón
    `MOVE:lat,lon` que ya usa `ojo_gps_bridge.py` con el iPhone — para
    reusar tal cual toda la lógica de Joystick/Recorrido/Fijar que ya está
    escrita y probada del lado de Ojo GPS.
  - Esto es un proyecto nuevo, no una extensión chica: hace falta un
    proyecto Android (Kotlin, Gradle), firmar el APK, y probarlo en
    dispositivos Android reales — ninguno disponible en este entorno de
    desarrollo. Queda para una etapa aparte después de validar Mac.

## Completado en 16.4.29

- [x] **El Panel de Administrador manda el código por Mail o WhatsApp.**
  Pedido de Lu: además de generar el código, poder mandarlo directo sin
  copiar y pegar a mano. `_open_admin_panel` guarda el último código y la
  cantidad de días generados en `last_code` (dict mutable, para que los dos
  nuevos botones lean el valor actualizado sin variables globales). El
  nuevo `_send_code(via)` arma un mensaje de texto fijo (código + pasos
  para activarlo) y abre `mailto:?subject=...&body=...` (sin destinatario
  fijo, lo elige quien lo manda) o `https://wa.me/?text=...` (sin número
  fijo, abre el selector de contacto de WhatsApp), con el mismo patrón de
  `urllib.parse.quote` que ya usa el botón Soporte. Límite real, avisado en
  el LEEME: ni `mailto:` ni el link de WhatsApp pueden adjuntar un archivo
  agregado por código — eso es una restricción de esos protocolos, no algo
  que dependa de Ojo GPS. Por eso esto solo prepara el mensaje de texto; la
  carpeta para compartir se sigue adjuntando a mano, como hasta ahora.

## Completado en 16.4.28

- [x] **Códigos de activación de 10.000+ días quedaban rotos en silencio.**
  `_generate_activation_code` arma el payload como `f"{days:04d}"`, que solo
  garantiza un mínimo de 4 dígitos, no un máximo. Con `days >= 10000` el
  payload pasa a tener 5+ dígitos, el código final queda con un largo
  distinto a 12 caracteres, y `_validate_activation_code` lo rechaza
  siempre — pero nada avisaba esto al generarlo, ni en el Panel de
  Administrador ni en `Generar-Codigo-Demo.cmd` / `--generar-codigo`, que
  solo chequeaban que fuera un número positivo. Reproducido a mano: 9999
  días genera un código válido, 10000 y 36500 generan códigos que
  `_validate_activation_code` siempre rechaza. Se agregó la constante
  `MAX_ACTIVATION_DAYS = 9999`; `_generate_activation_code` ahora levanta
  `ValueError` fuera de ese rango, y los tres puntos de entrada (panel de
  administrador, `main() --generar-codigo`) validan el rango antes de
  generar y muestran un mensaje claro en vez de entregar un código roto.
- [x] **"Partida"/"Llegada" del Recorrido y del mapa mostraban solo la
  altura, sin la calle, para direcciones con número primero (ej. "1750,
  Avenida Callao...").** Es el mismo problema que se arregló en la 16.4.24
  para "Destino elegido", pero ese arreglo unificó solo los tres lugares
  que armaban ese cartel puntual (`select_result`, `PLACE_REVERSE`,
  `MAP_REVERSE`) en `_short_place_label`; el Recorrido (`_begin_route`) y
  "Elegir en el mapa" para partida/llegada (`_use_map_location`) seguían
  armando el nombre corto con `texto.split(",")[0]` por su cuenta. Se
  extendió `_short_place_label` a ambos caminos: `_geocode_route_location`
  ahora pide `addressdetails=1` a Nominatim y devuelve el item completo (no
  solo el `display_name`); `_selected_route_location` hace lo mismo;
  `_route_prepare_worker` calcula `origin_short`/`destination_short` con
  `_short_place_label` antes de armar la ruta, y ese valor viaja tal cual
  hasta `_begin_route` sin volver a cortarlo. Para el mapa, se agregó
  `self.map_selected_short` y `self.map_selected_address_details`,
  poblados en el handler de `MAP_REVERSE` (incluido el camino de partida/
  llegada marcadas directamente en el mapa de Recorrido), y usados en
  `_use_map_location` en vez del corte ingenuo por coma.

## Completado en 16.4.27

- [x] **Cartel de días restantes para códigos no-admin.** Pedido de Lu:
  quien recibe una copia de prueba no tenía forma de saber, desde la app,
  cuánto le quedaba de acceso. `_check_activation()` pasó de devolver
  `(ok, is_admin)` a `(ok, is_admin, vence)` — calcula `vence` tanto en
  el camino de activación ya guardada (`activated_at + timedelta(days=
  ...)`) como en el de activar un código nuevo recién tipeado
  (`datetime.now() + timedelta(days=validated[0])`). Se hilvanó a través
  de `main()` y `OjoGPSApp.__init__` (nuevo parámetro `expires`,
  guardado en `self.activation_expires`). En `_build_ui`, el `elif` que
  sigue al chequeo de `is_admin` arma un cartel "Vence en N días" (o
  "Vence en N horas" si queda menos de un día), con el mismo estilo de
  badge que ADMINISTRADOR pero sin acción al hacer clic (es solo
  informativo). Con código de administrador se sigue viendo
  "ADMINISTRADOR" en vez de esto — son mutuamente excluyentes a
  propósito, mismo lugar del encabezado.
- [x] La carpeta "para compartir" también se reconstruyó con este
  cambio (ver más abajo) — es justo el escenario para el que se pidió
  esta función.

## Completado en 16.4.26

- [x] **Botón de Soporte en el encabezado.** Nuevo `_open_support_panel`
  ofrece tres botones. Mail: arma un `mailto:soporte@ojoguard.app` con
  asunto y cuerpo pre-cargados (versión de Ojo GPS incluida), codificado
  con `urllib.parse.quote` para que tildes y espacios no rompan el link.
  WhatsApp: arma un `https://wa.me/5491168468495?text=...`; verificado
  por búsqueda web que el formato correcto para celulares argentinos es
  código de país (54) + 9 + código de área + número, sin espacios ni "+",
  13 dígitos en total — coincide exactamente con el número que dio Lu
  (+54 9 11 6846 8495 → 5491168468495). IA: copia la descripción al
  portapapeles (`root.clipboard_append`) y abre claude.ai/new en el
  navegador con `webbrowser.open`. Las tres URLs se armaron y probaron
  por separado (script aparte, mismo código de encoding) antes de
  incluirlas. Se agregó una constante `APP_VERSION` (antes la versión
  solo estaba repetida en 12 lugares distintos sin una única fuente de
  verdad); al ser un string idéntico al resto, el mismo `sed` que ya se
  usa para subir de versión la actualiza sola, sin pasos extra.
- [x] El mail de soporte (soporte@ojoguard.app) lo armó Lu en IONOS,
  como reenvío gratuito a su Gmail personal — no hace falta bandeja
  propia para este uso.

## Completado en 16.4.25

- [x] **Panel de Administrador adentro de la app, para generar códigos
  sin salir a buscar el .cmd.** La marca de admin no es un dígito visible
  en el código ni algo que dependa de la cantidad de días — es
  criptográfica: `_generate_activation_code(days, admin=False)` firma
  `str(days)` con HMAC-SHA256 para códigos comunes, y `str(days) +
  "ADMIN"` para códigos de admin, usando la misma `ACTIVATION_SECRET` de
  siempre. `_validate_activation_code` devuelve ahora `(days, is_admin)`
  en vez de solo `days`: prueba primero la firma común, si no matchea
  prueba la firma con "ADMIN" agregado. Verificado a mano (script aparte,
  mismas fórmulas): un código de 3650 días sin admin valida
  `(3650, False)`; el mismo código regenerado con `admin=True` valida
  `(3650, True)`; un código de 3 días (el que se le dio al inversor) sigue
  validando `(3, False)`. Esto confirma que la duración del código no
  tiene nada que ver con si es admin o no — son dos cosas separadas.
  `_check_activation()` ahora devuelve `(ok, is_admin)` en vez de solo
  `ok`; se actualizó `main()` y `OjoGPSApp.__init__` (nuevo parámetro
  `is_admin`) para llevar el dato hasta la interfaz. Si `self.is_admin`,
  aparece un cartel "⚙ ADMINISTRADOR" en el encabezado (mismo lugar que
  el indicador de conexión), que abre `_open_admin_panel()`: un Toplevel
  con campo de días, botón para generar, el código resultante en un
  Entry de solo lectura con botón Copiar (usa el clipboard de Tk), y un
  historial de lo generado en esa sesión. Los códigos que se generan ahí
  siempre se piden con `admin=False` — no hay forma de generar un código
  de admin desde el panel mismo, evitando que alguien reenvíe sin querer
  la capacidad de generar más códigos de admin.
- [x] Se le generó a Lu un código de administrador nuevo (su código viejo
  de 3650 días sigue sirviendo para abrir la app, pero no es admin, y no
  hay forma de "actualizarlo" a admin sin generar uno nuevo — es
  inherente al diseño). Instrucciones para pasarse al nuevo código
  (borrar `activacion.json` y reactivar) quedaron en el LEEME.txt.

## Completado en 16.4.24

- [x] **"Destino elegido" mostraba solo el número para direcciones con
  altura.** `select_result` armaba el nombre corto con
  `display_name.split(",")[0]`; para resultados de Nominatim con formato
  "1750, Avenida Callao, ..." (número primero), eso dejaba solo "1750"
  sin la calle. Los otros dos lugares que arman este mismo nombre corto
  (los handlers `PLACE_REVERSE` y `MAP_REVERSE`) tenían lógicas
  ligeramente distintas entre sí, y el de `PLACE_REVERSE` tampoco incluía
  el número de calle. Se unificaron los tres en un solo método,
  `_short_place_label`, que arma "calle + altura" cuando ambos datos
  están disponibles (mismo patrón que ya usaba `MAP_REVERSE`, el único de
  los tres que lo hacía bien).
- [x] **Línea de barrio/hora local con letra más chica que el resto.**
  Usaba el estilo `Card.TLabel` (Segoe UI 10, sin negrita). Se agregó un
  estilo nuevo `PlaceContext.TLabel` (Segoe UI Semibold 10, mismo color
  verde) para darle más peso visual sin igualar el tamaño del nombre de
  destino de arriba.

## Completado en 16.4.23

- [x] **Sistema de código de activación con vencimiento por días,
  pensado para dar copias de demo (ej. a un inversor).** Nuevas funciones
  a nivel de módulo (antes de `class OjoGPSApp`, no dependen de una
  instancia): `_generate_activation_code(days)` arma un código
  `DDDD-XXXX-XXXX` donde `DDDD` es la cantidad de días en texto y las
  otras dos partes son los primeros 8 hex de un HMAC-SHA256 del payload
  con una clave fija (`ACTIVATION_SECRET`) — así un código no se puede
  inventar a mano ni alterar (probado: cambiar el `DDDD` de un código real
  dejando la firma vieja invalida el código).
  `_validate_activation_code(code)` hace el camino inverso y devuelve los
  días o `None`; tolera minúsculas, espacios en vez de guiones, y
  cualquier basura sin romper (probado con código vacío, texto random,
  firma incorrecta, largo incorrecto). El estado activado se guarda en
  `%LOCALAPPDATA%\Ojo GPS\activacion.json` (`código` + fecha en que se
  activó); en cada arranque se vuelve a validar la firma del código
  guardado (no se confía ciegamente en la fecha del JSON) y se compara
  `activado_en + días` contra la fecha de hoy. `_check_activation()` hace
  todo esto y, si no hay activación vigente, abre un `tk.Tk()` propio y
  aislado (independiente del root de `OjoGPSApp`, se destruye antes de
  crear el de la app real) pidiendo el código; si lo cancelan o cierran la
  ventana, `main()` corta ahí y no llega a abrir la app. Se probaron por
  separado (script aparte, mismas fórmulas) la generación/validación para
  varios valores de días incluyendo 0 y 9999, la detección de manipulación,
  entradas basura, y la matemática de vencimiento (5 de 7 días → vigente;
  10 de 7 días → vencido).
- [x] **`Generar-Codigo-Demo.cmd` nuevo.** Pide la cantidad de días por
  consola y llama a `py -3.13 ojo_gps_app.py --generar-codigo <días>`
  (flag nuevo en `main()`, maneja el caso e imprime el código sin abrir
  la ventana principal). Mismo patrón de invocación de Python que
  `Puente-WiFi-Administrador.cmd`.
- [x] Le generé a Lu su propio código para 3650 días (10 años) y quedó en
  el LEEME.txt para que no se quede afuera de su propia app con esta
  actualización.
- Límite real, avisado en el LEEME: es Python en código fuente legible, no
  un ejecutable compilado. Alguien con conocimientos de programación que
  abra `ojo_gps_app.py` podría encontrar `ACTIVATION_SECRET` y generar sus
  propios códigos, o directamente borrar el chequeo. Sirve como freno de
  buena fe para alguien que solo va a probar la app, no como protección
  real contra alguien decidido a evitarlo.

## Completado en 16.4.22

- [x] **Los puntos de la ruta en modo Caminar se corren hacia el costado
  (simulación de vereda).** Nuevo `_offset_point` (fórmula estándar de
  "punto destino" dado origen, rumbo y distancia, mismo radio terrestre
  que `_distance_m`) y `_offset_route_for_sidewalk`, que para cada punto
  calcula el rumbo de avance (bisectriz entre el tramo entrante y saliente
  para que las esquinas no queden con un salto brusco) y lo desplaza 2,5 m
  hacia el costado derecho de ese rumbo. Se aplica en `_route_worker` solo
  cuando `osrm_profile == "foot"`, sobre los puntos ya devueltos por OSRM,
  antes de mandarlos a `_begin_route`. Verificado con un script aparte
  (fuera del proyecto, con las mismas fórmulas): el desplazamiento da
  exactamente los 2,5 m pedidos, una recta se corre entera para el mismo
  lado sin distorsión, una ruta con giro de 90° corre suave por la
  esquina sin saltos, y el largo total de una polilínea recta se conserva
  igual antes y después de correrla (222.390 m en los dos casos). No se
  aplica a Bicicleta ni Auto. Limitación real, ya avisada en el LEEME: es
  una aproximación fija hacia un costado, no usa geometría real de veredas
  (no está disponible de forma confiable y gratuita), así que en calles
  muy anchas o curvas muy cerradas el punto puede no caer justo sobre la
  vereda real.

## Completado en 16.4.21

- [x] **El texto de distancia/duración del recorrido ahora se recalcula en
  vivo.** `_begin_route` armaba el string "Distancia: X km • Duración
  estimada: Y" una sola vez, con la velocidad y la distancia total del
  momento en que arrancaba el recorrido, y nada volvía a tocar
  `route_info_text` después de eso — ni `_route_tick` (que sí lee
  `route_speed` en vivo para mover el punto, pero nunca actualizaba el
  cartel) ni `_route_speed_changed` (que solo actualizaba la etiqueta
  chica de "X km/h" al lado del control). Resultado: el punto sí se movía
  más rápido o más lento al cambiar la velocidad, pero el cartel grande
  quedaba pegado al cálculo inicial. Se agregó `_remaining_route_distance_m`
  (suma las distancias entre `self.current_coords` y los puntos restantes
  de `route_points` desde `route_index`) y `_update_route_info_text`
  (arma el cartel con esa distancia restante y la velocidad actual). Se
  llama desde `_begin_route`, desde `_route_tick` en cada paso, y desde
  `_route_speed_changed` cuando hay un recorrido activo — esto último para
  que se actualice al toque incluso si el recorrido está en pausa. De paso
  el cartel pasó a decir "Distancia restante" y "Llegás en" en vez de
  "Distancia" y "Duración estimada", porque ahora es un valor que cambia
  con el avance, no una estimación fija del arranque. `_begin_route` dejó
  de necesitar el parámetro `distance_m` (ya no se usa; se llama solo con
  `points`, `origin_name`, `destination_name`).

## Completado en 16.4.20

- [x] **El recorrido usa el perfil de ruteo correcto según el modo.**
  `_route_worker` tenía `/route/v1/driving/` fijo en la URL de OSRM sin
  importar qué botón (Caminar/Bicicleta/Auto) estuviera elegido — esos
  botones solo cambiaban `route_speed`, nunca el camino calculado. Se
  confirmó (búsqueda web) que el demo público de OSRM
  (`router.project-osrm.org`, operado por FOSSGIS/routing.openstreetmap.de)
  sirve perfiles `car`/`bike`/`foot` worldwide, y que `driving` ya
  funcionaba como alias de `car`. Se agregó `self.route_profile`
  ("foot"/"bike"/"driving") ligado a cada botón de preset, y se pasa por
  toda la cadena `start_route → _route_prepare_worker → _route_worker`
  hasta la URL. Con Caminar, OSRM arma el camino sobre vías peatonales
  (`foot=*`, veredas y sendas mapeadas en OSM) en vez de la calle. Límite
  real: depende de qué tan completo esté el mapeo peatonal de OSM en cada
  zona; donde no hay veredas cargadas como vías separadas, el camino puede
  seguir coincidiendo con la calle. De paso se versionaron dos User-Agent
  que habían quedado en "OjoGPS-Windows/1.0" desde antes.
- [x] **Selección de foto de Street View por orientación, no solo
  distancia.** El pedido a Mapillary ahora incluye `compass_angle`
  (confirmado en la documentación oficial de la API v4: es el rumbo de la
  cámara en el momento de la foto). Para cada candidata se calcula el
  rumbo desde la posición de la cámara hacia el punto elegido (fórmula de
  bearing estándar, nuevo método `_bearing_deg`) y se compara contra el
  `compass_angle` real (`_angle_diff_deg`); el score final sigue sumando
  la distancia, así que gana la foto que mejor combina estar cerca y
  apuntar hacia el punto (antes se elegía solo por distancia, `found[0]`
  tras ordenar por metros). Se subió el `limit` de la búsqueda de 8 a 20
  para tener más candidatas entre las que elegir dentro del mismo radio de
  50 m. Límite real: sigue siendo una entre las fotos que haya en
  Mapillary cerca del punto — en zonas con poca cobertura puede no haber
  ninguna bien orientada.

## Completado en 16.4.19

- [x] **Segunda corrección de la foto de Street View.** Con la 16.4.18
  instalada, la foto seguía sin mostrarse en la máquina real de prueba
  (confirmado con captura de pantalla: mismo mensaje "No se pudo mostrar la
  foto recibida."). El decodificado base64→bytes de la 16.4.18 era correcto
  y necesario, pero no alcanzaba: el formato interno de la imagen (PPM) es
  el que da problemas para armarse en pantalla en esta máquina, más allá de
  cómo se le pasan los bytes. El mapa, en cambio, sí se ve bien siempre, y
  usa PNG. Se cambió la foto de Street View de PPM a PNG (mismo formato que
  el mapa, mismo mecanismo de decodificado de la 16.4.18) para no depender
  de un formato sin evidencia real de que funcione en Windows.

## Completado en 16.4.18

- [x] **Arreglada la foto de Street View, que no se mostraba nunca.** La
  búsqueda y descarga funcionaban bien (Mapillary encontraba foto y Ojo GPS
  la bajaba), pero al armarla para mostrarla en pantalla fallaba siempre con
  "No se pudo mostrar la foto recibida." Causa real: la foto viaja del hilo
  de descarga a la ventana como texto en base64 (necesario para pasarla por
  la cola de eventos como JSON), pero se la estaba pasando así, todavía en
  base64, directo a `tk.PhotoImage(data=...)`. Tk solo decodifica base64
  automáticamente para GIF; para PPM (el formato que usa Ojo GPS acá) espera
  los bytes crudos. Ahora se decodifica el base64 a bytes antes de
  entregárselo a `tk.PhotoImage`.

## Completado en 16.4.17

- [x] **Street View funciona sin configuración manual.** El token de
  Mapillary ya generado quedó incrustado en el código como valor por
  defecto (`MAPILLARY_TOKEN_DEFAULT`); si `mapillary_token.txt` existe y
  tiene contenido, ese archivo sigue teniendo prioridad, así que se puede
  reemplazar el día que haga falta.
- [x] Si el token (el incluido o uno propio en `mapillary_token.txt`) deja
  de ser válido, Ojo GPS lo detecta por la respuesta de error de Mapillary
  (401/403) y abre directamente la carpeta `%LOCALAPPDATA%\Ojo GPS` en el
  Explorador, con el aviso dentro de la ventana de Street View, en vez de
  solo mostrar un error genérico (el flujo anterior mostraba la ruta como
  texto en un cartel y solo se disparaba si no había token en absoluto, algo
  que con el valor por defecto ya no puede pasar).

## Completado en 16.4.16

- [x] **Street View integrado dentro de Ojo GPS** (primera versión).
  - No abre navegador externo: usa una ventana propia de Ojo GPS.
  - Disponible desde "Elegir en el mapa" y desde la pantalla principal, antes
    de pulsar Cambiar ubicación.
  - Si no hay foto cerca (radio de 50 m), muestra: **No hay vista de calle
    disponible cerca de este punto**.
  - Usa fotos de Mapillary (gratis) en vez de Google Street View, para no
    depender de una cuenta de facturación. Requiere un token gratuito propio
    guardado en `%LOCALAPPDATA%\Ojo GPS\mapillary_token.txt` (Ojo GPS explica
    cómo conseguirlo la primera vez que se usa).
  - Requiere el paquete Pillow; el instalador ya lo agrega automáticamente.
  - Pendiente de pulir: hoy elige la foto más cercana al punto, no
    necesariamente la que mira hacia la fachada. Si compass_angle ayuda a
    orientar mejor la vista, se puede sumar en una próxima versión.

## Completado en 16.4.15

- [x] Hacer que **Ver y editar en el mapa** de partida y llegada restaure el
  mapa si estaba minimizado u oculto detrás de la ventana principal.
- [x] Mostrar un error concreto si la ventana del mapa no puede abrirse.

## Completado en 16.4.11

- [x] Mostrar **partida y llegada juntas** en un único mapa.
- [x] Permitir editar cualquiera de las dos sin borrar la otra.
- [x] Conservar ambos puntos al volver a corregir el recorrido.

## Completado en 16.4.14

- [x] Hacer que **Ver y editar en el mapa** abra inmediatamente.
- [x] Evitar que una búsqueda de red bloquee la apertura del mapa.
- [x] Retirar el Street View que abría un navegador externo.

## Validación de la próxima ronda

- [ ] **Prioridad: probar todo el soporte Mac en una Mac real**, no
  disponible en el entorno donde se escribió este código:
  - 1-Instalar-Python-Mac.command en una Mac sin Python 3.13 ni Homebrew
    (debe explicar cómo instalar Homebrew) y en una con Homebrew ya
    instalado (debe instalar Python 3.13 solo, y pymobiledevice3/Pillow sin
    error de "externally-managed-environment").
  - El paso de Gatekeeper (click derecho > Abrir) en los cuatro .command la
    primera vez que se ejecutan.
  - Abrir-Ojo-GPS-Mac.command: confirma que abre la app y que la ventana de
    Terminal que queda no interfiere con el uso normal.
  - Preparar Wi-Fi en Mac: confirmar que se abre una Terminal nueva, que
    pide la contraseña con `sudo`, y que el flujo completo con un iPhone
    real (retirar cable, Fijar GPS) funciona igual que en Windows.
  - Comparar visualmente la interfaz en Mac contra Windows: los tamaños de
    fuente con `Helvetica Neue` (usados como reemplazo de "Segoe UI") no se
    probaron visualmente en una Mac real, solo con una familia distinta en
    Linux sin fuentes de Apple.
- [ ] En el Panel de Administrador, generar un código y tocar Mail:
  confirmar que abre el cliente de correo con el código y los pasos ya
  escritos, sin destinatario fijo. Repetir con WhatsApp y confirmar que
  abre el selector de contacto con el mismo texto. Tocar cualquiera de los
  dos sin haber generado un código todavía y confirmar que avisa en vez de
  abrir algo vacío.
- [ ] Probar el Panel de Administrador y `Generar-Codigo-Demo.cmd` con 9999
  días (debe generar código válido) y con 10000 (debe rechazarlo con el
  mensaje de error, sin generar nada).
- [ ] Probar Simular recorrido con una dirección con altura primero (ej.
  "1750, Avenida Callao...") como partida y como llegada, eligiéndola desde
  la lista de sugerencias, desde el mapa, y tipeada a mano; confirmar que
  el cartel de "Distancia restante" muestra calle y altura, no solo el
  número, en los tres casos.
- [ ] Repetir la misma prueba con "Elegir en el mapa" desde la pantalla
  principal (no desde Recorrido): marcar un punto con altura primero y
  confirmar que "Destino elegido" muestra la calle completa.
- [ ] Activar la carpeta "para compartir" con un código de pocos días y
  confirmar que se ve "Vence en N días" (no "ADMINISTRADOR"), que baja de
  a uno por día, y que en la última hora antes de vencer cambia a mostrar
  horas.
- [ ] Tocar el botón Soporte y probar los tres caminos: que el mail abra
  el cliente de correo con soporte@ojoguard.app y el cuerpo pre-cargado;
  que WhatsApp abra el chat correcto (no un número equivocado); que la
  opción de IA copie el texto y que se pueda pegar con Ctrl+V.
- [ ] Borrar activacion.json, abrir Ojo GPS y activar con el código de
  admin nuevo (3650-8698-4882); confirmar que aparece el cartel ⚙
  ADMINISTRADOR y que el panel genera códigos, los copia bien al
  portapapeles, y que un código generado ahí NO muestra el cartel de
  administrador al activarlo en otra instalación.
- [ ] Probar el código de activación en una máquina real: abrir Ojo GPS
  sin código guardado y confirmar que pide uno; probar con un código
  inválido (debe rechazarlo y dejar reintentar); activar con el código de
  Lu (3650 días) y confirmar que la próxima vez ya no pide nada; probar
  `Generar-Codigo-Demo.cmd` de punta a punta.
- [ ] Probar el corrimiento hacia la vereda en Caminar sobre el mapa en
  vivo: confirmar que el punto se ve al costado de la calle y no en el
  medio, y mirar particularmente cómo se ve en las esquinas (ahí es donde
  más chances hay de que se vea raro).
- [ ] Probar recorrido en modo Caminar en una zona con veredas bien
  mapeadas en OpenStreetMap y confirmar que el camino se ve distinto al de
  Auto (no pegado al medio de la calle). Repetir en una zona con poco
  mapeo peatonal para ver qué tan seguido cae de nuevo en la calle.
- [ ] Probar varias direcciones con Street View y confirmar que la foto
  elegida ahora muestra el frente del local/edificio con más frecuencia
  que antes, no solo la calle.
- [ ] Probar Street View en direcciones reales de Argentina y del exterior
  con el token ya incluido; confirmar que el aviso de "sin cobertura"
  aparece cuando corresponde.
- [ ] Probar la interfaz con escalas de Windows de 100 %, 125 % y 150 %.
- [ ] Repetir el circuito completo por cable y por Wi-Fi.
- [ ] Confirmar **Volver al GPS real** después de ubicación fija, joystick y recorrido.
- [ ] Probar búsqueda, mapa y recorrido con direcciones de Argentina y del exterior.

## Evolución futura — Ojo GPS Testing / Logística

- [ ] Crear un producto separado orientado a pruebas geográficas y operaciones logísticas.
  - Comparar rutas, tiempos estimados y escenarios en distintas ciudades.
  - Incorporar tráfico histórico o en tiempo real mediante proveedores autorizados.
  - Generar reportes y análisis sin mezclar estas funciones profesionales con la experiencia simple de Ojo GPS.

## Completado en 16.4.10

- La partida escrita manualmente se resuelve antes de seleccionar la llegada.
- El mapa muestra simultáneamente la partida azul y la llegada roja.
- El encuadre se ajusta automáticamente para mostrar ambos puntos.

## Completado en 16.4.9

- [x] Al elegir la llegada de un recorrido en el mapa, mostrar también la partida ya seleccionada.
- [x] Diferenciar visualmente la partida (`P` azul) y la llegada (`L` roja).
- [x] Hacer funcionar el zoom con `+` y `-` del teclado principal y del teclado numérico.
