# "Camino seguro": una función de Guardián para cuando vas a un lugar y no te sentís tranquilo

Estado: **IDEA** (Luciano, 19/10/2026; la vio en otra app). Nada construido.

## Qué es

Estás volviendo a tu casa, vas a un lugar que no te gusta, te perdiste o esperás que te abran la puerta. La activás:

1. Toma tu punto actual, en vivo.
2. Elegís **a dónde vas** y **cómo**: auto, transporte o caminando.
3. El sistema calcula **cuánto tarda** y arranca una **cuenta regresiva** con **2 minutos de más**.
4. Si no la desactivás antes de que termine, **les avisa a tus guardianes** (los referentes de esta función) con tu última señal, el destino y cuánto pasó.
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
- **Avisos:** a la persona, 2 minutos antes de que venza, "¿Seguís en camino? Llegué / Extender"; si no responde, mail a los guardianes (con su enlace) y repetición cada pocos minutos.
- **Transparencia y privacidad:** solo se comparte la ubicación durante el camino y solo con los guardianes elegidos; queda en el registro.

## Para decidir

- Nombre de la función (candidatos: "Camino seguro", "Llegada segura", "Avisame cuando llegues").
- Si los guardianes de esta función son los mismos que los de "Por las dudas" o una lista aparte.
- Cuánto se extiende al apretar "Extender" (10, 20, 30 min) y cuántas veces.
- Qué pasa con "No llegué bien": ¿avisa como un SOS?
- Revisión legal igual que para "Por las dudas".
