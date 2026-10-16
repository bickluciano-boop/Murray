# aplicar-mapa-app-tarjeta-panel.ps1 - El mapa dentro de la app, al estilo de "Buscar" de Apple: tarjeta mas chica y un boton por cada cosa que se puede hacer.
# Pedido de Luciano (16/10/2026): "en inicio esta muy grande el recuadro de cada dispositivo; yo tendria las opciones en cada dispositivo de poder localizar,
# hacer evidencia en el caso que permita, hacer sonar, y la mayor info, buscando una similitud con Buscar de Apple".
#  - Al abrir el mapa en la app se ve abajo la lista de Familia y equipos (nombre, como esta, direccion, distancia y el boton de sonar de cada uno).
#  - Al tocar uno, su tarjeta es mas baja: nombre, como esta (en vivo / sin conexion + hace cuanto + distancia), direccion y una fila de botones con icono:
#    Hacer sonar (o Detener sonido), Ubicar ahora, Evidencia (foto y audio, tambien en tus telefonos), Como llegar y Seguir en vivo. Abajo, bateria y datos.
#    Con una X se vuelve a la lista. Todo lo demas (paradas, avisos, evidencia recibida, cambiar rol, salir de la familia) sigue igual, mas abajo.
#  - En el celular o la tablet, al mantener el dedo sobre un boton se lee que hace (un toque corto lo aprieta como siempre).
# Solo cambia el mapa dentro de la app (?app=mapa) y suma el boton Pedir foto y audio para tus telefonos en el mapa del panel. El resto del panel no cambia.
# Requiere aplicar-mapa-app-compacto-panel.ps1 y los pasos de la consola. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-mapa.txt y
# src\panel-explanations.css. Respaldo .bak-tarjeta. Al final publica el panel solo.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
function Contar([string]$donde, [string]$que) {
    if ([string]::IsNullOrEmpty($que)) { return 0 }
    $n = 0; $i = 0
    while ($true) { $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal); if ($i -lt 0) { break }; $n = $n + 1; $i = $i + $que.Length }
    return $n
}
function Leer([string]$ruta) {
    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $texto = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    return @{ texto = $texto; bom = $bom; crlf = $texto.Contains("`r`n") }
}
function Ajustar([string]$t, [bool]$crlf) { $x = ($t -replace "`r`n", "`n"); if ($crlf) { $x = $x -replace "`n", "`r`n" }; return $x }
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }

if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\panel-mapa.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$mapaTexto = (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'function htmlTarjetaApp') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto 'html.app-mapa #og-mapa .ogm-tarjeta { left: 8px; right: 8px; bottom: 8px; max-height: 44%') -ne 1) { Mal "Falta aplicar antes aplicar-mapa-app-compacto-panel.ps1 (y los pasos de la consola)."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'mapa: modo app', 'const temaActual = () => (document.documentElement.getAttribute("data-theme") === "light" ? "claro" : "oscuro");
', 'const temaActual = () => (document.documentElement.getAttribute("data-theme") === "light" ? "claro" : "oscuro");

// Dentro de la app (?app=mapa) el mapa se ve como Buscar de Apple: abajo la lista de personas y equipos y, al elegir uno, su tarjeta compacta.
const EN_APP = document.documentElement.classList.contains("app-mapa");
'),
    @('src\panel-mapa.txt', 'mapa: iconos de la tarjeta', ('/** Bot' + [char]0x00f3 + 'n chico de sonido para la lista (como en Buscar de Apple). */'), ('const ICONO_UBICAR = ''<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="6.5" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="12" cy="12" r="1.9" fill="currentColor"/><path d="M12 2.5v3.5M12 18v3.5M2.5 12H6M18 12h3.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>'';
const ICONO_EVIDENCIA = ''<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 8.5h3l1.6-2.5h6.8L17 8.5h3a1 1 0 0 1 1 1V18a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9.5a1 1 0 0 1 1-1z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><circle cx="12" cy="13.6" r="3.3" fill="none" stroke="currentColor" stroke-width="2"/></svg>'';
const ICONO_LLEGAR = ''<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20.5 3.5 3.8 10.6l6.4 2.4 2.4 6.5z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>'';
const ICONO_VIVO = ''<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="2.3" fill="currentColor"/><path d="M7.6 7.6a6.2 6.2 0 0 0 0 8.8M16.4 7.6a6.2 6.2 0 0 1 0 8.8M4.6 4.6a10.4 10.4 0 0 0 0 14.8M19.4 4.6a10.4 10.4 0 0 1 0 14.8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>'';

/** Bot' + [char]0x00f3 + 'n chico de sonido para la lista (como en Buscar de Apple). */')),
    @('src\panel-mapa.txt', 'mapa: manija de la lista de abajo', ('    <aside class="ogm-lado">
      <p class="ogm-ceja">OJO GUARD MS ' + [char]0x00b7 + ' MAPA</p>'), ('    <aside class="ogm-lado">
      <button type="button" class="ogm-asa-lista" data-accion="cerrar-tarjeta" aria-label="Plegar o desplegar la lista"></button>
      <p class="ogm-ceja">OJO GUARD MS ' + [char]0x00b7 + ' MAPA</p>')),
    @('src\panel-mapa.txt', 'mapa: soltar el dedo despues de leer la ayuda', '  raiz.addEventListener("click", (evento) => {
    const boton = evento.target.closest("button, li[data-id]");', ('  raiz.addEventListener("click", (evento) => {
    // Si se mantuvo el dedo sobre un bot' + [char]0x00f3 + 'n para leer qu' + [char]0x00e9 + ' hace, al soltar no se aprieta.
    if (estado.mantuvo && evento.target.closest(".ogm-tile")) { estado.mantuvo = false; return; }
    const boton = evento.target.closest("button, li[data-id]");')),
    @('src\panel-mapa.txt', 'mapa: accion cerrar la tarjeta', '    if (accion === "cerrar-tarjeta") return plegar(!raiz.classList.contains("ogm-plegada"));', '    if (accion === "soltar") return soltar();
    if (accion === "cerrar-tarjeta") return plegar(!raiz.classList.contains("ogm-plegada"));'),
    @('src\panel-mapa.txt', 'mapa: ayuda tactil de la tarjeta', '  activarArrastre(raiz);
  $(''[data-ogm="archivo"]'', raiz).addEventListener("change", async (evento) => {', '  activarArrastre(raiz);
  activarAyudaTactil(raiz);
  $(''[data-ogm="archivo"]'', raiz).addEventListener("change", async (evento) => {'),
    @('src\panel-mapa.txt', 'mapa: soltar y ayuda tactil', ('/** Tarjeta de abajo en el celular: plegada muestra solo nombre, hora y direcci' + [char]0x00f3 + 'n. */'), ('/** Dentro de la app: cierra la tarjeta del equipo y vuelve a la lista de abajo. */
function soltar() {
  if (estado.vivo) void detenerVivo();
  estado.elegido = null;
  estado.recorrido = [];
  estado.mensajeOrden = null;
  estado.mensajeVivo = "";
  $("#og-mapa")?.classList.remove("ogm-plegada");
  dibujar();
  const lado = $("#og-mapa .ogm-lado");
  if (lado) lado.scrollTop = 0;
}

/** En el celular no existe "pasar por encima": al mantener el dedo sobre un bot' + [char]0x00f3 + 'n de la tarjeta se lee qu' + [char]0x00e9 + ' hace. Un toque corto lo aprieta como siempre. */
function activarAyudaTactil(raiz) {
  let espera = null, x = 0, y = 0;
  const cortar = () => clearTimeout(espera);
  raiz.addEventListener("touchstart", (evento) => {
    estado.mantuvo = false;
    cortar();
    const boton = evento.target.closest?.(".ogm-tile");
    if (!boton || !boton.dataset.ayuda) return;
    x = evento.touches[0].clientX;
    y = evento.touches[0].clientY;
    espera = setTimeout(() => {
      estado.mantuvo = true;
      const caja = $(''[data-ogm="msj"]'', raiz);
      if (caja) caja.textContent = boton.dataset.ayuda;
    }, 380);
  }, { passive: true });
  raiz.addEventListener("touchmove", (evento) => {
    const t = evento.touches[0];
    if (Math.hypot(t.clientX - x, t.clientY - y) > 12) cortar();
  }, { passive: true });
  raiz.addEventListener("touchend", cortar, { passive: true });
  raiz.addEventListener("touchcancel", cortar, { passive: true });
  raiz.addEventListener("contextmenu", (evento) => { if (evento.target.closest?.(".ogm-tile")) evento.preventDefault(); });
}

/** Tarjeta de abajo en el celular: plegada muestra solo nombre, hora y direcci' + [char]0x00f3 + 'n. */')),
    @('src\panel-mapa.txt', 'mapa: en la app no se elige uno solo', '  if (!estado.elegido || !estado.equipos.some((e) => e.id === estado.elegido)) {
    estado.elegido = (conUbicacion[0] || estado.equipos[0])?.id || null;
    forzarRecorrido = true;
  }', '  if (EN_APP) {
    // En la app arranca la lista con todos; la tarjeta aparece cuando se elige uno.
    if (estado.elegido && !estado.equipos.some((e) => e.id === estado.elegido)) estado.elegido = null;
  } else if (!estado.elegido || !estado.equipos.some((e) => e.id === estado.elegido)) {
    estado.elegido = (conUbicacion[0] || estado.equipos[0])?.id || null;
    forzarRecorrido = true;
  }'),
    @('src\panel-mapa.txt', 'mapa: margen del encuadre en la app', '  : { top: 80, right: 50, bottom: 260, left: 50 });', '  : EN_APP ? { top: 60, right: 40, bottom: Math.min(260, Math.round(window.innerHeight * 0.46)), left: 40 } : { top: 80, right: 50, bottom: 260, left: 50 });'),
    @('src\panel-mapa.txt', 'mapa: pedir evidencia a un telefono propio', '  return pedir("/api/remote/commands", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ deviceId: equipo.id, type: tipo }) });', ('  // Para un tel' + [char]0x00e9 + 'fono propio, "pedir evidencia" es la orden "capture" (la misma de Mis Equipos).
  return pedir("/api/remote/commands", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ deviceId: equipo.id, type: tipo === "capture-evidence" ? "capture" : tipo }) });')),
    @('src\panel-mapa.txt', 'mapa: los botones en baldosa no cambian de texto', '  const conTexto = !boton.classList.contains("ogm-sonar");', '  const conTexto = !boton.classList.contains("ogm-sonar") && !boton.classList.contains("ogm-tile");'),
    @('src\panel-mapa.txt', 'mapa: aviso de evidencia de un telefono propio', ('avisar(c.evidence ? "Llegaron la foto y el audio. Tambi' + [char]0x00e9 + 'n te los mandamos por mail." : "El tel' + [char]0x00e9 + 'fono sac' + [char]0x00f3 + ' la foto y el audio. Te llegan por mail.");'), ('avisar(c.evidence ? "Llegaron la foto y el audio. Tambi' + [char]0x00e9 + 'n te los mandamos por mail." : esPersona(equipo.id) ? "El tel' + [char]0x00e9 + 'fono sac' + [char]0x00f3 + ' la foto y el audio. Te llegan por mail." : "El tel' + [char]0x00e9 + 'fono sac' + [char]0x00f3 + ' la foto y el audio. Quedan en Evidencias y te llegan por mail.");')),
    @('src\panel-mapa.txt', 'mapa: evidencia tambien en los telefonos propios', '      ${elegido.tipo === "persona" && elegido.ordenable ? ''<button type="button" data-accion="capture-evidence">Pedir foto y audio</button>'' : ""}', '      ${puedeOrdenar(elegido) ? ''<button type="button" data-accion="capture-evidence">Pedir foto y audio</button>'' : ""}'),
    @('src\panel-mapa.txt', 'mapa: en la app la lista arranca desplegada', '  raiz.classList.remove("hidden");
  if (esCelular()) plegar(true);
  document.body.classList.add("og-mapa-abierto");', '  raiz.classList.remove("hidden");
  if (esCelular() && !EN_APP) plegar(true);
  document.body.classList.add("og-mapa-abierto");'),
    @('src\panel-mapa.txt', 'mapa: lista o tarjeta segun haya uno elegido', '  const equipos = estado.equipos;
  const elegido = equipoElegido();

  // Lista lateral (escritorio) / tira de abajo (celular)', '  const equipos = estado.equipos;
  const elegido = equipoElegido();
  // En la app: sin ninguno elegido se ve la lista de abajo; con uno elegido, su tarjeta.
  if (EN_APP) raiz.classList.toggle("ogm-sin-elegir", !elegido);

  // Lista lateral (escritorio) / tira de abajo (celular)'),
    @('src\panel-mapa.txt', 'mapa: tarjeta compacta en la app', '  tarjeta.classList.remove("hidden");
  tarjeta.innerHTML = `
    <button type="button" class="ogm-asa" data-accion="cerrar-tarjeta" aria-label="Plegar o desplegar"></button>
    <div class="ogm-cab">', '  tarjeta.classList.remove("hidden");
  tarjeta.innerHTML = EN_APP ? htmlTarjetaApp(elegido, st, km, lista, siguiendo, sonandoAhora) : `
    <button type="button" class="ogm-asa" data-accion="cerrar-tarjeta" aria-label="Plegar o desplegar"></button>
    <div class="ogm-cab">'),
    @('src\panel-mapa.txt', 'mapa: armado de la tarjeta de la app', 'function dibujar() {
  const raiz = $("#og-mapa");', ('/**
 * La tarjeta del equipo elegido dentro de la app, como la de Buscar de Apple: qui' + [char]0x00e9 + 'n es y c' + [char]0x00f3 + 'mo est' + [char]0x00e1 + ', d' + [char]0x00f3 + 'nde est' + [char]0x00e1 + ', un bot' + [char]0x00f3 + 'n por cada cosa que se
 * puede hacer (hacer sonar, ubicar, evidencia, c' + [char]0x00f3 + 'mo llegar, seguir en vivo) y los datos chicos abajo. Todo lo dem' + [char]0x00e1 + 's (paradas, avisos, evidencia,
 * administrar) sigue m' + [char]0x00e1 + 's abajo, sin cambios.
 */
function htmlTarjetaApp(e, st, km, paradasLista, siguiendo, sonandoAhora) {
  const lejos = distanciaA(e);
  const cuando = siguiendo && st.clase !== "vivo"
    ? `<b class="vivo">${esc(estado.vivo.texto || "Conectando con el tel' + [char]0x00e9 + 'fono' + [char]0x2026 + '")}</b>`
    : `${st.texto ? `<b class="${st.clase}">${st.clase === "vivo" ? "' + [char]0x25cf + ' " : ""}${esc(st.texto)}</b> ' + [char]0x00b7 + ' ` : ""}${esc(textoHace(e))}${lejos !== null ? ` ' + [char]0x00b7 + ' ${esc(textoDistancia(lejos))}` : ""}`;
  const baldosa = (accion, icono, texto, ayuda, clase = "") => `<button type="button" class="ogm-tile${clase ? ` ${clase}` : ""}" data-accion="${accion}" data-ayuda="${esc(ayuda)}" title="${esc(ayuda)}">${icono}<span>${esc(texto)}</span></button>`;
  const botones = [];
  if (puedeOrdenar(e)) {
    botones.push(sonandoAhora
      ? baldosa("stop-ring", ICONO_DETENER, "Detener sonido", "Corta la alarma del equipo.", "parar")
      : baldosa("alarm", ICONO_SONAR, "Hacer sonar", "Hace sonar el equipo para encontrarlo. Se corta solo al minuto."));
    botones.push(baldosa("locate", ICONO_UBICAR, "Ubicar ahora", "Pide al equipo que mande su ubicaci' + [char]0x00f3 + 'n de ahora."));
    botones.push(baldosa("capture-evidence", ICONO_EVIDENCIA, "Evidencia", e.tipo === "persona"
      ? "Pide una foto y un audio. La persona ve cada pedido en su tel' + [char]0x00e9 + 'fono."
      : "Saca una foto y graba unos segundos de audio, y te los manda. En iPhone, solo con Ojo Guard abierta."));
  }
  if (e.lat !== null) botones.push(baldosa("llegar", ICONO_LLEGAR, "C' + [char]0x00f3 + 'mo llegar", "Abre Google Maps con el camino hasta ac' + [char]0x00e1 + '."));
  if (admiteVivo(e)) {
    botones.push(siguiendo
      ? baldosa("vivo-parar", ICONO_VIVO, "Dejar de seguir", "Deja de pedir la ubicaci' + [char]0x00f3 + 'n cada pocos segundos.", "parar")
      : baldosa("vivo", ICONO_VIVO, "Seguir en vivo", "El tel' + [char]0x00e9 + 'fono manda su ubicaci' + [char]0x00f3 + 'n cada pocos segundos mientras tengas el mapa abierto."));
  }
  const datos = [
    e.bateria === null ? "" : `Bater' + [char]0x00ed + 'a ${Math.round(e.bateria)}%`,
    km >= 0.05 ? `Hoy ${km.toFixed(1).replace(".", ",")} km` : "",
    e.precision === null ? "" : `Margen de error ' + [char]0x00b1 + '${Math.round(e.precision)} m`,
  ].filter(Boolean).join(" ' + [char]0x00b7 + ' ");
  return `
    <button type="button" class="ogm-asa" data-accion="cerrar-tarjeta" aria-label="Plegar o desplegar"></button>
    <div class="ogm-cab ogm-cab-app">
      <button type="button" class="ogm-foto" data-accion="foto" title="Cambiar foto" ${e.tipo !== "telefono" || DEMO ? "disabled" : ""}>${avatarHtml(e, "grande")}</button>
      <div><p class="ogm-nom"><strong>${nombreHtml(e)}</strong>${etiquetaRol(e)}</p><small>${cuando}</small></div>
      <button type="button" class="ogm-cerrar" data-accion="soltar" aria-label="Cerrar y volver a la lista" title="Volver a la lista">' + [char]0x2715 + '</button>
    </div>
    <p class="ogm-direc">${esc(e.direccion || (e.lat !== null ? `${e.lat.toFixed(5)}, ${e.lng.toFixed(5)}` : "Todav' + [char]0x00ed + 'a sin ubicaci' + [char]0x00f3 + 'n"))}</p>
    ${botones.length ? `<div class="ogm-tiles">${botones.join("")}</div>` : ""}
    ${datos ? `<p class="ogm-meta">${esc(datos)}</p>` : ""}
    <p class="ogm-msj" data-ogm="msj">${esc(estado.mensajeOrden?.id === e.id ? estado.mensajeOrden.texto : "")}</p>
    ${estado.mensajeVivo ? `<p class="ogm-aviso-vivo">${esc(estado.mensajeVivo)}</p>` : ""}
    ${paradasLista.length ? `<ul class="ogm-paradas">${paradasLista.map((pa) => `<li><i></i>${esc(horaCorta(pa.desde))} a ${esc(horaCorta(pa.hasta))} ' + [char]0x00b7 + ' ${pa.minutos} min${pa.direccion ? ` ' + [char]0x00b7 + ' ${esc(pa.direccion)}` : ""}</li>`).join("")}</ul>` : ""}
    ${e.tipo === "persona" && e.ordenable ? `<p class="ogm-nota-menor">${esc(e.nombre)} ve en su tel' + [char]0x00e9 + 'fono cada pedido que hagas.</p>` : ""}
    ${e.tipo === "persona" ? htmlAvisos(e) : ""}
    ${estado.evidencia?.id === e.id ? htmlEvidencia(estado.evidencia, e) : ""}
    ${e.tipo === "persona" && e.gestionable ? ''<button type="button" class="ogm-administrar" data-accion="administrar">Cambiar rol o quitar</button>'' : ""}
    ${e.tipo === "persona" && e.rol === "titular" ? ''<button type="button" class="ogm-administrar" data-accion="salir">Salir de esta familia</button>'' : ""}`;
}

function dibujar() {
  const raiz = $("#og-mapa");')),
    @('src\panel-explanations.css', 'mapa en la app: lista de abajo y tarjeta con botones', '/* Botones en pastilla (como el dibujo de la consola). */', ('/* Dentro de la app (?app=mapa), al estilo de Buscar de Apple: el mapa arriba y abajo la lista de personas y equipos o, al elegir uno, su tarjeta con
   un bot' + [char]0x00f3 + 'n por cada cosa que se puede hacer (hacer sonar, ubicar, evidencia, c' + [char]0x00f3 + 'mo llegar, seguir en vivo). */
.ogm-asa-lista { display: none; }
@media (max-width: 899px) {
  html.app-mapa #og-mapa.ogm-sin-elegir .ogm-lado { display: flex; flex-direction: row; flex-wrap: wrap; align-items: baseline; align-content: flex-start; column-gap: 8px; position: absolute; left: 8px; right: 8px; bottom: 8px; z-index: 4; max-height: 40%; padding: 0 10px 8px; background: var(--ogm-panel); border: 1px solid var(--ogm-linea); border-radius: 18px; box-shadow: var(--ogm-sombra); overflow-y: auto; overscroll-behavior: contain; }
  html.app-mapa #og-mapa .ogm-lado .ogm-ceja, html.app-mapa #og-mapa .ogm-lado .ogm-invitar, html.app-mapa #og-mapa .ogm-lado .ogm-nota { display: none; }
  html.app-mapa #og-mapa .ogm-asa-lista { display: block; flex: none; position: relative; width: calc(100% + 20px); height: 22px; margin: 0 -10px; }
  html.app-mapa #og-mapa .ogm-asa-lista::before { content: ""; position: absolute; left: 50%; top: 8px; width: 44px; height: 5px; margin-left: -22px; border-radius: 3px; background: var(--ogm-suave); opacity: 0.55; }
  html.app-mapa #og-mapa .ogm-lado h2 { margin: 0; font-size: 1rem; letter-spacing: 0; }
  html.app-mapa #og-mapa .ogm-lado .ogm-sub { margin: 0; font-size: 0.74rem; }
  html.app-mapa #og-mapa .ogm-lado .ogm-asa-lista, html.app-mapa #og-mapa .ogm-lado .ogm-lista, html.app-mapa #og-mapa .ogm-lado [data-ogm="invitaciones"], html.app-mapa #og-mapa .ogm-lado [data-ogm="lugares"] { flex: 0 0 100%; }
  html.app-mapa #og-mapa .ogm-lista { gap: 0; }
  html.app-mapa #og-mapa .ogm-lista li { padding: 7px 4px; gap: 10px; border-radius: 12px; }
  html.app-mapa #og-mapa .ogm-lista li + li { border-top: 1px solid var(--ogm-linea); border-top-left-radius: 0; border-top-right-radius: 0; }
  html.app-mapa #og-mapa .ogm-lista li.ogm-grupo { border-top: 0; padding: 8px 4px 2px; }
  html.app-mapa #og-mapa .ogm-lista .ogm-av.chico { width: 40px; height: 40px; }
  html.app-mapa #og-mapa .ogm-lista strong { font-size: 0.95rem; }
  html.app-mapa #og-mapa .ogm-lista small { font-size: 0.76rem; }
  html.app-mapa #og-mapa.ogm-plegada.ogm-sin-elegir .ogm-lado > :not(.ogm-asa-lista):not(h2):not(.ogm-sub) { display: none; }

  html.app-mapa #og-mapa .ogm-tarjeta { max-height: 46%; }
  html.app-mapa #og-mapa .ogm-cab-app { align-items: center; gap: 10px; }
  html.app-mapa #og-mapa .ogm-cab-app .ogm-foto { flex: none; }
  html.app-mapa #og-mapa .ogm-cab-app .ogm-av.grande { width: 44px; height: 44px; }
  html.app-mapa #og-mapa .ogm-cab-app > div { flex: 1; min-width: 0; }
  html.app-mapa #og-mapa .ogm-nom { display: flex; align-items: center; gap: 6px; margin: 0; min-width: 0; color: var(--ogm-texto); }
  html.app-mapa #og-mapa .ogm-nom strong { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 1.04rem; line-height: 1.2; }
  html.app-mapa #og-mapa .ogm-nom .ogm-rol { margin: 0; }
  html.app-mapa #og-mapa .ogm-cab-app small { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 0.78rem; line-height: 1.35; }
  html.app-mapa #og-mapa .ogm-cerrar { flex: none; display: grid; place-items: center; width: 30px; height: 30px; border-radius: 50%; background: var(--ogm-oro-fondo); border: 1px solid var(--ogm-oro-borde); color: var(--ogm-suave); font-size: 0.85rem; }
  html.app-mapa #og-mapa .ogm-tiles { display: flex; gap: 6px; margin: 2px 0 6px; }
  html.app-mapa #og-mapa .ogm-tile { flex: 1 1 0; min-width: 0; display: flex; flex-direction: column; align-items: center; justify-content: flex-start; gap: 3px; padding: 8px 2px 6px; border-radius: 14px; background: var(--ogm-oro-fondo); border: 1px solid var(--ogm-oro-borde); color: var(--ogm-oro-vivo); -webkit-touch-callout: none; -webkit-user-select: none; user-select: none; }
  html.app-mapa #og-mapa .ogm-tile svg { width: 21px; height: 21px; flex: none; }
  html.app-mapa #og-mapa .ogm-tile span { color: var(--ogm-texto); font-size: 0.66rem; font-weight: 600; line-height: 1.15; text-align: center; }
  html.app-mapa #og-mapa .ogm-tile.parar { border-color: var(--ogm-vivo); color: var(--ogm-vivo); }
  html.app-mapa #og-mapa .ogm-tile:disabled { opacity: 0.5; cursor: wait; }
  html.app-mapa #og-mapa .ogm-meta { margin: 0 0 2px; font-size: 0.74rem; line-height: 1.4; color: var(--ogm-suave); }
  html.app-mapa #og-mapa .ogm-msj { margin: 6px 0 0; }
  html.app-mapa #og-mapa .ogm-nota-menor { margin: 4px 0 0; font-size: 0.72rem; }
  html.app-mapa #og-mapa .ogm-avisar { display: flex; align-items: center; justify-content: flex-start; gap: 8px; margin-top: 8px; text-align: left; font-size: 0.8rem; }
}

/* Botones en pastilla (como el dibujo de la consola). */'))
)
$descargas = @()

# --- Revisar que todas las anclas esten exactamente una vez, en todos los archivos ---
$archivos = @{}
foreach ($c in $cambios) {
    $ruta = Join-Path $raiz $c[0]
    if (-not (Test-Path $ruta)) { Mal ("No encuentro " + $c[0]); return }
    if (-not $archivos.ContainsKey($c[0])) { $archivos[$c[0]] = Leer $ruta }
}
$ok = $true
foreach ($c in $cambios) {
    $f = $archivos[$c[0]]
    $ancla = Ajustar $c[2] $f.crlf
    $cuantos = Contar $f.texto $ancla
    if ($cuantos -eq 1) { Ok ($c[0] + ": " + $c[1] + ": 1") } else { Mal ($c[0] + ": " + $c[1] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

# --- Descargar archivos nuevos y verificar que llegaron completos ---
foreach ($d in $descargas) {
    $tmp = (Join-Path $raiz $d[1]) + ".descarga"
    try { Invoke-WebRequest -UseBasicParsing $d[0] -OutFile $tmp } catch { }
    if (-not (Test-Path $tmp) -or (Sha $tmp) -ne $d[2]) {
        foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }
        Mal ("No se pudo descargar bien " + $d[1] + ". No toque nada."); return
    }
    Ok ("Descargado y verificado: " + $d[1])
}

# --- Respaldos ---
$tocados = @($archivos.Keys) + @($descargas | ForEach-Object { $_[1] })
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path ($ruta + ".bak-tarjeta")) { Mal ("Ya existe " + $t + ".bak-tarjeta. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-tarjeta"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-tarjeta): " + ($respaldados -join ", "))

# --- Aplicar ---
$esperado = @{}
foreach ($k in $archivos.Keys) { $esperado[$k] = $archivos[$k].texto.Length }
$nuevos = @{}
foreach ($k in $archivos.Keys) { $nuevos[$k] = $archivos[$k].texto }
foreach ($c in $cambios) {
    $f = $archivos[$c[0]]
    $ancla = Ajustar $c[2] $f.crlf; $reemplazo = Ajustar $c[3] $f.crlf
    $nuevos[$c[0]] = $nuevos[$c[0]].Replace($ancla, $reemplazo)
    $esperado[$c[0]] = $esperado[$c[0]] + ($reemplazo.Length - $ancla.Length)
}
foreach ($k in $archivos.Keys) { [System.IO.File]::WriteAllText((Join-Path $raiz $k), $nuevos[$k], (New-Object System.Text.UTF8Encoding($archivos[$k].bom))) }
foreach ($d in $descargas) { Move-Item -LiteralPath ((Join-Path $raiz $d[1]) + ".descarga") -Destination (Join-Path $raiz $d[1]) -Force }

# --- Verificar ---
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
foreach ($c in $cambios) {
    $v = (Leer (Join-Path $raiz $c[0]))
    Chk ($c[0] + ": " + $c[1] + " aplicado") ((Contar $v.texto (Ajustar $c[3] $v.crlf)) -eq 1)
}
foreach ($k in $archivos.Keys) {
    $largo = (Leer (Join-Path $raiz $k)).texto.Length
    Chk ($k + ": largo " + $largo + " (esperado " + $esperado[$k] + ")") ($largo -eq $esperado[$k])
}
foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-tarjeta") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: el panel quedo publicado. Abri el mapa en la app y toca un dispositivo."
Write-Host ""
