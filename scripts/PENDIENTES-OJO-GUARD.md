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
  **Caso robo (Luciano, 17/10/2026): "lo robaron y a los 5 minutos apagaron el
  celular".** Ninguna app puede mandar nada después de apagado ni interceptar el
  apagado en iPhone (en Android es poco confiable): hay que tener el dato ANTES.
  Ideas: (1) reporte adaptativo: con señales de riesgo (sacudón fuerte, velocidad
  de vehículo, de noche, lejos de casa) pasar a un punto cada 10 a 20 s y que el
  servidor guarde los últimos 30 minutos (rumbo y velocidad aunque lo apaguen);
  (2) detectar el arrebato (aceleración brusca + movimiento rápido) y mandar
  ya el aviso a los referentes; (3) la intención del silencio importa: silencio
  repentino con batería ALTA y en movimiento = apagado a mano o robo, alertar en
  5 a 10 minutos; silencio con batería muy baja = probable batería muerta, más
  espera (90 min de noche); (4) foto del intruso y captura silenciosa en Android
  (ya existen) mandadas al instante ante un intento de desbloqueo fallido (a
  decidir por privacidad); (5) recomendar lo del sistema, que sigue funcionando
  apagado: iPhone "Buscar" con la red de Buscar y Protección de dispositivo
  robado; Android "Encontrar mi dispositivo / Find Hub" y el bloqueo por
  detección de robo (según modelo y versión).
  **Nombre y botones (17/10/2026), en borrador:** la función se llamaría "por las
  dudas"; los que reciben el aviso, "referentes"; el resultado, "última señal".
  Luciano aclaró que quien se perdió nunca va a apretar nada: el que actúa es el
  referente preocupado, que NO está en el círculo familiar. Botón del referente:
  "No lo encuentro" (en una página web simple, sin app, a la que llega por el
  mail con que se lo eligió y que acepta; con código o enlace personal). Al
  apretarlo: (1) se le manda a la persona un "¿Estás bien?" a su teléfono; (2) si
  se cumplen las condiciones que la persona dejó permitidas (por ejemplo sin
  señal hace X, lejos de casa, batería baja o apagado en movimiento, horario
  21 a 06) se muestra la "Última señal" con el mapa, la hora y la batería; (3) si
  no se cumplen, se le dice "su teléfono se está reportando con normalidad; le
  mandamos un ¿estás bien?" y se vuelve a mirar a los 30 minutos. Todo consulta
  queda registrada y la persona la ve después. Sin botón nuevo de ayuda: el SOS
  existente también avisa a los referentes. Botón en Ajustes: "Elegir
  referentes" dentro de la tarjeta "Por las dudas"; pausa: "Esta noche, afuera".
  **Decidido el 17/10/2026:** el primer paso del botón "No lo encuentro" es el
  "¿Estás bien?" a la persona; si el referente marca "es una emergencia" y pasaron
  unas 3 horas sin señal, se muestra la última señal aunque no se cumplan todas
  las condiciones. Especificación completa y plan de primera versión (solo servidor
  y panel, sin build) en `scripts/POR-LAS-DUDAS-ESPECIFICACION.md`.
  **Primera parte armada (17/10/2026), sin instalar todavía:**
  `aplicar-por-las-dudas-panel.ps1` (código y pruebas en `scripts/por-las-dudas/`; hoy 54).
  Páginas `/por-las-dudas`, `/referente` y `/estoy-bien`, cuatro tablas `pld_*`, botón
  "No lo encuentro" con el "¿Estás bien?", condiciones, emergencia, apagado en movimiento
  con batería alta, lugares seguros, pausa y registro. Probado con una base SQLite en
  memoria y un navegador real; NO probado contra el servidor verdadero ni con teléfonos
  reales. Falta la segunda parte (avisos automáticos del cron, pantalla en la app, tutor
  que administra a un menor).
  **Instalada y publicada por Luciano el 17/10/2026 (versión 6bb4d53a):** las cuatro
  tablas `pld_*` creadas en la base y las páginas en el servidor; falta que la pruebe
  (`https://ojo-guard-ms-api.bickluciano.workers.dev/por-las-dudas`).
  **17/10/2026, primera prueba:** la página abre y muestra "Entrá primero al panel": ese
  navegador no tenía la sesión del panel (cookie `ojo_ms`). Mejora preparada:
  `aplicar-por-las-dudas-pagina-panel.ps1` (contenido bloqueado hasta que carguen los
  datos y tarjeta "Falta entrar al panel" con botón "Entrar al panel"). Idea: un acceso a
  esta página desde el panel y desde la app (hoy hay que escribir la dirección). Aplicada y publicada por
  Luciano el 17/10/2026 (versión 312f5d90); falta que cuente cómo se ve.
  **17/10/2026, segunda prueba:** Luciano cargó las condiciones y eligió un referente, y
  **"No me llegó"** el mail de invitación (hasta ahora la página decía "Listo" aunque el
  mail fallara; puede ser Spam o un fallo de Resend, hay que mirar). Arreglo preparado:
  `aplicar-por-las-dudas-enlace-panel.ps1` (al elegir o reenviar, la página dice si el mail
  salió o falló y muestra el enlace personal del referente con "Copiar enlace" y "Mandar por
  WhatsApp"; el enlace solo se le muestra a quien entró al panel). 54 pruebas y navegador
  real ok. Cuando esté aplicado: reenviar al referente, abrir el enlace en otro navegador,
  aceptar, apretar "No lo encuentro" y seguir con "¿Estás bien?" → "Estoy bien".
  Para saber por qué no llegó el mail: mirar Spam y el panel de Resend (resend.com → Emails);
  si el dominio de `MAIL_FROM` no está verificado, Resend solo deja mandar a la cuenta dueña.
  **Enlace aplicado y publicado por Luciano el 17/10/2026** (versión 01b74d7c). Luciano: "tampoco
  veo que en ningún lado diga No lo encuentro". Es a propósito (el botón lo ve solo el referente,
  en su enlace, después de aceptar), pero la página no lo explicaba: parche
  `aplicar-por-las-dudas-donde-panel.ps1` agrega ese texto bajo "Tus referentes". Idea para
  después: un botón "Ver cómo lo ve mi referente" en la página de la persona (hoy, una vez que el
  referente aceptó, el enlace ya no se puede volver a mostrar porque solo se guarda su hash).
  **17/10/2026 16:35 a 16:36, validado con mails reales (capturas de Luciano):** el referente aceptó
  ("aceptó ser tu referente") y apretó "No lo encuentro" ("quiere saber si estás bien", con botón "Estoy
  bien"). Los dos mails llegaron, así que Resend manda bien. Luciano: "yo no acepté nada en ningún
  momento" y Mariana dice que no le llegó ningún mail. **Registro del servidor (hora UTC, Argentina
  es 3 h menos):** 19:34:44 se sumó a MARIANA FLOMBAUM (correo `marinaflombaum@gmail.com`: ojo, "marina"
  y no "mariana", puede ser un error de tipeo o su mail real, a confirmar), 19:35:08 y 19:35:10 se
  reenvió el enlace (dos veces seguidas), 19:35:52 aceptó (42 s después), 19:36:04 apretó "No lo
  encuentro". Esos tiempos coinciden con los pasos que se le dieron a Luciano para probar (Reenviar,
  abrir el enlace en otro navegador, Aceptar, No lo encuentro), así que casi seguro lo hizo él probando.
  En el código lo único que acepta es abrir el enlace personal y tocar "Aceptar ser referente".
  Si el correo del referente estuviera mal escrito, hay que "Quitar" ese referente (el enlace deja de
  servir) y elegirlo de nuevo con la dirección correcta. Para probar solo: otro referente con otro mail propio.
  **Confirmado por Luciano: el mail correcto es `marianaflombaum@gmail.com`** (se había cargado
  `marinaflombaum`, sin la "a"), así que el enlace fue a otra dirección. "Quitar" lo mata (el código
  rechaza los enlaces de referentes dados de baja) y el Registro muestra una sola consulta (la suya),
  o sea que nadie más lo usó. Protección preparada: `aplicar-por-las-dudas-correo-panel.ps1` (al elegir un
  referente, la página muestra el mail completo y pide confirmar letra por letra; trae también el texto de
  dónde está "No lo encuentro" si todavía no estaba). Idea para más adelante: que el mail de invitación avise
  a quien lo recibe por error cómo avisar que no es para él.
  **Aplicada y publicada por Luciano el 17/10/2026** (versión 513cfddf, los dos cambios). Falta: quitar al referente
  con el mail mal escrito, elegir a Mariana con `marianaflombaum@gmail.com`, que ella acepte desde su teléfono y probar
  la última señal.
  **17/10/2026 ~17:30:** Luciano quitó al referente con el mail mal escrito (17:14) y cargó a Mariana con su mail
  correcto (como "mama", 17:15): **ella aceptó desde su teléfono** (la página la muestra "aceptó"). Con las
  condiciones de prueba (noche 0 a 23, 2 de 4), la tarjeta "Cómo estás hoy" dio solo 1 señal (de noche): la batería
  del teléfono es 77 % (el máximo configurable es 50). Para llegar a 2: silencio de 10 min (ponerlo en las dos
  casillas de silencio y modo avión 12 min). Falta: que Mariana apriete "No lo encuentro" y se vea la última señal;
  después "Estoy bien". Luciano preguntó: "el enlace no se le va? si lo pierde?". Hoy el enlace no vence y
  queda en el mail que recibió el referente (dice "Guardá este mail"); si lo pierde, antes había que
  "Quitar" y elegirlo de nuevo. Parche preparado: `aplicar-por-las-dudas-reenviar-panel.ps1` (botón "Mandar
  enlace de nuevo" también para quien ya aceptó: pide confirmar, el enlace anterior deja de servir; y
  "1 minuto" en singular). Idea más adelante: que el referente pueda instalar su enlace como ícono en el celular
  y que desde la app el dueño le pueda mandar el enlace con un toque.
  **Aplicado y publicado por Luciano el 17/10/2026** (versión 16aff6c9). Sigue: la prueba de la última señal con
  silencio (sin usar todavía "Mandar enlace de nuevo", porque deja sin efecto el enlace que Mariana ya guardó).
  **18/10/2026 por la mañana:** la prueba de la última señal con Mariana NO se completó (a las 20:26 del 17/10 la tarjeta
  decía "2 de 4" con el teléfono sin señal 22 min, pero el Registro no muestra ningún "No lo encuentro" de ella después
  de las 20:02). Luciano quitó a "mama" (10:43) y la probó solo con "PAPA" = su otro mail (hotmail): se sumó 10:44:25,
  "Reenviar" a las 10:44:36 (por eso llegaron DOS mails iguales a las 10:44: no es un error del servidor, son dos envíos;
  el segundo deja sin efecto el enlace del primero) y aceptó a las 10:48:59. Idea: en el mail de un reenvío decir "si te
  llegaron dos mails, usá solo el último". Sigue pendiente ver la última señal y probar "Estoy bien".
  **18/10/2026 11:02: PROBADO OK con PAPA (su otro mail):** con el teléfono apagado y "2 de 4", el referente vio "Última señal de
  Lu" (10:45, batería 75 %, mapa). Los mails "quiere saber si estás bien" y "consultó tu última señal" llegaron al Gmail del DUEÑO
  (no al del referente). Cosas para pulir: (1) la última señal sale "Sin dirección" (mostrar coordenadas), (2) "pasaron más de 1
  horas" (plural), (3) el aviso del teléfono dice "Abrí tu correo..." y muchos chicos no miran el mail: cambiar el texto ya, y en
  la próxima build de la app que tocar el aviso abra una pantalla con "Estoy bien" (no depender del mail), (4) el mail de
  invitación debe mostrar también el enlace escrito debajo del botón, (5) Luciano preguntó por un aviso AUTOMÁTICO ("se
  cumplieron 2 de 4") al referente: es la segunda parte (cron), todavía no existe; para que cada mail al referente lleve su
  enlace hay que cambiar a enlaces que el servidor pueda volver a armar (hoy solo se guarda una huella del enlace). Propuesta
  hecha a Luciano, esperando su sí.
  **18/10/2026, Luciano dijo SÍ al aviso automático** (y pidió arreglar Twilio: "por ahí no hay mucho que pagar"). Armado:
  `aplicar-por-las-dudas-cron-panel.ps1` (segunda parte de Por las dudas: cron de 15 min, "¿Estás bien?" → a los ~15 min mail a los
  referentes con su enlace → cada ~30 min hasta 4 → "volvió a dar señal" / "Estoy bien" corta; apagado en movimiento avisa enseguida;
  enlaces firmados que el servidor puede rearmar, "Reenviar" manda el mismo enlace, enlace escrito en los mails, coordenadas si no
  hay calle, "1 hora", aviso del teléfono sin "abrí tu correo"). 103 pruebas y navegador ok; instalador por bloque con huella SHA-256.
  Sin instalar todavía. Al probarlo con las condiciones de prueba (10 min, 2 de 4) puede avisar seguido: al terminar volver a
  noche 21 a 6, silencio 90/360, 3 de 4. **Twilio:** pasos dados a Luciano (Upgrade en console.twilio.com, saldo inicial, permisos
  geográficos de Argentina; SMS a Argentina ≈ USD 0,10 por mensaje según la página de precios de Twilio); falta que lo haga y probar un SMS.
  **19/10/2026, CORRECCIÓN (leído en el Gmail de Luciano, con su permiso):** el mail "Thank you for taking the first step…" que pegó era el de
  confirmación de envío del 15/09/2026, no uno nuevo; el **Business Profile ya estaba APROBADO el 16/09/2026** (bundle BU3e73…), no hay revisión en
  curso. El problema real es otro: ver la entrada de Twilio más abajo. No pegar nunca el Auth Token ni datos de tarjeta.
  **Aviso automático instalado y publicado por Luciano el 18/10/2026** (versión 3f36abcd; código reconocido por la huella, tabla
  `pld_episodios` creada, hook en `scheduled`). Falta probarlo con el teléfono apagado (cron :00/:15/:30/:45) y después volver a las
  condiciones reales (noche 21 a 6, silencio 90/360, 3 de 4).
  **18/10/2026 12:45:** el aviso automático abrió el episodio a la hora esperada (mail "¿Estás bien? Hace rato que no tenemos señales de tu
  teléfono"); un "Estoy bien" tocado a las 11:47 había cortado el primer intento (correcto). Aprendido: después de reiniciar un teléfono la
  app no manda señales hasta que se abre una vez (revisar en la próxima build). El mail "Mi teléfono dejó de responder" (12:15) es la
  vigilancia de silencio que ya existía, independiente. Falta ver el aviso a PAPA (cron de las 13:00), "No lo encuentro" con ese enlace,
  y el final "volvió a dar señal".
  **Pedido de Luciano (18/10/2026):** su papá tiene problemas y quiere poder cuidarlo "como a un niño" o como persona mayor: ya está su
  teléfono instalado con su propio usuario. Hoy el titular puede sonar/ubicar/foto y audio/en vivo sobre un familiar ADULTO (con aviso
  a la persona) y, si el rol es Menor, también los otros adultos de la familia. Falta (pendiente): que el tutor administre el "Por las
  dudas" de la persona cuidada (hoy cada cuenta administra el suyo en /por-las-dudas), y revisar el tema legal/de consentimiento con un
  abogado cuando sea una persona mayor con problemas.
  **18/10/2026, teléfono Android del papá de Luciano:** al ingresar la clave de administrador la app muestra "Configurá un acceso seguro. Para abrir
  Modo Seguro, primero configurá huella, rostro o PIN de bloqueo en este teléfono." porque el teléfono no tiene ningún bloqueo de pantalla (no hay
  PIN para escribir). Luciano eligió **B: no abrir esa pantalla en ese teléfono** y administrarlo desde su panel/teléfono. Para una próxima build:
  opción de permitir la configuración sin bloqueo en un teléfono marcado como "de una persona cuidada" (hoy es una protección), y que un
  teléfono de una persona mayor no registre intentos de clave incorrecta con foto si ella toca la pantalla sin querer.
  **Aclaración de Luciano (19/10/2026): da por buena la prueba de Por las dudas** ("eso está ok"); lo que deja para otro día es el teléfono de su
  papá (hoy le instaló la app pero tuvo que irse y su papá no sabe entrar a su Gmail). Nota honesta: nunca se vio en pantalla el mail del cron a
  PAPA ("Lu lleva rato sin dar señales") ni el final "volvió a dar señal"; están cubiertos por las pruebas con base simulada.
  **Decisiones de Luciano (19/10/2026):** (1) **hacer que el SOS también avise a los referentes** (solo servidor); (2) no le gusta el nombre
  "Por las dudas": quiere uno más preciso, propone **"Guardián"** (a confirmar; las personas serían "guardianes"); (3) idea nueva: **"Camino seguro"**
  (cuenta regresiva hasta llegar a un destino con aviso a los guardianes), ver `scripts/GUARDIAN-CAMINO-SEGURO-IDEA.md`.
  **SOS -> referentes: armado el 19/10/2026** (`aplicar-por-las-dudas-sos-panel.ps1`, sin build; 117 pruebas): al apretar el SOS, mail a los referentes
  que aceptaron con la ubicacion, el mapa, el aviso del 911 y su enlace; si se cancela, se les cuenta; una persona sin familia pero con referentes ya puede
  mandar el SOS; no depende de la pausa; si de que Por las dudas este encendido. Engancha tres lineas dentro de `nativeFamilySos` (anclas leidas del codigo
  real que pego Luciano). Falta decidir el nombre ("Guardian"); cuando se confirme es un parche de textos.
  **Instalado y publicado por Luciano el 19/10/2026** (version 6d0ce488). Falta probarlo: SOS de 3 s con el telefono de Luciano (llega a PAPA = su Outlook) y cancelar.
  **Aclaración de Luciano (19/10/2026): el SOS NO cambia de nombre.** "Guardián" reemplaza solo a "Por las dudas" (la función de referentes). Parche de
  textos pendiente: título y encabezado "Guardián", pie de los mails "ojo guard · guardián", dirección corta `/guardian` (la de `/por-las-dudas` sigue),
  sin tocar nombres internos (tablas, funciones, rutas de la API).
  **Aclaración posterior de Luciano (19/10/2026), que reemplaza lo anterior:** las personas se siguen llamando **referentes** (una sola lista para todo);
  **SOS** es el botón manual (avisa a familia y referentes); **"Guardián"** es el servicio de acompañarte en el camino (cuenta regresiva hasta llegar,
  avisa a los referentes); la función actual que avisa sola ("Por las dudas") necesita otro nombre: propuesta **"SOS automático"** (esperando su sí;
  alternativas "Aviso automático", "Si dejo de responder"). Cuando confirme: parche de textos (título, encabezado, pie de los mails, dirección corta).
  **Estructura final propuesta por Luciano (19/10/2026), que reemplaza lo anterior:** **Guardián** es el servicio, con UNA lista de referentes y dos funciones que
  se prenden o apagan (una, las dos o ninguna): **"Por las dudas"** (avisa sola si la persona deja de responder; se conserva el nombre, con subtítulo) y la de
  acompañar el camino (nombre propuesto: **"Acompañame"**; alternativas "Camino seguro", "Llegada segura"). El SOS queda aparte (siempre a mano) y avisa a
  familia y referentes. Plan: (1) dejar Por las dudas en uso real unos días; (2) página `/guardian` (referentes arriba, dos tarjetas con interruptor,
  "Acompañame" como "Próximamente"); (3) versión web de Acompañame (cuenta regresiva en el servidor, cron de 1 minuto, "Llegué" y "Extender"); (4) build de
  la app (Estoy bien desde el aviso, seguimiento y llegada automática, app que se despierta tras reiniciar). Esperando su sí al paso 2 y al nombre.
  **Idea de Luciano (19/10/2026), a confirmar:** un ícono **"OG"** como entrada a "Mi Guardián"; al tocarlo/pasar el mouse muestra abajo los dos modos:
  **"Modo Guardián"** (el que vigila siempre: lo que hoy es "Por las dudas") y **"Modo Cautela"** (el que se activa para un camino o situación; cuenta
  regresiva). Mismos referentes para los dos y para el SOS. Mi opinión: los nombres van siempre visibles bajo el ícono (en el celular no hay mouse), el ícono
  muestra el estado (gris / dorado / ámbar con aro de cuenta regresiva), y evitar el doble uso de "Guardián" (servicio y modo). Falta su confirmación de
  qué es cada modo y un comando de lectura para ver la barra superior del panel (para el botón OG que abra `/guardian`).
  **Corrección de Luciano (19/10/2026), esta es la versión vigente:** **Modo Guardián = acompañarte en el camino** (lo activás vos; cuenta regresiva;
  avisa a los referentes) y **Modo Cautela = lo que hoy es "Por las dudas"** (de fondo; si dejás de responder avisa; "cautela" = precaución, "por las
  dudas"). Referentes compartidos; SOS aparte. Plan: renombrar en páginas y mails "Por las dudas" → "Modo Cautela" (subtítulo "Por las dudas: si dejo de
  responder, mis referentes se enteran"), página `/guardian` (referentes arriba + tarjetas "Modo Cautela" activo y "Modo Guardián" próximamente), botón OG en el panel.
  **Armado el 19/10/2026 (sin instalar):** `aplicar-guardian-modo-cautela-panel.ps1` (123 pruebas y navegador ok): la página pasa a llamarse **"Tu protección"** (abre en
  `/guardian` y en `/por-las-dudas`), con tus referentes arriba, el **Modo Cautela** (cómo estás hoy, condiciones, pausa), la tarjeta **"Modo Guardián · Próximamente"** y
  el registro; el pie de los mails dice "ojo guard · modo cautela". OG = iniciales de Ojo Guard (confirmado por Luciano). **Falta el botón OG dentro del panel**:
  necesito que corra el comando de lectura de la barra superior (buscar "Mis dispositivos|Cerrar sesi|topbar|ogm-capas" en `src`).
  **Instalado y publicado por Luciano el 19/10/2026** (versión 793617a0): la página ya es "Tu protección" y abre en `/guardian`. Falta que mande una captura y el comando de la barra superior.
  **Botón OG armado (19/10/2026, sin instalar):** `aplicar-og-panel.ps1` (barra superior en `src\panel-index.html` + estilos en `src\panel-explanations.css`): solo se ve con la sesión
  abierta; con el mouse encima dice "Modo Guardián · Modo Cautela"; al tocarlo abre un menú con los dos modos y "Abrir Tu protección" (→ `/guardian`); en el celular el menú queda pegado al
  borde derecho. Probado en una maqueta en el navegador (celular y compu). **Instalado y publicado por Luciano el 19/10/2026** (versión 5aa32542); en el panel real (foto de Android, 19/10/2026) el OG se superponía con el nombre "ojo guard" y "Modo noche" / "Cerrar acceso" no entraban. **Arreglo armado (sin instalar):** `aplicar-og-arreglo-panel.ps1` (respaldo `.bak-og2`, un solo cambio en `src\panel-explanations.css`): hasta 560 px la barra pasa a dos filas (arriba el nombre; abajo, a la derecha, OG · Modo noche · Cerrar acceso) y el menú del OG se abre debajo, adentro de la pantalla. Probado en maqueta a 360 / 390 / 1100 px sin superposiciones; falta una foto del panel real tras Ctrl+F5. Luego: que el ícono muestre el estado (gris / dorado / ámbar con aro de cuenta regresiva) cuando exista el Modo Guardián.
  **Pausar o apagar (pedido de Luciano, 19/10/2026): armado, sin instalar** (`aplicar-pausar-apagar-panel.ps1`, respaldo `.bak-pldpausa`, solo servidor, sin build; 149 pruebas y navegador ok).
  Lo que pidió: en la tarjeta "Esta noche, afuera" (solo "Pausar 8 horas" y "Quitar pausa") quiere también "Pausar 12 horas", poder dar otro tiempo, y una opción para
  que la función quede desactivada. Hecho: la tarjeta pasa a llamarse **"Pausar o apagar"** (8 / 12 / 24 horas, "Otro tiempo" de 1 a 72 horas, "Quitar pausa", y dice hasta cuándo);
  un botón **"Apagar / Encender Modo Cautela"** (pregunta antes de apagar) reemplaza el casillero que estaba dentro de Condiciones; arriba de la tarjeta dice si está encendido, en
  pausa hasta tal hora o apagado; el registro anota todo. Extra por seguridad: si al pausar o apagar ya se les había avisado a los referentes, el aviso se cierra y se les cuenta
  por mail, y al terminar la pausa empieza de cero con el "¿Estás bien?" a la persona. **Pregunta abierta (sí/no):** hoy, con el Modo Cautela APAGADO, el SOS tampoco avisa a los
  referentes (con la pausa sí avisa). ¿Querés que el SOS avise a los referentes aunque el Modo Cautela esté apagado? Mi recomendación: sí.
  **OG en el celular, ya sin superponerse (fotos de Luciano, 19/10/2026; instalado `aplicar-og-arreglo-panel.ps1`, versión 6daba84e).** Pedidos nuevos: OG **debajo del logo, en la misma fila que
  Modo noche / Cerrar acceso, y más importante**; menú negro **más ancho** para que no quede una palabra sola abajo. Armado, sin instalar: `aplicar-og-importante-panel.ps1` (respaldo `.bak-og3`, solo panel,
  dos archivos): OG dorado macizo con sombra (abierto se invierte), a la izquierda de la segunda fila; menú de todo el ancho en el celular (hasta 380 px en compu); texto de Modo Cautela acortado
  ("Si dejo de responder, mis referentes se enteran."). Ojo: en el panel real la regla `.ghost` pisaba los colores del OG (se veía gris, no dorado); por eso el estilo nuevo es más específico y usa `!important`.
  **Decisiones de Luciano (20/10/2026):** (1) **el SOS avisa a los referentes SIEMPRE**, aunque el Modo Cautela esté apagado ("sí" a la pregunta abierta); (2) **un usuario menor solo puede ver, no editar**
  ("con usuario de mayor de edad sí; si es menor no podría tocar, solo para ver sin editar"): los datos (referentes, condiciones, pausa, apagar) los completa el **administrador de la familia (el titular)**.
  **Armado, sin instalar:** `aplicar-menores-solo-ver-panel.ps1` (respaldo `.bak-pldmenores`, solo servidor, 183 pruebas y navegador ok): el menor ve su página en modo solo lectura (campos bloqueados, aviso "Esto lo completa
  el administrador de tu familia" y el servidor responde 403 `solo_administrador` a cualquier cambio); un adulto arma la suya; el titular ve un selector "Estás viendo la protección de: Yo / Tomi" (`/guardian?persona=correo`)
  y arma la de cada **menor activo** de su familia (referentes aparte por persona; el mail al referente usa el nombre del menor); no puede armar la de un adulto, de otra familia ni dado de baja. Para la persona cuidada
  (papá) vale lo mismo si se le pone el rol **Menor** en Cuidados. Sin tocar tablas. Los textos de la página siguen en segunda persona ("tus referentes"); arriba aparece un cartel que explica de quién es. Pendiente a decidir: si los
  otros adultos de la familia (no solo el titular) también pueden armar la de un menor, y la pantalla equivalente en la app.
  **Adultos de la familia como administradores (Luciano, 20/10/2026):** "puede pasar que el padre viaje y el hermano mayor lo cuide; mientras sea plan familiar, sí" → responde la pregunta abierta: **los otros adultos
  de la familia también arman la protección de un menor** (no solo el titular). Armado, sin instalar: `aplicar-menores-adultos-panel.ps1` (respaldo `.bak-pldadultos`; incluye el de menores, acepta cualquiera de las
  cinco versiones anteriores; 188 pruebas y navegador ok): un adulto activo de la familia ve a los menores en el selector y arma sus referentes / condiciones / pausa / encendido; no vale para adultos, otra familia ni dados de
  baja; en el registro del menor queda **quién hizo cada cambio** ("hermano@correo.com (administrador de la familia) agregó un referente."). **Falta:** atarlo al **plan familiar** cuando existan planes (hoy el servidor no tiene
  planes: vale para toda familia armada); y la pantalla equivalente en la app.
  **Instalados y publicados por Luciano el 20/10/2026:** `aplicar-menores-solo-ver-panel.ps1` (versión ff75e6cd) y `aplicar-menores-adultos-panel.ps1` (versión ce55568d, código reconocido de 78585 caracteres). Falta probarlo en vivo con una persona con rol Menor
  (por ejemplo el papá en Cuidados) y que **encienda el Modo Cautela** (quedó apagado por las pruebas).
  **Tu protección: botones con aire y "Estado de tu teléfono" (fotos de Luciano del celular, 19/10/2026).** Instalada la versión corta (plegable); en las fotos se vio que el Modo Cautela quedó **APAGADO**
  ("Ahora: apagado") por las pruebas: hay que **encenderlo** (con apagado, tampoco avisa el SOS a los referentes). Críticas: "los botones muy juntos" (pausas y "Mandar enlace de nuevo" / "Quitar") y
  "Cómo estás hoy parece que se pregunta el ánimo; poco claro, mucha info, poco amigable". Armado, sin instalar: `aplicar-tu-proteccion-claro-panel.ps1` (respaldo `.bak-pldclaro`, solo servidor, 158 pruebas y navegador a
  360 y 390 px ok): todos los botones con espacio (`.botones`, gap 10 px), pausas como "Pausar por: 8 horas | 12 horas | 24 horas" en una fila, y la tarjeta pasa a "Estado de tu teléfono" con "Todo tranquilo" /
  "Con señales de alerta" + una frase simple ("tus referentes no verían nada ahora" / "podrían ver tu última señal"). Acepta que estén aplicadas las tres versiones anteriores. Nuevo campo `hoy.mostrar` en la API del dueño. **Instalado y publicado por Luciano el 19/10/2026** (versión f8b94aae, código reconocido de 73379 caracteres); falta su foto del celular y que vuelva a **encender** el Modo Cautela.
  **Tu protección más corta (Luciano dijo "sí" el 19/10/2026): armado, sin instalar** (`aplicar-tu-proteccion-plegable-panel.ps1`, respaldo `.bak-pldplegable`, solo servidor; 152 pruebas y navegador ok).
  Orden nuevo de `/guardian`: Tus referentes → Modo Cautela con "Pausar o apagar" a la vista → "Cómo estás hoy" (con "1 de 4 señales" al lado), "Condiciones" y "Registro" plegados
  (botón "Abrir") → Modo Guardián en una sola línea ("Próximamente"). Mide ~2240 px en el celular (antes ~3490). Trae todo lo de `aplicar-pausar-apagar-panel.ps1` y acepta que ese ya esté o no aplicado
  (comprueba la huella de cualquiera de las dos versiones anteriores). `e2e.js` quedó arreglado (el paso "sin sesión" estaba viejo) y `e2e.js` / `e2e-pausa.js` abren "Condiciones" antes de usarla.
  **Sin contestar de Luciano (mensajes del 19/10/2026, dictados):** "Los de abajo los sacaría" (¿qué tarjetas?) y "en vez de vale, es vale" (¿qué palabra?); si cada modo tendría
  sus propios referentes ("elegir uno o más").
  **Para retomar:** (el punto 2 de abajo queda como opcional)
  Lista:
  (1) Volver las condiciones de Por las dudas a las reales (noche 21 a 6, silencio 90 y 360, 3 señales, "Guardar condiciones") y prender el
  Android de prueba, para que no mande avisos de más a PAPA (su Outlook). (2) Repetir la prueba del aviso a PAPA sin tocar "Estoy bien": no se
  vio el mail "Lu lleva rato sin dar señales" del cron de las 13:00 del 18/10 (el Android se prendió o se cortó antes; se pidió mirar
  `pld_episodios` y `pld_log`). Después los dos finales, uno por vez: "Estoy bien" o "volvió a dar señal". (3) Papá: su Android pide un bloqueo
  de pantalla para abrir Modo Seguro; se propuso poner el correo de Luciano en "Cambiar correo" (el código llega a Luciano, el teléfono queda como
  equipo pendiente y se autoriza en Dispositivos), guiándolo por teléfono; la cuenta `mariobick14@gmail.com` quedó sin uso. Se dejó la pregunta de si
  armarle a Luciano un mensaje de WhatsApp con los pasos. (4) Twilio: cargar saldo y probar un SMS. (5) Apple Critical Alerts: el 21/10/2026
  preguntar y, si no hay respuesta, mandar el texto de `TEXTO-APPLE-ALERTAS-CRITICAS.md`. (6) Próxima build de la app: pantalla "Estoy bien" al
  tocar el aviso, la app que despierta después de reiniciar el teléfono, configuración sin bloqueo para una persona cuidada, y el título del iPhone.
  Falta probar: (1) que se muestre la última señal (bajando
  las condiciones: batería baja 50, noche de 0 a 23, 2 señales), (2) "Estoy bien" y el aviso al
  referente, (3) el registro. Ojo: tras "Estoy bien", durante 30 min "No lo encuentro" responde que
  ya dijo que está bien.
- [x] **Twilio (SMS): RESUELTO el 21-22/10/2026.** Luciano entró a la consola con "Continue with Google" (bickluciano@gmail.com), cargó USD 20 (saldo -1,65 → 18,35), la cuenta pasó a **Active** en minutos y el **22/10 a las 22:21 llegaron dos SMS reales a su iPhone** (remitente 33004): "Ingreso desde la app del telefono" y "Solicitud de ubicacion", con enlace al panel. Quedan: (1) dejar la **recarga automática** bien configurada (Billing → Manage auto-recharge: USD 20 cuando baje de USD 5, con la tarjeta que funcionó); (2) el número de EE.UU. +1 251 360 4304 tiene un registro **A2P a medias** (iniciado el 16/09): no hizo falta para Argentina; (3) a futuro, acortar el enlace de los SMS (hoy es la dirección larga de workers.dev). Con esto se puede decir en la app y en la bienvenida que el código y los avisos de seguridad llegan también por SMS. El resto de este apartado es el historial de cómo estaba antes.
- [x] (historial) **Twilio (SMS) no manda: la cuenta está SUSPENDIDA por saldo bajo** (corrige lo que se creía el 17/10: "se terminó el crédito gratis").
  Según los mails del 24 y 25/09/2026 (en el Gmail de Luciano): cuenta "My First Twilio Account" (SID AC006275…), dueño **bickluciano@gmail.com**;
  la **recarga automática falló** (pago rechazado: USD 10,06 el 24/09 y USD 20,50 el 25/09), el saldo quedó en -USD 0,50 y el 25/09 Twilio la
  suspendió ("Action Required: Your Twilio account is suspended (Low Balance)"). Mientras esté suspendida no salen los SMS de "Avisos de seguridad"
  ni el del SOS; el mail y el aviso en el teléfono siguen. Para reactivarla: entrar a twilio.com/login con "Continue with Google"
  (bickluciano@gmail.com; así entró el 07/09) o "Forgot password" con ESE correo (con luciano.bick@ojoguard.app no manda nada: no es el del
  dueño; las casillas @ojoguard.app sí se derivan a su Gmail), ir a Billing, actualizar la tarjeta (la anterior fue rechazada), recargar y dejar un
  método de pago de respaldo. Los números siguen cobrando cargos mientras tanto. Después, comprobar Argentina en los permisos geográficos y probar un
  SMS. "Por las dudas" usa mail y aviso en el teléfono, no necesita SMS.
  **19/10/2026 (13:35):** Luciano no puede entrar a la consola (la recuperación de contraseña de bickluciano@gmail.com no manda mail, ni a Recibidos ni
  a Spam; mirado también Gmail y la casilla IONOS). `help@twilio.com` ya no sirve (rebota: deprecado desde 05/2023; fue un error mío mandarlo ahí).
  Escribió contestando el ticket de siempre (Onboarding & Compliance, #29118167, trusthub-verify@twilio.zendesk.com) pidiendo recuperar el acceso
  y reactivar la cuenta. Esperar 1 a 3 días hábiles; reintentar "Forgot password" una vez pasada una hora; si no hay respuesta, "Any update?" o
  pedido nuevo en support.twilio.com → Contact Support.
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

## Idea de Luciano (20/10/2026): "Buscar" estilo Apple, dispositivos y artículos por defecto

- **Idea:** para no tener que vincular uno por uno muchos dispositivos, un modelo como el de Apple (Buscar / Familia): el permiso es **por persona** (solo se ve a quien autoriza que lo sigan) y, una vez dado,
  **todos sus dispositivos aparecen por defecto**, y también sus **artículos**.
- **Hoy (según lo armado hasta ahora):** la persona acepta la invitación de la familia, pero cada teléfono se autoriza por separado en Dispositivos (EQUIPO PENDIENTE → Autorizar, como el del papá), y para
  Ubicar / Hacer sonar / En vivo sobre un menor se usa **un solo teléfono** de la persona (el principal o el que reportó último).
- **Propuesta, etapa 1 (sin hardware):** al aceptar, todos los equipos **autorizados** de esa persona se ven solos en el mapa y en Ubicar / Sonar, y los que sume después también; la persona puede apagar el uso
  compartido de un equipo y la familia lo ve (sin modo oculto). Se mantiene la autorización de cada equipo nuevo (evita sumar un teléfono espía solo con el mail); se puede facilitar con un código o QR desde un equipo ya autorizado.
- **Etapa 2, artículos:** lo de Apple (AirTag) depende de su red de iPhones y no se puede copiar. Opciones reales: GPS baratos para auto / mochila / mascota que se leen por API, y el "Modo cercanía" con Bluetooth
  (ya anotado en Antirrobo). **Luciano confirmó (20/10/2026): "artículos" = llaves, mochila, auto (tipo AirTag).** Va para una build posterior.
- **¿Se puede "espejar" lo de Apple (Buscar) para no entrar a dos lugares? No.** Apple no ofrece una API pública para que otras apps lean la ubicación de AirTags, dispositivos o personas de Buscar: la ubicación está
  cifrada de punta a punta y solo la descifra el dueño; los accesorios "Works with Find My" (Chipolo, etc.) también se ven solo en la app Buscar. Las vías no oficiales (ingeniería inversa, pedir el Apple ID y el código 2FA)
  rompen los términos de Apple, son frágiles y la App Store las rechaza: no las usamos. (Google Find Hub, igual.) **Alternativa legítima:** un atajo "Abrir Buscar" / "Abrir Find Hub" dentro de Ojo Guard (un toque,
  sin espejar datos) + más adelante rastreadores GPS propios con API para auto / mascota / mochila que sí se ven en nuestro mapa, y el Modo cercanía por Bluetooth.

- **Decidido por Luciano (20/10/2026): "sí" a las dos.** (1) **Etapa 1 queda como próxima etapa de la app:** "Familia: todos los dispositivos de cada persona por defecto" (permiso por persona; los equipos autorizados de cada
  persona aparecen solos en el mapa y en Ubicar / Sonar; la persona puede apagar el uso compartido de un equipo y la familia lo ve; se mantiene la autorización de cada equipo nuevo). (2) **Artículos:** atajo "Abrir Buscar" /
  "Abrir Find Hub" ahora (sin espejar datos) y rastreadores GPS propios con API más adelante.

**Pedido de Luciano (20/10/2026): "arranquemos con lo de las builds y hay que programar el seguimiento Guardián".** Orden: primero los puntos 1 y 2 de la lista (para armar los parches se le pidió un comando de lectura de la app y del servidor: avisos, tareas en segundo plano, app.json y `sendExpoNotice`); en paralelo, la primera versión del Modo Guardián en el servidor (reloj en el servidor, extender 10/20/30 min hasta 3 veces, "No llegué bien" avisa como SOS).

**Hallazgos de la lectura de la app (20/10/2026):** (a) el servidor ya puede mandar datos dentro del aviso (`sendExpoNotice(token, título, texto, { data })`): el "¿Estás bien?" y los avisos del Guardián pueden llevar su enlace para que la app lo abra al tocarlos;
(b) la app usa `expo-background-task`, `expo-task-manager`, `expo-location`, `expo-notifications` y un módulo propio `modules/exact-alarm` (con `ExactAlarmBootReceiver.kt`); (c) las notas de la app dicen que la **causa raíz de que la app no despierte tras reiniciar
es el *direct boot* de Android** (hasta el primer desbloqueo la app no corre ni recibe FCM ni BOOT_COMPLETED), "confirmada, no resuelta": falta escribir un **modo mínimo nativo** (receptor `directBootAware` con `LOCKED_BOOT_COMPLETED`). Es código nativo y se prueba
solo con una build en un teléfono real; antes de escribirlo se pidió leer el módulo y esas notas.

**Modo Guardián: instalador armado (20/10/2026, sin instalar):** `aplicar-guardian-camino-panel.ps1` (respaldos `.bak-pldcamino` de `src\index.ts` y `wrangler.toml`; crea la tabla `gd_viajes` antes de tocar nada; reemplaza el bloque de Modo Cautela comprobando la huella de cualquiera de las seis versiones
anteriores; agrega las rutas `GET /camino` y `/api/guardian`; una rama en `scheduled` (`_controller.cron === "* * * * *"` → `gdCron`) y el segundo cron de cada minuto en `wrangler.toml`; publica). 240 pruebas y navegador ok. Del panel se leyó:
`async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext)` y `crons = ["*/15 * * * *"]`.
**Instalado y publicado por Luciano el 20/10/2026** (versión ea30b000; tabla `gd_viajes` creada; código reconocido de 79461 caracteres; el deploy muestra los dos `schedule`: `*/15 * * * *` y `* * * * *`). Falta la prueba real (abajo) y la parte de la app.
**Primera prueba real del Guardián (20/10/2026 ~03:00):** Luciano empezó un camino de prueba ("Kansas", en auto, 3 min + 2 de margen) y la página `/camino` anduvo en su Android; en su Gmail llegó "¿Seguís en camino?" a las 03:01:58 (2 minutos antes del límite 03:03), o sea que el cron de cada minuto funciona; **cayó en la pestaña Promociones de Gmail** (hay que moverlo a Principal / "siempre", o mejorar la reputación del remitente: es un aviso de seguridad). No se vio el aviso a PAPA (llega a su Outlook).
**Pedido de Luciano tras la prueba:** el tiempo del camino lo tiene que calcular la app con mapas, según tránsito y cortes (la persona se equivoca más). **Armado, sin instalar:** `aplicar-guardian-mejoras-panel.ps1` (respaldo `.bak-pldmejoras`; acepta las siete versiones anteriores; 263 pruebas y navegador ok): Google Routes API con el tránsito de ahora; ver `GUARDIAN-CAMINO-SEGURO-IDEA.md`. **Dos pedidos más de Luciano (20/10/2026, mismo instalador):** (a) "que diga con qué demora toqué" → al tocar Llegué la página, el registro y el mail a los referentes dicen a qué hora tocó y con cuánta demora respecto del límite ("1 minuto antes del límite" / "4 minutos después del límite") y cuánto tardó contra el tiempo calculado; (b) "los últimos 15 segundos que suene pip pip cada segundo, como una bomba para desactivar, así se dan cuenta de apretar" → la página del camino pita 1 vez por segundo en los últimos 15 s (y un tono largo al llegar a 0), vibra, tiene botón "Sonido: activado/apagado", y mantiene la pantalla encendida mientras hay camino en marcha. **Límite:** la página tiene que estar abierta y hay que tocarla una vez (regla de los navegadores); el pitido confiable con la pantalla bloqueada tiene que venir de la app (alarma nativa) en la próxima build.
**Clave de Google creada y guardada (20/10/2026):** Luciano habilitó la Routes API en el proyecto "ojo-guard", creó la clave `ojo-guard-rutas-servidor` (sin restricción de aplicación, restringida a Routes API) y la guardó con `wrangler secret put GOOGLE_ROUTES_KEY`. **Falta:** el tope diario de consultas (Cuotas) y, con el instalador nuevo, habilitar **Places API (New)** y agregarla a las restricciones de la clave.
**Primera prueba con Google (20/10/2026 ~03:50):** con "Av cabildo 2359" (calle suelta, sin ciudad) el camino salió "3 min": no era de Google sino el número que había quedado escrito de una prueba anterior, y una calle suelta es ambigua. **Armado, sin instalar:** `aplicar-guardian-direcciones-panel.ps1` (respaldo `.bak-plddirecciones`; acepta las ocho versiones anteriores; 274 pruebas y navegador ok): al escribir desde 3 letras se muestran **sugerencias de Google Places con barrio y ciudad** (sesgadas a donde está el teléfono), se elige una y el tiempo se calcula hasta ese `placeId` exacto; no deja empezar sin elegir si hay sugerencias; el casillero de minutos se vacía al cambiar destino o modo; y si Google falla, la pantalla dice por qué (con el mensaje que devuelve Google).
**Instalado y publicado por Luciano el 20/10/2026** (`aplicar-guardian-mejoras-panel.ps1`, versión 2d0e3026, código reconocido de 109976 caracteres): la demora al llegar y los pitidos ya andan; el tiempo por Google Mapas funciona cuando haya clave (mientras tanto, estimación por distancia).
**Falta:** que Luciano cree la clave de Google (Routes API, restringida solo a esa API, con tope diario de consultas) y la guarde con `npx wrangler secret put GOOGLE_ROUTES_KEY`.
**Prueba sugerida con la 1ª instalación:** Guardián → "Otro lugar" → nombre "Prueba", caminando, 3 minutos → no tocar nada: a los ~3 min llega el mail "¿Seguís en camino?"; a los 5, "Lucas no llegó a Prueba a la hora prevista" a los referentes que aceptaron (PAPA) y "Les avisamos a tus referentes" a la persona; después "Llegué" y a PAPA le llega "está bien".
**Direcciones instaladas y publicadas por Luciano el 20/10/2026** (`aplicar-guardian-direcciones-panel.ps1`, versión f0d56a76, código reconocido de 119566 caracteres, dos horarios). **Pedido siguiente de Luciano (20/10/2026): "que deje poner nombres de lugares como restaurantes".** Armado, sin instalar: `aplicar-guardian-lugares-panel.ps1` (respaldo `.bak-pldlugares`; reemplaza al de direcciones y acepta las nueve versiones anteriores, incluida la ya instalada; 277 pruebas y navegador ok): las sugerencias de Google Places incluyen comercios y restaurantes (se escribe "Kansas cabildo" y sale "Kansas Cabildo · Av. Cabildo 2501, Belgrano · a 1,8 km"); el pedido manda el punto del teléfono como origen para que Google calcule la distancia; la etiqueta pasa a "Dirección o nombre del lugar". **Instalado y publicado por Luciano el 20/10/2026** (`aplicar-guardian-lugares-panel.ps1`, código reconocido de 126315 caracteres, versión 865c3cd6). Falta probarlo con la clave. **Falta de Luciano:** habilitar **Places API (New)** en Google Cloud, agregarla a las restricciones de la clave `ojo-guard-rutas-servidor` (junto con Routes API) y poner el tope diario de consultas de Compute Routes (~1000/día).
**Primera prueba real de lugares (20/10/2026 ~04:07):** Luciano escribió "La panera rosa" y la pantalla dijo "No pudimos buscar direcciones: Google no entendió el pedido" (Google contestó 400 y no se vio el motivo). **Arreglo armado (sin instalar):** `aplicar-guardian-lugares-arreglo-panel.ps1` (respaldo `.bak-pldlugares2`; acepta las diez versiones anteriores, incluida la ya instalada; 285 pruebas y navegador ok): el autocompletar ya no manda la máscara de campos (no la necesita) y, si Google rechaza el pedido con ubicación, reintenta más simple (sin ubicación y por último solo el texto); si igual falla, la pantalla muestra qué intentos probó (`[A400 B400 C400]`) y el mensaje exacto de Google (o el principio de su respuesta), también al calcular la ruta. **Instalado y publicado por Luciano el 20/10/2026** (código reconocido de 126822 caracteres, versión cb596ecd). Pendiente de ver con la clave real qué parámetro rechazaba Google (falta su foto tras probar "La panera rosa").
**Segunda prueba (20/10/2026 ~04:15, con el arreglo instalado):** la pantalla dijo "no hubo conexión con Google (Error: Network connection lost.)"; antes de eso, el primer intento había dado 400 sin cuerpo legible. Hipótesis: la conexión entre Cloudflare y Google se corta (hay que reintentar) o Google corta la conexión según el pedido. **Armado, sin instalar:** `aplicar-guardian-lugares-conexion-panel.ps1` (respaldo `.bak-pldlugares3`; acepta las once versiones anteriores; 289 pruebas y navegador ok): todos los pedidos a Google (buscar lugares y calcular la ruta) se reintentan una vez si se corta la conexión; la búsqueda prueba tres pedidos (completo, sin ubicación, solo el texto) y la pantalla muestra el resultado de cada uno (`[A:red B200]`). **Instalado y publicado por Luciano el 20/10/2026** (código reconocido de 127943 caracteres, versión 5416e599); falta su foto de la prueba. Si todos fallan con conexión cortada, el siguiente paso es un diagnóstico dentro del panel (probar Routes y Places por separado con la clave real).
**Tercera prueba (20/10/2026 ~04:21, con el reintento instalado):** la pantalla dijo `[A400 B400 C400]` sin mensaje: Google contestó 400 vacío incluso al pedido más simple (solo el texto), o sea que el problema NO es el cuerpo del pedido. Probado desde acá con una clave falsa: un valor normal da el JSON "API key not valid"; un byte de control (0x01) en el encabezado de la clave da `PROTOCOL_ERROR` ("Network connection lost"). **Hipótesis:** la clave guardada con `wrangler secret put` trae caracteres de control (por ejemplo los que agrega la consola al pegar) y por eso también falló antes el cálculo de la ruta. **Armado, sin instalar:** `aplicar-guardian-lugares-clave-panel.ps1` (respaldo `.bak-pldlugares4`; acepta las doce versiones anteriores; 295 pruebas ok): la clave se limpia antes de usarla (se toma la parte `AIza` + 35 caracteres o se quitan los caracteres que no sirven) y, si algo falla, la pantalla dice cuántos caracteres tiene la clave, con qué empieza y cuántos raros se le quitaron (nunca la muestra entera). **Instalado y publicado por Luciano el 20/10/2026** (código reconocido de 128709 caracteres, versión 81ee771e); falta su foto de la prueba. Plan B si igual falla: volver a guardar la clave desde el portapapeles (`Get-Clipboard | npx wrangler secret put GOOGLE_ROUTES_KEY`), sin pegarla en el prompt.
**Cuarta prueba (20/10/2026, con la limpieza de la clave ya instalada, versión 81ee771e):** Luciano escribió "ahora ni busca": la pantalla quedaba en blanco (sin sugerencias ni mensaje). Causas posibles que dejaban todo en blanco: Google contesta bien pero sin resultados, falta la clave (`sin_clave`) o el panel contesta un error que la página tragaba. **Armado, sin instalar:** `aplicar-guardian-lugares-mensajes-panel.ps1` (respaldo `.bak-pldlugares5`; acepta las trece versiones anteriores; 298 pruebas y navegador ok): mientras busca dice "Buscando…"; después siempre dice algo (sugerencias, "Google no encontró lugares con ese texto" con el detalle de los intentos y la clave, "Al panel le falta la clave de Google" o "el panel contestó con un error"); si el pedido con ubicación no da resultados prueba el más simple. **Instalado y publicado por Luciano el 20/10/2026** (código reconocido de 129911 caracteres, versión aa9edb4a); falta su foto de la prueba.
**Quinta prueba (20/10/2026 ~04:32, con los mensajes instalados):** la pantalla dijo "Al panel le falta la clave de Google" (`sin_clave`): el valor guardado en `GOOGLE_ROUTES_KEY` no tiene ningún carácter válido (una clave de Google tiene solo letras, números, `_` y `-`; al limpiarla queda vacía). Diagnóstico: la clave NUNCA quedó bien guardada (probablemente el `wrangler secret put` guardó un carácter invisible, como el Ctrl+V sin pegar, o los puntitos de la clave oculta); por eso ni Routes ni Places anduvieron nunca. No era un problema del código. **Arreglo (sin instalador):** guardar la clave de nuevo desde el portapapeles, comprobando antes (sin mostrarla) que contenga UNA clave con forma `AIza` + 35 caracteres, desde la carpeta del panel; el secreto se aplica solo, no hace falta publicar. **Primer intento fallido (20/10/2026):** el comando leía el portapapeles apenas se pegaba, pero para pegar el comando hay que copiarlo y eso pisa la clave: leyó 680 caracteres (exactamente el largo del propio comando con saltos CRLF) y no guardó nada. **Orden correcto:** pegar y correr el comando PRIMERO; el comando espera (`Read-Host`, con `FlushInputBuffer` antes y todo lo demás en la misma línea) a que se copie la clave en Google Cloud y se apriete Enter; después lee el portapapeles, busca una clave con `[regex]::Matches($k,'AIza[0-9A-Za-z_-]{35}')` (debe haber exactamente una), la guarda con `$m[0].Value | npx.cmd wrangler secret put GOOGLE_ROUTES_KEY` y pisa el portapapeles con un espacio. **Clave guardada bien (20/10/2026 ~04:40):** "contiene 1 clave(s) de Google", 39 caracteres, "Success! Uploaded secret GOOGLE_ROUTES_KEY" en el Worker `ojo-guard-ms-api`. **Pero la clave quedó escrita en el chat:** el cartel `Read-Host` del comando parecía un campo para escribir y Luciano pegó ahí la clave, que salió en el texto que copió de PowerShell. No se usó para nada ni quedó en el repositorio (comprobado con una búsqueda por forma de clave). **A hacer al terminar las pruebas (rotar la clave):** crear una clave nueva en Google Cloud con las mismas restricciones (Routes API y Places API (New)) y el tope diario, guardarla con el comando de espera pero con `Read-Host -AsSecureString` (enmascarado) y "apretá Enter sin escribir ni pegar nada", y borrar la clave vieja. Lección: para esperar a que se copie algo no usar un cartel que parezca un campo; enmascarar o usar un mensaje aparte.
**Sexta prueba (20/10/2026 ~04:39):** con la clave bien guardada Google contestó 403 "Requests to this API places.googleapis.com method …AutocompletePlaces are blocked": la clave tenía restringida la API y faltaba **Places API (New)** en sus restricciones. Luciano la agregó y a las ~04:45 dijo "ahora sí busca bien": **la búsqueda de lugares (restaurantes, direcciones) ya anda en producción.** Falta confirmar con su foto la línea "calculado con mapas y el tránsito de ahora" (Routes API en las restricciones de la clave) y rotar la clave. La clave volvió a quedar pegada en el chat (2.ª vez): rotar ya con una clave nueva (restricciones Routes API + Places API (New), sin restricción de aplicación) y un comando que borra el portapapeles al empezar, espera con `Read-Host -AsSecureString` y solo guarda si hay exactamente una clave; después borrar la clave vieja y poner el tope diario de cuotas.
**Pedido de Luciano (20/10/2026 ~04:49), mirando "Tu camino" tras cancelar (con el cálculo de Google ya andando: "8 min + 2 de margen" hasta Kansas, Av. del Libertador): "ahora hay que poner que puedas volver para atrás".** **Armado, sin instalar:** `aplicar-guardian-navegacion-panel.ps1` (respaldo `.bak-pldnavega`; reemplaza al de "volver" y acepta las quince versiones anteriores, incluida la que deja ese; 302 pruebas y navegador ok): arriba de "Tu camino" hay dos enlaces, "← Volver a Tu protección" (`/guardian`) e "Ir al inicio" (`/`, la página principal del panel), siempre, también con el camino en marcha; cuando el camino terminó (llegué, cancelado, cerrado) aparece una tarjeta con "Volver a Tu protección", "Empezar otro camino" (`/guardian#gdSeccion`) e "Ir al inicio"; si el enlace no sirve hay botones para ir a Tu protección o al inicio; "Tu protección" también tiene arriba "← Ir al inicio"; y al cancelar ya no se repite "Camino cancelado.". Segundo pedido de Luciano (20/10/2026): "O a la página de inicio". **Instalado y publicado por Luciano el 20/10/2026** (código reconocido de 130746 caracteres, versión 2752b453); falta su prueba en el teléfono. Interpreté "volver para atrás" como volver a la pantalla anterior (no deshacer la cancelación); si quería deshacer, sería un botón "Reanudar" aparte.
**Navegación de Tu camino instalada y probada (20/10/2026 ~05:10):** "Volver a Tu protección" e "Ir al inicio" ya andan en el panel de Luciano (versión 2752b453). **Pedido siguiente de Luciano (20/10/2026): "cuando apretás Modo Guardián no te tiene que mostrar todo arriba lo de Modo Cautela, porque te muestra cualquier cantidad de palabras que no tienen nada que ver con ese modo; cuando uno aprieta Guardián o Cautela te tiene que mostrar el que va a esa configuración, no mezclado" (el botón OG tiene dos entradas, Modo Cautela y Modo Guardián, y las dos abrían la misma página larga).** **Armado, sin instalar:** `aplicar-tu-proteccion-modos-panel.ps1` (respaldos `.bak-pldmodos` de `src\index.ts` y `.bak-ogmodos` de `src\panel-index.html`; acepta las dieciséis versiones anteriores, incluida la que dejó el de navegación; 309 pruebas y los siete recorridos en navegador ok): `/guardian` abre en una pantalla de inicio con tres tarjetas (Tus referentes, Modo Cautela, Modo Guardián, cada una con su estado: "Encendido", "Sin camino en marcha"…) y el registro; al tocar una tarjeta se ve SOLO esa configuración (Modo Cautela: pausar o apagar, estado del teléfono, condiciones; Modo Guardián: a dónde vas, cómo vas, cuánto tardás; Tus referentes), con "← Tu protección" arriba para volver y la línea "Se avisa a: …" en cada modo; las direcciones son `/guardian#cautela`, `/guardian#guardian` y `/guardian#tus-referentes` (el viejo `#gdSeccion` sigue abriendo el Guardián; el botón Atrás del teléfono vuelve al inicio); en la protección de otra persona (menores) no se abre el Guardián; el botón OG del panel abre directo cada modo (cambia dos enlaces y el texto "Próximamente" de `src\panel-index.html`; si no encuentra el menú como esperaba lo deja como está y avisa); "Empezar otro camino" lleva directo al Guardián. No se saca ninguna función. **Instalado y publicado por Luciano el 20/10/2026** (código reconocido de 131805 caracteres, versión 6613c553; el menú del botón OG se cambió sin avisos); falta su prueba en el teléfono.
**Idea de Luciano (20/10/2026 ~05:25), a confirmar antes de armar:** "más limpio, como un teléfono: el Modo Cautela con un botón de activar y desactivar; y la configuración aparte, como en Apple (Configuración → Hora, Pantalla y brillo): cada función la prendés y la apagás y modificás ciertas cosas, pero lo global tiene que estar en Configuración; si querés algo distinto de lo seteado, vas a Configuración". **Propuesta (esperando su sí):** inicio con tarjetas (Modo Cautela con interruptor y estado, Modo Guardián con Empezar camino) y un acceso a Configuración; pantalla del Modo Cautela = interruptor grande + estado + pausa rápida (8/12/24 h) y nada más; pantalla del Modo Guardián = empezar camino / camino en marcha, sin interruptor; **Configuración** = Tus referentes (globales: sirven a los dos modos y al SOS), condiciones del Modo Cautela (horario de noche, sin señal, lejos de casa, batería, señales necesarias, emergencia tras), cómo te llaman, "mi casa es donde está mi teléfono", estado del teléfono, Registro y, si administra a otra persona, el selector "Estás viendo la protección de". Si no hay referentes, el inicio avisa y lleva a Configuración.
**Idea de Luciano confirmada (20/10/2026 ~05:45): "Sí, pero en Modo Guardián tiene que estar para poner la dirección, todo eso. Lo que sí podés configurar en Modo Guardián: que el margen extra sea 3 minutos en vez de 2, o poner cosas de avisos; lo cotidiano tiene que estar siempre en el botón principal. En Ajustes, Configuración, tiene que estar lo que uno cree que puede modificar cada tanto; los seteados los seteamos nosotros como creemos que va, y después uno lo modifica. Dentro de Configuración también: Ajustes y Accesibilidad, para que se entienda qué modificar y qué no, y que no sea todo tan chorizo."** **Armado, nunca se corrió por separado (lo reemplazó y está incluido en `aplicar-guardian-recalculo-panel.ps1`, más abajo):** `aplicar-tu-proteccion-configuracion-panel.ps1` (respaldo `.bak-pldconfig`; reemplaza al de "modos" y acepta las diecisiete versiones anteriores, incluida la instalada; 344 pruebas y ocho recorridos en navegador ok; crea la tabla `gd_config` con `wrangler d1 execute` y, si no puede, el panel la crea sola la primera vez). **Estructura:** inicio = Modo Cautela con interruptor (pide confirmación al apagar) + Modo Guardián + Configuración (y aviso si faltan referentes); pantalla del Modo Cautela = interruptor, estado y pausa rápida; pantalla del Modo Guardián = lo cotidiano (dirección o nombre del lugar, cómo vas, tiempo, Empezar camino); **Configuración** = lista de categorías (Referentes, Modo Cautela, Modo Guardián, Ajustes, Accesibilidad, Registro), cada una con su pantalla y "Volver a los valores recomendados"; "← Configuración" / "← Tu protección" para volver. **Modo Guardián configurable por persona** (valores recomendados entre paréntesis, límites): margen extra (2 min, 1 a 15), preguntar "¿Seguís en camino?" faltando N min (2, 1 a 10), veces de más tiempo (3, 0 a 5; con 0 no hay botones de +10/+20/+30), repetir el aviso a referentes cada N min (10, 5 a 60) y cantidad máxima de avisos (3, 1 a 5); no se cambia con un camino en marcha (409 `camino_en_marcha`) ni desde una cuenta de menor (403); no está disponible mirando la protección de otra persona (el administrador de un menor todavía no puede cambiar su Guardián: pendiente). **Accesibilidad** (se guarda en el teléfono/navegador con `localStorage`, vale en las pantallas de Ojo Guard del Worker: Tu protección, camino, referente y "Estoy bien"): tamaño de texto (normal/grande/muy grande), alto contraste, botones más grandes, sonido de la cuenta regresiva, vibración y mantener la pantalla encendida; un menor puede usarla. **Ajustes:** cómo te llaman tus referentes (se sacó de "Condiciones") y "Acerca de" (el cartel de validación). **Cautela:** las condiciones, "mi casa es donde está mi teléfono" y el estado del teléfono pasaron a Configuración; ya no hay tarjetas plegables.
**Aclaración de Luciano (20/10/2026 ~06:05): la idea de Configuración es para TODA la aplicación, no solo Guardián y Cautela:** "una manera de ordenar todo lo que es configurable, que vaya a parar ahí, y que todo sea un poco más limpio, ya que no se usa en lo cotidiano". **Plan por etapas:** (1) **Tu protección** (arriba, armada). (2) **Consola del panel** (web, `FOTO-CONSOLA-15-10-2026.md`): hoy tiene seis pestañas (Inicio, Mapa, Historial, Dispositivos, Pulseras, Cuenta) y lo configurable está desparramado: tema claro/oscuro en la barra, "Cuenta" (correo del titular, passkey, código de verificación, avisos de seguridad por correo/SMS/"si el teléfono deja de responder", pregunta de emergencia, reconocimiento facial y su compra), lugares y avisos de llegada/salida y roles en el Mapa, autorizar/quitar dispositivos, y pulseras; la propuesta es una entrada "Configuración" arriba (como el OG) con las mismas categorías (Cuenta y seguridad, Avisos, Apariencia, Accesibilidad, Tu protección, Familia y lugares, Dispositivos, Pulseras), mover ahí lo que no es cotidiano y dejar en cada pestaña solo lo del día a día; Accesibilidad compartida con las páginas del Worker (misma clave `ogAcc`, mismo origen). (3) **App del teléfono** (`FOTO-APP-NATIVA-14-10-2026.md`; ya tiene Inicio, Mi perfil y Configuración en tarjetas: Claves y Seguridad, Fotos de Intrusos, Modo Perdido y Cercanía, Preferencias, Dr. Ojo Guard, Ojo Guard MS): sumar "Tu protección" y "Accesibilidad" y repasar qué configurable sigue suelto en el Inicio. Antes de cada etapa se hace la "foto" (lista para tildar) y se piden comandos de lectura. **Pregunta para Luciano: por cuál etapa seguir (recomendado: la consola del panel).**
**Pregunta de Luciano (20/10/2026 ~05:55) sobre el Modo Guardián:** "si la persona cambia el recorrido, ¿recalcula el tiempo o queda fijo lo que puso? Puede haber un problema cuando se le extiende el tiempo por el recorrido (tránsito) y no porque frenó, o porque estuvo mucho tiempo parado". **Respuesta (hoy): el tiempo queda FIJO.** Se calcula una sola vez al empezar (Google Mapas con el tránsito de ese momento, o los minutos que puso la persona) y el límite es hora de inicio + tiempo + margen + lo que pida extender; no hay forma de cambiar el destino a mitad de camino (hay que cancelar y empezar otro) y el servidor no compara el avance: un camino lento por tránsito y uno en el que la persona frenó se ven igual (a la hora límite sale el aviso a los referentes). Lo que protege hoy: el aviso "¿Seguís en camino?" antes del límite (ahora configurable), los botones +10/+20/+30 (ahora configurables) y que "Llegué" avisa que está bien. **Propuesta (aceptada: "sí, armalo"):** (a) recalcular cada ~5 min con Google (tránsito) desde donde está el teléfono mientras el camino está en marcha, solo si el teléfono se está acercando al destino: si tardará más de lo previsto, sumar el tiempo solo (con un tope) y avisarle ("hay más tránsito: te dimos 8 minutos más"); si está quieto (frenó), no sumar: preguntar "¿Seguís en camino?" y, si no responde, avisar; (b) botón "Cambiar destino" (recalcula desde donde está); (c) botón "Voy a frenar un rato" (15/30/60 min) para paradas a propósito. Límites: en iPhone la app no despierta en segundo plano (depende de lo que la app reporte sola); cada recálculo es una consulta a Google Routes (~12 por hora de camino; poner el tope diario en Cuotas); hace falta guardar el destino exacto (ya se guarda `dest_lat`/`dest_lng`).
**Respuesta de Luciano (20/10/2026): "sí, armalo".** **Instalado y publicado (20/10/2026 tarde, versión del Worker `67551779-b0fe-401d-9685-bd46b019a2a2`; el instalador reconoció el bloque de 135310 caracteres, que es el de "modos / navegación": la Configuración por categorías no se había instalado aparte y entró junto con este):** `aplicar-guardian-recalculo-panel.ps1` (respaldo `.bak-pldrecalculo`; reemplaza al de Configuración, lo incluye y acepta las dieciocho versiones anteriores del bloque; no toca la base: las tablas nuevas se crean solas; 396 pruebas y nueve recorridos en navegador ok; falta probar el tránsito real en la calle). **(a) Tránsito:** mientras el camino está en marcha, el cron (cada minuto) mira cada ~4 min, con una ubicación del teléfono de los últimos 10 min, si la persona **se acerca** al destino (al menos 100 m más cerca que la muestra anterior, que tiene que tener 3 min o más); solo cuando faltan **20 min o menos** para el límite le pregunta a Google Routes cuánto le falta; si llegaría más tarde que el límite (diferencia de 2 min o más) **suma esa diferencia** al límite, hasta un tope por persona (`autoAjusteMin`, 60 recomendado, 0 a 180; **0 = no sumar**), le deja el aviso "Hay más tránsito" en el teléfono y lo anota en el Registro; si está quieto o se aleja no suma nada y sigue el aviso de siempre ("¿Seguís en camino?" y, si no responde, a los referentes). No se aplica si ya se avisó a los referentes (estado alerta) ni si el destino no tiene coordenadas (por ejemplo un camino con minutos puestos a mano y dirección sin resolver). **(b) "Cambiar destino"** (pantalla del camino, también con el enlace personal): lugar guardado u otro lugar (busca por nombre o dirección con Google Places, como al empezar); recalcula desde donde está el teléfono (o el origen que mande la pantalla); el límite arranca de nuevo (ahora + tiempo + margen); si Google no puede calcular pide los minutos; no se puede después de avisar a los referentes. **(c) "Voy a frenar un rato"** (15, 30 o 60 min, hasta 2 veces por camino, solo si la configuración permite pedir más tiempo): suma ese tiempo al límite **sin** avisar a los referentes; queda en el Registro. La pantalla dice "Sumamos N minutos por tránsito" y el resumen de "Llegué" cuenta los minutos por tránsito aparte de los que pidió. **Configuración > Modo Guardián** suma "Sumar tiempo si hay más tránsito, hasta (min)". Tablas: `gd_progreso` (por camino: última muestra, cuándo se recalculó, minutos sumados por tránsito y paradas) y la columna `auto_max_min` de `gd_config` (se agrega sola con `ALTER TABLE` en un try/catch). **Límites conocidos:** en iPhone la app no despierta en segundo plano: el recálculo usa lo que la app alcance a informar (si no hay ubicación reciente no suma nada, que es lo seguro); cada recálculo es una consulta a Google Routes (~12 por hora de camino como máximo; poner el tope diario en Cuotas); el administrador de un menor todavía no puede cambiar su Guardián.
**Cuatro pedidos de Luciano sobre lo recién instalado (20/10/2026 tarde) y cómo quedaron. Instalado y publicado (20/10/2026, versión del Worker `11113ce6-6825-4149-a23b-e61f6b9e9bf7`; el instalador reconoció el bloque de 169981 caracteres, el del recálculo):** `aplicar-guardian-pausa-panel.ps1` (respaldo `.bak-pldpausa`; reemplaza al de recálculo, lo incluye y acepta las diecinueve versiones anteriores del bloque; 438 pruebas y nueve recorridos en navegador ok; sin tocar la base: `gd_progreso` gana columnas solas con `PRAGMA table_info` + `ALTER TABLE`). **(1) "Si pongo voy a frenar un rato, ¿no tendría que dejar de restar el reloj? ¿Poner en pausa?"** Tenía razón: la versión instalada solo sumaba minutos al límite (el reloj seguía bajando y, si seguía antes, le quedaba tiempo de más). Ahora es una **pausa de verdad**: al elegir 15, 30 o 60 minutos se guarda lo que le faltaba para llegar (`resta_ms`), la pantalla muestra **EN PAUSA** con el reloj quieto y hasta qué hora dura, y el límite del servidor queda en "fin de la pausa + lo que le faltaba" (así nada salta mientras está frenado). **"Ya sigo"** retoma con lo que le quedaba (sin margen de más); si no toca nada, **la pausa termina sola** (tope: nadie queda pausado para siempre), el reloj sigue y se le avisa por mail y teléfono "Terminó tu parada" (si ya le quedan 2 minutos o menos, en su lugar sale el "¿Seguís en camino?"). Durante la pausa el cron no pregunta, no avisa a nadie ni recalcula por tránsito; no se avisa nunca a los referentes por frenar. Se puede alargar ("Frenar más tiempo"), cuenta como otra parada (máximo 2 por camino, y solo si la configuración permite pedir más tiempo); +10/+20/+30 en pausa se suman a lo que le falta; "Llegué" frenado cuenta lo que duró la pausa; "Cambiar destino" la termina. El resumen final dice "+ N de parada" aparte de lo pedido y del tránsito. Tu protección dice "(en pausa)". **(2) "Cambiar destino, ¿toma la geolocalización de donde estoy o piensa que estoy en otro punto, como en casa?"** Nunca usó un lugar guardado: usaba la ubicación del navegador del teléfono (pedida con 4 segundos de espera) y, si no la daba, **la última del teléfono sin mirar qué tan vieja era** (ese era el hueco: con una ubicación de horas el cálculo salía "raro"). Ahora el origen es siempre: ubicación actual del navegador (pedida con más tiempo y precisión, ignorada si es muy imprecisa, p. ej. la de una computadora); si no hay, la del teléfono **solo si es de los últimos 10 minutos**; si no, no calcula y pide permitir la ubicación o poner los minutos. Vale para "Cambiar destino", para el tiempo que se muestra antes de empezar y para "Empezar camino"; las sugerencias de lugares usan ese origen y, si solo hay una ubicación vieja, no dicen a cuántos km queda cada una. La pantalla y el Registro dicen desde dónde se calculó, cuántos minutos y cuántos km. **(3) "¿Cómo sabe si estoy caminando, auto o transporte? Tendrían que estar los íconos de cada uno y poder marcarlos."** "Cambiar destino" conservaba el modo con el que se empezó. Ahora **Empezar camino** y **Cambiar destino** tienen tres botones con icono (auto, transporte, caminando) que se marcan, y "Cambiar destino" suma la opción **"Seguir yendo a <el lugar>"** para cambiar solo cómo va (recalcula hacia el mismo destino exacto). El modo se guarda en el camino y lo usan el cálculo y el recálculo por tránsito. **(4) "No se escuchó el pip pip pip de los 15 segundos, ¿puede ser un auricular Bluetooth cerca?"** Sí es posible: si el teléfono está conectado por Bluetooth (auriculares, parlante, auto) el sonido sale por ahí, y esos aparatos suelen "dormirse" y tragarse los primeros sonidos cortos; otras causas posibles: volumen de contenido en cero, botón de silencio del iPhone (el sonido web lo respeta) y el permiso del navegador (hace falta un toque en la página). No se pudo oír en un teléfono real desde acá. Cambios: pips más fuertes y un poco más largos, **vibra aunque el navegador no deje sonar**, botón **"Probar sonido"** (tres pips y explica esas causas), aviso en el último minuto si el sonido no está habilitado y `navigator.audioSession.type = "playback"` donde el navegador lo soporte (para que suene con el silencio del iPhone puesto; sin probar en iPhone). **Confirmado por Luciano: era un auricular Bluetooth conectado; al desconectarlo, sonó.** Su pregunta: "¿se puede hacer que suene igual, sin depender de si agarra la entrada de un auricular?" **Desde una página web no:** el sistema elige la salida (con Bluetooth conectado, el sonido de medios va ahí) y el navegador no puede forzar el parlante. **Desde la app sí, con código nativo:** Android `AudioTrack.setPreferredDevice` al parlante integrado (`TYPE_BUILTIN_SPEAKER`) o `AudioManager.setCommunicationDevice`; iPhone `AVAudioSession.overrideOutputAudioPort(.speaker)` con la categoría PlayAndRecord. Ojo: una alarma común NO garantiza el parlante (en Android suele sonar también en los auriculares Bluetooth conectados). Requiere una build de la app y llevar la cuenta regresiva del Guardián a la app: ítem 9 de la próxima build. Mientras tanto la página avisa que si hay Bluetooth suena ahí y vibra (Android). **Luciano dijo que sí ("me parece que suma también lo del parpadeo para los 15 segundos")**. **Armado, sin instalar:** `aplicar-guardian-parpadeo-panel.ps1` (respaldo `.bak-pldparpadeo`; reemplaza al de la pausa y acepta las veinte versiones anteriores; 439 pruebas y nueve recorridos ok): en los últimos 15 segundos el reloj de la pantalla del camino se pone rojo y parpadea una vez por segundo, la tarjeta se marca en rojo y dice "Se termina el tiempo: tocá Llegué" (+ "o pedí más tiempo" si se puede); pasado el límite queda rojo y quieto; con "reducir movimiento" del teléfono no parpadea (queda rojo). No depende del sonido ni de la vibración. **Pendiente de verificar:** el recorrido real de tránsito y la pausa en su teléfono.
**Etapa 2, la consola del panel: instalada y publicada por Luciano (20/10/2026 noche; versión del Worker `5f6c638a-697c-4ccd-917e-c48d1e562902`; el instalador reconoció los dos archivos de la foto, `src\panel-app.txt` quedó en 105560 caracteres y `src\panel-index.html` en 49860, con la huella final igual a la esperada; respaldos `.bak-cfgconsola`). Falta que mire la lista para tildar de `FOTO-CONSOLA-20-10-2026.md` en la compu y en el celular.** Luciano mandó la foto (`foto-panel.ps1`, diez archivos; las huellas coinciden con su inventario) y se armó `FOTO-CONSOLA-20-10-2026.md` (cómo es hoy, qué cambia y lista para tildar). `aplicar-consola-configuracion-panel.ps1` (respaldo `.bak-cfgconsola`; solo consola, sin tocar el servidor ni la base; toca solo `src\panel-index.html` y `src\panel-app.txt`, y solo si son los de la foto: comprueba la huella antes y después, y restaura si no coincide; los estilos nuevos van adentro de la página para que nunca quede una copia vieja de los estilos con la página nueva): la pestaña **Cuenta pasa a Configuración**, con una lista de siete categorías: Cuenta y seguridad, Avisos, Tu protección (enlace a `/guardian#configuracion`), Familia y lugares (atajos al mapa: invitar, lugares, roles), Equipos y pulseras (atajos: agregar un equipo, quitar o autorizar, presentación), Reconocimiento facial y Apariencia y accesibilidad (modo claro o noche, tamaño del texto, alto contraste y botones grandes; misma clave `ogAcc` que Tu protección). Las tarjetas de antes pasan intactas (mismos ids y botones); el botón de tema de la barra de arriba queda solo en la pantalla de acceso; Atrás y recargar vuelven a la misma pantalla (`#config-…`); en modo de emergencia queda oculta como Cuenta; en pantalla ancha mantiene las dos columnas; la pestaña, más larga que "Cuenta", entra en 360 px con letra normal y grande (con "Muy grande" se corta, como "Mapa y Familia"). **De paso, arreglo del botón OG en la compu:** sus estilos habían quedado adentro del bloque solo-celular (`max-width: 520px`) de `panel-explanations.css` (error de un instalador anterior mío): en pantalla ancha se veía un triangulito con "OG" sin estilo, hasta sin sesión; ahora se ve como en el celular y su menú se despliega entero (desde 1280 px la franja fija de arriba lo recortaba con `clip-path`). Pruebas: recorrido en navegador (390 px y 1200 / 1440 px, claro y noche, modo de emergencia) y el instalador corrido de verdad con PowerShell 7 (LF, CRLF, con y sin BOM; rechaza archivos distintos, falta de un archivo y respaldo previo; restaura si falla la huella final). Herramientas en `scripts/consola/`. Lo que sigue: etapa 2b (lista propia de Lugares dentro de Configuración, opcional) y etapa 3 (la app).
**Pregunta de Luciano (20/10/2026 noche): "la alerta tocando 5 segundos el botón, o en iPhone por atajo, y que mande la señal al referente, ¿está puesto?"** Respuesta: sí, con matices. Botón de la app: se mantiene **3 segundos** (`MANTENER_MS = 3_000` en `SosBlock.tsx` y `3000L` en el servicio de accesibilidad de Android; no son 5), y en Android también los dos botones de volumen 3 s con la pantalla bloqueada; iPhone: atajo "SOS Ojo Guard" (acción "Abrir direcciones URL" con `ojoguard://sos?k=…`; con Siri anduvo el 13/10, falta probar el toque en la espalda con el iPhone bloqueado). Referentes: desde el 19/10 el SOS les manda un mail con la ubicación, el mapa, el aviso del 911 y su enlace; desde el 20/10 avisa **siempre**, aunque el Modo Cautela esté apagado (`aplicar-menores-solo-ver-panel.ps1`, ya instalado); si la persona cancela, se les cuenta. **Hueco encontrado:** el enlace "Ver su última señal" del mail sigue las condiciones del Modo Cautela (`pldEvaluar` / `pldApiReferente`: con el Modo Cautela apagado o en pausa, o sin condiciones, el referente ve solo un mensaje y a la persona le llega un "¿Estás bien?"), así que durante un SOS puede no ver la señal que se va actualizando; el mail trae solo la ubicación del momento en que apretó. El SMS del SOS no sale mientras Twilio siga suspendida. **Preguntas sí/no abiertas:** (1) que mientras haya un SOS activo (`family_sos`) el enlace del referente muestre siempre la última señal, sin depender de las condiciones (solo servidor, sin build; recomendado: sí); (2) 3 s o 5 s para el botón (cambio en la app más una build; recomendado: dejar 3 s).
**Pedido de Luciano (20/10/2026 noche; lo de "Llegué igual" quedó superado por la respuesta de abajo: Llegué es estricto): "hice un recorrido y después lo mismo sin moverme: si no te movés, ponés la dirección, esperás el tiempo y decís que llegaste bien, lo toma como hecho y en realidad nunca llegaste. Tendría que haber una manera con la geolocalización de darte cuenta si de verdad está en el lugar".** Tenía razón: `Llegué` cerraba el camino sin mirar dónde estaba la persona (y apagaba el aviso a los referentes). **Armado, sin instalar:** `aplicar-guardian-llegada-panel.ps1` (respaldo `.bak-pldllegada`; solo servidor, sin tocar la base; reemplaza al de parpadeo, lo incluye y acepta las catorce versiones del bloque desde `aplicar-guardian-mejoras-panel.ps1`: las anteriores no tienen `gdRutaMapas` y el instalador las rechaza; 459 pruebas y nueve recorridos en navegador ok; corrido de verdad con PowerShell 7 contra las 14 versiones en LF, CRLF y CRLF con BOM, y los casos de rechazo). Al tocar Llegué la página pide la ubicación del navegador (como Cambiar destino) y el servidor la compara con el destino (`gd_viajes.dest_lat / dest_lng`) junto con la del teléfono si es de los últimos 10 minutos: con cualquiera de las dos a menos de **300 m** da por llegada (`motivo_fin = llegue_comprobada`; el resumen y el registro dicen "Comprobamos con tu ubicación…"). Si está **lejos** (seguro, aun contando el error de la ubicación) **no se cierra**: 409 `lejos_del_destino` y la pantalla dice "Todavía no estás en Casa: según tu ubicación estás a 1,7 km…" con **Volver a comprobar** y **Llegué igual**; si **no se puede ver** dónde está (sin permiso, ubicación vieja o con más de 500 m de error) → 409 `sin_comprobar`, mismo panel. El reloj sigue y, si no llega, el aviso a los referentes sale como siempre (con la pausa puesta tampoco se cierra). **Llegué igual** cierra y queda `llegue_sin_comprobar` y anotado en el registro ("Cerraste el camino a Casa… pero tu ubicación está a 1,7 km"); a los referentes solo les llega algo si ya se los había avisado (el mail dice que está bien, cuenta la distancia y que se comuniquen). No se comprueba: un destino escrito a mano con los minutos (no tiene punto en el mapa) y cuando ya se avisó a los referentes (ahí es "ya estoy bien": se cierra y el mail dice si la ubicación lo confirma o a cuántos km estaba). **Preguntas sí/no abiertas:** (1) ¿"Llegué igual" queda, o se vuelve estricto (solo llegar, cambiar el destino o cancelar el camino)? Recomendado: que quede, para que nadie se quede atrapado con un GPS flojo; queda anotado. (2) ¿"Llegué igual" estando lejos también les avisa a los referentes? Recomendado: no, para no asustarlos por un GPS flojo. (3) ¿Una opción en Configuración del Modo Guardián para apagar la comprobación? Recomendado: no por ahora.
**Respuesta de Luciano (20/10/2026 noche) a lo de Llegué, y dos cosas más:** (1) **"Porque si no, los chicos son tramposos y dirían que van a lo de un amigo, el papá se queda tranquilo porque llegó, pero al final se quedó en el lugar bailando, esperando que termine el tiempo"** → Llegué **estricto**: se sacó "Llegué igual" y `forzar` (no hay forma de cerrar el camino sin estar en el lugar; si no se puede comprobar, se vuelve a comprobar, se pide más tiempo o se cancela; en la alerta, con los referentes ya avisados, sigue sin discutirse). (2) **"Que tenga un margen de 100, 150 metros, por las dudas de que no geolocalice bien"** → el margen de llegada es de **150 m** (antes 300) y se elige en Tu protección > Configuración > Modo Guardián > Llegada (`gd_config.radio_llegada_m`, de 50 a 500 m; "Volver a los valores recomendados" lo devuelve a 150; la respuesta 409 trae `radioM` y la pantalla dice "se da por llegada a menos de 150 m"). (3) **"Ahora empieza a pitar después de los 5 segundos y tampoco parpadea, como habíamos dicho, en rojo"** → dos causas probables: el navegador no deja sonar (ni vibrar) hasta que se toca la pantalla, y recién a los ~5 s la persona la tocó; y el parpadeo era una animación de estilos que se apagaba con "reducir movimiento" / animaciones apagadas del teléfono (lo había puesto yo a propósito). Ahora: el reloj titila con un **temporizador** (una vez por segundo, siempre), y el aviso **"Sonido sin activar: tocá la pantalla una vez para que suenen los pitidos de los últimos 15 segundos"** se ve desde que se abre el camino (antes solo el último minuto). Para que suene sin tocar nada hace falta la app (ítem 9 de la próxima build). **Armado, sin instalar:** `aplicar-guardian-llegada-estricta-panel.ps1` (respaldo `.bak-pldestricta`; solo servidor, sin tocar la base: `gd_config` gana la columna `radio_llegada_m` sola; reemplaza al de llegada y al del parpadeo, los incluye y acepta las quince versiones del bloque desde `aplicar-guardian-mejoras-panel.ps1`; 463 pruebas y nueve recorridos en navegador ok, con un audio de mentira que queda suspendido hasta el primer toque; corrido de verdad con PowerShell 7 contra las 15 versiones en LF, CRLF y CRLF con BOM, y los casos de rechazo). **Pregunta sí/no abierta (por los chicos tramposos):** hoy **"Cancelar camino" no avisa a nadie** y **"Cambiar destino"** tampoco: un chico podría cancelar, o cambiar el destino al lugar donde se queda, y el papá no se enteraría. ¿Les avisamos a los referentes cuando se cancela o se cambia el destino? Recomendado: sí para los menores (solo el administrador lo apaga); para un adulto, que sea una opción de Configuración. Siguen abiertas las del SOS (que el enlace del referente muestre siempre la última señal durante un SOS: recomendado sí; el botón queda en 3 s). **Instalado y publicado por Luciano el 20/10/2026** (versión del Worker `b8bbdf2a-36ec-481c-bd9c-88e3e20c2c35`; el instalador reconoció el bloque de 189186 caracteres, el de "origen / modos / sonido": los instaladores del parpadeo y de la llegada comprobada nunca se habían corrido, y este los incluye; por eso "no parpadeaba"). Falta probarlo en el celular: Llegué sin moverse (no cierra y dice a cuántos metros o km), en el lugar (cierra como comprobado), el margen de Configuración, los últimos 15 segundos (titila en rojo) y el aviso de sonido.
**Respuesta de Luciano (20/10/2026 noche) a la pregunta de avisar al cancelar o cambiar: "sí, avisar cuando cambia o cancela".** Hecho (solo servidor y páginas del panel): a los referentes que aceptaron les llega un mail cuando la persona **cancela el camino** ("Lucas canceló el camino a Casa": a qué hora, a dónde iba, la última ubicación del teléfono con el mapa y a cuántos metros o km estaba del destino, y "Si no lo esperabas, comunicate con Lucas") o **cambia el destino a otro lugar** ("Lucas cambió el destino: ahora va a Kansas Cabildo": antes iba a Casa, ahora a Kansas, cómo va, hasta qué hora tiene y la última ubicación). **No avisa** si sigue yendo al mismo lugar y solo cambia cómo va o recalcula el tiempo, ni al frenar un rato (eso sigue sin avisar). La pantalla del camino lo dice antes ("Si cambiás de destino, se les avisa a tus referentes."; al cancelar, "¿Cancelar el camino? Se les avisa a tus referentes.") y después lo confirma ("Se les avisó a tus referentes."); en el registro queda "Se le avisó a Mamá que cancelaste el camino a Casa.". **Opción** en Tu protección > Configuración > Modo Guardián > "Avisos a tus referentes" > "Avisarles también si cambio el destino o cancelo el camino" (viene en **Sí**; `gd_config.avisar_cambios`, columna que se crea sola; con un menor la cambia solo el administrador; con un camino en marcha no se cambia; "Volver a los valores recomendados" la deja en Sí). Si no hay referentes activos, cancelar o cambiar anda igual. **Instalado y publicado por Luciano el 20/10/2026** (versión del Worker `0eb0877d-7782-4b99-9308-ba2ac64da4ae`; el instalador reconoció el bloque de 201299 caracteres, el de la llegada estricta, y dejó `src\index.ts` en 455738 caracteres): `aplicar-guardian-avisos-cambios-panel.ps1` (respaldo `.bak-pldcambios`; solo servidor, sin tocar la base; reemplaza al de la llegada estricta, lo incluye y acepta las dieciséis versiones del bloque desde `aplicar-guardian-mejoras-panel.ps1`, incluida la ya instalada de la versión del Worker `b8bbdf2a`; 473 pruebas y nueve recorridos en navegador ok; corrido de verdad con PowerShell 7 contra las 16 versiones en LF, CRLF y CRLF con BOM —48 corridas— y los casos de rechazo). El instalador de la llegada estricta se sacó del repositorio (ya estaba instalado y este lo incluye). Falta probarlo en el celular: cancelar (el mail al referente con la ubicación), cambiar a otro lugar (mail), seguir al mismo lugar en otro transporte (sin mail) y la opción Sí/No en Configuración. Siguen abiertas las del SOS (que el enlace del referente muestre siempre la última señal durante un SOS: recomendado sí; el botón queda en 3 s).
**Dos observaciones de Luciano al probar lo recién instalado (20/10/2026 noche).** (1) **"En Configuración, en la parte de protección, no te deja ir atrás como todos los demás que dicen botón Configuración. Sí o sí estás obligado a ir a inicio. Es en Tu protección."** Tenía razón: Configuración > **Tu protección** de la consola abre otra página (`/guardian#configuracion`), que arriba solo tenía "← Ir al inicio" y "← Tu protección" (el inicio de esa página), y no había cómo volver a la lista de la consola. **Instalado y publicado por Luciano el 20/10/2026** (versión del Worker `0145f42f-46df-42a6-8942-c5c6f43c8857`; reconoció el bloque de 206062 caracteres; `src\index.ts` quedó en 456193; falta que pruebe el "← Configuración"): `aplicar-proteccion-volver-panel.ps1` (respaldo `.bak-pldvolver`; solo la página Tu protección del servidor, sin tocar la base ni la consola; reemplaza al de avisos al cancelar o cambiar, lo incluye y acepta las diecisiete versiones del bloque desde `aplicar-guardian-mejoras-panel.ps1`, incluida la ya instalada de la versión del Worker `0eb0877d`; 474 pruebas y nueve recorridos en navegador ok, más un recorrido real consola → Tu protección → "← Configuración" → vuelve a la lista; corrido de verdad con PowerShell 7 contra las 17 versiones en LF, CRLF y CRLF con BOM —51 corridas— y los casos de rechazo): si la página se abre **directo en su Configuración** (así llega desde la consola, un cambio de página completo), la pantalla se llama "Tu protección" (como la categoría que se tocó), arriba dice **← Configuración** y vuelve a `/#config` (la lista de Configuración de la consola); adentro de cada categoría siguen "← Ir al inicio" y "← Tu protección" (vuelve a esa lista); si se llega desde el inicio de Tu protección (botón OG o la tarjeta Configuración) todo queda como estaba. Se detecta con `var DESDEPANEL=vistaActual()==="configuracion"` al cargar la página (un cambio solo de `#` dentro de la misma página no cuenta). El instalador de los avisos al cancelar o cambiar se sacó del repositorio (ya estaba instalado y este lo incluye). (2) **"En Ajustes está Software y abajo a la derecha dice Panel y es el mismo botón repetido, ¿o no?"** No es de la consola ni de Tu protección (ahí no hay nada que se llame "Software"): es de la **app del celular**, donde la barra tiene Inicio, Perfil, Ajustes y **Panel** (abre la consola con la sesión ya iniciada). El único repetido que hubo era "Abrir Ojo Guard MS →" adentro de Ajustes > Ojo Guard MS y se sacó el 16/10 (`aplicar-familia-pantalla-app.ps1`; quedan Enviar código, Vincular, Sincronizar órdenes y Crear acceso seguro, que son otra cosa). El código de la app está en la compu de Luciano y acá no se ve qué dice "Software": **Aclaración de Luciano: se refería a "Ojo Guard MS" (la tarjeta de Ajustes de la app) y "Panel" (barra de abajo, a la derecha), que le parecen el mismo botón repetido.** Funcionan distinto (la tarjeta es vincular/sincronizar este teléfono; Panel abre la consola) pero los nombres confunden: para la próxima build, (la tarjeta y el botón Panel usaban el mismo ícono `config-conexion.png`). Luciano pidió: "que esté en Claves y Seguridad con los dos íconos". **Aplicado por Luciano el 20/10/2026, `tsc` compila bien (sale en la próxima build, falta verlo en el teléfono):** `aplicar-ms-en-claves-app.ps1` (respaldo `.bak-msclaves`; toca solo `src\GruposConfiguracion.tsx`, comprobado por huella contra el archivo que mandó el 20/10/2026; corrido con PowerShell 7 en LF, CRLF y CRLF con BOM; sintaxis revisada con TypeScript, falta el `tsc` completo en su compu, que el instalador corre al final): desaparece la tarjeta Ojo Guard MS de Ajustes, Claves y Seguridad muestra los dos íconos (llave y conexión) y el estado de la vinculación, y adentro está la sección "Ojo Guard MS · Teléfono principal" con todos sus botones para confirmar a cuál se refiere y, si es un repetido de verdad, sacarlo en la próxima build de la app.
**SOS: enlace del referente en vivo (20/10/2026, "hacemos esos pendientes"; se siguió lo recomendado: sí al enlace, el botón queda en 3 s).** **Instalado y publicado por Luciano el 20/10/2026** (versión del Worker `0c119a04-8de2-4221-a8f8-fc68dfeea514`; reconoció el bloque de 206516 caracteres; `src\index.ts` quedó en 457493; falta probarlo con un SOS real): `aplicar-sos-enlace-vivo-panel.ps1` (respaldo `.bak-pldsosenlace`; solo servidor, sin tocar la base; reemplaza al de "volver", lo incluye y acepta las dieciocho versiones del bloque, incluida la instalada de la versión del Worker `0145f42f`; 479 pruebas y nueve recorridos ok; PowerShell 7 contra las 18 versiones, 54 corridas, y casos de rechazo). `pldSosActivo` (último `sos` más nuevo que el último `sos-fin` en `pld_log`, hasta 6 h): con un SOS en marcha, "No lo encuentro" muestra la última señal sin condiciones ni "¿Estás bien?", con el cartel "SOS en marcha"; cancelado el SOS vuelve a lo de siempre. No hay cambio de app.
**Revisión de los mails de las pruebas en el Gmail de Luciano (20/10/2026 noche).** Cancelar y "Llegué" lejos andan bien (mail "Lu canceló el camino a Ugarteche 3326" con ubicación y "a 200 m"; "Todavía no estás en…" a 210 m). **Repetidos:** los tres "Lu no llegó a Ugarteche 3234" (19:22, 19:33, 19:44 UTC) son a propósito (aviso 1, 2 y 3 de 3, cada ~10 min mientras el camino sigue abierto; se cambia en Configuración > Modo Guardián). **Sin dirección:** esos mails traían solo coordenadas ("-34.58003, -58.41070") porque el teléfono no mandó la dirección. **Armado, sin instalar:** `aplicar-mails-direccion-panel.ps1` (respaldo `.bak-pldmails`; solo servidor; reemplaza al del SOS y acepta las diecinueve versiones; 482 pruebas y nueve recorridos ok; PowerShell 7, 57 corridas): si falta la dirección se la pide a Google (Geocoding; hace falta habilitar esa API en la clave, si no salen las coordenadas) y los mails de "no llegó", "canceló" y "cambió el destino" dicen siempre a cuánto está del destino. **Detalle visto:** el mail "está bien" del 19:42 decía "su ubicación está a 650 m" (usó la ubicación del teléfono de hace 10 min) mientras la pantalla decía "no se pudo comprobar": pendiente unificar el texto.
**Pulido para el próximo instalador del panel:** distinguir en pantalla "falta la clave" de "la clave guardada no sirve (tiene N caracteres raros)".
**Punto 1 de la build, armado (20/10/2026, sin instalar):** `aplicar-aviso-con-enlace-app.ps1` (respaldo `.bak-avisoenlace`, solo `App.tsx`, solo JavaScript): al tocar un aviso con `data.tipo` = `pld-estoy-bien` o `guardian` (con la app abierta, en segundo plano o cerrada) se abre `data.url` en el navegador,
solo si es de `https://ojo-guard-ms-api.bickluciano.workers.dev/` y el aviso es de las últimas 2 horas; el servidor ya manda ese `data` (en el código nuevo de Tu protección / Guardián, que se instala con `aplicar-guardian-camino-panel.ps1`, todavía sin armar).
**Punto 2, lo que se leyó de la app:** la cadena de despertadas usa `AlarmManager` (módulo `exact-alarm`: `ExactAlarmReceiver` → `ExactAlarmTaskService` → tarea JS cada 15 min; `ExactAlarmBootReceiver` escucha `BOOT_COMPLETED` y `QUICKBOOT_POWERON`); las credenciales viven en `expo-secure-store` (`src/remoteStorage.ts`, clave `ENROLLMENT_KEY`),
que antes del primer desbloqueo no se puede leer. El modo nativo de direct boot necesita: receptor `directBootAware` con `LOCKED_BOOT_COMPLETED`, una copia mínima de credenciales en `createDeviceProtectedStorageContext()` (con un token de arranque de alcance limitado, no el enrolamiento completo), un cliente HTTP en Kotlin, y del lado del servidor un endpoint de "latido de arranque". Falta decidir el alcance con Luciano.

### Lista de la próxima build de la app (juntada el 20/10/2026, falta armarla y probarla)

1. Pantalla **"Estoy bien"** al tocar el aviso "¿Estás bien?" (no depender del mail).
2. Que la app **despierte sola después de reiniciar** el teléfono (hoy no manda señales hasta abrirla una vez).
3. **Configuración sin bloqueo de pantalla** para una persona cuidada (papá): hoy la app pide "Configurá un acceso seguro" y el PIN; elegida la opción B: no abrir esa pantalla en ese teléfono.
4. ~~Sin foto al tocar mal el código para personas mayores~~ **Decidido por Luciano (20/10/2026): "con foto"**: se mantiene la foto al tocar mal el código, también en el teléfono de personas mayores. No se cambia.
5. **Regla de menores y administrador en la app:** el menor solo ve su protección, el titular y los adultos de la familia la arman (ya está en el servidor y el panel).
6. **Familia: todos los dispositivos de cada persona por defecto** (etapa 1 de arriba) y el atajo "Abrir Buscar" / "Abrir Find Hub".
7. Título del iPhone alineado; pendientes sueltos de la lista de iPhone / Android más arriba (por ejemplo "Compartir de nuevo" cortado en Familia).
8. Trámites que acompañan: declaración **DSA de trader** en App Store Connect, `--auto-submit`, y la respuesta de Apple por Alertas críticas (21/10).
9. **Guardián en la app: cuenta regresiva de los últimos 15 segundos por el parlante del teléfono aunque haya Bluetooth conectado** (módulo nativo: Android `setPreferredDevice(TYPE_BUILTIN_SPEAKER)`, iPhone `overrideOutputAudioPort(.speaker)`), con vibración y pantalla encendida; hoy la página web no puede forzar la salida (Luciano, 20/10/2026: el pip no sonó con un auricular Bluetooth conectado).

### Primer arranque y estética: lista armada mirando Life360 (21/10/2026, pedido de Luciano: "me gusta la modernidad de las imágenes; la nuestra es muy dura")

Life360 (4.8 en la App Store, 22 mil calificaciones, #10 en Redes sociales; gratis con plan Platinum de USD 19,99/mes y 7 días de prueba; su consentimiento dice que puede vender o compartir los datos de ubicación para anuncios) como referencia de primer arranque. **Primer arranque:** (1) una pantalla por permiso, explicando para qué sirve ANTES del aviso del sistema (ubicación siempre, movimiento, notificaciones, segundo plano en iPhone); (2) código de invitación con vencimiento (7 días), QR y botones de Messages / WhatsApp; (3) elegir el rol (mamá, papá, hijo, abuelo, pareja, amigo); (4) configurar "Casa" en el primer minuto y sugerir escuela, trabajo, gimnasio, supermercado; (5) "Alguien me invitó" / "Empezar desde cero" en la primera pantalla; (6) verificar por WhatsApp en vez de SMS (resuelve de paso lo de Twilio); (7) previsualizar cómo llegan los avisos antes de pedir permiso de notificaciones; (8) foto de perfil con pin redondeado, o inicial si se omite. **Avisos y mails:** frases cortas con una acción ("Revisa su ubicación"); SOS con cuenta regresiva en pantalla y "tu SOS se enviará a N personas". **Estética (sin copiar el violeta de ellos, respetando la marca):** esquinas más redondas y más aire, un solo foco por pantalla, tarjetas blancas cálidas en modo claro y vidrio ahumado en noche, avatares y pines con foto en el mapa, íconos de línea más suaves, microanimaciones lentas, textos en minúscula y más cálidos; el ámbar solo para energía y estado. Todo lo nuevo se marca `NÚCLEO · EN VALIDACIÓN` hasta probarlo en un teléfono. Nada de candados, escudos ni tableros de tarjetas con números.

**Maqueta aprobada por Luciano (21/10/2026: "eso sí me gusta"):** cuatro pantallas de ejemplo (mapa claro, Modo Guardián, primer arranque con permiso, mapa de noche) en un artefacto privado de Claude (`claude.ai/artifact/Ya3SRUKvGSbAgnXqzd3Ff2`; es de ejemplo, con la etiqueta `VISIÓN · SIMULACIÓN CONCEPTUAL`). Dirección elegida: **azul, blanco y dorado** (nada de violeta; "lo vemos" el tono exacto con los tweaks), formas redondeadas, mucho aire, pines con inicial (después con foto), hoja de abajo con Personas / Lugares / Equipos, reloj en anillo en el Guardián. Falta decidir por dónde empezar: lo web (camino, Tu protección y consola) se ve al instante sin build; la app necesita build.
**Estética web, paso 1 (21/10/2026, "sí, empezá por ahí"; "la tipografía es más clara, se ve mejor"). Armado, sin instalar:** `aplicar-estetica-web-panel.ps1` (respaldo `.bak-pldmoderno`; solo servidor; reemplaza al de los mails con dirección —que Luciano todavía no había corrido— y lo incluye; acepta las veinte versiones del bloque, incluida la instalada de la versión del Worker `0c119a04`; 482 pruebas y nueve recorridos ok; PowerShell 7, 60 corridas y casos de rechazo): las páginas del camino, Tu protección, Configuración y el enlace del referente pasan a fondo marfil con tarjetas blancas redondeadas (de noche, azul tinta con marfil y dorado, según el modo del teléfono), botones en pastilla azules, tipografía Plus Jakarta Sans y Outfit (Google Fonts, con la del sistema como respaldo), el reloj del camino dentro de un anillo azul que se vacía, "sonido sin activar" en aviso dorado (ya no rojo) y la marca "ojo guard" en texto. Falta: consola y app. Nota: `e2e.js` fallaba de noche (el último mail a Lucas era el de "consultó tu última señal"); se corrigió para buscar el mail con el enlace de "Estoy bien".
**Estética de la consola, paso 2 (21/10/2026; Luciano: "no rompamos ningún código y no saquemos nada nuestro"). Armado, sin instalar:** `aplicar-consola-estetica-panel.ps1` (respaldo `.bak-esteticaconsola`; toca solo `src\panel-index.html`, agrega un bloque `<style id="estetica-v1">` y la tipografía; no cambia ningún id, botón ni programa; comprueba la huella del archivo que dejó el instalador de Configuración —49860 caracteres— antes y después; PowerShell 7 en LF, CRLF y CRLF con BOM; `e2e-consola.js` y `e2e-emergencia.js` dan idéntico con y sin el estilo): tarjetas blancas redondeadas sobre marfil (de noche, azul tinta), botones de borde suave en pastilla, lista de Configuración y barra de abajo más redondeadas, campos más suaves; el botón OG y el de modo claro / noche siguen. Falta: la app.

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

## App: arranque del usuario nuevo (22/10/2026)
- Instalados en la app (salen en la PROXIMA build): bienvenida de 13 diapositivas, foto de perfil, foto del documento (DNI o pasaporte), foto de la cara, acceso solo con prueba de 3 dias (Empresa escondida, su codigo queda), logo e icono nuevos.
- PENDIENTE (no existe todavia): la COMPARACION entre la cara y el documento. Hoy las tres fotos quedan guardadas en el telefono con estado "pendiente_de_verificar". Hay que decidir proveedor o desarrollo propio, deteccion de persona real, texto de consentimiento, cuanto tiempo se guardan los datos y revision legal (datos biometricos). Hasta entonces la app NO dice que verifico nada.
- PENDIENTE: subir esas fotos al servidor (no hay endpoint) y mostrar la foto de perfil en el circulo familiar.
- PENDIENTE: pasos 6 y 7 del arranque (telefono y claves, circulo) siguen siendo las pantallas actuales ("Preparar este telefono"); falta unificar el aspecto y la barra de 7 pasos.
- Quien ya tiene la app abierta con su cuenta no ve nada de esto: solo el usuario nuevo.

## Dominio propio del panel (22/10/2026)
- `ojoguard.app` esta ahora en Cloudflare (servidores de nombres `ligia`/`rudy`); los 21 registros se copiaron desde IONOS (web en GitHub Pages, correo IONOS, Resend en `notificaciones`, `panel`, `watch`). DNSSEC no estaba activo.
- `ms.ojoguard.app` conectado al Worker `ojo-guard-ms-api` desde Cloudflare (Dominios y rutas). `aplicar-dominio-panel.ps1` lo deja fijo en `wrangler.toml` y pasa `PASSKEY_ORIGIN` / `PASSKEY_RP_ID` a ese dominio (links de SMS y mails + passkeys). Hay que volver a registrar las passkeys una vez.
- PENDIENTE: registros opcionales no copiados: TXT `_openai-site-verification`, AAAA de `info`, TXT `cf-custom-hostname` (sin guion bajo).
- PENDIENTE: la web `ojoguard.app` (GitHub Pages) muestra "We're still building this page" con el correo personal; poner contenido real, boton "Ingresar" a `ms.ojoguard.app` y `soporte@ojoguard.app`. Bing indexa `watch.ojoguard.app` primero.
- PENDIENTE: la app (build) sigue llamando a `workers.dev` (`OJO_REMOTE_API_BASE` en sos.ts/familyGeofence.ts y en App.tsx): funciona, pero conviene pasarla a `ms.ojoguard.app` en el proximo build.
- PENDIENTE: marca: buscar "Ojo Guard" en el INPI (clases 9, 42, 45) y registrarla con un agente; el usuario de YouTube `@ojoguard` esta ocupado por un canal inactivo.

## Direccion principal y mails nuevos (22/10/2026)
- HECHO: `ojoguard.app` abre el panel (Worker, dominio personalizado). `ms.ojoguard.app` y `workers.dev` siguen andando. Se borraron en Cloudflare los 4 registros A de GitHub del dominio raiz. `PASSKEY_RP_ID`/`PASSKEY_ORIGIN` = `ojoguard.app`; links de mails y SMS salen con `ojoguard.app`.
- HECHO: mails con franja azul + logo nuevo, cuerpo blanco compacto para el celular, codigo grande arriba, pie con el link del panel (instaladores `aplicar-correos-marca-panel.ps1`, `-pie-`, `-compacto-`; el cuerpo de cada mail se escribe igual y `claroCorreo` pasa los colores). Logo PNG servido en `/marca/ojo-guard-correo.png`.
- HECHO: mapa de Google en `ojoguard.app` (se agrego `https://ojoguard.app/*` a las direcciones permitidas de la "Clave de API 3").
- PENDIENTE: boton "Agregar huella o Face ID en este equipo" en Configuracion > Cuenta y seguridad. Hoy el acceso seguro (passkey) solo se crea desde el boton "Crear acceso seguro a MS" de la app del telefono. La tarjeta "Proteccion de ingreso" dice "1 acceso seguro activo": es el viejo, de la direccion anterior, no sirve en `ojoguard.app`. Mientras tanto se entra con el codigo por mail o con el codigo del autenticador.
- PENDIENTE (verificar con el telefono): que "Crear acceso seguro a MS" de la app abra `ojoguard.app` y no `workers.dev` (si abre `workers.dev` la passkey falla por el dominio). Si falla, hay que pasar la app a `ojoguard.app` (proxima build) o redirigir desde el servidor.
- PENDIENTE: DMARC estricto (`p=quarantine`, luego `reject`) para que los mails lleguen a la bandeja principal; hoy `_dmarc` es un CNAME a `dmarc.ionos.com`. Ver primero que politica tiene. Es requisito para el logo en el circulo (BIMI).
- PENDIENTE: logo de la marca en el circulo del remitente (BIMI): hace falta DMARC estricto + logo SVG Tiny + certificado (VMC, pide marca registrada, o CMC, pide 12 meses de uso publico del logo). Costo de cientos a mas de mil dolares por ano, a cotizar. Va despues del registro de marca en INPI.
- PENDIENTE: tope diario de gasto del mapa de Google cuando haya muchos clientes.
- PENDIENTE: la web de `ojoguard.app` raiz ya no es la de GitHub: ahora es el panel. Si se arma una web de presentacion, va en `www.ojoguard.app` (sigue apuntando a GitHub Pages) o en otro subdominio; el pie de los mails ya dice `ojoguard.app`.

## Mac como equipo (23/10/2026)
- `scripts/compu/ojo_guard_compu.py` (v0.6) es el programa de la computadora para Windows y Mac. El de Windows en uso es la v0.5 (`ojo_guard_compu_v05_windows.py` en la misma carpeta, copia de referencia). En la notebook corre desde `%APPDATA%\OjoGuardCompu`; `config.json` y `log.txt` de ahi NO se comparten (tienen la clave y ubicaciones).
- Mac: sonido con `afplay`, foto con opencv (AVFoundation), audio con sounddevice, bateria con `pmset`, ubicacion APROXIMADA por internet (macOS no da ubicacion exacta a un Python simple), arranque con LaunchAgent. El panel lo muestra como equipo "Mac" (plataforma `macos`).
- PENDIENTE: probar en la Mac real (permisos de camara y microfono; si el LaunchAgent los pide, correr una vez a mano con `--probar-evidencia`). Mejora posible: ubicacion exacta con CoreLocation (pyobjc).
- PENDIENTE: en el panel, "Agregar dispositivo" no ofrece computadoras; el alta se hace corriendo este programa. Agregar una opcion "Computadora (Windows o Mac)" con los pasos.

## Ubicacion de computadoras y mapa (23/10/2026, charla con Luciano)
- PROBLEMA (visto en el Android): en la primera pagina de la app el mapa muestra los equipos en lugares distintos aunque estan todos juntos. La Mac aparece en un lugar donde nunca estuvo: el programa de la compu (`ojo_guard_compu.py`) manda `source: ip`, `accuracy: 5000`, `confidence: baja` (ubicacion por la direccion IP, que suele caer en la central del proveedor, a veces en otra ciudad) y el mapa la dibuja como un punto firme.
- PENDIENTE: el boton de arriba a la derecha que centra y junta los equipos NO funciona en el mapa de la app (en la consola del panel si). El codigo del mapa de la app es `src/InicioMapa.tsx` (en la PC de Luciano, no esta en el repo): hace falta ese archivo para arreglarlo.
- PENDIENTE "Ubicacion honesta": (1) en la Mac, intentar la ubicacion real de macOS (CoreLocation por Wi-Fi) y si no se puede dejar la de internet; (2) en el mapa y el panel, ubicacion solo por internet = circulo grande con la etiqueta "aproximada", sin mezclarla con los puntos precisos y sin que el boton de centrar la use; (3) etiqueta de confianza: exacta (GPS) / aproximada (red) / vieja (hace X horas); (4) aprender redes conocidas: si el telefono confirma con GPS que esta en "casa" y la compu ve la misma red Wi-Fi, esa red queda como "casa"; (5) cruzar con el telefono cuando comparten red.
- Sobre Apple: la impresion de Luciano (Buscar mostrando lugares que no existen, p. ej. Hurlingham) es una experiencia suya; NO esta verificado como falla general de Apple, por eso no va en el pitch como hecho.
- Pitch: decir "cuando el equipo se conecta" y no "siempre lo encuentra"; un equipo apagado o sin internet no avisa (Apple tiene una red de Bluetooth entre sus dispositivos; Ojo Guard no). Revisar las laminas para que no prometan de mas.
- IDEA A EVALUAR (no descartada): usar listas publicas de claves Wi-Fi (apps tipo WiFi Map) para que una compu sin red se conecte sola. Antes de decidir: (1) consultar a un abogado (conectar solo un equipo vs. que una persona vea la clave); (2) preguntar a esas empresas si hay API o licencia para terceros (sus terminos suelen prohibir copiar la base); (3) probar si el programa corre en la pantalla de bloqueo (hoy solo corre con sesion iniciada); (4) medir si aporta algo (el ladrón suele conectar a su propio Wi-Fi o a datos del celular). Las redes ya guardadas se conectan solas por el sistema: no hace falta nada.
- MEJORA SIMPLE: "redes de confianza": el usuario carga redes de otros lugares (padres, oficina) donde el equipo no tiene la clave guardada.

## Mac: permiso de camara y microfono (23/10/2026) - RESUELTO
- Problema: el programa que arranca solo (LaunchAgent) corria con el Python suelto, que NO figuraba en Ajustes > Privacidad > Camara/Microfono: macOS lo negaba (`camara_no_disponible`, `PortAudioError -9986`) aunque `--probar-evidencia` desde la Terminal andaba.
- Solucion: `scripts/compu/instalar_mac_permisos.sh` arma `~/Applications/OjoGuardCompu.app` (copia del Python de python.org + Info.plist con textos de permiso, firma ad hoc) y el LaunchAgent corre esa app con `PYTHONHOME`. macOS pidio permiso a "OjoGuardCompu" (camara y microfono) y desde entonces la Evidencia llega: log `Evidencia enviada: foto 82 KB, audio si, ubicacion si.` y aparece en la pestana Evidencias del panel. Deshacer: `bash instalar_mac_permisos.sh --volver`.
- Para otra Mac: bajar el programa, vincular, `python3 ojo_guard_compu.py --instalar`, correr `instalar_mac_permisos.sh` y permitir los carteles. Hay que hacerlo despues de cada actualizacion de Python (la app lleva una copia).
- PENDIENTE: que `--instalar` en Mac arme esta app solo (hoy es un paso aparte).
- PENDIENTE: la ubicacion de la Mac sigue siendo por internet (+-5000 m); la app OjoGuardCompu ya tiene el texto de permiso de ubicacion, falta usar CoreLocation (pyobjc) para tenerla exacta.
- PENDIENTE: el cartel de orden dice "se ejecuta cuando el telefono se conecte" tambien para computadoras: decir "la computadora".
- PENDIENTE: panel: computadoras con ubicacion solo aproximada: cartel "Conectada" (no "En vivo"), circulo grande y sin pin firme.
- (23/10/2026) HECHO en el panel: computadora con ubicacion solo aproximada (margen >= 1500 m) = "Conectada" (no "En vivo"), pin apagado, "aprox." y circulo del margen (`aplicar-mapa-aproximada-panel.ps1`). El boton circulo del mapa va a "mi ubicacion" y despues "ver todos" con equipos recientes y no aproximados (`aplicar-mapa-centrar-mi-panel.ps1`).
- (23/10/2026) EN PRUEBA: ubicacion real de la Mac con CoreLocation (programa v0.7.0 + `scripts/compu/actualizar_mac_ubicacion.sh`: instala pyobjc-framework-CoreLocation, verifica la huella del programa, guarda `.bak-0.6.1`). Necesita el permiso de Ubicacion para OjoGuardCompu. NO probado en Mac real al escribirlo: si CoreLocation no entrega nada, el programa sigue usando la ubicacion por internet. Volver atras: `bash actualizar_mac_ubicacion.sh --volver`.
- (23/10/2026) UBICACION EXACTA DE LA MAC: NO SE PUDO. Se probo CoreLocation (programa v0.7.1, `actualizar_mac_ubicacion.sh`) y despues abrir la app con `open` (`mac_ubicacion_como_app.sh`, macOS 14.8.9): en los dos casos el registro dijo `mac_sin_ubicacion_permiso_0_error_1` (macOS nunca pregunta y CoreLocation rechaza). Con `open` la Evidencia dejo de andar (`camara_no_disponible`); con `--volver` (lanzador anterior) volvio a andar: `Evidencia enviada: foto 68 KB, audio si, ubicacion si.` ESTADO FINAL: Mac con el lanzador directo + programa v0.7.1 (si CoreLocation no entrega, usa la ubicacion por internet y lo deja escrito en el registro). La ubicacion de la Mac sigue siendo aproximada y el panel la muestra asi.
- IDEAS para la ubicacion de la Mac (no hechas): (1) app firmada con cuenta de desarrollador de Apple (unos 99 dolares por ano) y notarizada: es la salida estable para CoreLocation; (2) usar la ubicacion del telefono cuando comparten red ("misma red = mismo lugar"); (3) redes conocidas (ver mas arriba).
- NO usar `mac_ubicacion_como_app.sh` (rompe la Evidencia). Si se corrio, `bash mac_ubicacion_como_app.sh --volver`.
- (23/10/2026) VERIFICADO en el Android: "Crear acceso seguro a MS" abre `https://ojoguard.app/crear-acceso?bootstrap=...` (dominio nuevo). No hace falta cambiar la app para eso. Sigue pendiente pasar el resto de las direcciones fijas de la app (`workers.dev` en sos.ts, familyGeofence.ts, App.tsx y MapaEnApp.tsx) a `ms.ojoguard.app` en la proxima build (hoy funcionan porque `workers.dev` sigue activo).
- (23/10/2026) Boton "Agregar huella o Face ID en este equipo" (Configuracion > Cuenta y seguridad): instalado (`aplicar-huella-equipo-panel.ps1`, `-detalle-`, `-aviso-`). La notebook de Luciano (HP, Windows 10) NO tiene huella, rostro ni PIN de Windows Hello (los tres "no disponible actualmente": falta lector/camara IR y probablemente TPM), asi que ahi el boton avisa que no se puede. Falta probarlo de verdad en equipos que si tienen (Mac con Touch ID, notebook con lector de huella, o el celular).
- PENDIENTE (diseno): el cuadro "Correo registrado" del codigo de verificacion deja que Chrome autocomplete un correo viejo (hotmail) y lo trate como contraseña; ponerle `autocomplete="off"` / `one-time-code` y no mezclarlo con el de huella.
- PENDIENTE: en la app del telefono, esconder o quitar "Crear acceso seguro a MS" (en el telefono casi no sirve; vale mas en las computadoras).
- (23/10/2026) PENDIENTE (Luciano, lo hace despues): probar el boton "Agregar huella o Face ID en este equipo" en la MAC con Touch ID. Pasos: abrir `ojoguard.app` a mano en Chrome o Safari en la Mac, entrar con "Tengo un codigo de verificacion configurado" (correo `bickluciano@gmail.com`, no el de Hotmail que autocompleta Chrome), Configuracion > Cuenta y seguridad > "Agregar huella o Face ID en este equipo", poner Touch ID. Despues cerrar sesion y probar "Entrar con huella o Face ID". Tambien probar en el celular Android desde el navegador. Si falla, el mensaje trae el motivo entre parentesis. Antes conviene aplicar `aplicar-huella-equipo-aviso-panel.ps1` (commit 7a6b2c7d, sha 18927f0f...) para que un equipo sin huella/PIN lo diga claro.
- (24/10/2026) HALLAZGO: el boton "Panel" de la app (iPhone y Android) abria `https://ojo-guard-ms-api.bickluciano.workers.dev/acceso-v7?directo=1` (direccion vieja): el enlace de `nativePanelHandoff` se armaba con el origen de la peticion. Arreglo en el servidor: `aplicar-panel-ojoguardapp-panel.ps1` arma el enlace de la consola completa con `PASSKEY_ORIGIN` (ojoguard.app); el mapa dentro de la app (purpose "mapa") sigue en `workers.dev` porque `MapaEnApp.tsx` solo deja pasar `ORIGEN` = workers.dev. Si se pasa la app a `ms.ojoguard.app`, cambiar tambien `ORIGEN` en `MapaEnApp.tsx` ANTES de cambiar el enlace del mapa.

## Dr. Ojo Guard: que detecte lo de Modo perdido y las ordenes trabadas (24/10/2026, pedido de Luciano)
- Luciano: "esto lo tendria que decir el Dr. Ojo Guard; en teoria esta todo tildado". Hoy el Dr. mira: Conexion con Ojo Guard MS, Avisos, Ubicacion "Siempre", Gesto de volumen (A), Sirena del SOS (A), Auriculares Bluetooth (A), Bateria sin restricciones (A), Atajo del SOS (i). NO mira lo que fallo hoy:
  1. Modo perdido tomando toda la pantalla: en Android solo ocupa la pantalla con el telefono BLOQUEADO (permiso "notificaciones de pantalla completa" ya estaba activo, categoria "Modo perdido" bien: banner, sonido, anular No interrumpir). Con el telefono desbloqueado muestra solo el cartelito. Falta un item "Pantalla completa de Modo perdido" (permiso + "Mostrar sobre otras aplicaciones") y un boton "Probar Modo perdido" (como "Probar la sirena") que bloquee/avise "bloqueá el teléfono y esperá".
  2. Ordenes trabadas: hay pedidos `auto-locate` acumulados en `pending` cada 15 min para dos telefonos (`native_1`, `native_d`) que nunca se ejecutan (24/10/2026). La limpieza del 13/10 (`aplicar-limpieza-pedidos-automaticos.ps1`) evidentemente no esta frenando esto. Falta: revisar la causa en `src/index.ts` (cron) y un item del Dr. "Ordenes pendientes" (N sin ejecutar, mas viejo hace X).
  3. Evidencia en iPhone: es limite de Apple (solo se saca al abrir la app); el Dr. podria avisarlo como "nota" en el iPhone.
- Los items nuevos del Dr. necesitan una build nueva de la app (Android e iPhone).
- Datos del 24/10/2026: Evidencia Android "Mi teléfono" ejecutada (23/10 23:02 hora AR), una fallo `remote_capture_timeout`; iPhone "Mi teléfono" dos pedidos `pending` (nunca ejecutados); no hay ningun pedido `lost` en la cola desde el 20/10 (la orden de Modo perdido no llega a crearse: falta ver que muestra el panel al tocar Activar Modo perdido, posible confirmacion de identidad). Dos telefonos se llaman igual "Mi teléfono": renombrar.
- (24/10/2026) IDEA de Luciano: un BUSCADOR dentro de Ajustes de la app, y mas adelante un asistente con IA que ayude a encontrar y arreglar cosas ("donde esta Preparar autonomia para Modo perdido", "por que no se abre Modo perdido"). Ajustes hoy: banner "Permisos de Android: 4/4 OK" + tarjetas Familia y amigos, Claves y Seguridad, Fotos de Intrusos, Modo Perdido y Cercania, Preferencias. Propuesta por etapas: (1) buscador simple que filtre las tarjetas y los bloques por palabra (sin IA, sin costo); (2) en el Dr. Ojo Guard, mensajes con "que hacer" por ítem; (3) asistente con IA solo con textos de ayuda propios (sin enviar datos personales, ubicaciones ni fotos), con costo por consulta y revision de privacidad. Necesita build nueva. El banner "4/4 OK" solo mira 4 permisos basicos: no mira pantalla completa de Modo perdido ni la cola de ordenes.
- (24/10/2026) HALLAZGO Modo perdido en el Android de Luciano: la orden LLEGA y Modo perdido se activa al abrir la app ("MODO PERDIDO ACTIVO", con opcion de fijar la app), pero con el telefono bloqueado solo aparece la notificacion; no tapa la pantalla. Permisos revisados y bien: notificaciones de pantalla completa (activo), categoria "Modo perdido" (banner, sonido, anula No interrumpir), bateria "Sin restricciones", app sin "administrar si no se usa". Falta: "Mostrar sobre otras apps" = "Sin permiso", y el telefono NO deja darlo: al tocarlo dice "Funcion no disponible: se desactivo esta funcion porque ralentiza el telefono" (equipo de gama baja / Android Go, "siempre estuvo asi"). Para revisar con el codigo (`FullScreenAlertModule.kt`, `LostModeAlertActivity.kt`, `fullScreenAlertDiagnostics.ts`, `AndroidManifest.xml`): si la pantalla de Modo perdido puede salir SOLO con la notificacion de pantalla completa (sin "mostrar sobre otras apps"), y si no, avisarlo en el Dr. Ojo Guard como "limite de este telefono". Probar tambien en otro Android (marca y modelo a anotar).

## Ficha de los equipos de prueba (leer ANTES de diagnosticar algo de un teléfono)
Actualizada el 24/10/2026. Lo que no se sabe todavía está marcado "completar"; se completa en cuanto Luciano lo dice.
- **Android de Luciano ("Android Luciano" en la app): Xiaomi** (modelo y versión de Android: completar; Ajustes > Acerca del teléfono).
  Pantalla con muesca de gota y botones de navegación clásicos. Datos probados: permiso de pantalla completa (avisos) activado; batería sin restricciones;
  canal "Modo perdido" bien configurado; **"Mostrar sobre otras apps" figura "Función no disponible… ralentiza el teléfono" (siempre fue así)**.
  Modo perdido: llega la notificación en el bloqueo pero no toma la pantalla; al abrir la app aparece "MODO PERDIDO ACTIVO". Hacer sonar anda; evidencia anda.
  Xiaomi tiene permisos propios aparte de los de Android ("Mostrar en pantalla de bloqueo", "Abrir ventanas emergentes en segundo plano", autoinicio):
  revisar en Información de la app > Permisos > Otros permisos (pendiente de captura de Luciano). Luciano dice que antes de los cambios de diseño de la app andaba:
  fecha/versión de cuándo anduvo por última vez: completar. Los instaladores de diseño (estética, Inicio, Configuración) solo tocan pantallas de la app, nada nativo.
- **Android del papá de Luciano**: marca y modelo: completar (18/10/2026 se probó el acceso seguro con la clave de administrador).
- **iPhone de Luciano** y **iPhone de Mariana**: modelo y iOS: completar. Evidencia con la app cerrada: límite de Apple (queda pendiente hasta que se abra la app).
- **Mac**: macOS 14.8.9, Python 3.13; permisos de cámara/micrófono resueltos con OjoGuardCompu.app; ubicación exacta no se pudo (CoreLocation error 1).
- **Notebook HP con Windows 10**: sin Windows Hello (sin rostro, huella ni PIN), por eso no puede crear passkey ahí.
- Regla: antes de diagnosticar algo de un equipo, mirar esta ficha; si falta un dato, preguntarlo UNA vez y anotarlo acá.

### Modo perdido en el Xiaomi de Luciano: lectura del diagnóstico (24/10/2026, app 0.9.1 build 170)
- Permisos de Android: todos concedidos, ninguno rechazado, ubicación permanente, "Administrar la app si no se usa" apagado. Pantalla de permisos estándar de Android (sin "Otros permisos" de Xiaomi). "Avisos de pantalla completa: ya permitidos".
- Registro técnico: **el último aviso de pantalla completa se disparó el 20/10/2026 15:54:14**; en la prueba de hoy (~10:25-10:32) NO se disparó ninguno. La notificación que se ve en el bloqueo hoy no es la de pantalla completa.
- Sincronización en segundo plano por alarma exacta (appState=background, source=exact-alarm): 10:10:20 y 10:29:12 (cada ~19 min), con "commands-fetched: ninguna orden pendiente" a las 10:10:21 y 10:29:13. Entre 10:29:13 y 10:32:26 (cuando Luciano abrió la app) no hay ninguna lectura de órdenes: el aviso llegó pero la app no se despertó a leer la orden.
- Hipótesis (sin confirmar): Modo perdido depende de la sincronización por alarma (~19 min) y no del aviso push; si la orden llega entre dos sincronizaciones, la pantalla completa se dispara recién en la siguiente. Prueba pendiente: activar Modo perdido anotando la hora y esperar ~20 min con el teléfono bloqueado sin tocarlo.
- Mejora a evaluar (requiere build): que el aviso push despierte a la app para leer la orden al instante, y que el Dr. Ojo Guard muestre "última orden recibida / último aviso de pantalla completa".

- **Mejora de la app (hallazgo de Luciano, 24/10/2026): "Permisos de Android 4/4" no parece un botón.** Cuesta encontrarlo en Ajustes y es justo donde está el diagnóstico de Modo perdido. Que se vea como botón (tarjeta con flecha y relieve) y que el Dr. Ojo Guard lleve directo ahí ("Ver diagnóstico"). Requiere build.

### Modo perdido no toma la pantalla bloqueada: causa más probable (24/10/2026, app 0.9.1 build 170, leyendo App.tsx y src/backgroundRemoteTask.ts)
- Hay DOS caminos que ejecutan la orden "lost-mode":
  1. `src/backgroundRemoteTask.ts` (segundo plano: push de datos, tarea periódica, alarma exacta cada ~15 min): activa el estado Y llama a `triggerForegroundAlert("lost-mode")` = `showFullScreenAlert(..., fijar=true)`, y lo anota en el historial. Este es el que funcionó el 28/09 y el 20/10.
  2. `App.tsx` `executeRemoteCommand` rama "lost-mode" (cuando el proceso de la app está vivo y el aviso push dispara `addNotificationReceivedListener` → `syncRemoteCommands`): activa el estado, intenta `startScreenPinning()` y postea una notificación común. **NO llama a `showFullScreenAlert`.** Depende del vigilante de 2 s (`traerLaPantallaAlFrente`), que en segundo plano Android congela (lo dice el comentario de `triggerForegroundAlert`).
- Evidencia del 24/10: en el historial no hay ninguna orden lost-mode en segundo plano (todas las lecturas dicen "ninguna orden pendiente": 10:10, 10:29, 11:02), el último aviso de pantalla completa sigue siendo 20/10 15:54:14, y llegaron dos notificaciones (la del servidor + la común de App.tsx). Todo cuadra con que la orden la tomó el camino 2 y quedó confirmada antes de que el camino 1 la viera.
- Arreglo propuesto (chico, requiere build): en la rama "lost-mode" de `App.tsx`, si `AppState.currentState !== "active"`, llamar también a `showFullScreenAlert("Ojo Guard — Modo perdido", cuerpo, true)` y anotarlo con `recordFullScreenAlertAttempt({reason:"lost-mode"...})`. Hipótesis fuerte, no probada: se comprueba con el build nuevo.
- No tiene que ver con el diseño ni con Xiaomi (permisos todos concedidos).

- **CONFIRMADO por Luciano (24/10/2026): Modo perdido vuelve a tomar la pantalla bloqueada en el Xiaomi** con la build que incluye `aplicar-modo-perdido-pantalla-completa-app.ps1` (commit 222bc17) y `aplicar-arranque-tipos-app.ps1` (ebcd0bf). Causa: la rama "lost-mode" de App.tsx no pedía la pantalla completa con la app atrás. Carpeta de la app: `Downloads\CARPETA PRINCIPAL OJO GUARD ANDROID\OJOGUARDANDROIDV30 (1)310826\OJO-GUARD-ANDROID-V30` (la de `...MS\...\OJO-GUARD-MS-V30` es el panel; en esa también hay un App.tsx suelto, no usarlo). Build de Android: `eas.cmd build --platform android --profile preview`. Para correr instaladores: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force`.
- Pendiente tras esto: que el Dr. Ojo Guard muestre "última orden recibida" y "Permisos de Android" se vea como botón; revisar iPhone (evidencia lenta) y la cola de `auto-locate` de native_1 / native_d.

### Cola de `auto-locate` y equipos (25/10/2026)
- Consulta a la base (`ojo-guard-ms`, remota): equipos Android "Mi teléfono" = native_d, native_1, native_4, native_f (y native_b revocado "Android Luciano (vinculacion anterior)"), iPhone native_e, Windows win-d33d "Notebook LB", Mac win-4455 "marian".
- **native_d** no ejecutaba nada desde el 31/08/2026 y acumulaba 98 `auto-locate` pendientes (uno cada 15 min): **marcado `revoked` y pendientes borrados el 25/10/2026** (hecho a mano con `wrangler d1 execute`, solo ese equipo).
- native_1 (58 pendientes) y native_4 (29) ejecutan cosas pero acumulan `auto-locate`: probablemente teléfonos que pasan horas apagados/sin datos (ej. el del papá). La limpieza automática los borra a los 2 días. Pendiente: identificar de quién es cada uno y **renombrar** los cuatro "Mi teléfono" (confunden). native_f (0 pendientes, último 25/10 07:30) y native_e (iPhone, 0) andan bien.
- Nota: `wrangler d1 execute` dio una vez el error 7403 (cuenta no autorizada) con la sesión válida; reintentar sin cambios funcionó. Si se pega un comando cortado, PowerShell muestra `>>` (esperando): Ctrl+C.

### Ficha de equipos (identificados el 25/10/2026, ids de la base `ojo-guard-ms`)
- **native_f** = Android Luciano (Xiaomi), batería confirmada por Luciano; renombrado "Android Luciano (Xiaomi)".
- **native_e** = iPhone de Luciano; renombrado "iPhone Luciano".
- **native_1** = Android del papá de Luciano (creado el 18/10/2026); a renombrar "Android papa".
- **native_4** = Samsung de Guido (hermano de Luciano), enlazado el 28/09/2026, sabe que la tiene instalada para hacer pruebas; a renombrar "Android Guido (Samsung)".
- native_b y native_d: instalaciones viejas de Luciano, revocadas. win-d33d = Notebook LB (Windows). win-4455 = "marian", Mac de Mariana.
- (Las direcciones de las últimas ubicaciones no se guardan en las notas.)
- **Renombrados en la base el 25/10/2026** (hecho): "Android Guido (Samsung)", "Android papa", "Android Luciano (Xiaomi)", "iPhone Luciano". Ya no queda ningún equipo activo llamado "Mi teléfono" (solo native_d, revocado). Los pedidos `auto-locate` que se acumulan en los teléfonos de papá y Guido cuando están apagados son esperables; la limpieza automática los borra.
- **25/10/2026: los teléfonos del papá (native_1) y de Guido (native_4) se pasaron a la cuenta principal de Luciano** (con el consentimiento de los dos, que los dieron para probar la app), como equipos `additional` (no `primary`, para que no puedan aprobar dispositivos nuevos). Respaldo en la tabla `devices_owner_backup` (id, owner_email, device_role). **Deshacer:** `UPDATE devices SET owner_email=(SELECT owner_email FROM devices_owner_backup b WHERE b.id=devices.id), device_role=(SELECT device_role FROM devices_owner_backup b WHERE b.id=devices.id) WHERE id IN (SELECT id FROM devices_owner_backup);`. El iPhone de Luciano (native_e) sigue en su cuenta de Apple (familia): decidir aparte si pasarlo. Falta comprobar que aparecen en la consola y que Hacer sonar/Ubicar llegan.
- **Prueba que falta (25/10/2026):** los equipos "Android papa" y "Android Guido (Samsung)" ya aparecen en la consola de Luciano, pero figuran **sin conexión** (últimos contactos 01:01 y 03:16 de esa madrugada, antes del cambio de cuenta; probablemente dormidos/apagados). Cuando Guido abra la app y el equipo pase a "En línea": probar **Hacer sonar** y anotar si llega, cuánto tarda y la versión de la app instalada en ese Samsung. Después probar con el de papá.
- **25/10/2026, aplicados en la carpeta de la app (compilan, falta la build):** `aplicar-permisos-boton-app.ps1` (cartel "Permisos de Android: 4/4 OK ✓ · ver detalle ›") y `aplicar-dr-modo-perdido-app.ps1` (Dr. Ojo Guard: "Modo perdido sobre la pantalla bloqueada" con botón para permitir avisos de pantalla completa, "Revisión de órdenes en segundo plano" que avisa si la app no se despertó en más de 40 min, y nota del límite de Apple en iPhone). Qué probar con la build: abrir Dr. Ojo Guard > Hacer chequeo en el Xiaomi (deben aparecer los dos items nuevos), y en el iPhone la nota. NO hecho: botón "Probar Modo perdido", item de órdenes pendientes del servidor (necesitaría `remoteApi.ts`), buscador en Ajustes y asistente con IA.
- **Probado por Luciano el 25/10/2026 en el Xiaomi (build nueva de Android):** Dr. Ojo Guard 100 % con los dos items nuevos en verde ("Modo perdido sobre la pantalla bloqueada" y "Revisión de órdenes en segundo plano: hace menos de una hora"). Falta ver en pantalla el cartel "Permisos de Android: 4/4 OK ✓ · ver detalle ›" y probar el caso de falla (apagar el permiso de pantalla completa y ver que el Dr. lo marque y ofrezca el botón). Siguiente: build de iPhone (`eas.cmd build --platform ios --profile production --auto-submit`, perfil `submit.production.ios.ascAppId` ya está en eas.json; el ícono nuevo ya está en assets, huella 6FEFA17F…). iPhone venía de la build 32 (17/10).
- **Probado por Luciano el 25/10/2026 en el iPhone con la build nueva (TestFlight):** estética nueva, Dr. Ojo Guard 100 % y la nota nueva "Con la app cerrada, el iPhone no deja sacar fotos ni grabar audio… límite de Apple, no una falla" se ve. (En iPhone no salen los dos items de Android, como se esperaba.) Pendiente probar en el iPhone: botón Panel (¿abre ojoguard.app?), Modo perdido y evidencia al abrir la app.
- **Confirmado por Luciano el 25/10/2026 (captura en el iPhone con la build nueva):** el botón **Panel** de la app abre `ojoguard.app` (la consola completa, "Mapa y Familia" con "iPhone Luciano hace 33 s" y "Luciano · Android, Titular"). Se cierra el pendiente "Panel abre ojoguard.app". Queda para la próxima build: cambiar `ORIGEN` en `MapaEnApp.tsx` si se quiere pasar el mapa dentro de la app a `ms.ojoguard.app`.
- **Pruebas de SOS del 25/10/2026:** (1) Xiaomi → iPhone con el gesto de volumen: llegó, sonó y apareció la alerta (OK). (2) iPhone → Xiaomi con tres golpes atrás: el aviso llegó (tres notificaciones: "SOS LB iPhone pidió ayuda", "LB iPhone vio tu SOS", "SOS enviado") pero **sin sonido en el Xiaomi**. (3) Al estar el Android del papá en la cuenta de Luciano, **el SOS de Luciano también le sonó a su papá** (funcionó; se asustó): efecto de pasar equipos de otra persona a la cuenta, anotar siempre al hacerlo. Conclusión: la sirena anda en otros Androids; en el Xiaomi falta ver la configuración del aviso (categoría/sonido/Anular No interrumpir) y el estado del botón "Modos" (No molestar). Pendiente: decidir si el equipo del papá se devuelve a su cuenta (comando de deshacer más arriba) y si Guido lo mantiene durante las pruebas.
- **Decisión de Luciano (25/10/2026):** los teléfonos del papá (native_1) y de Guido (native_4) se **quedan en su cuenta**: que reciban sus SOS está bien porque son sus referentes (llamarlo si pide ayuda). Ya no hace falta el comando de deshacer salvo que ellos pidan salir. Pendiente: confirmar que también figuran como referentes en Tu protección (para que reciban el aviso con su nombre y teléfono) y decirles qué hacer si les llega un SOS.

## IDEA de Luciano (25/10/2026): panel simple de "a quién aviso de qué y por dónde" (Referentes + Familia + mails/SMS/push)
- Origen: al pasar los teléfonos del papá y de Guido a su cuenta, el SOS de Luciano les sonó a ellos (el servidor avisa a **todos los teléfonos aprobados de cada cuenta destinataria**: `pushTokensOf(env, email)`), sin que nadie los eligiera como referentes. A Luciano le parece raro que llegue una notificación sin haberlo decidido el usuario.
- Pedido: elegir **por persona** (con un interruptor o cuadrito) a quién se avisa de cada cosa; ej. "si se cae/le pasa algo a mi papá, avisar a todos sus referentes; si no llega a un lugar, avisar solo a mi mamá". Y lo mismo para **canales**: algunos avisos "solo por mail está ok", otros mail + texto + notificación (códigos y urgencias inmediatas). Hoy llegan muchos por día (está probando).
- Hoy conviven **dos listas**: Familia (cuentas con app: adultos/menores/amigos; reciben push con sirena, mail y SMS según `notification_prefs`) y Referentes de "Por las dudas" (solo mail con enlace personal; también reciben el SOS por mail). Falta decidir si se unifican.
- Propuesta a discutir (sin construir todavía): una sola lista de personas; por persona 3 interruptores — **SOS/emergencia**, **Seguridad** (no responde, no llegó, se apagó, sin señal), **Informativo** (llegó/salió de un lugar, resúmenes) — y "cómo" por nivel: urgente = notificación con sirena + SMS + mail; normal = notificación silenciosa + mail; informativo = solo mail. Pantalla en el panel (sin build) y, si hace falta, un ajuste en la app. Un equipo agregado a la cuenta NO debería recibir avisos de otras personas salvo que su dueño lo elija.
- Pendiente aparte: SOS iPhone → Xiaomi sin sonido (Xiaomi: canal "ojo-busqueda-v2", sin "Anular No interrumpir" en el código; falta la captura de configuración del aviso y ver si "Modos" está prendido).
- **Decisiones de Luciano (25/10/2026) sobre el panel de avisos:** (1) **una sola lista de personas** (no mantener Familia y Referentes separadas: "complica más"); (2) los **menores no pueden usar los interruptores: se ven en gris** (solo mira; coherente con la decisión del 20/10 "un usuario menor solo puede ver, no editar"). Falta decidir: quién edita los interruptores de un adulto (¿él mismo o el titular?), y los textos/nombres de los tres niveles.
- **25/10/2026: evidencia en la tarjeta de cada equipo.** Pregunta de Luciano: "en algunos equipos aparece la evidencia y en otros no". Causa hallada en `src/index.ts`: la lista de la cuenta usa `ORDER BY occurred_at DESC LIMIT 50` (50 más recientes de toda la cuenta; el Xiaomi tiene 108 evidencias con foto, la notebook 25, la Mac 16, el iPhone 10, el papá 4, Guido 1). Arreglo: `aplicar-evidencia-por-equipo-panel.ps1` (commit e8fc765): las 50 más recientes MÁS la última evidencia con foto de cada equipo. Publicado por Luciano el 25/10/2026 (versión 58b885ac). Falta ver que la tarjeta del Xiaomi la muestre. Nota: la tabla `evidence_attempts` filtra por `owner_email`; las evidencias viejas del papá y de Guido quedaron con su correo anterior y no se ven en la cuenta de Luciano; las nuevas sí.
- **26/10/2026: la tarjeta del navegador (ojoguard.app) también muestra la última evidencia guardada del equipo** (`aplicar-evidencia-tarjeta-consola-panel.ps1`, commit 7e7efe2; publicado por Luciano, versión ce1150f7). Aclaración de por qué "en algunos aparece y en otros no": hay dos tarjetas distintas (la del mapa dentro de la app, con botones con ícono, y la del navegador); y la evidencia solo se ve en los equipos propios de la cuenta con la que se entra (en la app del iPhone entra con la cuenta de Apple, y el Xiaomi es "persona Luciano · Titular" sin botones ni evidencia: por diseño de privacidad). Falta ver con captura que se vea en el navegador. Para ver las del papá/Guido anteriores al cambio de cuenta no alcanza (quedaron con su correo anterior).
- **26/10/2026, prueba de "Pedir foto y audio" al iPhone (LB iPhone) desde la consola:** el aviso "Luciano pidió una foto y un audio de tu teléfono" llegó, pero la captura **falló en el iPhone**: "Diagnóstico de captura: Falló la captura del 25/10/2026, 21:20:23: CameraImageCaptureException: Image could not be captured (at ExpoCamera/CameraPhotoCapture.swift:130)". El iPhone sí sacó fotos otras 10 veces (intermitente). Causa probable (sin confirmar): en `App.tsx` `captureSecurityEvidence()` se llama en `onCameraReady` y toma la foto enseguida; en iPhone la cámara avisa "lista" un instante antes de poder sacar, y además hay audio grabándose a la vez. Arreglo propuesto (requiere build): esperar ~400 ms antes de la primera foto en iOS y reintentar una vez a los 700 ms si falla.
- **Texto equivocado en iPhone:** el botón del cartel "Diagnóstico de captura" dice "Abrir configuración de Android" también en el iPhone (dos lugares de `App.tsx`, `openSystemSettings`). Debe decir "Abrir los ajustes del iPhone" en iOS. Requiere build.
- **26/10/2026: publicado** `aplicar-mensaje-orden-consola-panel.ps1` (commit 7067ad6, versión 2a772cf8): el aviso del pedido ("Enviando orden…", "Orden enviada…", "Llegaron la foto y el audio", "No se pudo: …") ahora se ve debajo de los botones de la tarjeta del navegador (antes quedaba al final, escondido). **Armado, falta aplicar y build de iPhone:** `aplicar-captura-iphone-app.ps1` (espera 0,4 s y reintenta una vez la foto en iPhone; "Abrir los ajustes del iPhone" en vez de "Android" en el iPhone).
- **26/10/2026:** Luciano aplicó `aplicar-captura-iphone-app.ps1` (commit a0ad3a2) en la carpeta de la app; compila bien. **Falta la build de iPhone** (`eas.cmd build --platform ios --profile production --auto-submit`) y repetir la prueba "Pedir foto y audio" a LB iPhone con la app abierta. En Android no cambia nada de comportamiento (solo el texto del botón, que sigue diciendo Android).
- **26/10/2026: publicado** `aplicar-evidencia-trasera-familia-panel.ps1` (commit e1cdfa6, versión 637a54c3): la evidencia pedida a un familiar trae también la foto trasera (servidor `familyEvidenceOf`/`remoteFamilyEvidence`, mail con las dos fotos, y la tarjeta del navegador y la de la app muestran las dos). Decisión de Luciano: "cuanto más información, mejor, siempre que la persona lo autorice". **Falta (parte de la llave por persona del panel de permisos):** que cada persona pueda activar/apagar "puede pedirme foto y audio"; hoy solo se le avisa en su teléfono cada pedido. Falta ver con captura que se vean las dos fotos al pedirle a LB iPhone.
- **26/10/2026, causa de que la consola (Gmail) no mostrara la evidencia del iPhone:** cuando la cámara TRASERA falla pero la frontal se guarda, `App.tsx` (`captureSecurityEvidence`, rama de error con `cameraFacing === "back"`) guardaba la frontal pero rechazaba el pedido (`rear_camera_capture_failed`) → el servidor lo marca `failed` y quien lo pidió no recibe nada (ni foto frontal ni audio). Arreglo armado: `aplicar-captura-trasera-app.ps1` (el pedido cuenta como cumplido con la frontal; en iPhone espera 1,3 s al cambiar a la trasera). Ya con la build 33+ de iPhone (se vio "Abrir los ajustes del iPhone"), falta aplicarlo y hacer otra build. Probado por Luciano el 25/10 23:38: frontal OK, trasera falló.
- **26/10/2026: publicado** `aplicar-aviso-flotante-consola-panel.ps1` (commit e59f3b3, versión b30d0ce6): en el navegador, cada aviso del pedido sale también como cartel azul arriba del mapa (9 s). Motivo: el texto de estado debajo de los botones no se veía en la tarjeta de LB iPhone y no se pudo diagnosticar a distancia (el CSS no lo oculta; sospecha: página en caché). Falta ver con captura que aparezca el cartel. Pendiente aparte: aplicar `aplicar-captura-trasera-app.ps1` (commit d6af2af) y hacer la build.
- **26/10/2026, build 34 de iPhone (0.9.1):** al pedir foto y audio desde la consola, la **frontal** volvió a fallar (19:11:19, `Image could not be captured`), con la app en la pantalla del código (teclado numérico) cuando llegó el pedido. La consola ya muestra "No se pudo: el teléfono no pudo sacar la foto." debajo de los botones (el aviso funciona). Armado `aplicar-captura-reintentos-app.ps1`: hasta 3 reintentos en iPhone (0,6/1,2/2 s) y deja anotado en Registros técnicos en qué intento salió. Hipótesis sin confirmar: la grabación de audio y la cámara arrancan a la vez (audio session) o la app está en la pantalla del PIN (cámara oculta). Si sigue fallando, probar `skipProcessing: true` y arrancar el audio después de la primera foto. Falta aplicar `aplicar-captura-trasera-app.ps1` (d6af2af) y `aplicar-captura-reintentos-app.ps1` y hacer build.
- **26/10/2026: aplicados en la carpeta de la app** (compilan): `aplicar-captura-trasera-app.ps1` (d6af2af) y `aplicar-captura-reintentos-app.ps1` (968febf). **Falta la build de iPhone** (`eas.cmd build --platform ios --profile production --auto-submit`) y la prueba final con la app a la vista. Qué mirar: que la consola muestre el cartel azul y después "Llegaron la foto y el audio" con las dos fotos (o solo la frontal si falla la trasera); y en Registros técnicos del iPhone "foto front: salió en el intento N".
- **Hallazgo de Luciano (26/10/2026, Xiaomi, mapa dentro de la app): el cuadro "Invitar a alguien" (Familia y amigos) no tiene forma visible de volver atrás.** Se abrió sin querer (probable toque en el ícono de "persona +" del mapa); no hay botón "Cancelar"/"X" a la vista (el formulario es más alto que la ventana y los botones quedan abajo, para desplazarse), tocar afuera no lo cierra, y la ✕ de arriba a la izquierda es la de salir de la app (lleva al teclado numérico). Arreglo propuesto (panel, sin build; `src/panel-mapa.txt`, diálogo de invitar): ✕ fija arriba a la derecha del cuadro, botón "Cancelar" siempre visible (pegado abajo) y cerrar al tocar afuera. Lo mismo conviene revisar en los otros cuadros del mapa (aviso de llegada/salida, cambiar rol, salir de la familia).

## Descarga de la app de Android desde ojoguard.app (27/10/2026)
- Pedido de Luciano: "en nuestra pagina, no podriamos tener la ultima version y se meten y la bajan? / ponen actualizar" y un boton "Actualizar version" en Ajustes. El zip "Actualizacion 26/10" de su Drive era el APK mismo (146,63 MB; Drive lo marco como zip).
- `aplicar-descarga-panel.ps1` (generado por `panel/generar_descarga_panel.py`): agrega `GET /descargar` (pagina con boton "Actualizar Ojo Guard"), `GET /descargar/ojo-guard.apk` (HEAD tambien) y `GET /api/app/version` (JSON `{disponible, version, subido, bytes, sha256, url}`). CORRECCION 27/10: `EVIDENCE_FILES` es un KV (25 MB por valor), no un R2; lo asumi sin comprobar. `aplicar-descarga-kv-panel.ps1` (generado por `panel/generar_descarga_kv_panel.py`) lo corrige: el APK se guarda en partes de 16 MB (`descargas/<id>/<n>`) y `descargas/version.json` (con `partes`) se escribe al final.
- `subir-apk-panel.ps1 -Apk <ruta> -Version <texto>`: valida que sea un APK (zip con AndroidManifest.xml, 20-280 MB), lo corta en partes de 16 MB, las sube con `wrangler kv key put --namespace-id`, sube al final `descargas/version.json`, baja el APK desde la pagina y compara la huella SHA-256, y borra las partes de la version anterior. Se repite en cada build nueva.
- PENDIENTE (necesita build nueva): boton "Actualizar version" en Ajustes de la app: consulta `/api/app/version`, compara con la version instalada y abre `https://ojoguard.app/descargar`. Para eso hay que decidir un numero de build que el servidor conozca (hoy `-Version` es solo texto).
- PENDIENTE (idea): aviso cuando sale una version nueva: (a) al abrir la app, con el mismo chequeo; (b) push a los Android del grupo al subir el APK. La (b) no esta verificada: habria que comprobar que tocar la notificacion pueda abrir la pagina.
- Primera instalacion en Guido/papa: por el link de Drive o por la pagina; si Android rechaza por firma distinta, no borrar la app (ver contingencia).
- 27/10/2026, Luciano vio `ojoguard.app/descargar` y dijo "lastima que lo hiciste con la estetica anterior" y "el logo del ojo es modelo viejo" (la primera version usaba el dorado viejo y `/marca/logo-correo.png`). `aplicar-descarga-estetica-panel.ps1` (generado por `panel/generar_descarga_estetica_panel.py`, va despues del `-kv-`): estilo actual (marfil con degradado azul, boton azul en pastilla, Plus Jakarta Sans, logo SVG nuevo igual al icono de la app, Modo noche con `ojo_ms_tema`) y arregla la fecha con punto doble. OJO: `/marca/logo-correo.png` sigue siendo el logo viejo y lo usan otras paginas/mails; revisar si hay que cambiarlo.

## Prueba final de evidencia en iPhone, build 35 (27/10/2026)
- Resultado: **funciona.** Desde la consola (Gmail), "Pedir foto y audio" a LB iPhone con la app en el mapa: aviso azul "Orden enviada - esperando al telefono", despues "Llegaron la foto y el audio. Tambien te los mandamos por mail.", y la tarjeta muestra "Ultima evidencia" con **Delantera y Trasera**. Dos pedidos seguidos, los dos bien.
- Cuenta en la base (`commands`, tipo `capture-evidence`, iPhone): build 34, 26/10 19:11 fallo `CameraImageCaptureException: Image could not be captured`; desde el arreglo de reintentos (build 35) 4 `executed` el 26/10 + 2 `executed` hoy, y **1 `remote_capture_timeout` hoy 11:22** (la app arranco el pedido ~23 s despues y espero 30 s sin terminar). Total build 35: 6 de 7. La falla no se pudo explicar: el registro del iPhone no anota nada porque "Registros tecnicos" solo lee el modulo nativo de Android (muestra "Todavia no hay ningun registro nativo de camara guardado").
- Consulta util (solo lectura, en la carpeta del panel; `created_at` es texto ISO en UTC, -3 h para Argentina): `npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "SELECT status, error, created_at, executed_at, failed_at FROM commands WHERE type='capture-evidence' ORDER BY created_at DESC LIMIT 8"`
- PENDIENTE (proxima build, junto con "Actualizar version"): (1) en `captureSecurityEvidence`/timeout de 30 s: anotar EN QUE PASO se trabo (camara frontal lista / foto frontal / trasera) y devolverlo en el error del pedido (ej. `remote_capture_timeout:trasera`); (2) si la frontal ya salio y se agota el tiempo, mandar igual la frontal (como ya se hace si la trasera da error); (3) tope de tiempo a `takePictureAsync` por si queda colgada sin lanzar error; (4) que "Registros tecnicos" muestre tambien los pasos de captura en iPhone (guardarlos en AsyncStorage).
- DEFECTO (iPhone): en Ajustes > Registros tecnicos de la app aparece texto de Android ("Android exige que vos confirmes el ahorro de bateria", botones "Permitir actividad en segundo plano sin restricciones" y "Abrir ahorro de bateria"); en iOS esa seccion no tiene sentido y hay que esconderla.
- La pantalla del iPhone se pone negra mientras saca la foto: es la pantalla de reposo del modo "guard" (`idleBlackScreen`), esperada.

## Ojo viejo en otras paginas (27/10/2026)
- Revisado: los mails ya salen con el logo nuevo (`ojo-guard-correo.png`, 22/10), la consola y las paginas Tu proteccion / camino / referente tienen el ojo nuevo en SVG. La unica que seguia con `/marca/logo-correo.png` (ojo viejo) y el estilo oscuro con dorado era la pagina de invitacion `/unirme` ("Te invitaron a una familia").
- `aplicar-unirme-estetica-panel.ps1` (generado por `panel/generar_unirme_estetica_panel.py`): la pasa al estilo actual con el ojo nuevo, mantiene el codigo, los pasos y el boton "Abrir Ojo Guard", y suma el link a `ojoguard.app/descargar` para Android.
- PENDIENTE: la ruta `GET /marca/logo-correo.png` (ojo viejo) sigue existiendo en el servidor aunque ya nada la usa; se puede sacar en una limpieza. No pude comprobar las paginas en vivo desde aqui (el dominio esta bloqueado en mi entorno): solo por los instaladores.

## TestFlight con enlace publico para el iPhone (27/10/2026) - en curso
- Pedido de Luciano: que la invitacion (`/unirme`) y `/descargar` tambien sirvan para iPhone. Apple solo permite TestFlight o App Store; el camino elegido es un **enlace publico de TestFlight** (grupo externo, requiere revision beta de Apple; cualquiera con el link instala la beta).
- Hecho en App Store Connect (Luciano): grupo externo **FRIENDS&FAMILY** creado (0 testers, 0 compilaciones). Builds 31 a 35 de la 0.9.1 en "Lista para enviar". Falta: llenar "Informacion para las pruebas" (descripcion, correo de comentarios, datos de contacto, inicio de sesion), anadir la build 35 al grupo, enviar a revision y activar el enlace publico.
- Obstaculo: Apple pide usuario y contrasena para que el revisor entre; Ojo Guard entra por codigo de 6 numeros por correo. Solucion: `aplicar-revision-apple-panel.ps1` (generado por `panel/generar_revision_panel.py`): correo `revision@ojoguard.app` que no manda mail y acepta UN codigo al azar guardado como secreto `REVIEW_CODE` (lo muestra al final y lo copia al portapapeles). Cuenta vacia, sin acceso a datos de nadie; los intentos fallidos usan el bloqueo normal; el panel no la acepta (solo el ingreso nativo `/api/native/enroll`). Apagar despues de la aprobacion: `npx.cmd wrangler secret delete REVIEW_CODE`.
- PENDIENTE al terminar: cuando Apple apruebe y haya enlace publico, agregar el boton "Instalar en iPhone" en `/unirme` y `/descargar` (hace falta el link; no se inventa).
- PENDIENTE: el revisor de Apple tambien tendra que pasar por los pasos de identidad de la app (foto de perfil, documento, selfie); explicarlo en las notas de revision.
- 27/10/2026 ~13:54: Luciano **envio a revision** la build 0.9.1 (35) en el grupo externo FRIENDS&FAMILY. Estado: "Pendiente de revision". Datos cargados: correo de comentarios `soporte@ojoguard.app`, contacto `luciano.bick@ojoguard.app` y `+54 9 11 5597 1291`, usuario `revision@ojoguard.app` con el codigo de `REVIEW_CODE` como contrasena (el codigo se vio una vez en el chat de la sesion: apagarlo con `npx.cmd wrangler secret delete REVIEW_CODE` cuando Apple apruebe). Siguiente: cuando Apple apruebe, en el grupo > Ajustes/Testers activar el **enlace publico** y pasarmelo para poner "Instalar en iPhone" en `/unirme` y `/descargar`. Si Apple rechaza, leer el motivo en App Store Connect y corregir.

## SOS silencioso en el Xiaomi: diagnostico (27/10/2026)
- Prueba con `probar-sos-xiaomi.ps1` (version segura de `probar-sos-android.ps1`: manda solo al equipo "Android Lucian..."; la vieja elegia el Android visto mas recientemente de la cuenta y desde que los telefonos de papa y Guido estan en la cuenta de Luciano podia mandarles la prueba a ellos: **no usarla**). Con el Bluetooth conectado a los JBL TUNE y el modo "Modos" activo, llegaron los 3 avisos; el [1] ("igual al SOS real": canal `ojo-sos`, sirena, datos del mapa) **sono en cuanto llego**; sono en los JBL y en el parlante. => el canal, el volumen y el Bluetooth no son la causa.
- Hipotesis que queda (no confirmada: Luciano no recuerda cual SOS fue el mudo): regla del servidor en `nativeFamilySos`: si la misma persona pidio un SOS hace menos de 40 s (aunque lo haya cancelado) el nuevo llega **sin sonido** (`sirenaAnteriorSonando`), pensada para el iPhone (la sirena de un aviso no se puede cortar). En `family_sos` hay un par asi: 25/10 15:34:00 (atendido) y 15:34:25 (cancelado), hora de Argentina. El resto estan a mas de 40 s (el mas cercano 50 s: 23/10 15:57:38 y 15:58:28).
- PROPUESTA (pendiente de decision de Luciano): que el silencio de los 40 s se aplique solo a los destinatarios con iPhone y que en Android el segundo SOS suene igual (en una emergencia real un segundo pedido no deberia llegar mudo a un Android). Cambio chico en el servidor: leer `platform` junto con `push_token`.
- LIMPIEZA: un SOS quedo `activo` sin cerrar desde el 21/10 18:19 (hora de Argentina) en `family_sos`.
- Nota: `pushTokensOf` manda a TODOS los dispositivos aprobados de la cuenta; un SOS real al titular suena tambien en los telefonos de papa y Guido mientras esten en su cuenta.
- HECHO (27/10/2026, a pedido de Luciano: "si"): `aplicar-sos-android-sonido-panel.ps1` (generado por `panel/generar_sos_android_sonido_panel.py`): el silencio de los 40 s del segundo SOS seguido queda solo para iPhone (`pushTokensConPlataforma`, `dest.platform === "ios"`); en Android suena igual. Solo servidor, sin build. Falta probar con dos SOS seguidos a un Android (avisando antes a papa y Guido: les suena tambien).

## Proxima build: Actualizar version + pasos de la captura + iPhone sin texto de Android (27/10/2026) - armado, sin instalar
- App (`aplicar-version-captura-app.ps1`, generado por `app/generar_version_captura_app.py`, respaldo `.bak-version`, requiere `aplicar-captura-reintentos-app.ps1`; probado sobre el App.tsx real de 263.510 bytes con la revision de tipos de la propia instalacion y, aparte, los trozos nuevos con tsc estricto): (1) boton "Actualizar version" en Ajustes > permisos (solo Android): consulta `https://ojoguard.app/api/app/version`; si el numero entre parentesis de la version publicada (ej. "0.9.2 (163)") es mayor al build instalado abre `ojoguard.app/descargar`; si no hay numero, abre la pagina igual; (2) pasos de la captura de evidencia guardados en AsyncStorage (`ojo_captura_pasos_v1`) y visibles en Registros tecnicos en iPhone y Android; (3) a los 30 s sin terminar: si la frontal ya salio se entrega sola; si no, el error es `remote_capture_timeout:<paso>` (esperando camara frontal / sacando foto frontal / esperando camara trasera / sacando foto trasera / guardando evidencia); (4) iPhone: se esconde el texto y los botones de Android del ahorro de bateria.
- Panel (`aplicar-motivo-captura-panel.ps1`): la consola acepta el sufijo `:<paso>` y sigue mostrando "no llego a sacar la foto a tiempo".
- Subidor (`subir-apk-panel.ps1`): ahora `-Version "0.9.2 (163)"` conserva los parentesis. IMPORTANTE para que el boton compare: pasar siempre el numero de build de ANDROID (el de EAS) entre parentesis.
- PENDIENTE chico: la pagina `/descargar` muestra la version entre parentesis y con "(0.9.2 (163))" queda doble; cambiarlo cuando se toque esa pagina.
- Despues de la build: probar en iPhone (pedir foto y audio varias veces y mirar Registros tecnicos) y en Android (boton Actualizar version).

## Pruebas de la build Android 175 / iPhone 36 y siguiente paso (27/10/2026)
- APK 0.9.1 (175) publicado en `ojoguard.app/descargar` (version.json con el numero de build entre parentesis; huella `02c7dc69...`); instalado en el Xiaomi encima de la anterior; el boton "Actualizar version" (Ajustes > Permisos de Android > Preparar autonomia...) dijo "Ya tenes la ultima version (0.9.1, build 175)". La nota de la consola de EAS: "Incremented versionCode from 174 to 175". iPhone actualizado a la 36 (TestFlight), sin probar todavia la captura de foto con los pasos anotados.
- Defecto de diseno que marco Luciano: "Actualizar version" esta muy escondido. Pedido: una tarjeta al lado del Dr. Ojo Guard ("actualizacion del sistema", con volver a instalar) y/o adentro del Dr. Elegida la opcion 3 (las dos). Armado: `aplicar-actualizar-app.ps1` (generado por `app/generar_actualizar_app.py`; baja `src\PaginaActualizar.tsx` y `assets\config-actualizar.png` de `scripts/app/` con huella; toca App.tsx, src\GruposConfiguracion.tsx, src\PaginaChequeo.tsx; requiere `aplicar-version-captura-app.ps1`): tarjeta "Actualizar Ojo Guard" en Configuracion (solo Android, junto a Dr. Ojo Guard) con version/build, "Buscar actualizacion" y "Volver a instalar la ultima"; y linea "Version de Ojo Guard: al dia / Hay una version nueva" arriba del Dr. Ojo Guard. Sale en la PROXIMA build.
- Limite conocido: la pagina guarda solo la ULTIMA version del APK (al subir otra se borran las partes de la anterior): "volver a una version vieja" no es posible. Si se quiere, hay que conservar la anterior.
- Instalador de la app: si falla la revision de tipos, ahora restaura Y borra los respaldos (en `aplicar-version-captura-app.ps1` quedaba `App.tsx.bak-version` y habia que borrarlo a mano con comprobacion de huella).

## TestFlight con enlace publico: listo (27/10/2026)
- Apple aprobo la beta 0.9.1 (35) y la (37) en el grupo externo FRIENDS&FAMILY. Enlace publico creado: `https://testflight.apple.com/join/QcWAsHkG` (abierto a todo el mundo, limite 10 testers; si se llena con desconocidos: bajarlo o subir el limite desde App Store Connect > grupo > Testers > Enlace publico). Hay una build 38 repetida (mismo codigo que la 37): no se suma al grupo.
- `aplicar-testflight-panel.ps1` (generado por `panel/generar_testflight_panel.py`): boton "Instalar en iPhone" en `ojoguard.app/descargar` y en la pagina de invitacion `/unirme`, y arregla el parentesis doble de la version ("0.9.1 (175)").
- Cuando termine la cuenta de demostracion para Apple (ya aprobo): apagar `REVIEW_CODE` con `npx.cmd wrangler secret delete REVIEW_CODE` (mientras Apple pueda volver a revisar builds nuevas conviene dejarla; decidir con Luciano).

## Android build 176 publicada y probada (28/10/2026)
- Motivo del "se subio la vieja": el comando de subida pedia el numero de build con `Read-Host` y el Enter del pegado lo contestaba en blanco; ademas el APK nuevo no estaba en Descargas. Se subio `application-e6fa565b-...apk` (build 176, 139,85 MB, huella 6cde4648c915...) con `-Version '0.9.1 (176)'` fijo (sin pregunta). Verificado por huella contra la pagina; partes del 175 borradas.
- Probado en el Xiaomi: Configuracion muestra la tarjeta **"Actualizar Ojo Guard"** (icono de descarga) al lado de Dr. Ojo Guard; adentro: "Tu version: 0.9.1 · build 176 / Ya tenes la ultima version (0.9.1 (176))", "Buscar actualizacion", "Volver a instalar la ultima". Luciano: "Esta perfecto."
- Sigue pendiente: probar los "pasos de captura" (Registros tecnicos) y la linea de version dentro del Dr.; la build de iPhone con lo mismo; botones Android/iPhone en la pagina de entrada (falta `panel-index-actual.html`).
- 28/10/2026: `aplicar-login-descargas-panel.ps1` (generado por `panel/generar_login_descargas_panel.py`): en la pagina de entrada de ojoguard.app (donde se escribe el codigo) agrega "¿Todavia no tenes la app?" con botones Android (`/descargar`) e iPhone (TestFlight). Cambia solo `src\panel-index.html` y publica. Probado en navegador sobre la copia del HTML real de Luciano. Sin texto de precios (el primer mes gratis es una decision de negocio todavia no tomada).

## Verificacion de identidad en el arranque de la app (28/10/2026)
- Hallazgo (Luciano instalando a Mariana en iPhone, TestFlight link publico OK): la app pide foto de perfil, documento y selfie (`app/arranque/ArranqueIdentidad.tsx`) pero NO verifica nada: acepto una foto de un termo como DNI. Las fotos solo se guardan en el telefono (`pendiente_de_verificar`), no se suben ni se comparan. Ademas el texto de la selfie promete "La comparamos con la foto de tu documento", y hoy no es cierto.
- Decision de Luciano: **Didit + RENAPER** (no los controles basicos A). Referencia de precios (fuentes de terceros, confirmar): Didit KYC USD 0,30 por verificacion, primeras 500/mes gratis por funcion segun su documentacion; consulta RENAPER ~USD 0,20 (solo se cobra si hay resultado concluyente). Alternativas descartadas por ahora: Veriff (USD 0,80-1,89 + minimo 49/mes), Sumsub (1,35-1,85 + 149-299/mes), Onfido/Persona (a medida).
- Idea de flujo: la app pide numero de DNI (+ nombre) y selfie; el Worker llama a Didit (clave `DIDIT_API_KEY` como secret, nunca en la app ni en el chat) y guarda solo el resultado (verificada / rechazada) y no la foto del DNI. Ventaja: no guardamos DNIs. Limite: solo DNI argentino; extranjeros/pasaporte necesitan otra via.
- Falta: (1) Luciano crea la cuenta en Didit; (2) leer la documentacion oficial (esta sesion no alcanza docs.didit.me/didit.me: hace falta permitir esos dominios o pegar la documentacion); (3) definir que pasa si falla (reintento, revision manual); (4) politica de privacidad (que datos, cuanto tiempo); (5) cambiar el texto de la selfie hasta que exista la verificacion.
- 28/10/2026: cuenta de Didit creada por Luciano (business.didit.me; flujo por defecto "V1 LIVE" con precio $0,58+, NO usarlo; faltan: crear clave de API en la consola y cargarla con `npx.cmd wrangler secret put DIDIT_API_KEY`, nunca por chat). Documentacion RENAPER pegada por Luciano (pagina docs.didit.me/api-reference/database-validation/argentina/renaper):
  - `POST https://verification.didit.me/v3/database-validation/`, cabecera `x-api-key`, cuerpo multipart: `issuing_state=ARG`, `services=arg_renaper`, `document_number` (regex `[MFmf]?\d{7,8}`, 7-9 caracteres), `selfie` (archivo JPEG/PNG/WebP), `gender` (M/F/X), opcionales `first_name`, `last_name`, `date_of_birth` (YYYY-MM-DD), `vendor_data` (nuestro id de usuario).
  - Respuesta 200 siempre; mirar `validations[0].outcome_code`: `MATCH`, `NO_MATCH`, `BIOMETRIC_NO_MATCH` (score < 50 o RENAPER dice que no), `BIOMETRIC_IMAGE_UNUSABLE` (pedir otra selfie), `REGISTRY_UNAVAILABLE` (reintentar, no se cobra). `source_data.face_match_score` es texto 0-100.
  - USD 0,20 por consulta concluyente; p95 < 2 s. Cubre DNI de extranjeros residentes (mismo DNI). La libreta vieja no entra al flujo con ID, pero el numero sirve en esta llamada. Pasaporte/extranjero sin DNI: otro camino (verificacion estandar de Didit).
  - Limite: sin "Liveness" una foto de la cara de otra persona podria pasar; el flujo con Liveness es el alojado de Didit (workflow con OCR + LIVENESS + DATABASE_VALIDATION). Empezar con la llamada directa; migrar si hace falta.
  - Idea de diseno: la app pide numero de DNI + sexo (M/F/X) + selfie; el Worker llama a Didit, guarda solo resultado (outcome, score, fecha, DNI parcial/hash), NO guarda la selfie. En la politica de privacidad hay que nombrar a Didit como proveedor.
- 28/10/2026: decision de Luciano: la verificacion se puede OMITIR para usar la app; sin verificar no se puede pedir foto y audio a OTRAS personas (opcion A: los equipos propios siguen pudiendo). Servidor armado: `aplicar-identidad-didit-panel.ps1` (generado por `panel/generar_identidad_didit_panel.py`): `GET /api/native/identity`, `POST /api/native/identity/verify` ({deviceId, documentNumber, gender M/F/X, selfieBase64}; clave `DIDIT_API_KEY`), tabla `identity_checks` (se crea sola; guarda resultado, puntaje, ultimos 3 digitos y huella del DNI, nunca la selfie), tope de 5 intentos por dia, bloqueo `identity_required` (403) en `remoteFamilyCommand` para `capture-evidence`, mensaje en el mapa. Probado con simulacion (resultados MATCH, BIOMETRIC_NO_MATCH, REGISTRY_UNAVAILABLE, tope, error 401 de Didit). FALTA: (1) Luciano crea la clave de API en Didit y la carga con `npx.cmd wrangler secret put DIDIT_API_KEY`; (2) aplicar el instalador del panel; (3) la APP: pantalla DNI + sexo + selfie con "Omitir por ahora", tarjeta "Verificar mi identidad" en Configuracion, texto honesto, y build; (4) Luciano debe verificarse el para poder pedir evidencia a Mariana (LB iPhone).
- 28/10/2026: **publicado** `aplicar-identidad-didit-panel.ps1` (commit f74a0cd, version 10b05d29). Clave cargada: `DIDIT_API_KEY` = la de la aplicacion **Sandbox** de Didit (no cobra, resultados simulados). Cuando el circuito ande hay que cambiarla por la de "My Application" (`npx.cmd wrangler secret put DIDIT_API_KEY`) y cargar saldo en Didit (la consulta RENAPER cuesta USD 0,20 y no esta en el cupo gratis).
- 28/10/2026: App armada (`aplicar-identidad-app.ps1`, generado por `app/generar_identidad_app.py`; archivos `app/src/VerificarIdentidad.tsx`, `app/arranque/ArranqueIdentidad.tsx` (reemplaza), `app/assets/config-identidad.png`, commit e470b22): arranque = foto de perfil (paso 3) + DNI/sexo (paso 4) + selfie (paso 5) con "Omitir por ahora"; ya no se pide la foto del documento; las fotos viejas de documento y cara se borran del telefono; tarjeta "Verificar mi identidad" al final de Configuracion (todas las plataformas). Revisado con tsc estricto (noUncheckedIndexedAccess + exactOptionalPropertyTypes) sobre archivos de prueba. FALTA: aplicar en la carpeta de la app (compila con tsc), build de Android y iPhone, y probar con la clave Sandbox (resultados simulados). Despues: cambiar a la clave real, cargar saldo, texto de privacidad que nombre a Didit.

## Primer feedback de una usuaria real: la mama de Luciano en iPhone (28/10/2026)
- Cuenta de lo que paso (charla de WhatsApp que paso Luciano): abrio `ojoguard.app` y "no veo como bajarla" (la pagina de entrada no tenia botones); el enlace de TestFlight la mando primero a bajar la app TestFlight y creyo que era la equivocada ("se descargan este TestFlight, no se descarga en el Ojo Guard", "me quedo instalada la del TestFlight"); tuvo que aceptar terminos de Apple sin saber por que; el boton Instalar aparecia gris un rato. Despues las 13 laminas de bienvenida: "se entiende perfecto, pero son muchos pasos", "Too much information, me canse", y "si entras de una sin saber, estas muy perdida". Le gusto el panel en la compu.
- Hecho: `aplicar-login-descargas-panel.ps1` (generado por `panel/generar_login_descargas_panel.py`) = botones Android e iPhone en la pagina de entrada + guia de 4 pasos para iPhone (tambien en `/descargar` y `/unirme`): 1) tocar Instalar en iPhone (se abre TestFlight, es normal), 2) Obtener TestFlight y volver a tocar el enlace, 3) aceptar terminos e Instalar (si esta gris esperar), 4) abrir Ojo Guard (ojo dorado) y dejar TestFlight instalada.
- ACORDAR ANTES DE TOCAR (pedido de Luciano): como se comunican y se recortan las laminas de bienvenida. La informacion tiene que estar, pero mas amena y didactica (ideas: 4-5 laminas con lo esencial, el resto como ayuda dentro de la app en el momento en que hace falta; cada lamina con una sola idea y una accion).
- Mensaje a sumar (idea de Luciano y de su mama): "Funciona entre iPhone y Android" en la primera lamina y en la pagina de descarga.
- CORRECCION 28/10/2026: los botones Android/iPhone de la pagina de entrada YA estaban publicados (Luciano habia aplicado la primera version de `aplicar-login-descargas-panel.ps1`, commit 3b90413; le dijo a su mama "anda abajo donde esta iPhone"). Lo nuevo es solo la guia de 4 pasos: `aplicar-guia-iphone-panel.ps1` (generado por `panel/generar_guia_iphone_panel.py`), que se monta sobre lo ya instalado. El `aplicar-login-descargas-panel.ps1` actual del repo (version combinada) responde "ya estaba aplicado" en esa maquina: no volver a usarlo.
- 28/10/2026: enlace unico `https://ojoguard.app/bajar` (`aplicar-bajar-panel.ps1`, generado por `panel/generar_bajar_panel.py`): Android -> redirige a /descargar; iPhone -> pagina con la guia de 4 pasos y el boton de TestFlight; compu y vista previa de WhatsApp -> las dos opciones. Probado con simulacion de los cuatro casos. QR de ese enlace (comprobado que se lee): `marca/qr-ojoguard-bajar.png` y `.svg`. Pendiente: aplicar el instalador y probar `/bajar` desde un Android y un iPhone reales.
- 28/10/2026: Luciano probo "Verificar mi identidad" en el Xiaomi (build 177): al sacar la selfie la camara abrio, saco la foto y la app volvio sola a la pantalla numerica. Causa probable: Android devuelve la foto (onActivityResult) antes de avisar que la app volvio al frente (onResume); `clearPendingSystemActivity()` se llamaba apenas llegaba la foto y la vuelta tardia se tomaba por una salida real. En el selector de fondo de pantalla de App.tsx no pasa porque hay trabajo asincrono antes del `finally`. Arreglo: `avisarCamaraAbierta()`/`soltarAvisoCamara()` (aviso 5 s mas) en `VerificarIdentidad.tsx` y `ArranqueIdentidad.tsx`; instalador `aplicar-identidad-camara-app.ps1` (generado por `app/generar_camara_app.py`). Falta aplicarlo, hacer la build 178 y repetir la prueba; si sigue pasando, anotar en Registros tecnicos que pasa (puede ser que Xiaomi cierre la app por memoria).
- 28/10/2026: `aplicar-descargar-limpia-panel.ps1` (generado por `panel/generar_descargar_limpia_panel.py`): `/descargar` esconde la tarjeta de iPhone en un Android y manda a `/bajar` a un iPhone. Probado con simulacion.
- 28/10/2026, para la build 179 (juntar mas cambios antes de hacerla): en Configuracion > Verificar mi identidad el titulo y la bajada se repetian ("Verificar mi identidad" arriba y "Verifica tu identidad" abajo). Ya cambiado en `app/src/VerificarIdentidad.tsx` (`sinTituloPropio = revisarEstado`): en Configuracion la pantalla no repite su titulo. FALTA el instalador (descarga de `VerificarIdentidad.tsx` con huella, igual que `aplicar-identidad-camara-app.ps1`) y la build. Pendiente tambien: ver el resultado de la prueba de la selfie con el arreglo de la camara (build 178, aviso 5 s).
- 28/10/2026, prueba en el Xiaomi con la build 178 (aviso de camara 5 s): igual vuelve solo a la pantalla numerica al sacar la selfie. Luciano: "tiene algo que ver con el Android, a veces me pasa lo mismo cuando te quiero adjuntar una foto... a la tercera me lo toma" => el sistema (MIUI) cierra la app por memoria mientras esta abierta la camara del sistema; no era el aviso de AppState. Arreglo: la selfie se saca con la camara DENTRO de la app (`CameraView` de expo-camera, como la evidencia): `VerificarIdentidad.tsx` (commit 904ada2). Instalador `aplicar-identidad2-app.ps1` (generado por `app/generar_identidad2_app.py`). La foto de PERFIL del arranque sigue usando la camara del sistema (con opcion de galeria); si en Android pasa lo mismo, pasarla tambien a la camara de la app.
- Luciano en esa prueba: puso DNI, la pagina mostraba "Guardar cambios / Volver sin guardar" (botones de toda Configuracion), toco guardar y volvio al inicio sin nada guardado. El DNI no se guarda a proposito (solo se manda a verificar). Arreglo: en las paginas Verificar mi identidad y Actualizar Ojo Guard esos dos botones ya no se muestran (cambio en App.tsx dentro de `aplicar-identidad2-app.ps1`).
- 28/10/2026, bienvenida (decision de Luciano): "no es lo mismo 7 que 13". Las 13 explicaciones y sus dibujos se mantienen tal cual, juntadas de a dos (13 -> 7 laminas): (1) Bienvenido + Mapa, (2) Camino seguro + SOS, (3) Defensa antirrobo + Si perdes el telefono, (4) Que nada se aleje + Evidencias y reconocimiento facial, (5) Dispositivos y cuidado de mayores + Avisos de llegada y salida, (6) Alertas y acceso seguro + Panel en la compu, (7) Todo listo (permisos). Diseno: dos dibujos chicos lado a lado (marco azul / dorado) y los dos textos abajo con un punto del mismo color; probado renderizando los componentes reales con react-native-web. Archivo `app/arranque/Bienvenida.tsx` (commit ec5c8b5), instalador `aplicar-laminas-app.ps1` (generado por `app/generar_laminas_app.py`). Sale en la build 180 (la 179 ya estaba corriendo). Dejado para despues: lamina resumen con tildes (ubicacion por piso, caidas "proximamente", SOS con botones de volumen, etc.) y explicacion la primera vez que se entra a cada funcion; foto de PERFIL con la camara de la app.
- 28/10/2026, build 179 en el Xiaomi: la camara dentro de la app deja ver la verificacion hasta el final y las paginas Verificar/Actualizar ya no traen los botones de Guardar. Pero el resultado fue "El servicio de verificacion no esta disponible ahora" (el servidor devolvio identity_provider_error o identity_unreachable con la clave de Sandbox de Didit). Armado `aplicar-identidad-diag-panel.ps1` (generado por `panel/generar_identidad_diag_panel.py`): el servidor anota en el registro lo que contesta Didit (estado + 400 primeros caracteres); se mira con `npx.cmd wrangler tail ojo-guard-ms-api --format pretty` mientras se reintenta. Hipotesis a confirmar con el estado: 401/403 (la clave de Sandbox no sirve para esa consulta o falta saldo), 400/422 (formato del pedido), 402 (saldo).
- 28/10/2026: `wrangler tail` con el diagnostico mostro `didit_unreachable Error: Network connection lost` (el servidor llega a Didit pero la conexion se corta al mandar la selfie). Arreglo: `aplicar-identidad-envio-panel.ps1` (generado por `panel/generar_identidad_envio_panel.py`) arma el cuerpo completo (con Content-Length) antes de mandarlo. Si sigue fallando: bajar el tamano de la selfie en la app (`takePictureAsync({ scale: 0.5 })`, build 180) y/o comprobar si el endpoint de Didit acepta la clave de Sandbox.
- 28/10/2026: con el cuerpo armado completo sigue `didit_unreachable Error: Network connection lost` (dos intentos). Hipotesis: Didit corta la conexion al recibir el pedido (clave de Sandbox rechazada o tamano) y Cloudflare lo reporta asi. `aplicar-identidad-sonda-panel.ps1` (generado por `panel/generar_identidad_sonda_panel.py`) anota el tamano del pedido y manda una prueba chica con una imagen diminuta para ver el estado real que contesta Didit.
- 28/10/2026: con la sonda: `didit_unreachable ... bytes=535028 sonda=400` y `bytes=558215 sonda=400` => la prueba chica SI llega a Didit y la clave de Sandbox es aceptada (400 por imagen falsa, no 401); el pedido real (~535-558 KB, la selfie de la camara de la app en base64 decodificada) es el que se corta. `aplicar-identidad-matriz-panel.ps1` (generado por `panel/generar_identidad_matriz_panel.py`) prueba pedidos de 1, 100, 300, 520 y 1024 KB para encontrar el tamano que se corta. Solucion probable: achicar la selfie en la app (`takePictureAsync({ scale: 0.5 })` o menor `quality`) en la build 180.
- 28/10/2026, RESULTADO de la matriz: `matriz=1k=400 100k=400 300k=CORTA 520k=CORTA 1024k=CORTA` => Didit (endpoint database-validation) corta la conexion con pedidos de 300 KB o mas; la selfie de la camara pesaba ~535-593 KB. Arreglo en la app: achicar la selfie a 600 px de ancho y compresion 0,6 antes de mandarla (`reducirSelfie` en `VerificarIdentidad.tsx`, con `expo-image-manipulator`, compatible con la API vieja y la nueva). Instalador `aplicar-selfie-chica-app.ps1` (generado por `app/generar_selfie_chica_app.py`); necesita `npx.cmd expo install expo-image-manipulator` antes. Idea de Luciano para despues: captura guiada tipo banco ("mas cerca / mas lejos", se pone verde y saca sola) = prueba de vida; la da el flujo alojado de Didit o una deteccion de cara en el telefono. Quitar del servidor la sonda/matriz de diagnostico cuando ande (envian pedidos de prueba a Didit solo cuando falla).
- 28/10/2026, build 180 en el Xiaomi: la cámara propia anda y la selfie chica YA NO se corta (el servidor ve `didit_failed 400`, o sea Didit contesta). Falta saber el motivo del 400 (el cuerpo no salía en el registro). `aplicar-identidad-cuerpo-panel.ps1` (generado por `panel/generar_identidad_cuerpo_panel.py`) anota estado, tipo, largo y cuerpo de la respuesta + tamaño de selfie, largo del DNI y sexo. Hipótesis: campo faltante o formato (p. ej. nombre/fecha de nacimiento obligatorios para RENAPER, calidad de la imagen) o la clave Sandbox. Después de resolver: quitar sonda/matriz del servidor.
- 28/10/2026, con `aplicar-identidad-cuerpo-panel.ps1`: `didit_failed status=400 tipo=- largo=0 cuerpo="" selfie=56825 dni=8 sexo=M` => Didit contesta 400 SIN cuerpo ni tipo, incluso con selfie de 55 KB: no es un error de validacion de Didit sino un pedido multipart mal formado (el `content-type` sacado de `new Request(...)` venia vacio, o sea sin boundary, y caia a "multipart/form-data" pelado; tambien explica el `sonda=400`). Arreglo: `aplicar-identidad-multipart-panel.ps1` (generado por `panel/generar_identidad_multipart_panel.py`) arma el multipart a mano con su propio limite. Probado en Node (se lee con `Response.formData()`: campos y bytes de la selfie intactos). La falla "Network connection lost" con 300+ KB puede haber sido el mismo problema; si con el pedido bien armado vuelve a cortar, reducir igual.
- 28/10/2026, con el multipart armado a mano sigue `didit_failed status=400 tipo=- largo=0 cuerpo=""` (selfie 52-57 KB). Luciano sospecha que la clave Sandbox se cargó mal. `aplicar-identidad-clave-panel.ps1` (generado por `panel/generar_identidad_clave_panel.py`) limpia la clave (espacios, saltos, comillas, "Bearer") y anota su forma en el registro (`clave: largo=A/B [limpiada]`, nunca la clave). Si A≠B o la clave es muy corta/larga, se vuelve a cargar con `npx.cmd wrangler secret put DIDIT_API_KEY`.
- 28/10/2026, clave de Didit bien cargada (43 caracteres; antes se había guardado 1 carácter y luego un comando copiado del chat; se carga con `poner-clave.ps1`, que lee el portapapeles y valida el largo). Resultado: Didit acepta clave y pedido pero contesta `500` (HTML "Server Error (500)") dos veces seguidas con selfie de 56-58 KB, DNI de 8 dígitos y sexo M. La MCP de Didit confirma que arg_renaper exige `selfie`. `aplicar-identidad-variantes-panel.ps1` (generado por `panel/generar_identidad_variantes_panel.py`): ante un 500 manda 5 variantes (sin vendor_data, con nombre+fecha, sin services, selfie chica, selfie chica + vendor_data) y anota `didit_variantes`. Si todas dan 500, es problema del Sandbox de Didit (escribir a soporte de Didit o probar en vivo con saldo). Quitar sonda/matriz/variantes del servidor cuando ande.
- 28/10/2026, resultado de las variantes: con la selfie real (52-59 KB) TODAS dan 500 de Didit (sinVd, conDatos, sinServices); con una imagen diminuta/corrupta da 400 `{"selfie":["Invalid image format or corrupt image."]}`. O sea: Didit valida la imagen y recién después se rompe por dentro (Sandbox o procesamiento de la cara). `aplicar-identidad-variantes2-panel.ps1` (generado por `panel/generar_identidad_variantes2_panel.py`): segunda ronda con imagen JPEG válida SIN cara (320x320), otro DNI y otro sexo. Si todo da 500 con cualquier dato: bug del Sandbox/endpoint de Didit -> escribir a soporte de Didit (con la hora y el tipo de error) o probar en vivo (My Application + saldo).
- 28/10/2026, segunda ronda de variantes: TODO da 500 (imagen válida sin cara, otro DNI, otro sexo, con/sin vendor_data) => es un fallo del lado de Didit (endpoint database-validation con arg_renaper en Sandbox), no de nuestros datos. Se dejó un BORRADOR de correo en Gmail (respuesta al hilo "Your Didit account is live", a albertorosas@didit.me) con el detalle para que Luciano lo revise y lo envíe. Opciones: esperar respuesta de Didit, o probar en vivo (aplicación "My Application" + saldo; consulta RENAPER ~USD 0,20 solo si hay resultado concluyente). Mientras tanto la verificación no se puede completar; la app sigue usable (se puede omitir). Quitar sonda/matriz/variantes del servidor cuando ande.
- 28/10/2026: la foto de perfil del arranque ahora se saca con la cámara propia de la app (como la selfie de identidad), para que en el Xiaomi no vuelva a la pantalla del PIN. Instalador `aplicar-perfil-camara-app.ps1` (generado por `app/generar_perfil_camara_app.py`; reemplaza `src\ArranqueIdentidad.tsx`; sale en la build 181). La galería sigue con el selector del sistema (sin probar en Xiaomi).
- 28/10/2026: tarjeta "Mi foto de perfil" dentro de Perfil (ver, cambiar con la cámara de la app o elegir de la galería): `app/src/FotoPerfil.tsx` + `guardarPerfil` en `ArranqueIdentidad.tsx`; instalador `aplicar-foto-perfil-app.ps1` (generado por `app/generar_foto_perfil_app.py`; sale en la build 182). OJO: la foto se guarda SOLO en el teléfono; ningún otro lugar la muestra todavía (ni el mapa, ni el círculo familiar). El texto viejo del arranque decía "es la foto que ve tu círculo": se corrigió. Pendiente de decidir con Luciano: mostrarla en la app (círculo junto al nombre/Perfil, local) y/o subirla al servidor para que la familia la vea en el mapa y en la lista (implica privacidad: texto en la política y consentimiento).
- 28/10/2026, decisión de Luciano: la foto de perfil la tiene que ver la gente con la que se comparte (mismas reglas de la lista de familia: un amigo solo ve al titular y viceversa). Servidor: `aplicar-foto-perfil-panel.ps1` (generado por `panel/generar_foto_perfil_panel.py`): tabla `profile_photos` (email, JPEG base64 ≤ ~90 KB, versión), `POST /api/native/profile-photo` (+`/delete`), `GET /api/native/profile-photo?deviceId=&person=<id|me>` y `GET /api/remote/profile-photo?person=` (solo si esa persona está en la lista de quien pide, vía `familyPeopleFor`), campo `photo` (versión o null) en cada persona y en `me`. Simulación con 13 casos OK (sin permiso = 404, borrar, inválida, enorme). FALTA: app (subir la foto reducida a 256 px al guardarla/cambiarla, mostrarla en Perfil y en la lista de familia con `Authorization`), panel web (lista y marcadores del mapa), política de privacidad (la foto se guarda en el servidor y la ven las personas del círculo; se puede borrar).
- 28/10/2026: panel: `aplicar-foto-perfil-mapa-panel.ps1` (mapa y lista muestran la foto de perfil de las personas; `fotoV` en `normalizarFamilia`, `urlFoto` para personas; sube `mapa-v1.js?v=2`) y `aplicar-foto-perfil-cabecera-panel.ps1` (tu foto al lado del correo arriba, `ponerFotoCuenta`; sube `app-v9.js?v=9`). Las fotos solo aparecen cuando alguien las sube desde la app (build 182).
- 28/10/2026: app (build 182): la foto de perfil se achica a 256 px y se SUBE al servidor para que la vea el círculo (`app/src/fotoPerfilServidor.ts`: `subirFotoPerfil`, `fotoSubida`, `marcarFotoSubida`; la tarjeta Mi foto de perfil y el arranque la suben; si no hay conexión, Perfil ofrece "Compartir con mi círculo"). Instalador `aplicar-foto-perfil2-app.ps1` (generado por `app/generar_foto_perfil2_app.py`; requiere `aplicar-foto-perfil-app.ps1` y el servidor con `aplicar-foto-perfil-panel.ps1`). FALTA: opción de dejar de compartir / borrar la foto del servidor (hoy solo se puede reemplazar; el endpoint `/api/native/profile-photo/delete` ya existe), texto en la política de privacidad, y avisar a quien ya tenía foto (se le ofrece compartirla, no se sube sola).
- 28/10/2026: Luciano: "si no aparece acá (mapa, su propio celular) mucho sentido no tiene". En el mapa las personas (otros) ya muestran su foto; los equipos propios mostraban solo el dibujo de teléfono. `aplicar-foto-perfil-mapa2-panel.ps1` (generado por `panel/generar_foto_perfil_mapa2_panel.py`): un celular tuyo sin foto propia (la del lápiz) muestra tu foto de perfil; computadoras y relojes siguen con su dibujo; sube `mapa-v1.js?v=3`.
- 28/10/2026: botón "Dejar de compartir mi foto" en Perfil (`dejarDeCompartirFoto` en `fotoPerfilServidor.ts`: borra la foto del servidor y el marcador de subida; la foto sigue en el teléfono y se puede volver a compartir). Instalador `aplicar-foto-perfil3-app.ps1` (generado por `app/generar_foto_perfil3_app.py`); sale en la build 183.
- 29/10/2026: iPhone (Luciano, "Diagnóstico de captura"): "Falló el guardado de la evidencia … deleteAsync … File '…/Application/<UUID>/Documents/ojo-guard-history/<id>.jpg/..' is not writable". Causa probable: `evidenceHistory.ts` guardaba rutas absolutas con el identificador de la carpeta de datos de iOS, que puede cambiar al actualizar por TestFlight; el borrado de un archivo viejo con esa ruta fallaba y arrastraba el guardado de la evidencia nueva. Arreglo en `app/src/evidenceHistory.ts` (`currentUri` rearma la ruta con la carpeta actual al leer, `safeDelete` no deja que un borrado frene el guardado); probado con simulación (5 casos OK). Instalador `aplicar-historial-evidencia-app.ps1` (generado por `app/generar_historial_evidencia_app.py`); sale en la próxima build de iPhone y Android. Sin confirmar en el iPhone todavía.
- 29/10/2026: pruebas con iPhone build 43 y Android: (1) SMS ya sale (Twilio reactivado; la cuenta se había suspendido el 25/10 por falla de la recarga automática de USD 20,05; falta dejar un medio de pago de respaldo en Billing > Auto-recharge); (2) correo de evidencia llega a la casilla de la cuenta dueña del teléfono (lubick@me.com para el iPhone), no a la de Gmail; (3) el guardado de evidencia en iPhone se arregló con `evidenceHistory.ts` (rutas reubicadas); (4) pedir foto y audio desde la cuenta Gmail (Android) a "LB iPhone" NO se ejecuta porque ahí el iPhone es una PERSONA adulta de la familia y la regla exige identidad verificada (Didit da 500); desde la cuenta del iPhone (equipo propio) funciona, incluso con el teléfono apagado/bloqueado. Alternativa pendiente de decidir: verificación manual solo para la cuenta del titular (instalador chico) mientras Didit se arregla; o cargar el iPhone como "equipo propio" de la cuenta Gmail. Revisar que el cartel de `identity_required` del panel se vea claro. Foto de perfil compartida funciona entre cuentas (pin y lista con foto); botón "Dejar de compartir mi foto" en la 43 de iPhone y la próxima de Android.
- 29/10/2026: "Borrar mi cuenta" (Apple lo exige dentro de la app). Servidor: `aplicar-borrar-cuenta-panel.ps1` (generado por `panel/generar_borrar_cuenta_panel.py`): `POST /api/native/account/delete` {deviceId, confirm:"BORRAR"} borra de 32 tablas (equipos, ubicaciones, evidencias + archivos de KV, familia, avisos, referentes, Guardián, verificación, foto de perfil, códigos, passkeys/TOTP, etc.), avisa por correo y devuelve {ok, parcial, fallos}. Simulación de 10 casos OK (sin token 401, sin BORRAR 400, parámetros de cada SQL, falla de una tabla no frena a las demás). NO verificado contra la base real: los nombres de columnas salen del código; si alguna tabla falla queda en `fallos` y en el registro (`account_delete`). FALTA: pantalla en la app (Perfil) con confirmación escribiendo BORRAR, limpiar datos locales (enrollment, historial, identidad, foto) y volver al inicio; política de privacidad ya lo menciona como pendiente; también ofrecerlo en el panel web (Configuración > Cuenta y seguridad).
- 29/10/2026: app: `BorrarCuenta.tsx` (en Perfil, debajo de Mi foto de perfil): confirma escribiendo BORRAR, llama a `POST /api/native/account/delete` y, solo si el servidor confirma, limpia el teléfono (vínculo, historial de evidencias, carpeta de identidad, AsyncStorage). Instalador `aplicar-borrar-cuenta-app.ps1` (generado por `app/generar_borrar_cuenta_app.py`); requiere `aplicar-foto-perfil-app.ps1`. Salen en la próxima build (Android y iPhone). Dudas: el PIN u otros datos en SecureStore (no solo el vínculo) podrían quedar al borrar; probar en un teléfono de prueba antes de enviar a Apple. También falta ofrecer "Borrar mi cuenta" en el panel web.
- 29/10/2026: iPhone build 44: la foto de perfil "desapareció" de Perfil (ruta absoluta con el identificador de carpeta viejo, igual que el historial de evidencias). Arreglo: `rutaActual`/`mismoArchivo` en `ArranqueIdentidad.tsx` y aviso en la tarjeta si de verdad falta el archivo (`FotoPerfil.tsx`). Instalador `aplicar-foto-ruta-app.ps1` (generado por `app/generar_foto_ruta_app.py`). Probado con tsc y la lógica de la ruta; sale en la próxima build. Ojo: al actualizar la app el identificador puede cambiar cada vez, así que conviene revisar otros lugares que guarden rutas absolutas (selfies temporales, historial, fotos de equipos).
- 29/10/2026: PRUEBA REAL de "Borrar mi cuenta" en un iPhone con una cuenta de prueba (paradormiraflores@gmail.com; no estaba en ninguna familia). Antes: devices 1, location_history 1, profile_photos 1, access_codes 1, family (titular) 1. Después de borrar desde la app (escribiendo BORRAR, respuesta "Tu cuenta se borró", sin "parcial"): TODAS las tablas consultadas en 0 (devices, location_history, commands, evidence_attempts, profile_photos, notification_prefs, identity_checks, access_codes, family titular/integrante). Falta confirmar: llegada del correo "Tu cuenta de Ojo Guard se borró" a esa casilla; que otras tablas (pld_*, gd_*, totp, passkeys) también queden en 0 en una cuenta que las use; y pulir la pantalla: tras borrar siguen viéndose las otras tarjetas (foto, estado del equipo) hasta reabrir la app.
- 29/10/2026: tras "Borrar mi cuenta" la app ahora muestra una pantalla completa (Modal) "Tu cuenta se borró" que tapa las demás tarjetas; en Android con botón "Cerrar Ojo Guard" (BackHandler.exitApp). Instalador `aplicar-borrar-cuenta2-app.ps1` (generado por `app/generar_borrar_cuenta2_app.py`). Confirmado en la prueba real que llega el correo "Tu cuenta de Ojo Guard se borró" (la plantilla le agrega al pie "Guardá este link por si perdés el acceso": sacarlo en este aviso).
