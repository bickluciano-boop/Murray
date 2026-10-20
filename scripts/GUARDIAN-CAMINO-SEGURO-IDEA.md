# "Guardián": acompañarte en el camino (cuando vas a un lugar y no te sentís tranquilo)

Estado: **PRIMERA VERSIÓN ARMADA EN EL SERVIDOR (20/10/2026), sin instalar** (código y pruebas en `scripts/por-las-dudas/`, sección "Modo Guardián" de `pld.ts`; 240 pruebas y navegador ok). Idea de Luciano del 19/10/2026 (la vio en otra app).

**Nombres (aclarados por Luciano el 19/10/2026):** **Referentes** = las personas que elige (una sola lista para todo); **SOS** = el botón manual, que avisa a la familia
y a los referentes; **Modo Guardián** = este servicio, acompañarte en el camino (lo activa la persona); **Modo Cautela** = la función que avisa sola, que hoy se llama "Por las dudas"
("cautela" = precaución, "por las dudas"). Entrada: el ícono **OG**. Los avisos de Guardián van a los **mismos referentes**.

## Qué es

Estás volviendo a tu casa, vas a un lugar que no te gusta, te perdiste o esperás que te abran la puerta. La activás:

1. Toma tu punto actual, en vivo.
2. Elegís **a dónde vas** y **cómo**: auto, transporte o caminando.
3. El sistema calcula **cuánto tarda** y arranca una **cuenta regresiva** con **2 minutos de más**.
4. Si no la desactivás antes de que termine, **les avisa a tus referentes** con tu última señal, el destino y cuánto pasó.
5. Si llegás, apretás **Llegué** y se corta. Si el sistema ve que llegaste (tu teléfono está en el destino), te pregunta
   **"¿Llegaste bien?" → Sí / No / Extendemos a X minutos**.

## Cómo funcionaría (borrador técnico)

- **El reloj corre en el servidor**, no en el teléfono: si el teléfono se apaga o se rompe, el aviso sale igual. Hace falta una pasada de cron **cada minuto**
  (hoy el cron corre cada 15; habría que agregar `* * * * *` en `wrangler.toml`).
- **El tiempo del viaje:** con la API de rutas de Google (tránsito y tráfico) o, sin clave, una estimación por distancia y velocidad media.
  Con Google se calcula en la página (Maps JavaScript, `DirectionsService`) con la clave que ya usa el mapa; hay que tener habilitada la API de Directions.
- **El destino:** una dirección escrita (búsqueda de lugares) o un lugar guardado ("Casa", los de Lugares).
- **Primera versión sin build:** una página web que se abre en el celular (como `/por-las-dudas`), con "Llegué", "Extender 10 / 20 / 30 min" y el aviso a los guardianes.
  Sin seguimiento en vivo ni llegada automática: eso lo da la app (ubicación en segundo plano) en una build posterior.
- **Avisos:** a la persona, 2 minutos antes de que venza, "¿Seguís en camino? Llegué / Extender"; si no responde, mail a los referentes (con su enlace) y repetición cada pocos minutos.
- **Transparencia y privacidad:** solo se comparte la ubicación durante el camino y solo con los referentes elegidos; queda en el registro.

## Para decidir

- (Resuelto) El nombre de este servicio es **Guardián** y los referentes son los mismos que los del SOS.
- Cuánto se extiende al apretar "Extender" (10, 20, 30 min) y cuántas veces.
- Qué pasa con "No llegué bien": ¿avisa como un SOS?
- Revisión legal igual que para "Por las dudas".

## Lo que quedó armado (20/10/2026)

- **Decisiones de arranque** (Luciano dijo "hay que programar el seguimiento Guardián"): extender **10 / 20 / 30 minutos, hasta 3 veces**; "No llegué bien" = **"Necesito ayuda"**: avisa enseguida a los referentes como un SOS, con la última ubicación; margen de **2 minutos**; aviso a la persona **2 minutos antes** de vencer; si no responde, mail a los referentes y repetición **cada 10 minutos, hasta 3 avisos**; un camino olvidado se cierra solo a las **12 horas**.
- **El reloj corre en el servidor** (`gdCron`): el instalador `aplicar-guardian-camino-panel.ps1` agrega un **segundo cron de cada minuto** en `wrangler.toml` (`crons = ["*/15 * * * *", "* * * * *"]`) y una rama al principio de `scheduled` (`_controller.cron === "* * * * *"` → solo `gdCron`; el cron de cada 15 minutos queda igual que antes).
- **El tiempo lo calcula Google Mapas (20/10/2026, pedido de Luciano tras probar: "la persona es más probable que se equivoque")**: `gdRutaMapas` usa la **Routes API** de Google (`computeRoutes`; auto = `DRIVE` con `TRAFFIC_AWARE`, transporte = `TRANSIT`, a pie = `WALK`; región AR) desde la ubicación del teléfono (o la del celular, si la da al empezar) hasta el Lugar o la dirección escrita (Google la geocodifica y las coordenadas se guardan para saber si llegó). Con ese tiempo, la persona **no puede cambiarlo**; si queda a más de 5 horas se rechaza (ej. "Kansas" EEUU). Hace falta la clave `GOOGLE_ROUTES_KEY` (secreto del panel; `npx wrangler secret put GOOGLE_ROUTES_KEY`), creada en Google Cloud con la Routes API habilitada y restringida solo a esa API. Sin clave, o si Google falla, se estima por la distancia (solo Lugares) o la persona pone los minutos, como antes. Más adelante: volver a calcular durante el camino (si el tránsito empeora) y avisar.
- **Destino (antes, sin Google):** uno de sus Lugares (el tiempo se calcula por distancia en línea recta × 1,3 y velocidad media: auto 28 km/h, transporte 15 km/h + 5 min de espera, caminando 4,5 km/h; **es una estimación, la persona puede cambiarla**) u "Otro lugar" con los minutos puestos por ella. Sin Google Directions todavía (mejorar cuando haya clave del lado del servidor).
- **Seguimiento:** mientras dura el camino se le pide al teléfono una ubicación nueva cada 5 minutos (Android; en iPhone no despierta la app) y, si el teléfono llega al destino (150 m, ubicación de menos de 10 minutos), se le pregunta "¿Llegaste bien?".
- **Páginas:** la tarjeta "Modo Guardián" dentro de `/guardian` (empezar) y `/camino?t=...` (el camino: reloj, Llegué, +10/+20/+30, Necesito ayuda, Cancelar), con enlace personal firmado: se abre desde el mail o el aviso sin entrar al panel. API: `POST /api/guardian`.
- **Condiciones:** hace falta al menos un referente que haya aceptado; un menor puede empezar su propio camino; no se puede armar el camino de otro.
- **Tabla nueva:** `gd_viajes`. Los avisos al teléfono llevan `data: { tipo: "guardian", url }` para que la app abra el enlace al tocarlos.
- **Pendiente:** instalador (tabla + código + rutas + cron de cada minuto), pantalla del camino en la app (seguimiento en segundo plano con la app abierta, llegada automática más precisa), compartir el camino en vivo con los referentes, Directions de Google, revisión legal.
