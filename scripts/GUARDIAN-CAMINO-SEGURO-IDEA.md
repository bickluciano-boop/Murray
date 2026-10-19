# "Guardián": acompañarte en el camino (cuando vas a un lugar y no te sentís tranquilo)

Estado: **IDEA** (Luciano, 19/10/2026; la vio en otra app). Nada construido.

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
