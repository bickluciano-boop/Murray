# Foto de la consola (Ojo Guard MS) — 20/10/2026

Cómo está hoy la consola y qué cambia con el paso **Configuración** (etapa 2 de "todo lo configurable, lo que no es de todos los días, va en
Configuración"). Armado leyendo los diez archivos de `src` que mandó Luciano (`panel-index.html`, `panel-app.txt`, `panel-mapa.txt` y los siete de
estilos), con las huellas del inventario del 20/10/2026 14:05. Copia de respaldo: `FOTO-PANEL-PARA-CLAUDE-2026-10-20_1405` (carpeta y .zip).
El detalle de las pantallas que no cambian está en `FOTO-CONSOLA-15-10-2026.md`; acá se anota lo que cambió desde entonces y lo de este paso.
Sirve de **lista para tildar**: ninguna utilidad se pierde ni se mueve sin dejar dicho dónde queda.

## 1. Cómo es la consola hoy (antes de este paso)

- **Cuatro pestañas** (barra flotante abajo; en pantalla ancha, desde 1280 px, van arriba al medio): **Mapa y Familia** · **Mis Equipos** ·
  **Evidencias** (con el contador) · **Cuenta**. "Inicio" y "Pulseras" ya no son pestañas: la última evidencia está en Evidencias, y las pulseras y los
  artículos viven dentro de Mis Equipos.
- **Barra de arriba:** logo "ojo guard MS", botón de tema (**Modo noche** / **Modo claro**, se recuerda en `localStorage` con la clave `ojo_ms_tema`),
  **Cerrar acceso** y el botón dorado **OG** (menú: Modo Cautela, Modo Guardián y "Abrir Tu protección").
- **Encabezado del panel:** cartel de emergencia (solo en modo de emergencia), "Centro de protección" con el correo, el estado de la cuenta
  ("N equipos vinculados") y **Actualizar**. Se redibuja solo cada 15 segundos.
- **Mapa y Familia** (`panel-mapa.txt`): mapa, lista de la familia y los equipos, tarjeta de cada persona (Seguir en vivo, Ubicar ahora, Hacer sonar,
  Pedir foto y audio, Cómo llegar), "Avisarme cuando llegue o salga", invitar (adulto, menor o amigo), lugares guardados, invitaciones sin usar,
  cambiar rol o quitar, salir de la familia y el cartel de SOS. Detalle en la foto del 15/10, punto 5.
- **Mis Equipos:** "Mis equipos" (con **Agregar dispositivo**; la tarjeta de cada equipo trae las siete acciones: Solicitar evidencia, Localizar ahora,
  Hacer sonar, Detener sonido, Detectar cerca, Activar y Desactivar Modo perdido; además ver el mapa, escanear, historial de ubicaciones, autorizar y
  quitar), "Pulseras vinculadas" (alarmas, salud y **Ver presentación**) y "Artículos y rastreadores".
- **Evidencias:** la lista (la más reciente arriba) con fotos, audio, "Abrir ubicación" y reconocimiento facial.
- **Cuenta:** seis tarjetas en dos columnas (Correo del titular, Protección de ingreso, Código de verificación, Avisos de seguridad, Pregunta de
  emergencia, Reconocimiento facial) y **Personas autorizadas**.
- **Ventanas encima:** video de la presentación, mapa grande, visor de foto y buscador de vista de calle y satelital.

## 2. Qué cambia con este paso

La pestaña **Cuenta** pasa a **Configuración**: una lista de categorías, como los Ajustes de un teléfono. Cada categoría abre su pantalla (con la flecha
"← Configuración" y también con el botón Atrás del teléfono). **No se saca nada:** las tarjetas de antes son las mismas (mismos ids, botones y campos) y solo
cambian de lugar. En pantalla ancha las tarjetas siguen en dos columnas.

| Categoría | Qué trae | De dónde viene |
|---|---|---|
| Cuenta y seguridad | Correo del titular, Protección de ingreso, Código de verificación, Pregunta de emergencia y Personas autorizadas | Cuenta (mismas tarjetas) |
| Avisos | Avisos de seguridad: por correo, por SMS, "si el teléfono deja de responder" y Guardar | Cuenta (misma tarjeta) |
| Tu protección | Enlace a `/guardian#configuracion` (referentes, Modo Cautela y Modo Guardián: tiempos y avisos) | Página Tu protección; el botón **OG** de arriba sigue para lo de todos los días |
| Familia y lugares | Atajos: "Invitar a la familia" (abre el mapa con el cuadro de invitación) y "Abrir Mapa y Familia" (lugares, avisos de llegada y salida, roles) | Mapa (no se mueve: se llega desde acá) |
| Equipos y pulseras | Atajos: "Agregar un equipo" (Mis Equipos con el cuadro abierto), "Ir a Mis Equipos" (quitar o autorizar) y "Ver presentación" de las pulseras | Mis Equipos (no se mueve) |
| Reconocimiento facial | Búsquedas disponibles y compra (5 por USD 1, 10 por USD 1,50) | Cuenta (misma tarjeta) |
| Apariencia y accesibilidad | Modo claro o noche; tamaño del texto (Normal, Grande, Muy grande), alto contraste y botones más grandes | Tema: la barra de arriba. Accesibilidad: nuevo |

- **Tema:** el botón de la barra de arriba solo se ve en la pantalla de acceso (sin sesión); adentro del panel está en Apariencia. Es el mismo botón y la
  misma clave (`ojo_ms_tema`).
- **Accesibilidad:** misma clave que Tu protección (`ogAcc`, mismo sitio): lo que se elige en una se ve en la otra. Se aplica antes de dibujar la página
  (un `<script>` corto en el `<head>`).
- **Modo de emergencia:** Configuración queda oculta, como lo estaba Cuenta (y no se abre ni escribiendo `#config…` en la dirección).
- **Direcciones:** `#config` (la lista), `#config-cuenta`, `#config-avisos`, `#config-facial`, `#config-familia`, `#config-equipos` y `#config-apariencia`.
  Recargar la página vuelve a la misma pantalla; al tocar la pestaña siempre se ve la lista.
- **Versiones:** `app-v9.js?v=7` pasa a `?v=8` y `theme-gold-v2.css` a `?v=cfg1`, para que el navegador no use una copia vieja.
- **Archivos que toca** (`aplicar-consola-configuracion-panel.ps1`, respaldo `.bak-cfgconsola`): `src\panel-index.html` (pantalla nueva, pestaña y las dos
  versiones), `src\panel-app.txt` (código nuevo al final; lo anterior no se cambia) y `src\panel-history.css` (estilos al final, marcados
  `configuracion-v1`). Los comprueba con una huella SHA-256 antes de tocarlos y después de escribirlos. Mapa, Mis Equipos, Evidencias y los otros
  cinco archivos de estilos no se tocan.

## 3. Lista para tildar (después de instalar)

- [ ] Abrir la consola con **Ctrl+F5** y entrar. Abajo dice **Configuración** (con un engranaje) donde antes decía Cuenta, y entra completo en el celular.
- [ ] Tocar **Configuración**: aparece la lista de siete categorías.
- [ ] **Cuenta y seguridad:** se ven el correo del titular, "Protección de ingreso", "Código de verificación" (con su botón), la pregunta de emergencia
  (guardar una de prueba) y Personas autorizadas.
- [ ] **Avisos:** tildar "Por correo", "Por SMS" y "si el teléfono deja de responder", y **Guardar** (dice que se guardó).
- [ ] **Tu protección:** abre la página de Tu protección, en su Configuración.
- [ ] **Familia y lugares:** "Invitar a la familia" abre el mapa con el cuadro de invitación; "Abrir Mapa y Familia" abre el mapa.
- [ ] **Equipos y pulseras:** "Agregar un equipo" abre Mis Equipos con el cuadro de nuevo equipo; "Ir a Mis Equipos"; "Ver presentación" abre el video.
- [ ] **Reconocimiento facial:** se ven las búsquedas y los dos botones de compra (no hace falta comprar).
- [ ] **Apariencia y accesibilidad:** el botón cambia entre modo claro y modo noche; Grande y Muy grande agrandan el texto; Alto contraste y Botones más
  grandes se notan; al recargar siguen puestos; y en **Tu protección** se ve lo mismo.
- [ ] El botón **Atrás** del teléfono vuelve de una categoría a la lista; tocar la pestaña otra vez también.
- [ ] Cerrando sesión, en la **pantalla de acceso** el botón de modo noche sigue arriba.
- [ ] **Mapa y Familia, Mis Equipos y Evidencias** se ven y andan igual que antes (probar un "Hacer sonar" y un "Ver mapa").
- [ ] Con letra **Muy grande** el nombre de la pestaña puede verse cortado ("Configura…"); les pasa igual a "Mapa y Familia" y "Evidencias".

## 4. Queda para más adelante

- **Etapa 2b (opcional):** una lista propia de **Lugares** con altas y bajas dentro de Configuración (hoy se manejan en el mapa y se llega con un atajo), y
  sacar del mapa lo que sobre.
- **Etapa 3:** la **app** del teléfono: sumar "Tu protección" y "Accesibilidad" a su Configuración y repasar qué configurable sigue suelto en el Inicio.
- **Seguridad:** la clave de Google Maps del navegador figura en el código de la página (es lo normal para una clave de navegador). Confirmar en
  Google Cloud que está restringida por sitio web (referente HTTP) y por API.
