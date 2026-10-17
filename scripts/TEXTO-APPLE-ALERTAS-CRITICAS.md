# Texto para escribirle a Apple por las Alertas críticas

Preparado el 17/10/2026. **No mandar antes del 21/10/2026**: la idea es esperar cuatro días más; si en ese
plazo no llegó respuesta ni aparece "Critical Alerts" en las capacidades de `app.ojoguard.mobile`, se manda.

Antes de mandarlo, mirar (1) la casilla de lubick@me.com con la búsqueda `7R4MM73U2Y` y `Critical`, también en
Spam, y (2) developer.apple.com → Account → Certificates, Identifiers & Profiles → Identifiers →
`app.ojoguard.mobile` → Capabilities, por si "Critical Alerts" ya aparece para tildar.

Dónde mandarlo: developer.apple.com → **Contact Us** (elegir la opción de membresía/cuenta o la de ayuda con
entitlements/capabilities y pegar el texto). Lo manda quien es el **Account Holder** (Luciano, lubick@me.com).

Datos que tienen que coincidir con el pedido original:

- Pedido enviado el **09/10/2026** (17:3x), Request ID **7R4MM73U2Y**.
- App: Ojo Guard, Bundle ID `app.ojoguard.mobile`.
- Team: LUCIANO JULIAN BICK, Team ID `8XZ6R7M4A9`.
- Permiso: `com.apple.developer.usernotifications.critical-alerts`.

## Asunto

```
Follow-up: Critical Alerts entitlement request 7R4MM73U2Y (app.ojoguard.mobile, Team 8XZ6R7M4A9)
```

## Mensaje

```
Hello,

On October 9, 2026 I submitted a request for the Critical Alerts entitlement
(com.apple.developer.usernotifications.critical-alerts) and received the Request ID
7R4MM73U2Y. I have not received any response, and I cannot see the status of the request
in my developer account.

Could you please confirm that the request was received and is under review, or tell me if
you need any additional information from me?

Details
- App: Ojo Guard (iOS)
- Bundle ID: app.ojoguard.mobile
- Team: LUCIANO JULIAN BICK (Team ID 8XZ6R7M4A9)
- Account Holder / Apple ID: lubick@me.com
- Request ID: 7R4MM73U2Y (submitted on October 9, 2026)

Why the app needs this entitlement
Ojo Guard is a personal and family safety app. It sends two kinds of time-critical alerts,
both started on purpose by a person and only to the user's own devices or to the family
members who joined that user's family circle with an invitation:

1. An SOS alert. A family member holds a button for 3 seconds to ask for help, and the other
   members of the family circle are notified with the person's location.
2. A "make it ring" alert, like the one in Find My. The owner (or an adult of the family) asks a
   lost or stolen phone to play an alarm so it can be found.

If the receiving iPhone is in silent mode or Do Not Disturb, a regular notification can be
missed, and the SOS or the ring fails exactly when it is needed. Critical Alerts would be used
only for these two cases. They would never be used for marketing, reminders or general
notifications.

Thank you very much for your help.

Luciano Julian Bick
lubick@me.com
```

## Si Apple pide más datos

Respuesta corta y sin inventar nada: son las dos situaciones de arriba (SOS y hacer sonar un teléfono
perdido), las dos las inicia una persona, y el aviso solo le llega a su propia familia o a sus propios
equipos. Si piden capturas, mandar la pantalla del SOS (botón rojo "SOS 3 s" de la barra de abajo) y la tarjeta
del mapa con el botón "Hacer sonar".

Cuando aprueben: permiso `com.apple.developer.usernotifications.critical-alerts` en `app.json`, sonido de
alarma propio en el aviso del servidor (`sound: { critical: 1, ... }`) y pedir el permiso de alertas críticas
al usuario (con una pantalla que explique para qué). Va todo en una sola build de iPhone.
