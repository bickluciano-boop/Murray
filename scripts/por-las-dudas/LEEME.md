# Por las dudas: código y pruebas (primera parte, NÚCLEO · EN VALIDACIÓN)

- `pld.ts`: el código que va dentro de `src/index.ts` del panel (junto a `fetchCorreo`). Lo instala
  `scripts/aplicar-por-las-dudas-panel.ps1` (el instalador lleva esta misma fuente con los acentos escritos como `\uXXXX`).
- `tablas.sql`: las tablas nuevas (`pld_config`, `pld_referentes`, `pld_log`, `pld_checkins`, `pld_episodios`).
- `stubs.ts` y `pruebas.ts`: pruebas contra una base SQLite en memoria (Node 22 con `node:sqlite`) que imitan D1 y los
  ayudantes del servidor (`now`, `hash`, `json`, mails...). Para correrlas, con `tablas.sql` en la carpeta actual:
  1. convertir los acentos: `python3 -c "import re;s=open('pld.ts',encoding='utf-8').read();open('pld_ascii.ts','w').write(re.sub(r'[^\x00-\x7f]',lambda m:'\\\\u%04x'%ord(m.group(0)),s))"`
  2. `cat stubs.ts pld_ascii.ts pruebas.ts > harness.mts` y cambiar `new URL("./tablas.sql", import.meta.url)` por una ruta
     absoluta, y `node --no-warnings harness.mts` (300 pruebas, incluidas las del aviso automático del cron, el SOS, Tu protección plegable y Pausar o apagar).
- `servidor.ts` y `e2e.js`: un servidor local con las mismas funciones y un recorrido en navegador real (Playwright):
  la persona agrega un referente, el referente acepta y aprieta "No lo encuentro", la persona responde "Estoy bien".
- `e2e-enlace.js`: recorrido en navegador del enlace personal del referente ("Copiar enlace", "Mandar por WhatsApp", mail que falla,
  "Reenviar"); necesita el interruptor `POST /__correo-falla` de `servidor.ts`.
- `e2e-pausa.js`: recorrido en navegador de "Pausar o apagar" (pausar 12 horas, otro tiempo, quitar pausa, apagar con pregunta, encender).
- `e2e-menores.js`: recorrido en navegador del titular que arma la protección de un menor (selector, cartel, referentes y pausa de Tomi) del hermano mayor (adulto de la familia) que también lo arma, y del menor que solo puede mirar (campos bloqueados, 403 por la API). `servidor.ts` trae la familia de ejemplo.
- `e2e-guardian.js`: recorrido en navegador del Modo Guardián: tarjeta en Tu protección (sin referentes / con minutos calculados), empezar el camino, la página `/camino` (reloj, Llegué, +10 min), el vencimiento con el cron y el aviso a los referentes. `servidor.ts` trae los endpoints de prueba `/__gd-cron` y `/__gd-minutos`.
- `generar_pld.py`: arma el instalador `.ps1` a partir de `pld.ts` (hay que pasarlo antes por la conversión de acentos).

Especificación: `../POR-LAS-DUDAS-ESPECIFICACION.md`. 

Segunda parte (aviso automático, `pldCron`): el parche `../aplicar-por-las-dudas-cron-panel.ps1` reemplaza todo el bloque de Por las dudas dentro de
`src/index.ts` (comprueba antes con una huella SHA-256 que es el código que dejaron los parches anteriores), engancha `pldCron` en `scheduled` y crea
`pld_episodios`. Falta: pantalla en la app, tutor que administra a un menor, reporte adaptativo y detección de arrebato.
