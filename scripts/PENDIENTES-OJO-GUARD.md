# Pendientes de Ojo Guard (app + Ojo Guard MS)

Actualizado: 16/10/2026.

## En curso

- [ ] **Ordenar la app nativa de a poco (más simple, para todas las edades)**
  (14/10/2026). Reglas: el funcionamiento no cambia, solo dónde está cada
  cosa y cómo se ve; antes de tocar nada se hizo la "foto"
  (`FOTO-APP-NATIVA-14-10-2026.md` con todo lo que hay hoy, y `foto-app.ps1`
  que guarda un .zip de la carpeta y compara el código; ya corrido, zip
  guardado). Etapas:
  - [ ] **Paso 1: Configuración en tarjetas**
    (`aplicar-configuracion-tarjetas-app.ps1`, archivo nuevo
    `src/GruposConfiguracion.tsx`, respaldo `.bak-grupos`; sale en la próxima
    build; aplicado el 15/10/2026 y compila bien, falta la build y probar en el teléfono). Cinco tarjetas: Claves y
    Seguridad (Claves de acceso, Evidencia y ubicación, Detección de intentos),
    Fotos de Intrusos (Protección sin internet, Intentos de entrada), Modo
    Perdido y Cercanía (mensaje de recuperación, Modo cercanía, Personas,
    dispositivos y artículos), Mi Teléfono y Fondo (estado del dispositivo,
    Datos del teléfono, Apariencia, Preferencias generales entera) y Permisos
    (en Android "Permisos de Android" con "N de 4"; en iPhone "Permisos del
    iPhone"). Debajo de las tarjetas quedan "Familia y amigos" (con el Dr. Ojo
    Guard y el SOS) y "Ojo Guard MS". En el primer arranque se ve todo junto
    como siempre. El botón atrás de Android vuelve primero a las tarjetas. A
    comprobar en el teléfono: que cada bloque de la lista de la foto siga
    estando, en su tarjeta, con sus botones.
  - [ ] **Paso 2: limpieza chica**
    (`aplicar-configuracion-limpieza-app.ps1`, respaldo `.bak-limpcfg`; sale
    en la próxima build; aplicado el 15/10/2026 y compila bien, falta la build y probar). Solo cambia lo que se ve: los tres
    registros técnicos (rastro del aviso, historial de segundo plano,
    diagnóstico nativo de cámara) quedan en un renglón plegado "Registros
    técnicos (para soporte)" dentro de "Preparar autonomía"; "Estado del
    dispositivo" muestra el nombre que se le puso al teléfono; encabezado y
    cartel de administrador más cortos (el texto largo sigue en el primer
    arranque); subtítulos más cortos de la guía de Android y de "Preparar
    autonomía". Lo de guardar por tarjeta se descartó: cambia el
    funcionamiento (hoy un solo "Guardar cambios").
  - [ ] **Paso 3a: look claro y portada "canchera"**
    (`aplicar-configuracion-look-app.ps1`, respaldo `.bak-look`; sale en la
    próxima build, falta aplicar). Pedido por Luciano con una imagen de
    ejemplo (crema, tarjeta del teléfono con "En línea · 66 %", banda verde
    "Permisos de Android: 4/4 OK", tarjetas grandes con ícono dorado). Son seis
    tarjetas: Familia y SOS (la sección Familia y amigos con el Dr. Ojo Guard
    y el SOS), Claves y Seguridad, Fotos de Intrusos, Modo Perdido y
    Cercanía, Mi Teléfono y Fondo y Ojo Guard MS (la vinculación); con cuatro
    quedaban dos filas sueltas.
    La app abre clara por defecto y el oscuro queda como "Modo noche"
    (interruptor en Mi Teléfono y Fondo > Apariencia; el del "?" sigue); la
    barra de arriba del teléfono cambia según el tema. Íconos propios (familia,
    llave, cámara, radar, teléfono, enlace), sin escudos ni candados (manual de marca), como
    PNG en `assets/` (sin librerías nuevas). Quien ya eligió tema lo conserva.
  - [ ] **Paso 3b: Inicio, Mi perfil y Configuración**
    (`aplicar-inicio-configuracion-app.ps1`, respaldo `.bak-inicio`; sale en
    la próxima build, falta aplicar). Salió de las fotos y pedidos del
    15/10/2026 con el look 3a instalado. Estructura: al entrar con la clave
    se ve el **Inicio** (tarjeta del teléfono con "En línea · batería", los
    botones **Mi perfil** y **Configuración** con la tuerca, y Familia y SOS
    con el SOS debajo de las personas). **Mi perfil** (los datos de uno):
    Estado del dispositivo, Datos del teléfono, Apariencia (Modo noche y
    fondo). **Configuración**: banda de permisos y seis tarjetas de a dos:
    Claves y Seguridad, Fotos de Intrusos (solo Intentos de entrada), Modo
    Perdido y Cercanía (mensaje, contacto, recompensa, Modo cercanía,
    personas y artículos), Preferencias (Preferencias generales y "Envíos
    pendientes", que antes era "Protección sin internet"), Dr. Ojo Guard y
    Ojo Guard MS. "‹ Atrás" vuelve un paso (también el botón atrás de
    Android); la ✕ solo está en el Inicio, más chica. Arreglado: la grilla
    salía en una columna en pantallas angostas; "batería 87 %" y "protección
    100 %" se confundían; volver de Google Maps pedía la clave de nuevo
    (`markPendingSystemActivity` en `abrirEnMapa`).
    Pendiente de pedido: en Modo Perdido, **ver y pedir Modo perdido** desde
    la app (hoy se pide desde el panel Ojo Guard MS; la app solo guarda el
    mensaje de recuperación y la cercanía; requiere una API nueva en el
    panel); el mapa dentro de la app en Android con círculos de cada persona
    (hoy solo iPhone; en Android hace falta una clave de Google Maps, ver
    "Android" más abajo); el botón SOS grande y rojo del dibujo; "Perfil" del
    primer arranque.
  - [ ] **Acceso directo al panel desde la app del propio teléfono**
    (pedido de Luciano el 15/10/2026: "es absurdo e incómodo volver a poner la
    clave más la clave de acceso de Google" si ya se entró a la app).
    `aplicar-acceso-directo-panel.ps1` (ruta `POST /api/native/panel-handoff`
    con el token del dispositivo, que da un enlace de un solo uso de 1 minuto;
    `GET /auth/device?t=…` lo canjea por la cookie de sesión `ojo_ms` con método
    nuevo "device"; tabla `panel_handoff` que crea el propio panel; aviso de
    seguridad por correo en cada acceso; la sesión "device" cuenta como
    fuerte durante sus 30 minutos, así que no pide passkey en las acciones
    sensibles) y `aplicar-acceso-directo-app.ps1` (el botón "Abrir Ojo Guard
    MS" pide el enlace y lo abre; si falla, abre la entrada de siempre; y
    volver del navegador no pide la clave de la app). Falta aplicar los dos
    (primero el del panel) y la build; probar: abrir la consola desde el botón
    y comprobar que entra directo y que llega el correo de aviso; entrar desde
    otro equipo tiene que seguir pidiendo todo. Riesgo conocido a propósito:
    quien tenga el teléfono desbloqueado y la clave de administrador de la
    app puede abrir la consola sin passkey (el aviso por correo lo deja a la
    vista).
  - [ ] **Inicio v2: el Mapa primero** (pedido de Luciano el 15/10/2026, con
    la build de Android 1 instalada: el SOS grande como primera cosa "no me
    termina de convencer"). Idea: al abrir la app se ve **el mapa con todos
    los equipos y la familia**; la app sirve para lo que se hace **con el
    teléfono en la mano** (hacer sonar un equipo propio, ver dónde están los
    hijos y amigos, hacerle sonar el celular a un menor que lo busca, invitar,
    lugares, avisos de llegada y salida); lo que depende de que se lo hayan
    robado (Modo perdido, evidencia, etc.) queda en el panel. El SOS queda
    siempre a mano pero chico (no ocupa media pantalla); "Pedir ayuda sin abrir
    la app" y "Unirme con un código" pasan adentro de Familia/Configuración sin
    perderse. Camino propuesto: en Android el mapa nativo de Google necesita una
    clave que la app no tiene (y sin ella se cierra), así que se muestra **el
    mismo mapa del panel dentro de la app** (WebView, con el acceso directo de
    un solo uso para no pedir claves; en el panel, modo "solo mapa" sin barra ni
    pestañas; el aviso de seguridad por correo del acceso directo no puede
    llegar en cada apertura: como mucho uno cada 12 h para este uso). Requiere
    el módulo `react-native-webview` (nativo: **build nueva de Android y la
    primera de iPhone con esto adentro**). La build de iPhone se espera hasta
    tener el Inicio v2. Elegido el camino del WebView (Luciano no puso
    objeciones y se quejó de que "Mapa ›" abría Google Maps con un pin suelto
    y coordenadas). Armado y probado (sin teléfono): panel
    `aplicar-mapa-en-app-panel.ps1` (`/acceso-v7?app=mapa`, enlace del acceso
    directo con destino "mapa", aviso por correo como mucho cada 12 h; tabla
    `panel_handoff_aviso` y columna `purpose` las crea el propio panel) y app
    `aplicar-inicio-mapa-app.ps1` (Inicio nuevo: línea con el teléfono, botones
    Mi perfil / Familia / Configuración, mapa del panel en un WebView y SOS en
    una franja baja; pantalla nueva "Familia" con lo que estaba abajo del
    Inicio: lista, unirse con un código, pausar, salir y el SOS completo con sus
    ayudas; instala `react-native-webview` con `npx expo install`). El del
    panel quedó aplicado y publicado el 15/10/2026 (versión 1b64d1c0). Pedido
    extra de Luciano (muy importante): **entrar al panel a un toque desde lo
    primero que se ve**, sin pasar por Configuración > Ojo Guard MS ni por la
    pantalla de sincronización: botón "Abrir panel" arriba a la derecha del
    Inicio (usa el mismo acceso directo de `openOjoGuardMs`; dice "Abriendo…"
    mientras pide el enlace). Falta
    aplicarlos (primero el del panel; el del panel y el de la app ya están
    aplicados el 15/10/2026, el de la app compila bien con react-native-webview
    instalado), hacer la build de Android y probar:
    el mapa entra solo, "Cómo llegar" abre afuera y vuelve sin pedir la clave,
    el mapa se ve en claro y en noche, el SOS funciona desde la franja, y
    "Familia" tiene todo lo de antes. Después, la build de iPhone.
  - [ ] **Inicio v2, ajustes tras la primera build con mapa** (fotos de
    Luciano, 15/10/2026: el mapa carga bien en el teléfono, con Google Maps,
    el popup de cada persona y el SOS abajo; "Abrir panel" y Familia andan).
    Pedidos: (1) **barra de arriba fija en todas las pantallas** como las
    pestañas de MS: Inicio, Familia, Perfil, Ajustes y "Panel" (abre MS directo),
    marca en cuál se está; Familia/Perfil/Ajustes sin "Atrás" (los grupos de
    Ajustes sí); (2) **tarjeta del mapa demasiado grande** al tocar un equipo:
    dentro de la app queda pegada abajo, máx. 44 % del alto, datos en fila
    (`aplicar-mapa-app-compacto-panel.ps1`, solo panel, se ve al instante en la
    app instalada); (3) **SOS repetido**: ahora solo en el Inicio (franja roja);
    Familia trae las ayudas "sin abrir la app" y un recordatorio. De paso: en
    Familia, "Mapa ›" lleva al mapa del Inicio y ya no abre Google Maps con un
    pin suelto. App: `aplicar-barra-superior-app.ps1` (necesita antes el del
    Inicio con mapa; es solo JS, pero hace falta build para verlo). Aplicado
    por Luciano el 15/10/2026 y compila bien; el "sin saltos" del panel también
    está aplicado (el "compacto" suelto nunca se aplicó: lo reemplaza el de la
    ronda 3, que lo trae incluido). Falta la build de Android (una sola, con
    todo) y probar la barra fija, el SOS sin repetir, "Mapa ›" de Familia y
    "Abrir panel" con la pantalla "Abriendo…". Pendiente
    para después: que "Mapa ›" enfoque a esa persona en el mapa; textos y
    tamaños finos de la barra; iPhone.
  - [ ] **"Abrir panel" sin saltos** (fotos de Luciano, 15/10/2026: al
    apretar "Abrir panel" se veía el cambio a Chrome, una pantalla blanca, un
    instante la pantalla "Entrá a tu cuenta" y el panel con el mapa vacío antes
    del mapa). `aplicar-panel-sin-saltos-panel.ps1` (solo panel): entrando
    directo (`/acceso-v7?directo=1` para la consola completa, `?app=mapa` para
    el mapa de la app) se muestra "Abriendo Ojo Guard MS…" hasta que el mapa
    dibuja (se saca sola a los 6 s o si no hay sesión). Queda el salto a Chrome:
    para evitarlo del todo, que "Panel" abra el panel **adentro de la app**
    (WebView con la misma sesión del mapa); riesgos a mirar: passkeys no andan
    en WebView (la sesión "device" no las necesita), subir archivos (búsqueda
    de caras) y descargas. Propuesto a Luciano el 15/10/2026: dijo que no;
    "Panel" sigue abriendo el panel en Chrome (con la pantalla "Abriendo…").
  - [ ] **Inicio v2, ronda 3: mapa estilo "Buscar" y Familia más clara**
    (fotos de Luciano, 16/10/2026, con la build de Android que trae la barra
    fija; con capturas de "Buscar" de Apple como ejemplo). Pedidos:
    (1) **Ajustes repetía "Abrir Ojo Guard MS"** (ya está "Panel" en la barra):
    sacar ese botón de Ajustes > Ojo Guard MS (quedan "Sincronizar órdenes
    ahora" y "Crear acceso seguro a MS"); (2) **el recuadro de cada
    dispositivo en el Inicio era muy grande**: tarjeta compacta con un botón
    con ícono por cada cosa que se puede hacer: Hacer sonar / Detener sonido,
    Ubicar ahora, Evidencia (foto y audio, "en el caso que permita": en iPhone
    solo con la app abierta), Cómo llegar y Seguir en vivo, más el estado
    ("En vivo / Sin conexión · hace X · distancia"), la dirección y la
    batería; abajo del mapa la lista Familia y equipos como en "Buscar"
    (persona o equipo, cómo está, dirección, distancia y botón de sonar); X
    para volver a la lista; mantener el dedo sobre un botón explica qué hace.
    Hecho: `aplicar-mapa-app-tarjeta-panel.ps1` (incluye la tarjeta compacta;
    solo panel, se ve al instante
    en la app instalada; probado con el mapa simulado en claro y noche; suma
    "Pedir foto y audio" para los teléfonos propios en el mapa del panel, con
    la orden "capture" de Mis Equipos). (3) **La pantalla Familia poco
    clara** (comparada con "Personas / Dispositivos" de Apple): rediseñar en la
    app (filas como la lista de Personas, sin el título "Familia y amigos"
    repetido adentro, "Mapa ›" que no tape la etiqueta del rol, y las partes
    de unirse con código, pausar y salir más ordenadas). Hecho:
    `aplicar-familia-pantalla-app.ps1` (archivo nuevo `src/FamiliaPantalla.tsx`
    que reemplaza a `FamilySection` cambiando solo el import de App.tsx, más
    sacar el botón repetido de Ajustes; respaldo `.bak-famlista` (`.bak-familia` ya existía de la etapa A); compila bien
    en la prueba; aplicado por Luciano el 16/10/2026 y compila bien; el del
    panel también está aplicado y publicado). La pantalla: lista de personas (inicial con aro verde si
    está en vivo, rol, "En vivo · hace 2 min" / "Sin conexión · hace 1 día" /
    "Ubicación pausada", dirección, batería, flecha para ir al mapa del
    Inicio; el mapa de Apple que había arriba en iPhone ya no está porque el
    mapa de todos es el del Inicio), y tarjetas con título: Mi ubicación,
    SOS y ayuda, Unirme a una familia; al final "Salir de la familia". Sale en
    la próxima build de Android (falta hacerla y probar la pantalla Familia nueva,
    la tarjeta del mapa con sus botones y Ajustes sin el botón repetido). Pendiente: que
    tocar a una persona la enfoque en el mapa; iPhone.
  - [ ] **Mapa del Inicio, ronda 2: todavía más chico + SOS en cuadradito**
    (foto de Luciano, 16/10/2026, con el mapa nuevo: "el recuadro de los
    dispositivos ocupa la mitad del mapa; si una persona está lejos, en la
    provincia y vos en capital, cuesta verla"; y "el SOS tendría que ser un
    cuadrado más chico abajo y que solo diga 3 y el signo de segundos").
    Panel: `aplicar-mapa-app-tarjeta2-panel.ps1` (tarjeta de un tercio del mapa
    en vez de casi la mitad: nombre, estado con batería y dirección en el
    encabezado; lista de abajo más baja con el título en una línea; el
    encuadre mide lo que tapan la lista o la tarjeta y deja a todos a la
    vista). App (falta, va en la próxima build): SOS como cuadradito rojo con
    "SOS" y "3 s" en vez de la franja ancha; pendiente de elegir dónde:
    arriba a la derecha junto al nombre (no ocupa lugar del mapa) o abajo a la
    izquierda sobre el mapa.
  - [ ] **Barra de abajo con el SOS, Familia dentro de Ajustes y más mapa**
    (Luciano, 16/10/2026: "pondría los 5 iconos abajo, con el SOS en la misma
    línea, y toda la pantalla más mapa; achico lo de Android en línea y
    batería"; y "Familia y amigos queda grande, no entiendo la función: vas al
    mapa y ves lo mismo que en el Inicio; la configuración de familia podría
    estar en otro lado, solo para agregar gente"). Hecho (aplicado por
    Luciano el 16/10/2026 y compila bien, el del panel también; falta la
    build): `aplicar-barra-abajo-app.ps1` (respaldo `.bak-barraabajo`): barra
    fija abajo en todas las pantallas con **SOS** (cuadradito rojo "SOS · 3 s",
    se mantiene apretado 3 segundos; ya enviado pasa a "Estoy bien" y el aviso
    "SOS enviado. Le avisamos a…" flota arriba; solo si el teléfono está en una
    familia; el SOS queda a mano en todas las pantallas), Inicio, Perfil,
    Ajustes y Panel; se esconde con el teclado. **Familia sale de la barra** y
    pasa a ser una tarjeta ancha arriba de Ajustes ("Familia y amigos", con
    "‹ Atrás"): adentro quedan cuántas personas comparten con vos, el aviso de
    "Siempre" del iPhone, Mi ubicación (pausar 1 hora/reanudar), SOS y ayuda
    (pedir ayuda sin abrir la app), Unirme con un código y Salir de la
    familia; la lista de personas se saca de ahí porque es la misma del mapa.
    La franja ancha del SOS de abajo del mapa y la barra de arriba se sacan; el
    nombre del teléfono con "En línea · batería" queda chico en el renglón de
    la ✕ y la ayuda (?). Panel: `aplicar-mapa-app-sumar-panel.ps1` (el botón
    "Sumar" en la lista de abajo del mapa, que abre lo de siempre para invitar;
    se ve al instante). Orden: primero el del panel, después el de la app, y
    recién entonces la build de Android (una sola). A mirar en el teléfono: el
    SOS (mantener 3 s y "Estoy bien"), que la barra no tape el gesto de volver
    de Android, y que "Sumar" abra la invitación. Pendiente: iPhone.
    **Primera build con la barra de abajo (fotos de Luciano, 16/10/2026, en
    **Enfocar a la persona al tocarla (Luciano pidió "4", 16/10/2026):** en
    el mapa del Inicio, tocar a alguien de la lista ya lo elegía y lo centraba,
    pero respecto de todo el mapa, y quedaba pegado a la tarjeta de abajo; la
    lista de personas con "Mapa ›" ya no existe en Familia (se sacó). Arreglo
    (solo panel, sin build): `aplicar-mapa-enfocar-panel.ps1` — `centrar` deja
    a la persona en el medio de la parte libre, arriba de la tarjeta (también
    en "Seguir en vivo"); la cuenta se probó con una proyección de prueba. Aplicado y publicado por
    Luciano el 16/10/2026 (versión 89f28c5a); falta que cuente cómo se ve.
    **Más mapa y rotar (foto de Luciano, 16/10/2026, tras enfocar):** "queda
    poco espacio de mapa" y "no se puede rotar el mapa". Eligió: (1)
    Mapa/Satélite en un solo botón chico (hecho, solo panel:
    `aplicar-mapa-capas-panel.ps1`, se ve el de la otra vista y al tocarlo se
    cambia; aplicado y publicado por Luciano el 16/10/2026, versión 70bcd2be); (2) nombre del teléfono en un solo renglón arriba ("Android
    Luciano · En línea · 24%"): FALTA, va en la próxima build junto con el
    arreglo de la ✕ y el ? del iPhone (un solo script de app, a preparar);
    (3) **rotar con dos dedos: crear un Map ID propio** en Google Cloud (el
    mapa de hoy es "raster", que no rota; hace falta mapa vectorial con
    Map ID, Rotación sí y Tilt no, más un estilo que oculte comercios y
    transporte). Luciano crea el Map ID y me lo pasa; entonces: script de panel
    con `mapId`, modo claro/noche con `colorScheme` (el `styles` del código
    deja de valer con Map ID y el `colorScheme` solo se fija al crear el
    mapa), botón "norte" para volver a mirar al norte, y ajustar `centrar`
    para que cuente el giro (el desplazamiento por la tarjeta hoy supone norte
    arriba). No eligió "Tarjeta que se achica" (queda como idea).
    **Prueba de la build de Android con todo (foto de Luciano, 17/10/2026):**
    anda el nombre en un renglón ("Android Luciano · En línea · 39%"), la barra
    más baja y las pestañas Personas · 1 | Dispositivos · 2. Problema: "no
    funciona el circuito (círculo) para centrar en el mapa": al tocar a una
    persona o equipo de la lista esperaba que el mapa se acerque y lo deje a la
    vista; la foto muestra el mundo entero y "LB iPhone" en el océano Índico
    (≈ 3°N, 74°E), con Mi teléfono y Notebook LB en Buenos Aires. Dos cosas: (1)
    el encuadre inicial incluye al iPhone y por eso se aleja al mundo (ubicación
    rara del iPhone: a revisar la fila de "LB iPhone" en la lista, dirección y
    distancia); (2) en el mapa vectorial `panTo` + `setZoom` seguidos se pisan:
    `aplicar-mapa-centrar-panel.ps1` mueve la cámara de una vez
    (`moveCamera({ center, zoom })`, con respaldo para mapas sin esa función). Aplicado y publicado por
    Luciano el 17/10/2026 (versión 65066e46).
    **Luciano (17/10/2026): "toque el icono que toque de dispositivos, no va
    ahí, se queda en el lugar".** Causa: tocar un PIN en el mapa solo elegía al
    equipo (`elegir(equipo.id, false)`, a propósito en el panel de la compu) y el
    mapa no se movía; solo la lista centraba. `aplicar-mapa-pin-centrar-panel.ps1`
    (solo panel, independiente del anterior): en la app el pin pasa
    `elegir(equipo.id, EN_APP)`, o sea también lleva el mapa hasta ahí. Aplicado y
    publicado por Luciano el 17/10/2026 (versión fbe45142). **Probado por
    Luciano el 17/10/2026 en Android: "perfecto, funcionaron los 4 pasos"** (tocar
    el pin y el nombre en la lista lleva el mapa hasta el equipo, y el ◎).
    **Rotar, Map ID creado (16/10/2026):** proyecto de Google Cloud `ojo-guard`
    (número 798400186504), Map ID `1b7239dd38bbcc4a7271dd0d` (nombre OJO GUARD,
    vector con rotación; la consola ya muestra vista previa Claro/Oscuro por
    Map ID). Script `aplicar-mapa-rotar-panel.ps1` (solo panel): `mapId`,
    `renderingType` vectorial, giro con dos dedos, sin inclinación,
    `colorScheme` claro/noche, brujula junto a Mapa/Satélite y `centrar` que
    cuenta el giro; probado con un Google simulado (opciones, brújula y
    enfoque con 0, 40, 135 y 270 grados). Sin probar contra Google real:
    riesgos a mirar en el teléfono: (1) que el Map ID sea del mismo proyecto
    que la clave del mapa (si no, el mapa sale gris o sin estilo); (2) que los
    comercios y el transporte aparezcan (el estilo del código `styles` ya no
    vale: se oculta desde "Estilos de mapa" de la consola y se asocia al Map
    ID, o se importa el JSON de estilo); (3) en Satélite no gira (límite de
    Google); (4) cambiar claro/noche con el mapa abierto puede no verse hasta
    reabrir (el `colorScheme` se fija al crear el mapa). Si algo sale mal:
    copiar los `.bak-rotar` de `src\` y publicar.
    Aplicado y publicado por Luciano el 16/10/2026 (versión 3e092ad6); falta
    que cuente cómo se ve y si gira en el teléfono.
    **Probado en Android (foto de Luciano, 16/10/2026): "gira perfecto", pero
    "está sobrecargado".** Se ven comercios y paradas de Google (Museo Evita,
    íconos de colectivo): el estilo del código ya no vale con Map ID, hay que
    ocultarlos desde "Estilos de mapa" de la consola y asociar el estilo al
    Map ID `1b7239dd38bbcc4a7271dd0d`. **Luciano (16/10/2026): los comercios no
    molestan, ayudan como referencia: NO se oculta nada, se deja el mapa de
    Google como está (no hace falta el estilo de la consola).** Pidió
    reducir los íconos de abajo y del mapa, y reubicar Satélite:
    `aplicar-mapa-liviano-panel.ps1` (solo panel: pines de 30 px con etiqueta
    solo con el nombre —la hora y la marca al elegir—, botones de arriba más
    chicos, Mapa/Satélite como icono de capas en la columna de la derecha con
    la brújula, tarjeta con botones y letra más chicos; probado en un navegador,
    antes y después; aplicado y publicado por Luciano el 16/10/2026, versión
    fb541e96). **Foto de Luciano, 16/10/2026: "perfecto, los pines más chicos;
    el cartel de LB iPhone podría ser más chico, como una hilera, y grande
    cuando lo tocás".** Hecho: `aplicar-mapa-tarjeta-fila-panel.ps1` (solo
    panel): al elegir un equipo o persona la tarjeta empieza plegada en UNA
    FILA (inicial o dibujo, nombre, cómo está y la cruz; 51 px contra 72 px de
    la plegada anterior y 170 px abierta), y se abre tocándola o deslizando la
    manija hacia arriba; probado en un navegador con las reglas reales. FALTA,
    en la próxima build (app): la barra de abajo
    (SOS, Inicio, Perfil, Ajustes, Panel) más baja y con íconos más chicos, el
    nombre del teléfono en un solo renglón y la ✕ y el ? del iPhone, todo en un
    solo script de app: `aplicar-barra-chica-app.ps1` (16/10/2026, **aplicado
    por Luciano y compila bien; falta la build de Android y de iPhone**): botones de la barra de ~53 a ~40 de alto, íconos de 22
    a 17, letra de 11 a 10, SOS cuadradito de 52 a 38 de alto mínimo, encabezado
    "Android Luciano · En línea · 24%" en un renglón, y en iPhone la ✕ y el ?
    bajan `initialWindowMetrics.insets.top`. Reemplaza `src\GruposConfiguracion.tsx`
    y `src\SosBlock.tsx` (revisa que sean los de `aplicar-barra-ajustes-app.ps1`)
    y toca 3 lugares de `App.tsx` (import y dos `top`); respaldo `.bak-barrachica`;
    termina con `npx tsc --noEmit`. Aplicado por Luciano el 16/10/2026: build
    de Android hecha e instalada (a probar) y build 32 de iPhone terminada el
    17/10/2026 (falta `eas submit` a TestFlight y probar la ✕ y el ?). Aviso de
    Expo: ya van 56 builds por encima de lo incluido (USD 24 de uso adicional
    este período): conviene juntar cambios de app antes de cada build.
    **Probado por Luciano en el iPhone (build 32, versión por TestFlight,
    17/10/2026, foto 13:09):** la ✕ y el ? ya quedan debajo de la hora y la
    batería; "Mi IPHONE 13 Pro · En línea · 90%" en un renglón; barra de abajo
    más baja con el SOS; mapa con pines chicos, tarjeta en una fila y filtro En
    vivo/Hoy/7 días al elegir a alguien. Detalle menor para la próxima build de
    app: en iPhone el título queda unos puntos más arriba que la ✕ y el ? (el
    `paddingTop: 4` de `cabeza` en iOS, contra `8 + insets.top` de los botones). Dato:
    la tarjeta ya se pliega tocando su encabezado (nombre) o arrastrando la
    manija (`ogm-plegada`); desde `aplicar-mapa-tarjeta-fila-panel.ps1`
    (aplicado el 16/10/2026, versión 33bb086a) empieza plegada en una fila.
    **Lista de abajo en una fila (Luciano eligió, 16/10/2026, tras una foto de
    la lista "Familia y equipos" abierta con el nombre cortado "LB i…"):** "Lista
    en una fila" y "Ocultar En vivo/Hoy/7 días" (no eligió "Nombre completo").
    `aplicar-mapa-lista-fila-panel.ps1` (solo panel): al abrir el mapa en la
    app la lista empieza plegada: título + Sumar (50 px contra ~156 abierta);
    un toque en el título o en la manija la abre o la cierra; al cerrar la
    tarjeta de un equipo (✕) se vuelve a la fila; En vivo/Hoy/7 días se esconde
    mientras no hay nadie elegido. Probado en un navegador con las reglas reales. Aplicado y
    publicado por Luciano el 16/10/2026 (versión be617b95).
    Pendiente decidir: el nombre cortado ("LB i…") en la lista abierta.
    **Luciano (16/10/2026): "está repetido el icono de sumar, yo lo dejaría
    arriba".** `aplicar-mapa-sumar-arriba-panel.ps1` (solo panel): el botón
    Sumar de la lista de abajo se esconde (con `!important`, sirve con la lista
    abierta o plegada); queda el icono de la persona con el + en la columna de
    botones de arriba a la derecha. Aplicado y publicado por Luciano el
    16/10/2026 (versión 7b148784).
    **Luciano (16/10/2026): "queda mejor — personas/dispositivos".** Entendido
    como pestañas de Buscar de Apple: `aplicar-mapa-pestanas-lista-panel.ps1`
    (solo panel, requiere el de la lista en una fila): la lista de abajo tiene
    dos pestañas "Personas · n" y "Dispositivos · n"; se ve una sola a la vez
    (sin los títulos FAMILIA / DISPOSITIVOS); la fila plegada ES el selector:
    tocar una pestaña abre la lista en esa, tocar la marcada con la lista abierta
    la pliega; sin personas queda solo Dispositivos; la consola de la compu no
    cambia. Probado la lógica y el aspecto en un navegador. Si quería otra cosa
    (por ejemplo solo cambiar los títulos), se vuelve con los `.bak-listapest`
    (el nombre `.bak-pestanas` ya lo usaba un paso viejo de la consola: la primera
    corrida paró sin tocar nada). Aplicado y publicado por Luciano
    el 16/10/2026 (versión f481a143); falta que cuente cómo se ve.
    Android):** funciona el mapa chico, la lista con "Sumar" y la barra con el
    SOS cuadradito. Problemas: (1) **la barra se superponía con los botones
    de Android** (atrás/inicio/recientes) y se comían los toques: por eso el
    SOS "estaba pero no funcionaba"; (2) el nombre del teléfono arriba quedaba
    pisado por la barra de estado; (3) **las dos iniciales no se entienden**
    ("LI", "MT", "NL"): querían el dibujo del equipo como el círculo de
    "Buscar" de Apple, o poder editarlo (el lápiz del círculo ya deja poner
    una foto a un equipo); (4) en la tarjeta de una persona adulta ("LB
    iPhone") solo sale "Cómo llegar": **por diseño las órdenes (sonar,
    ubicar, evidencia, en vivo) son solo para equipos propios y menores de la
    familia**; "LB iPhone" es un familiar ADULTO, no un equipo de la cuenta
    (a esa invitación se le puso ese nombre; en una prueba anterior se le
    cambió el rol a menor por D1 y se volvió a adulto). Pendiente de decidir
    con Luciano cómo darle esas órdenes a su propio iPhone (vincularlo como
    equipo propio, o marcar a un familiar como "mi equipo": cambio de servidor).
    Arreglos: `aplicar-mapa-iconos-panel.ps1` (panel: dibujos de celular,
    compu y reloj en los círculos; una sola inicial en las personas; botones de
    la tarjeta que no se estiran; estado a dos renglones) y
    `aplicar-barra-ajustes-app.ps1` (app: la barra deja abajo el lugar que mide
    el teléfono con `react-native-safe-area-context`, que es NATIVO: hace
    falta otra build de Android; el título baja de la barra de estado; el SOS
    cuenta 3, 2, 1 mientras se lo mantiene).
    **Dónde aparece la evidencia (pregunta de Luciano, 16/10/2026):** pidió
    evidencia a la notebook, sacó la foto y en Ajustes no había nada. Es así:
    Ajustes > Fotos de Intrusos muestra los intentos de ESTE teléfono; la
    evidencia que sacan otros equipos queda en la pestaña Evidencias del panel
    y llega por mail. Mejora hecha: `aplicar-mapa-evidencia-panel.ps1` (panel,
    se ve al instante): la tarjeta de cada equipo del mapa trae "Última
    evidencia" (foto que se agranda sobre el mapa y audio con reproductor), y
    al pedir evidencia, cuando llega, la tarjeta baja sola hasta ella; además
    la tarjeta ya no vuelve arriba cada vez que se actualiza. Se aplica sola o
    después de los dibujos (probado en los dos órdenes).
    Aplicados por Luciano el 16/10/2026 (panel): los dibujos de equipos
    (`aplicar-mapa-iconos-panel.ps1`) y la evidencia en la tarjeta
    (`aplicar-mapa-evidencia-panel.ps1`). Falta aplicar
    Foto de Luciano (16/10/2026): la "Última evidencia" funciona (se ve la
    foto) pero **mostraba solo la delantera y el audio no sonaba** (el
    reproductor directo no anda en el visor de la app). Arreglo:
    `aplicar-mapa-evidencia2-panel.ps1` (panel): se ven la delantera y la
    trasera, y el audio pasa a un botón "Escuchar el audio" que lo baja y lo
    reproduce desde la memoria (si no se puede, lo dice; el audio sigue en
    Evidencias del panel). Si aun así no suena en el teléfono, ver qué tipo de
    audio sube la notebook (WAV u otro) y si el servidor lo marca bien.
    `aplicar-barra-ajustes-app.ps1` y hacer la build. Aplicado por Luciano
    el 16/10/2026 también `aplicar-mapa-evidencia2-panel.ps1`.
    **Audio de la evidencia en Android (Luciano, 16/10/2026: "suena en iPhone,
    no suena en Android"):** causas halladas probando en un navegador con la
    política de audio estricta: (1) el reproductor estaba dentro de la tarjeta
    del mapa, que se redibuja cada pocos segundos, y el audio desaparecía;
    (2) el visor de Android solo deja arrancar un audio dentro del toque y
    bajar el archivo tarda. Arreglo (solo panel, sin build):
    `aplicar-mapa-audio-android-panel.ps1` — reproductor propio fijo arriba del
    mapa, con cruz para cerrarlo; en el toque se arranca un silencio de 0,1 s
    para destrabar el reproductor y después se cambia por el audio; si el visor
    no lo arranca dice "Tocá el play para escuchar"; si el audio no se puede
    reproducir muestra tipo, tamaño y código. Si aun así no suena en Android,
    pedir la foto del texto del reproductor (y, de último, poner
    `mediaPlaybackRequiresUserAction={false}` en `MapaEnApp.tsx`, que sí pide
    build). Aplicado y publicado por Luciano el 16/10/2026 (versión
    d4ea403b). Probado por Luciano el 16/10/2026: "ahora sí se escucha" en el
    Android (en el iPhone ya sonaba). **Pedido nuevo
    (hecho y aplicado el 16/10/2026, versión 14725ebb: `aplicar-familia-ordenes-adultos-panel.ps1`):** poder hacer sonar (y ubicar) el teléfono de cualquier familiar,
    como en Buscar de Apple ("a ella le llega una alarma y se da cuenta que la
    estoy buscando"); propuesta enviada: sonar y ubicar para adultos y menores
    (lo pide el titular; la persona oye la alarma y ve un aviso), evidencia y en
    vivo solo equipos propios y menores, amigos afuera. Falta su respuesta
    (1 como propongo, 2 también evidencia y en vivo, 3 solo sonar); es un
    cambio de servidor (`family/command` y `canCommand`) y hay que revisar que
    las apps lo reciban igual que el de un menor.
    Luciano no eligió número pero dijo "falta el sonido y todo lo demás" al
    tocar a "LB iPhone": se tomó la opción 2 (sonar, ubicar, evidencia y en vivo)
    para el TITULAR sobre familiares ADULTOS, siempre con aviso a la persona
    (push y correo, salvo ubicar, quien lo hizo); un adulto no puede pedírselo a
    otro adulto; amigos afuera; con la ubicación pausada solo se puede hacer
    sonar (409 "paused"). Servidor: `familyMinorTarget`, `familyIsTutorOf`,
    `canCommand`, la orden y el en vivo de familia, el correo de la foto y los
    textos del rol Adulto. Las apps no cambian (la orden llega al teléfono
    igual que la de un menor; en el iPhone, sonar es una notificación y la foto
    solo con la app abierta). Probado: las consultas SQL con datos de ejemplo y
    el script contra el espejo del servidor.
    **Hacer sonar en iPhone (Luciano, 16/10/2026):** con la app cerrada y el
    interruptor lateral en silencio no suena (límite de iPhone; falta Apple
    con las Alertas críticas, ID 7R4MM73U2Y); con el interruptor en sonido
    suena la sirena del aviso (28 s) y NO se puede cortar; con la app abierta
    sonaban DOS alarmas (la del aviso y la de la app) y la del aviso no se
    corta. Arreglos preparados: `aplicar-sirena-corta-app.ps1` (app, pide build:
    con la app abierta el aviso de "Hacer sonar" no suena porque ya suena la
    alarma de la app, que sí se detiene; y suma `ojo_sirena_corta.wav`, 10 s
    con fundido) y, para correr DESPUÉS de instalar las builds,
    `aplicar-sirena-corta-panel.ps1` (servidor: el aviso de "Hacer sonar" usa
    la sirena corta y `interruptionLevel: "time-sensitive"`; antes de la build
    de iPhone nueva el iPhone tocaría el sonido común). El script de la
    barra/SOS (`aplicar-barra-ajustes-app.ps1`) y `aplicar-sirena-corta-app.ps1`
    los aplicó Luciano el 16/10/2026; la build de Android con la barra de abajo
    y el SOS cuadradito está instalada y anda (foto del 16/10/2026: la barra
    no se superpone con los botones de Android, el título queda bajo la barra de
    estado, el SOS de 3 s manda la notificación al iPhone). **SOS en iPhone
    (Luciano, "sí", 16/10/2026):** la sirena de aviso del SOS no se corta ni con
    "Estoy bien" y apretar de nuevo la superponía. Se sumó al script del servidor
    `aplicar-sirena-corta-panel.ps1`: sirena de 10 s en iPhone para el SOS (en
    Android sigue la de 28 s, sale del canal de la app) y, si la misma persona
    vuelve a pedir SOS en menos de 40 s (aunque haya cancelado), el aviso
    llega igual, visible y urgente, pero sin sonido (nunca se bloquea). Orden:
    build de iPhone nueva instalada y recién después el script del servidor.
    **Probado por Luciano el 16/10/2026 (iPhone con la build 31, versión 0.9.1,
    instalada por TestFlight; servidor `aplicar-sirena-corta-panel.ps1`
    aplicado, versión a3d65baf):** Hacer sonar desde el Android al iPhone con la
    app abierta suena UNA sola alarma y "Detener sonido" la corta; con la app
    cerrada y el interruptor lateral en sonido suena (también al repetir a los
    segundos); con el interruptor en silencio no suena (límite de Apple, falta
    Alertas críticas); el SOS dos veces seguidas: el primero suena y el segundo,
    a los segundos, llega sin sonido (como se diseñó). El SOS del Android
    (3 s) anda perfecto. **Falta para la próxima build de iPhone:** en el
    iPhone la ✕ de arriba a la izquierda y el ? de arriba a la derecha se
    pisan con la hora y la batería (`closeSettingsButton` y `helpButton` usan
    `top: Platform.OS === "android" ? 18 : 8` y en iPhone, al ser absolutos,
    no cuentan el margen seguro de arriba: sumar `initialWindowMetrics.insets.top`
    de `react-native-safe-area-context`, ya instalado). Pendientes de otro
    lado: Alertas críticas de Apple (ID 7R4MM73U2Y), declaración de condición de
    comerciante (DSA) en App Store Connect (cartel visto el 16/10/2026; la pide
    Apple para enviar apps/actualizaciones a la UE; la decide Luciano o su
    contador) y que "Mapa ›"/tocar a una persona la enfoque en el mapa.
  - [ ] Paso 3: pantalla de inicio "Familia y SOS" (con el SOS grande) y
    "Perfil" (lo que se completa al bajar la app); Configuración pasa a ser la
    del engranaje. Pendiente decidir: si el SOS se puede usar sin pedir clave.
    Decidido el 15/10/2026: la app abre **clara por defecto** (como los
    ejemplos de Luciano: crema, botón SOS rojo grande, tarjeta "Mi Familia",
    engranaje) y el oscuro queda como opción "Modo noche"; el interruptor
    sale del "?" y pasa a "Mi Teléfono y Fondo". Quien ya eligió un tema lo
    conserva (se guarda en `ojo-guard-tema`); solo cambia el de quien nunca
    eligió. La pantalla de guardia sigue oscura.
  - [ ] **Ordenar la consola (panel Ojo Guard MS)** con el mismo método.
    Regla de Luciano (15/10/2026): del pack de Drive ("00. LEER PRIMERO —
    Pack Completo para Programación", imágenes y PDFs) se toma **lo mejor**:
    la estética (crema, tarjetas suaves, botones dorados en pastilla, barra
    superior con pestañas), algunas frases y lo simplificado. Lo que
    se toma, a confirmar con él: pestañas 6 a 4 con Mapa y Familia de inicio;
    login con "Entrar con Passkey / Huella digital" arriba; "Sumar familiar,
    equipo o pulsera/artículo" como un solo botón (app y consola); botones
    de equipo "Pedir foto/audio", "Localizar", "Hacer sonar"; ocultar la
    cámara no disponible; "Permisos de Android: 4/4 OK ✓"; "Todo listo ✓";
    "Guardado automático ✓" (solo en interruptores); "¿Qué hace Ojo Guard
    por vos y tu familia?" en el "?"; panel de soporte con toque largo en la
    versión (app). **No se omite ninguna utilidad que hoy da Ojo Guard**: lo
    que sale de la vista (por ejemplo Detener sonido o Detectar cerca) queda
    en un "Más". Plan: paso 0 `foto-panel.ps1` (copia
    de respaldo + archivos de la pantalla de la consola para subirlos a
    Drive + inventario con huellas), después el inventario de utilidades de
    la consola (como `FOTO-APP-NATIVA-14-10-2026.md`), y de a poco: 4
    pestañas con Mapa y Familia como inicio; Mis Equipos más limpio (las
    explicaciones largas en un "?" que se despliega al tocar, no al pasar el
    mouse, porque el celular no tiene mouse); Evidencias (ocultar el
    recuadro de cámara no disponible); login con Passkey arriba y Cuenta.
    A verificar antes de prometer: si el panel sabe que un equipo está
    sonando (para un solo botón Hacer sonar / Detener sonido), y frases
    como "cifrados" o "métricas de salud" de pulseras. Autoguardado: solo
    interruptores; las claves de 6 números mantienen su botón Guardar.
    - [x] **Paso 1 de la consola: claro por defecto, 4 pestañas**
      (`aplicar-consola-pestanas-panel.ps1`, respaldo `.bak-pestanas`, publica
      solo; aplicado y publicado el 15/10/2026, fotos de Luciano en la compu:
      anda). Decidido por Luciano el 15/10/2026: abre
      claro y el oscuro es "Modo noche" (quien ya eligió un tema lo conserva).
      Pestañas: Mapa y Familia (lo primero que se ve; es el Mapa de hoy), Mis
      Equipos (dispositivos + pulseras + artículos), Evidencias (última e
      historial juntos, con la cantidad) y Cuenta; desaparecen Inicio y los 5
      contadores; la explicación de cada botón de equipo va en un "?" que se
      despliega al tocar; botones en pastilla; en pantalla ancha las pestañas
      van arriba. Probado en un navegador con los archivos reales y datos de
      ejemplo (compu y celular, claro y noche). Siguientes pasos: Mis Equipos
      más limpio (un solo botón sonar/detener cuando el panel sepa el estado
      real, "Más" para lo menos usado, Pedir foto/evidencia también en el
      Mapa), estética de las tarjetas.
    - [ ] **Paso 2 de la consola: barra fija, evidencias, Cuenta, acceso**
      (`aplicar-consola-pestanas2-panel.ps1`, respaldo `.bak-paso2`, publica
      solo; aplicado y publicado el 15/10/2026, versión 4ad88554; falta que
      Luciano lo mire y mande fotos; requiere el paso 1). Fotos del 15/10/2026
      en la compu: barra fija, evidencias sin recuadro vacío y Cuenta en dos
      columnas, andan.
    - [ ] **Paso 2b de la consola: explicaciones al pasar el mouse**
      (`aplicar-consola-ayudas-panel.ps1`, respaldo `.bak-ayudas`, publica
      solo; aplicado y publicado el 15/10/2026, versión 0b7885ea; falta verlo
      en pantalla). Pedido de Luciano: los "?" parecían un problema;
      con mouse o touchpad la explicación del botón aparece al pasar por
      encima (sin símbolo); en celular/tablet queda una "i" chica que la
      despliega al tocar.
    - [ ] **Paso 2c de la consola: calle en vez de coordenadas, "activo hace X"**
      (`aplicar-consola-direcciones-panel.ps1`, respaldo `.bak-direcciones`,
      publica solo; aplicado y publicado el 15/10/2026, versión ef9df11e; falta
      verlo en pantalla). Fotos del 15/10/2026: "Mi teléfono" mostraba
      `-34.579752, -58.4114573` porque la ubicación en vivo llega sin calle
      (`nativeLiveLocation` guarda lo que manda la app). Ahora la
      consola pide la calle a `/api/remote/address` (OpenStreetMap, de a una y
      sin repetir) en Mis Equipos y en el Mapa. Y cuando el equipo está activo
      pero la ubicación es vieja, dice "activo hace 3 min · ubicación hace 23 h".
    - [ ] **Paso 2d de la consola: "Sin conexión" solo sin señales**
      (`aplicar-consola-estado-panel.ps1`, respaldo `.bak-estado`, publica
      solo; aplicado y publicado el 15/10/2026; la foto muestra al iPhone con
      "visto hace 21 min · ubicación hace 23 h" y sin el cartel rojo). Fotos del 15/10/2026 con el 2c: "Mi teléfono" ya
      muestra la calle ("Ugarteche 3167, Palermo") y la Notebook dice "activo
      hace 7 s"; el iPhone seguía en rojo "Sin conexión hace 23 h" aunque se
      había abierto la app 17 min antes. Ahora "Sin conexión" solo sale si no
      hubo ni ubicación ni señal de vida en 3 h; si hubo señal: "visto hace 17
      min · ubicación hace 23 h".
    - [ ] **Paso 3b de la consola: en el celular, la explicación al mantener
      el dedo** (`aplicar-consola-toque-panel.ps1`, respaldo `.bak-toque`,
      publica solo; aplicado y publicado el 15/10/2026, versión 2c66ac8f;
      falta verlo en el celular). Pedido de Luciano al ver las "i" en el
      celular: que al poner el dedo aparezca la observación y no la "i". Mantener
      apretado un cuarto de segundo muestra el globito (queda 2 s después de
      soltar) y NO hace la acción; un toque corto la hace. Probado con toques
      reales simulados (mantener: globito y 0 órdenes; toque corto: 1 orden).
    - [x] **Paso 3 de la consola: Mis Equipos más limpio**
      (`aplicar-consola-equipos-panel.ps1`, respaldo `.bak-equipos`, publica
      solo; aplicado y publicado el 15/10/2026, versión 108f6f90; falta verlo
      en pantalla). A la vista: Solicitar evidencia, Localizar ahora,
      Hacer sonar (pasa a Detener sonido al ejecutarse) y Activar Modo perdido
      (pasa a Desactivar). En "Más acciones": la acción contraria, Detectar
      cerca y Quitar este dispositivo (nada se saca; el estado de sonar y
      Modo perdido es memoria de la pestaña, así que tras recargar la página
      "Detener sonido" queda en "Más acciones"). Falta de la lista: Pedir
      foto/evidencia también en el Mapa, y la estética de las tarjetas.
    - [ ] **iPhone "Sin conexión hace 23 h" en el mapa** (15/10/2026): el
      iPhone tenía 5% de batería en el último reporte y ahora 45% y en uso.
      Hipótesis: se reinició y la app no vuelve sola a mandar datos hasta que
      se abre o se mueve ~150 m (límite de iOS). Prueba pedida: abrir Ojo Guard
      en el iPhone y ver si pasa a "En vivo". Si pasa: cambiar el cartel
      "Sin conexión" por algo más justo ("Última señal hace N h"). Si no pasa:
      investigar la app del iPhone. Resultado de la prueba (15/10/2026): al
      abrir la app el cartel "Sin conexión" desapareció y la batería pasó de
      5% a 50% (el aviso de vida llega), pero la ubicación siguió en "hace
      23 h": con el iPhone quieto, iOS pausa el seguimiento y la app no manda
      punto al abrirse (`familyLocation.ts`: `activar()` solo reanuda el
      seguimiento). Arreglo de la app (va con la próxima build de iPhone,
      aceptado por Luciano): al abrir la app o volver al frente, mandar una
      ubicación actual (`getCurrentPositionAsync`) además de reanudar el
      seguimiento. Script `aplicar-iphone-ubicacion-al-abrir-app.ps1` (solo
      `src/familyLocation.ts`, respaldo `.bak-puntoabrir`; compila con
      `tsc --noEmit` en la prueba; falta aplicarlo y hacer la build de iPhone). Del lado del panel, el paso 2c ya aclara "activo hace X". Lo visto en las fotos
      del paso 1: en la compu la barra de pestañas flotaba sobre el texto al
      bajar y el recuadro "No disponible" de la cámara trasera seguía
      apareciendo. Ahora: la franja de arriba (logo, pestañas y botones) queda
      fija con fondo; las evidencias no muestran recuadros vacíos (la línea
      "Delantera / Trasera / Audio" sigue diciendo qué hay y qué falta); Cuenta
      en tarjetas (correo y protección separadas, dos columnas en la compu);
      acceso con "Entrar con huella o Face ID" arriba de todo (desplegado si ya
      se entró así en ese equipo) y el código por correo justo debajo; en el
      celular el encabezado entra en una línea. Probado en navegador (compu y
      celular, claro y noche) y con la corrida simulada del script.

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
  arreglado el 13/10/2026 con `aplicar-limpieza-pedidos-automaticos.ps1` (el
  cron ya no les crea pedidos a los iPhone y borra los vencidos sin ejecutar de
  más de un día y los automáticos de más de una semana).
- [x] **Panel: nombre de cada teléfono con su marca** (12/10/2026): en el
  mapa y la tarjeta dice "Mi teléfono · Android", "Notebook LB · Windows"; en
  la lista lateral va como etiqueta chica (ANDROID, IPHONE, WINDOWS) para que
  no se corte el nombre (`actualizar-mapa.ps1`, solo panel, sin build).
- [x] **SOS (Familia, etapa C)** (12 y 13/10/2026, aplicado, publicado y
  probado con los dos teléfonos de Lu: botón en la app, gesto de volumen en
  Android, "Estoy bien", sirena en Android por el canal `ojo-sos` y en
  iPhone atravesando No molestar con el aviso urgente; el atajo de
  Siri con el enlace también anduvo el 13/10; falta probar el toque en la
  espalda con el iPhone bloqueado y probar con el iPhone de Mariana). Servidor y panel (`aplicar-familia-sos-panel.ps1` + dos tablas,
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
- [x] **SOS: re-aviso a los 5 minutos** (13/10/2026, aplicado y publicado con
  `aplicar-sos-reaviso-panel.ps1`). Un SOS quedaba "activo" 3 horas en el
  servidor (`SOS_ACTIVE_MS`) hasta que alguien tocara "Estoy bien", y mientras
  tanto otro SOS de la misma persona NO volvía a avisar (solo renovaba la
  ubicación en vivo): un día "no llegaba" al iPhone porque había uno viejo sin
  cancelar. Ahora, pasados 5 minutos del último aviso, un SOS nuevo vuelve a
  avisar con sirena (antes no, para no sonar diez veces por apretar de más) y
  el viejo pasa a estado `reemplazado`. Límite que queda: en iPhone, con el
  interruptor lateral de silencio puesto, el aviso urgente (Time Sensitive)
  pasa No molestar y se ve pero no suena; solo lo atraviesan las Critical
  Alerts (pendiente de Apple, ID 7R4MM73U2Y). En Android no pasa: la sirena
  sale por el volumen de alarma.
- [x] **Revisar mi protección** (13/10/2026, aplicado y probado). Botón en
  Configuración > Familia, arriba del SOS: da un porcentaje (ok vale 1, revisar
  0,5, falta 0; cada cosa pesa 1 o 2) y una lista con avisos, ubicación
  "Siempre", conexión con el servidor, y en Android gesto de volumen (apagado /
  prendido pero caído / funcionando), sirena del canal `ojo-sos` y batería sin
  restricciones; en iPhone el atajo (si alguna vez se abrió el enlace). Cada
  cosa que falta trae un botón a la pantalla del sistema; al volver de Ajustes
  se revisa sola. Lo que la app no puede ver (Concentración del iPhone, el
  interruptor de silencio) queda como nota. Además, en Android avisa con una
  notificación si el gesto figura prendido pero el servicio no responde (máx.
  una vez cada 12 h). Probado: Android 100 % (build 158) e iPhone 86 % y luego
  100 % al usar el atajo. Nativo: `SosAccessibilityService.conectado` e
  `isRunning()` en `SosTriggerModule`. Qué Android no deja: prender o apagar
  solo el servicio de accesibilidad.
- [x] **Dr. Ojo Guard (antes "Mi protección")** (13/10/2026, aplicado con
  `aplicar-dr-ojo-guard-app.ps1`, build 160 de Android instalada y probada).
  Título "Dr. Ojo Guard · 100 %", botón "Hacer chequeo" / "Volver a hacer el
  chequeo", "Chequeo hecho a las…". Item de Android "Auriculares Bluetooth"
  (peso 2, estado revisar si hay audio Bluetooth conectado, con botón "Abrir el
  Bluetooth"; nativo `bluetoothAudio` en `SosTriggerModule`) y botón "Probar la
  sirena" (alarma local por el canal `ojo-sos`, `probarSirena` en
  `sosTask.ts`). Probado: con los auriculares PLT_Legend conectados (0 % de
  batería, pero Android los tomaba como conectados) da 91 % con el aviso y la
  sirena de prueba no se oye; al desconectarlos vuelve a 100 % y suena. Salió
  de que el 13/10 los avisos no sonaban en el Android por esos auriculares. El
  iPhone recibe el nombre nuevo en su próxima build.
- [ ] **Texto del botón "Que la sirena suene con No interrumpir"** (13/10/2026,
  Lu creyó que hacía sonar la sirena; solo abre los ajustes del canal): en
  `SosBlock.tsx` cambiarlo por "Abrir los ajustes de la sirena" y aclarar que la
  prueba de sonido es "Probar la sirena" del Dr. Ojo Guard. Para la próxima
  actualización de la app.
- [x] **SOS: tocar el aviso lleva al mapa + Configuración como acordeón**
  (13/10/2026, aplicado: panel publicado con `aplicar-sos-mapa-panel.ps1` y app
  con `aplicar-sos-mapa-configuracion-app.ps1`; builds de Android y iPhone
  instaladas). El aviso del SOS lleva `data: { type: "sos", personId, name,
  latitude, longitude }`; `sosMapa.ts` abre Apple Maps en iPhone / Google Maps
  en Android con la ubicación más nueva de la persona al tocar el aviso (con
  la app abierta, en segundo plano o cerrada, sin repetirse). `Plegable.tsx`
  pliega "Mi protección" y las instrucciones del SOS (el botón rojo queda a la
  vista), y Configuración pasa a acordeón en `App.tsx` (`CollapsibleSection`
  con `useSeccionAbierta`: todo cerrado, abrir una cierra las otras, solo la
  primera con `defaultOpen` arranca abierta, la guía de Android solo en el
  primer arranque, `maintainVisibleContentPosition`). También arregla el texto
  cortado del botón rojo. Probado: en el iPhone, tocar el aviso abre Apple Maps
  con el pin. Falta probar: Google Maps en el Android, y que el scroll no salte
  al abrir una sección con otra larga abierta arriba.
- [ ] **Pruebas del SOS que faltan** (14/10/2026): (1) SOS del iPhone al Android
  con el Bluetooth apagado y el teléfono bloqueado, para confirmar que suena la
  sirena y que al tocar el aviso abre Google Maps (en el iPhone ya se probó que
  abre Apple Maps); (2) "Tocar atrás" con tres toques en el iPhone bloqueado
  (¿pide Face ID?, ¿cuánto tarda?); (3) probar con el iPhone de Mariana.
- [ ] **SOS del iPhone que no llegó al Android** (13/10/2026, 16:02): el
  servidor lo guardó (`family_sos` + `family_sos_to` con
  `bickluciano@gmail.com`) y después sí llegó el aviso "canceló el SOS", pero el
  aviso del SOS no apareció ni sonó. `probar-sos-android.ps1` mandó 3 avisos con
  el mismo formato del SOS (canal `ojo-sos`, datos del mapa) y Expo confirmó la
  entrega de los 3: el camino Expo-Google-Android anda. El Android tenía el
  modo "Ojo guard" (Modos) puesto a propósito: permite las alarmas y las
  notificaciones de Ojo Guard, así que no era eso. El SOS real de las 16:34
  llegó (Expo entregó, recibo ok) pero mudo; los 3 avisos de prueba también
  llegaban mudos, hasta que se apagó el Bluetooth (había unos auriculares
  PLT_Legend conectados): ahí el aviso sonó. Falta repetir el SOS real del
  iPhone con el Bluetooth apagado para confirmar que suena y que al tocar el
  aviso abre Google Maps. El primer SOS de las 16:02 no apareció nunca en el
  Android y no hay registro (el registro de SOS se agregó después). Para ver qué dice
  Expo de cada SOS, `aplicar-sos-registro-panel.ps1` anota cada aviso de SOS
  en `push_log` y `ver-registro-avisos.ps1` muestra el ticket y el recibo. El
  atajo del iPhone quedó armado (acción "Abrir direcciones URL" con el enlace
  `ojoguard://sos?k=…`, nombre "SOS Ojo Guard") y manda el SOS; falta probar
  el "Tocar atrás" con tres toques y el iPhone bloqueado (Face ID).
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
- [ ] **IDEA (17/10/2026, caso real): "Referentes de emergencia" / caja negra
  del celular.** Luciano contó que un chico de 16 años desapareció saliendo de un
  boliche, con el celular sin batería y sin ninguna app de ubicación vinculada,
  así que la familia no tiene cómo saber dónde estuvo por última vez. Pidió pensar
  una lista de referentes que reciban la última ubicación del celular, elegida de
  antemano por la propia persona "por las dudas". Propuesta para charlar (todavía
  sin decidir ni construir): la persona elige 1 a 5 referentes; en el día a día
  nadie ve nada; el teléfono manda de a poco puntos de ubicación (solo cambios
  grandes, poca batería) y el servidor se queda con el último; los referentes
  reciben (1) aviso de batería baja con la última ubicación, (2) aviso de "sin
  señal hace N horas" con la última ubicación, y (3) un botón "Pedir última
  ubicación" que deja registro y le avisa a la persona. Va como un rol nuevo de
  Familia ("Referente", visibilidad solo en emergencia). Cuidados: lo activa la
  propia persona (también un menor, con sus padres al tanto), lista visible de
  quién tiene acceso, registro de cada consulta, qué datos se guardan y por cuánto
  tiempo. Límites técnicos: en iPhone hace falta permiso de ubicación "Siempre";
  no se puede mandar nada cuando el celular ya se apagó, por eso el servidor tiene
  que tener siempre el último punto.
  **Regla automática (Luciano, 17/10/2026):** que el aviso salte solo cuando
  coinciden varias señales: hace mucho que el teléfono no se conecta, está lejos
  de su residencia, batería baja y horario raro (21 a 06). Propuesta: puntaje de
  4 señales (sin reportar: 90 min de noche / 6 h de día; lejos: más de 3 km de
  Casa y fuera de sus Lugares; batería menor o igual a 15 %; horario 21 a 06,
  configurable); con 2 señales un "¿Estás bien?" a la propia persona (botón
  "Estoy bien" que ya existe en el SOS) y un ping de ubicación; con 3 o más y sin
  respuesta en 15 min, aviso a los referentes con la última ubicación, la hora y
  la batería, repetido cada 30 min y con "Ya reconectó" cuando vuelve. Se evalúa
  en el servidor con el cron de 15 min que ya existe (el teléfono apagado no
  puede avisar solo). Los referentes pueden ser solo un mail (sin app) con un
  enlace al mapa. Anti falsas alarmas: Lugares seguros (casa de un amigo),
  "esta noche duermo afuera" (pausa por horas), cada referente puede silenciar.
- [ ] **Alertas críticas de Apple.** **Enviado el 09/10/2026 a las 17:3x.
  Request ID: 7R4MM73U2Y.** Esperar el mail de Apple (puede tardar semanas);
  **17/10/2026: no hay ningún mail de Apple sobre esto** (en iCloud solo están
  los del contrato de desarrollador del 15/09/2026) **y Apple no tiene pantalla
  de estado**. Texto para escribirle a soporte ya preparado en
  `scripts/TEXTO-APPLE-ALERTAS-CRITICAS.md`; Luciano pidió mandarlo si a los 4
  días (**21/10/2026**) no pasó nada (recordatorio agendado para ese día).
  Mientras tanto mirar developer.apple.com → Identifiers → `app.ojoguard.mobile`
  → Capabilities por si "Critical Alerts" aparece para tildar. Antes decía: si en 2 o 3 semanas no hay respuesta, volver a enviarlo con los mismos
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
