# Consola del panel (Ojo Guard MS): herramientas para armar y probar los cambios

La consola es el sitio que sirve el Worker del panel (`src/panel-index.html`, `src/panel-app.txt`, `src/panel-mapa.txt` y los archivos de estilos).
Los archivos de Luciano no se guardan acá (`foto-panel.ps1` los vuelve a juntar); acá van las herramientas. Cómo es la consola hoy y la lista para
tildar: `../FOTO-CONSOLA-20-10-2026.md`.

- `hacer_consola.py`: con una carpeta `orig/` que tiene los archivos de Luciano, arma `nuevo/` con el paso **Configuración** (la pestaña Cuenta pasa a
  Configuración, con categorías). Cambia solo lo necesario y comprueba que todo `id` que había sigue y que las tarjetas de antes pasan intactas.
- `generar_consola.py`: arma `../aplicar-consola-configuracion-panel.ps1` (instalador de tres archivos). Usa el motor de los instaladores anteriores
  de la consola y suma dos controles: la huella SHA-256 de los originales antes de tocar nada y la del resultado después de escribir (si no coincide,
  restaura desde los respaldos). `CONSOLA_DIR` es la carpeta que tiene `orig/` y `nuevo/`.
- `huellas-20-10-2026.txt`: huellas SHA-256 de los diez archivos de la foto (inventario de Luciano, con saltos de línea normalizados).
- `servir.js`: servidor estático con los nombres que usa la página (`node servir.js nuevo 8802`); el modo demostración es `/?demo=1`.
- `e2e-consola.js` y `e2e-emergencia.js`: recorridos en navegador real (Playwright). El primero prueba Configuración completa (categorías, Atrás,
  tema, accesibilidad, atajos y que las otras pestañas sigan igual); el segundo, el modo de emergencia y la recarga en una pantalla, con la sesión simulada.

Para repetirlo: poner los diez archivos en `orig/` (con sus nombres de `src`), `python3 hacer_consola.py`, `node servir.js nuevo 8802` y
`node e2e-consola.js 8802`; después `CONSOLA_DIR=$PWD python3 <ruta>/generar_consola.py`. Además se corrió el instalador de verdad con PowerShell 7 en
Linux contra copias de los archivos (saltos de línea LF y CRLF, con y sin BOM; archivo distinto, falta de un archivo, respaldo ya existente y falla de
la verificación final con restauración).
