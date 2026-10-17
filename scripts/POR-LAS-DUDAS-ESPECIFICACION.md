# "Por las dudas" — especificación en borrador

Estado: **VISIÓN** (idea acordada con Luciano el 17/10/2026, nada construido ni probado en un teléfono real).
Origen: un chico de 16 años desapareció saliendo de un boliche, con el celular sin batería y sin ninguna app de
ubicación vinculada; la familia no tenía cómo saber dónde estuvo por última vez.

## Qué es

Una persona elige de antemano a sus **referentes**. En el día a día nadie ve nada. Si pasan cosas raras (las
condiciones que la propia persona permitió), un referente preocupado puede ver la **última señal** del teléfono.
La persona que se pierde nunca aprieta nada: el que actúa es el referente.

## Nombres (borrador)

| Dónde | Nombre |
|---|---|
| La función (tarjeta en Ajustes) | **Por las dudas** (en inglés: *just in case*) |
| Las personas elegidas | **Referentes** |
| Botón de Ajustes | **Elegir referentes** |
| Botón del referente preocupado (página web, sin app) | **No lo encuentro** |
| Lo que ve el referente | **Última señal** (mapa, hora, dirección, batería) |
| Pausa | **Esta noche, afuera** |
| Respuesta de la persona | **Estoy bien** (el mismo del SOS) |

Sin botón nuevo de ayuda: el **SOS** existente también avisa a los referentes.

## Flujo

1. **Alta (una sola vez).** La persona (o un menor con sus padres al tanto) elige 1 a 5 referentes. A cada uno le llega
   un mail con un enlace personal; **acepta** ser referente. Sin app.
2. **Día a día.** El teléfono manda de a poco su ubicación (solo cambios grandes). El servidor se queda con el último
   punto y, ante señales de riesgo, con los últimos 30 minutos. Nadie lo ve.
3. **Referente preocupado aprieta "No lo encuentro".** (Página web con su enlace personal.)
   1. Al teléfono de la persona le llega un **"¿Estás bien?"** de parte de ese referente (botón "Estoy bien").
   2. Si se cumplen las **condiciones permitidas**, se muestra la **Última señal**.
   3. Si no se cumplen: "su teléfono se está reportando con normalidad; le mandamos un ¿estás bien?" y se vuelve a
      mirar a los 30 minutos.
   4. Si el referente marca **"es una emergencia"** y pasaron, por ejemplo, **3 horas sin señal**, se muestra igual
      aunque no se cumplan todas las condiciones. (Decidido el 17/10/2026.)
4. **Aviso automático.** Si las condiciones se cumplen y nadie respondió el "¿Estás bien?" en 15 minutos, el servidor
   avisa solo a los referentes con la última señal (se repite cada 30 minutos y avisa cuando el teléfono reconecta).
5. **Transparencia.** Cada consulta o aviso queda registrado y la persona lo ve después ("Mamá consultó tu última señal
   el 21/10 a las 03:12").

## Condiciones (señales)

| Señal | Valor inicial |
|---|---|
| Silencio | sin reportar 90 min de noche, 6 h de día |
| Lejos de casa | más de 3 km de "Casa" y fuera de sus Lugares |
| Batería | 15 % o menos |
| Horario | 21:00 a 06:00 (configurable) |
| Silencio repentino con batería alta y en movimiento | alerta en 5 a 10 min (apagado a mano o robo) |
| Silencio con batería muy baja | más espera (probable batería muerta) |

Regla de partida: **3 de las 4** señales. Con 2 señales: solo el "¿Estás bien?" a la propia persona.

## Contra las falsas alarmas

- **Lugares seguros** (casa de un amigo): estar ahí no cuenta como "lejos".
- **Esta noche, afuera**: pausa por unas horas.
- Cada referente puede **silenciar**.
- Antes de contar un silencio, el servidor pide una ubicación nueva al teléfono (en iPhone la app puede estar suspendida).

## Límites técnicos (honestos)

- Ninguna app puede mandar nada con el teléfono ya apagado; en iPhone no se puede interceptar el apagado. Por eso el
  servidor tiene que tener siempre el último punto.
- iPhone: hace falta el permiso de ubicación "Siempre" para que se reporte en segundo plano.
- Recomendar lo del sistema, que sigue andando apagado: iPhone "Buscar" con la red de Buscar y Protección de
  dispositivo robado; Android "Encontrar mi dispositivo / Find Hub" y el bloqueo por detección de robo (según modelo).

## Privacidad

- **Mayor de edad:** lo activa la propia persona; sin su consentimiento no se activa.
- **Menor de 18:** lo activa y administra el tutor (el mayor responsable, como ya pasa con el rol "Menor" de Familia). Luciano
  (17/10/2026): al ser menor no haría falta el consentimiento del chico porque la tutela la tiene el mayor. Aun así se
  mantiene el aviso al menor de que alguien consultó su última señal (la app ya le avisa cuando un tutor le pide foto o
  audio): es una decisión de confianza del producto, no una exigencia que haya que cumplir. Lo legal lo confirma un abogado.
- Lista visible de quién tiene acceso.
- Se guarda lo mínimo: el último punto y, con señales de riesgo, los últimos 30 minutos; tiempo de guardado a definir.
- Revisar con un abogado antes de lanzarlo (menores, consentimiento, registro de consultas).

## Plan

**Primera versión (sin build de la app):** solo servidor y panel.
- Tablas nuevas en D1 (referentes, reglas, registro de consultas y avisos). Ya existen `family_places` (Lugares),
  `family_alerts`, `family_sos`, `family_sos_to`.
- Evaluación de las condiciones en el cron de 15 minutos que ya existe.
- Mails con el enlace personal del referente (ya hay envío de mails) y la página web "No lo encuentro".
- Carga de referentes y condiciones desde el panel.

**Segunda etapa (con build):** pantalla "Por las dudas" en la app, reporte adaptativo (un punto cada 10 a 20 s con
señales de riesgo), detección de arrebato, SOS que también avise a los referentes, consejos de Android.

## Pendientes de decidir

- Cuánto tiempo se guarda el recorrido.
- Si los avisos van solo por mail o también por SMS/WhatsApp.
- Cómo se verifica que el referente es quien dice (enlace personal + código por mail).
- Revisión legal.
