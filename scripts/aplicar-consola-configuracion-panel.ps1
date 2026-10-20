# aplicar-consola-configuracion-panel.ps1 - Consola (Ojo Guard MS): la pestana "Cuenta" pasa a ser "Configuracion", ordenada por categorias (como los Ajustes de un celular).
# Luciano (20/10/2026): "todo lo configurable (lo que no es de todos los dias) va en Configuracion, mas limpio, como los Ajustes de un telefono". Etapa 2: la consola.
# Que cambia:
#  - La pestana de abajo "Cuenta" se llama "Configuracion" (con un engranaje). Al tocarla se ve una lista: Cuenta y seguridad, Avisos, Tu proteccion, Familia y lugares,
#    Equipos y pulseras, Reconocimiento facial, Apariencia y accesibilidad. Cada una abre su pantalla, con una flecha para volver (el boton Atras del telefono tambien vuelve).
#  - Las tarjetas de antes (correo, proteccion de ingreso, codigo de verificacion, avisos, pregunta de emergencia, reconocimiento facial y personas autorizadas) son las mismas,
#    con los mismos botones: solo cambian de lugar.
#  - "Tu proteccion" abre la pagina de Configuracion de Tu proteccion (el boton OG de arriba sigue para lo de todos los dias: Modo Cautela y Modo Guardian).
#  - "Familia y lugares" y "Equipos y pulseras" son atajos a donde ya esta cada cosa (el mapa, Mis Equipos, invitar, agregar un equipo, la presentacion de las pulseras). No se duplica nada.
#  - "Apariencia y accesibilidad": el boton de modo claro / noche (adentro del panel ya no esta arriba; en la pantalla de acceso sigue donde estaba) y el tamano del texto,
#    el alto contraste y los botones mas grandes (se recuerdan en este dispositivo y valen tambien en Tu proteccion).
#  - En el modo de emergencia, Configuracion sigue oculta, como antes lo estaba Cuenta.
# Mapa y Familia, Mis Equipos y Evidencias no se tocan. No se saca nada: todo lo que habia sigue (mismos botones y mismos campos).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-index.html y src\panel-app.txt, y solo si son los de la foto del 20/10/2026
# (se comprueba con una huella SHA-256; si no, no toca nada). Los estilos nuevos van adentro de la pagina, asi llegan siempre juntos. Respaldo .bak-cfgconsola. Al final publica el panel solo.
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
foreach ($f in @("src\panel-index.html", "src\panel-app.txt")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'id="cfg-lista"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
function ShaTexto([string]$t) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($t -replace "`r`n", "`n"))))).Replace("-", "").ToLower()
}
$originales = @{
    'src\panel-index.html' = 'b2d6abd6595e033dbc1bd57b4f28c7564633f850753009bc7f40375d14c51c8b'
    'src\panel-app.txt' = '3e290574f46ccec0249219ed53e966e8ca2148bdf4ad335715f4af3bc693416d'
}
$finales = @{
    'src\panel-index.html' = '2bf2d1bc38ad184c3dfb097f9f40998c6480333426816ccce94f3b90470f8f37'
    'src\panel-app.txt' = 'a905fe8a37569102e6ad15516ba0c38230d9d2bf94fef559582d5b5752004607'
}
foreach ($k in $originales.Keys) {
    $huella = ShaTexto (Leer (Join-Path $raiz $k)).texto
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el de la foto del 20/10/2026 (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "Los dos archivos son los de la foto del 20/10/2026"
$cambios = @(
    @('src\panel-index.html', 'acceso: se aplica la accesibilidad guardada antes de dibujar', '    <style>button.location-guide{display:flex', ('    <script>
      /* Accesibilidad compartida con Tu protecci' + [char]0x00f3 + 'n (misma clave "ogAcc" en este mismo sitio): tama' + [char]0x00f1 + 'o del texto, alto contraste y botones m' + [char]0x00e1 + 's grandes. */
      (function () {
        try {
          var q = JSON.parse(localStorage.getItem("ogAcc") || "{}") || {}, r = document.documentElement;
          if (q.t === "g") r.style.fontSize = "118%";
          if (q.t === "x") r.style.fontSize = "136%";
          if (q.c) r.classList.add("ac");
          if (q.b) r.classList.add("ab");
        } catch (e) { /* sin almacenamiento: todo queda como siempre */ }
      })();
    </script>
    <style>button.location-guide{display:flex')),
    @('src\panel-index.html', 'pestana Cuenta pasa a Configuracion', ('<button class="bottom-tab" data-view="account" type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x25cb + '</span><span>Cuenta</span></button>'), ('<button class="bottom-tab" data-view="account" type="button"><span class="tab-icon" aria-hidden="true">&#9881;&#65038;</span><span>Configuraci' + [char]0x00f3 + 'n</span></button>')),
    @('src\panel-index.html', 'version nueva del programa', '<script type="module" src="/app-v9.js?v=7"></script>', '<script type="module" src="/app-v9.js?v=8"></script>'),
    @('src\panel-index.html', 'estilos de Configuracion (adentro de la pagina)', '  </head>', ('    <style id="configuracion-v1">
      /* configuracion-v1: Configuraci' + [char]0x00f3 + 'n de la consola (lista de categor' + [char]0x00ed + 'as y una pantalla por categor' + [char]0x00ed + 'a). Usa los mismos colores de siempre (variables), as' + [char]0x00ed + ' sirve en modo claro y modo noche. */
      .cfg-lista { padding: 0; overflow: hidden; }
      .cfg-item {
        display: flex; align-items: center; justify-content: space-between; gap: 14px; width: 100%;
        padding: 18px 20px; text-align: left; background: transparent; color: inherit; border: 0; border-top: 1px solid var(--line);
        border-radius: 0; font-weight: inherit; text-decoration: none; cursor: pointer; transform: none;
      }
      .cfg-item:first-child { border-top: 0; }
      .cfg-item:hover, .cfg-item:focus-visible { background: var(--panel-2); filter: none; transform: none; }
      .cfg-item::after { content: "\203A"; flex: none; color: var(--muted); font-size: 1.7rem; line-height: 1; }
      .cfg-item strong { display: block; font-size: 1.04rem; color: inherit; }
      .cfg-item small { display: block; margin-top: 4px; color: var(--muted); font-weight: 400; line-height: 1.4; }
      .cfg-volver {
        display: inline-flex; align-items: center; margin: 0 0 18px; padding: 8px 15px; border: 1px solid var(--line); border-radius: 999px;
        color: var(--gold-text, var(--lime)); font-weight: 700; font-size: 0.9rem; text-decoration: none;
      }
      .cfg-volver:hover, .cfg-volver:focus-visible { background: var(--panel-2); }
      #account > #cfg-lista { grid-column: 1 / -1; max-width: 760px; }
      #account > .cfg-panel { grid-column: 1 / -1; }
      .cfg-panel { display: grid; gap: 18px; align-items: start; }
      .cfg-panel > .section-head { margin-bottom: 0; }
      .cfg-panel > .account-card { margin: 0; padding: clamp(20px, 3vw, 30px); }
      .cfg-panel .dashboard-section { margin: 18px 0 0; }
      .cfg-panel .account-card button { justify-self: start; }
      @media (min-width: 900px) {
        .cfg-panel { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .cfg-panel > .cfg-volver { justify-self: start; }
        .cfg-panel > .cfg-volver, .cfg-panel > .section-head, .cfg-panel > .dashboard-section { grid-column: 1 / -1; }
      }
      /* La pesta' + [char]0x00f1 + 'a "Configuraci' + [char]0x00f3 + 'n" es m' + [char]0x00e1 + 's larga que "Cuenta": en el celular se achica un poco el espacio entre letras para que se lea entera. */
      @media (max-width: 520px) {
        .bottom-tab > span:not(.tab-icon) { letter-spacing: -0.015em; }
      }
      .cfg-rotulo { margin-top: 6px; font-size: 0.82rem; color: var(--muted); }
      .cfg-chips { display: flex; flex-wrap: wrap; gap: 8px; }
      .cfg-chips button { padding: 10px 16px; font-size: 0.9rem; }
      :root .cfg-chips button[aria-pressed="true"] { background: var(--lime); color: var(--ink); border-color: var(--lime); }
      /* La barra de arriba se queda con el bot' + [char]0x00f3 + 'n de tema solo en la pantalla de acceso; ya adentro, est' + [char]0x00e1 + ' en Configuraci' + [char]0x00f3 + 'n. */
      .shell:has(#dashboard:not(.hidden)) #theme-toggle { display: none; }

      /* Accesibilidad (misma clave y mismas ideas que en Tu protecci' + [char]0x00f3 + 'n) */
      :root.ab button, :root.ab .map-button, :root.ab .app-link, :root.ab .cfg-volver, :root.ab .bottom-tab { min-height: 48px; }
      :root.ab button, :root.ab .map-button, :root.ab .app-link { padding-top: 16px; padding-bottom: 16px; font-size: 1.05rem; }
      :root.ab .bottom-tab { padding-top: 12px; padding-bottom: 12px; }
      :root.ab .cfg-item { padding-top: 24px; padding-bottom: 24px; }
      :root.ab input[type="checkbox"] { width: 22px; height: 22px; }
      :root.ac { --muted: #e4e6df; --line: #8b9189; --ac-texto: #ffffff; }
      :root.ac[data-theme="light"] { --muted: #262723; --line: #6c6b61; --ac-texto: #000000; }
      :root.ac small, :root.ac p, :root.ac .section-copy, :root.ac .status-grid span, :root.ac .actions small, :root.ac label, :root.ac .cfg-rotulo,
      :root.ac .account-card span, :root.ac .account-card small, :root.ac .device-meta, :root.ac .command-status, :root.ac .bottom-tab { color: var(--ac-texto) !important; }
      :root.ac .card, :root.ac .cfg-item, :root.ac .cfg-volver, :root.ac input, :root.ac .ghost, :root.ac .bottom-tabs { border-color: var(--line) !important; }

      /* El bot' + [char]0x00f3 + 'n OG ten' + [char]0x00ed + 'a estilo solo en el celular (las reglas quedaron adentro de "max-width: 520px"): ac' + [char]0x00e1 + ' se repiten para pantallas m' + [char]0x00e1 + 's anchas. */
      @media (min-width: 521px) {
        /* OG: entrada a Tu proteccion (Modo Cautela y Modo Guardian). Solo se ve con la sesion abierta (cuando "Cerrar acceso" se muestra). */
        .og-guardian { display: none; position: relative; order: -1; margin-right: auto; }
        #logout:not(.hidden) + .og-guardian { display: block; }
        header.topbar .topbar-actions details.og-guardian > summary.ghost { list-style: none; cursor: pointer; padding: 10px 20px !important; font-size: 0.9rem !important; font-weight: 800 !important; letter-spacing: 0.12em; border-radius: 999px !important; border: 2px solid #b8932f !important; color: #1b1505 !important; background: #d9b24c !important; box-shadow: 0 3px 10px rgba(184, 147, 47, 0.45); user-select: none; white-space: nowrap; }
        .og-guardian summary::-webkit-details-marker { display: none; }
        header.topbar .topbar-actions details.og-guardian[open] > summary.ghost { background: #1b1505 !important; color: #f0c75a !important; border-color: #d9b24c !important; }
        .og-menu { position: absolute; right: 0; top: calc(100% + 8px); z-index: 80; width: min(380px, calc(100vw - 32px)); display: grid; gap: 6px; padding: 10px; border-radius: 16px; background: #14151a; color: #f3f1ea; border: 1px solid #4a3f1f; box-shadow: 0 14px 40px rgba(0, 0, 0, 0.45); }
        .og-menu a { display: grid; gap: 2px; color: inherit; text-decoration: none; padding: 8px 10px; border-radius: 12px; }
        .og-menu a:hover, .og-menu a:focus-visible { background: #211d12; }
        .og-menu strong { color: #f0c75a; font-size: 0.9rem; }
        .og-menu span { color: #a29e92; font-size: 0.78rem; line-height: 1.35; }
        .og-menu .og-ir { color: #f0c75a; font-weight: 700; font-size: 0.82rem; text-align: right; }
      }
      /* En pantalla ancha (desde 1280 px) la franja de arriba recorta lo que se sale de ella; con el men' + [char]0x00fa + ' de OG abierto se la deja de recortar para que se vea entero. */
      @media (min-width: 1280px) {
        .shell:has(#dashboard:not(.hidden)) > .topbar:has(.og-guardian[open]) { clip-path: none !important; box-shadow: none !important; }
      }
    </style>
  </head>')),
    @('src\panel-index.html', 'pantalla de Configuracion (las tarjetas de antes pasan intactas)', ('        <section id="account" class="dashboard-section" data-views="account"><div class="section-head"><div><p class="eyebrow">TU CUENTA</p><h2>Acceso y seguridad</h2><p class="section-copy">Tu correo identifica la cuenta y mantiene la misma informaci' + [char]0x00f3 + 'n en todos tus dispositivos.</p></div></div><article class="account-card card"><span>Correo del titular</span><strong id="account-email-copy">Correo no disponible</strong><small>Las acciones importantes generan un aviso de seguridad por correo.</small></article><article class="account-card card"><span>Protecci' + [char]0x00f3 + 'n de ingreso</span><strong id="account-security-state">Pendiente de configurar</strong><small id="account-security-copy">Cre' + [char]0x00e1 + ' el acceso seguro desde el tel' + [char]0x00e9 + 'fono principal.</small></article>
        <article class="account-card card" id="totp-card">
          <span>C' + [char]0x00f3 + 'digo de verificaci' + [char]0x00f3 + 'n</span>
          <strong id="totp-state">No configurado</strong>
          <small>Un c' + [char]0x00f3 + 'digo de 6 d' + [char]0x00ed + 'gitos que cambia cada 30 segundos, generado en una app como Google Authenticator o Authy. Sirve para entrar aunque no tengas Face ID a mano.</small>
          <button id="totp-setup-button" class="ghost" type="button">Configurar c' + [char]0x00f3 + 'digo de verificaci' + [char]0x00f3 + 'n</button>
          <button id="totp-share-button" class="ghost hidden" type="button">Agregar en otro dispositivo (respaldo)</button>
          <div id="totp-setup-panel" class="hidden">
            <small>Carg' + [char]0x00e1 + ' este c' + [char]0x00f3 + 'digo en tu app de autenticaci' + [char]0x00f3 + 'n (opci' + [char]0x00f3 + 'n "ingresar manualmente" o "clave secreta"):</small>
            <p><strong id="totp-secret-display"></strong></p>
            <a id="totp-otpauth-link" class="app-link" href="#">Abrir directo en la app de autenticaci' + [char]0x00f3 + 'n</a>
            <div id="totp-confirm-fields">
              <label>C' + [char]0x00f3 + 'digo de 6 n' + [char]0x00fa + 'meros<input id="totp-confirm-code" inputmode="numeric" maxlength="6" pattern="[0-9]{6}" autocomplete="one-time-code" /></label>
              <button id="totp-confirm-button" type="button">Confirmar</button>
            </div>
            <p id="totp-setup-message" class="message"></p>
          </div>
        </article>
        <article class="account-card card" id="notification-prefs-card">
          <span>Avisos de seguridad</span>
          <strong>' + [char]0x00bf + 'C' + [char]0x00f3 + 'mo quer' + [char]0x00e9 + 's recibirlos?</strong>
          <small>Eleg' + [char]0x00ed + ' correo, SMS o los dos. El SMS es m' + [char]0x00e1 + 's r' + [char]0x00e1 + 'pido pero no incluye fotos ni audio.</small>
          <label><input id="notify-email" type="checkbox" /> Por correo</label>
          <label><input id="notify-sms" type="checkbox" /> Por SMS</label>
          <label><input id="notify-silence" type="checkbox" /> Avisarme tambi' + [char]0x00e9 + 'n si el tel' + [char]0x00e9 + 'fono deja de responder sin motivo aparente</label>
          <small>Si alguien intenta entrar y enseguida el tel' + [char]0x00e9 + 'fono se apaga, el aviso se manda siempre. Esta opci' + [char]0x00f3 + 'n agrega el caso en que se apaga sin que haya pasado nada ' + [char]0x2014 + ' ' + [char]0x00fa + 'til, pero puede avisarte si lo apag' + [char]0x00e1 + 's vos de noche.</small>
          <label id="notify-phone-field" class="hidden">N' + [char]0x00fa + 'mero de celular (con c' + [char]0x00f3 + 'digo de pa' + [char]0x00ed + 's, ej: +54 9 11 2345-6789)<input id="notify-phone" type="tel" inputmode="tel" placeholder="+54 9 11 2345-6789" /></label>
          <button id="notify-prefs-save" type="button">Guardar</button>
          <p id="notify-prefs-message" class="message"></p>
        </article>
        <article class="account-card card" id="qa-card">
          <span>Pregunta de emergencia</span>
          <strong id="qa-status">Cargando&#8230;</strong>
          <small>Si perd&#233;s tus tel&#233;fonos y no pod&#233;s abrir tu correo, entr&#225;s desde cualquier celular con esta pregunta y su respuesta. La eleg&#237;s vos. Sirve una sola vez, y despu&#233;s cre&#225;s otra.</small>
          <form id="qa-set-form">
            <label>Tu pregunta<input id="qa-set-question" type="text" maxlength="120" placeholder="Ej.: &#191;Mi primera mascota?" autocomplete="off" required /></label>
            <label>Tu respuesta (letras y n&#250;meros, m&#237;nimo 6)<input id="qa-set-answer" type="text" maxlength="60" placeholder="Ej.: pelusa1952" autocomplete="off" autocapitalize="none" spellcheck="false" required /></label>
            <small>Eleg&#237; una respuesta que no se pueda averiguar mirando tus redes ni pregunt&#225;ndole a alguien. Tampoco escribas la respuesta en la pregunta: cualquiera que sepa tu correo puede ver la pregunta.</small>
            <button id="qa-save">Guardar pregunta y respuesta</button>
          </form>
          <p id="qa-set-message" class="message"></p>
        </article>
        <article class="account-card card" id="face-search-card">
          <span>Reconocimiento facial</span>
          <strong id="face-search-balance">0 b' + [char]0x00fa + 'squedas disponibles</strong>
          <small>Compar' + [char]0x00e1 + ' la cara de una evidencia contra tu propia galer' + [char]0x00ed + 'a del tel' + [char]0x00e9 + 'fono. Funci' + [char]0x00f3 + 'n paga, se descuenta 1 b' + [char]0x00fa + 'squeda por cada comparaci' + [char]0x00f3 + 'n. <span class="status-tag status-tag-core">' + [char]0x25cf + ' N' + [char]0x00da + 'CLEO ' + [char]0x00b7 + ' EN VALIDACI' + [char]0x00d3 + 'N</span></small>
          <button id="face-search-buy-5" type="button" class="ghost">5 b' + [char]0x00fa + 'squedas ' + [char]0x00b7 + ' USD 1</button>
          <button id="face-search-buy-10" type="button" class="ghost">10 b' + [char]0x00fa + 'squedas ' + [char]0x00b7 + ' USD 1,50</button>
          <small>El precio est' + [char]0x00e1 + ' en d' + [char]0x00f3 + 'lares y se cobra en pesos al cambio del d' + [char]0x00ed + 'a.</small>
          <p id="face-search-message" class="message"></p>
        </article></section>
        <section id="people" class="dashboard-section" data-views="account"><div class="section-head"><div><p class="eyebrow">ACCESOS</p><h2>Personas autorizadas</h2><p class="section-copy">S' + [char]0x00f3 + 'lo estas personas pueden consultar o administrar la cuenta.</p></div><span class="feature-status">Invitaciones ' + [char]0x00b7 + ' pr' + [char]0x00f3 + 'ximamente</span></div><div id="people-root" class="list-grid"></div></section>
'), ('        <section id="account" class="dashboard-section" data-views="account">
          <div id="cfg-lista">
            <div class="section-head"><div><p class="eyebrow">AJUSTES</p><h2>Configuraci' + [char]0x00f3 + 'n</h2><p class="section-copy">Lo que no us' + [char]0x00e1 + 's todos los d' + [char]0x00ed + 'as est' + [char]0x00e1 + ' ac' + [char]0x00e1 + ', ordenado por tema. Lo de todos los d' + [char]0x00ed + 'as sigue en cada pesta' + [char]0x00f1 + 'a.</p></div></div>
            <nav class="card cfg-lista" aria-label="Categor' + [char]0x00ed + 'as de Configuraci' + [char]0x00f3 + 'n">
              <button type="button" class="cfg-item" data-cfg="cuenta"><span><strong>Cuenta y seguridad</strong><small>Tu correo, c' + [char]0x00f3 + 'mo entr' + [char]0x00e1 + 's, el c' + [char]0x00f3 + 'digo de verificaci' + [char]0x00f3 + 'n y la pregunta de emergencia.</small></span></button>
              <button type="button" class="cfg-item" data-cfg="avisos"><span><strong>Avisos</strong><small>C' + [char]0x00f3 + 'mo te avisamos si pasa algo con tu tel' + [char]0x00e9 + 'fono: por correo o por SMS.</small></span></button>
              <a class="cfg-item" href="/guardian#configuracion"><span><strong>Tu protecci' + [char]0x00f3 + 'n</strong><small>Referentes, Modo Cautela y Modo Guardi' + [char]0x00e1 + 'n. Se abre en otra pantalla.</small></span></a>
              <button type="button" class="cfg-item" data-cfg="familia"><span><strong>Familia y lugares</strong><small>Invitar a la familia, lugares guardados, avisos de llegada y salida y roles.</small></span></button>
              <button type="button" class="cfg-item" data-cfg="equipos"><span><strong>Equipos y pulseras</strong><small>Agregar un equipo, quitarlo o autorizarlo, y la presentaci' + [char]0x00f3 + 'n de las pulseras.</small></span></button>
              <button type="button" class="cfg-item" data-cfg="facial"><span><strong>Reconocimiento facial</strong><small>B' + [char]0x00fa + 'squedas disponibles y compra.</small></span></button>
              <button type="button" class="cfg-item" data-cfg="apariencia"><span><strong>Apariencia y accesibilidad</strong><small>Modo claro o noche, tama' + [char]0x00f1 + 'o del texto, contraste y botones grandes.</small></span></button>
            </nav>
          </div>
          <div id="cfg-cuenta" class="cfg-panel hidden" data-cfg-panel="cuenta">
            <a class="cfg-volver" href="#config">&#8592; Configuraci' + [char]0x00f3 + 'n</a>
            <div class="section-head"><div><p class="eyebrow">CONFIGURACI' + [char]0x00d3 + 'N</p><h2>Cuenta y seguridad</h2><p class="section-copy">Tu correo identifica la cuenta y mantiene la misma informaci' + [char]0x00f3 + 'n en todos tus dispositivos.</p></div></div>
<article class="account-card card"><span>Correo del titular</span><strong id="account-email-copy">Correo no disponible</strong><small>Las acciones importantes generan un aviso de seguridad por correo.</small></article><article class="account-card card"><span>Protecci' + [char]0x00f3 + 'n de ingreso</span><strong id="account-security-state">Pendiente de configurar</strong><small id="account-security-copy">Cre' + [char]0x00e1 + ' el acceso seguro desde el tel' + [char]0x00e9 + 'fono principal.</small></article>
        <article class="account-card card" id="totp-card">
          <span>C' + [char]0x00f3 + 'digo de verificaci' + [char]0x00f3 + 'n</span>
          <strong id="totp-state">No configurado</strong>
          <small>Un c' + [char]0x00f3 + 'digo de 6 d' + [char]0x00ed + 'gitos que cambia cada 30 segundos, generado en una app como Google Authenticator o Authy. Sirve para entrar aunque no tengas Face ID a mano.</small>
          <button id="totp-setup-button" class="ghost" type="button">Configurar c' + [char]0x00f3 + 'digo de verificaci' + [char]0x00f3 + 'n</button>
          <button id="totp-share-button" class="ghost hidden" type="button">Agregar en otro dispositivo (respaldo)</button>
          <div id="totp-setup-panel" class="hidden">
            <small>Carg' + [char]0x00e1 + ' este c' + [char]0x00f3 + 'digo en tu app de autenticaci' + [char]0x00f3 + 'n (opci' + [char]0x00f3 + 'n "ingresar manualmente" o "clave secreta"):</small>
            <p><strong id="totp-secret-display"></strong></p>
            <a id="totp-otpauth-link" class="app-link" href="#">Abrir directo en la app de autenticaci' + [char]0x00f3 + 'n</a>
            <div id="totp-confirm-fields">
              <label>C' + [char]0x00f3 + 'digo de 6 n' + [char]0x00fa + 'meros<input id="totp-confirm-code" inputmode="numeric" maxlength="6" pattern="[0-9]{6}" autocomplete="one-time-code" /></label>
              <button id="totp-confirm-button" type="button">Confirmar</button>
            </div>
            <p id="totp-setup-message" class="message"></p>
          </div>
        </article>
        <article class="account-card card" id="qa-card">
          <span>Pregunta de emergencia</span>
          <strong id="qa-status">Cargando&#8230;</strong>
          <small>Si perd&#233;s tus tel&#233;fonos y no pod&#233;s abrir tu correo, entr&#225;s desde cualquier celular con esta pregunta y su respuesta. La eleg&#237;s vos. Sirve una sola vez, y despu&#233;s cre&#225;s otra.</small>
          <form id="qa-set-form">
            <label>Tu pregunta<input id="qa-set-question" type="text" maxlength="120" placeholder="Ej.: &#191;Mi primera mascota?" autocomplete="off" required /></label>
            <label>Tu respuesta (letras y n&#250;meros, m&#237;nimo 6)<input id="qa-set-answer" type="text" maxlength="60" placeholder="Ej.: pelusa1952" autocomplete="off" autocapitalize="none" spellcheck="false" required /></label>
            <small>Eleg&#237; una respuesta que no se pueda averiguar mirando tus redes ni pregunt&#225;ndole a alguien. Tampoco escribas la respuesta en la pregunta: cualquiera que sepa tu correo puede ver la pregunta.</small>
            <button id="qa-save">Guardar pregunta y respuesta</button>
          </form>
          <p id="qa-set-message" class="message"></p>
        </article>
        <section id="people" class="dashboard-section" data-views="account"><div class="section-head"><div><p class="eyebrow">ACCESOS</p><h2>Personas autorizadas</h2><p class="section-copy">S' + [char]0x00f3 + 'lo estas personas pueden consultar o administrar la cuenta.</p></div><span class="feature-status">Invitaciones ' + [char]0x00b7 + ' pr' + [char]0x00f3 + 'ximamente</span></div><div id="people-root" class="list-grid"></div></section>
          </div>
          <div id="cfg-avisos" class="cfg-panel hidden" data-cfg-panel="avisos">
            <a class="cfg-volver" href="#config">&#8592; Configuraci' + [char]0x00f3 + 'n</a>
            <div class="section-head"><div><p class="eyebrow">CONFIGURACI' + [char]0x00d3 + 'N</p><h2>Avisos</h2><p class="section-copy">C' + [char]0x00f3 + 'mo quer' + [char]0x00e9 + 's enterarte si pasa algo con tu tel' + [char]0x00e9 + 'fono.</p></div></div>
        <article class="account-card card" id="notification-prefs-card">
          <span>Avisos de seguridad</span>
          <strong>' + [char]0x00bf + 'C' + [char]0x00f3 + 'mo quer' + [char]0x00e9 + 's recibirlos?</strong>
          <small>Eleg' + [char]0x00ed + ' correo, SMS o los dos. El SMS es m' + [char]0x00e1 + 's r' + [char]0x00e1 + 'pido pero no incluye fotos ni audio.</small>
          <label><input id="notify-email" type="checkbox" /> Por correo</label>
          <label><input id="notify-sms" type="checkbox" /> Por SMS</label>
          <label><input id="notify-silence" type="checkbox" /> Avisarme tambi' + [char]0x00e9 + 'n si el tel' + [char]0x00e9 + 'fono deja de responder sin motivo aparente</label>
          <small>Si alguien intenta entrar y enseguida el tel' + [char]0x00e9 + 'fono se apaga, el aviso se manda siempre. Esta opci' + [char]0x00f3 + 'n agrega el caso en que se apaga sin que haya pasado nada ' + [char]0x2014 + ' ' + [char]0x00fa + 'til, pero puede avisarte si lo apag' + [char]0x00e1 + 's vos de noche.</small>
          <label id="notify-phone-field" class="hidden">N' + [char]0x00fa + 'mero de celular (con c' + [char]0x00f3 + 'digo de pa' + [char]0x00ed + 's, ej: +54 9 11 2345-6789)<input id="notify-phone" type="tel" inputmode="tel" placeholder="+54 9 11 2345-6789" /></label>
          <button id="notify-prefs-save" type="button">Guardar</button>
          <p id="notify-prefs-message" class="message"></p>
        </article>
          </div>
          <div id="cfg-facial" class="cfg-panel hidden" data-cfg-panel="facial">
            <a class="cfg-volver" href="#config">&#8592; Configuraci' + [char]0x00f3 + 'n</a>
            <div class="section-head"><div><p class="eyebrow">CONFIGURACI' + [char]0x00d3 + 'N</p><h2>Reconocimiento facial</h2><p class="section-copy">Comparar la cara de una evidencia con tu galer' + [char]0x00ed + 'a. Es una funci' + [char]0x00f3 + 'n paga.</p></div></div>
        <article class="account-card card" id="face-search-card">
          <span>Reconocimiento facial</span>
          <strong id="face-search-balance">0 b' + [char]0x00fa + 'squedas disponibles</strong>
          <small>Compar' + [char]0x00e1 + ' la cara de una evidencia contra tu propia galer' + [char]0x00ed + 'a del tel' + [char]0x00e9 + 'fono. Funci' + [char]0x00f3 + 'n paga, se descuenta 1 b' + [char]0x00fa + 'squeda por cada comparaci' + [char]0x00f3 + 'n. <span class="status-tag status-tag-core">' + [char]0x25cf + ' N' + [char]0x00da + 'CLEO ' + [char]0x00b7 + ' EN VALIDACI' + [char]0x00d3 + 'N</span></small>
          <button id="face-search-buy-5" type="button" class="ghost">5 b' + [char]0x00fa + 'squedas ' + [char]0x00b7 + ' USD 1</button>
          <button id="face-search-buy-10" type="button" class="ghost">10 b' + [char]0x00fa + 'squedas ' + [char]0x00b7 + ' USD 1,50</button>
          <small>El precio est' + [char]0x00e1 + ' en d' + [char]0x00f3 + 'lares y se cobra en pesos al cambio del d' + [char]0x00ed + 'a.</small>
          <p id="face-search-message" class="message"></p>
        </article>          </div>
          <div id="cfg-familia" class="cfg-panel hidden" data-cfg-panel="familia">
            <a class="cfg-volver" href="#config">&#8592; Configuraci' + [char]0x00f3 + 'n</a>
            <div class="section-head"><div><p class="eyebrow">CONFIGURACI' + [char]0x00d3 + 'N</p><h2>Familia y lugares</h2><p class="section-copy">Todo lo de tu familia se maneja en el mapa; desde ac' + [char]0x00e1 + ' lleg' + [char]0x00e1 + 's directo.</p></div></div>
        <article class="account-card card">
          <span>Invitar a la familia</span>
          <strong>Sum' + [char]0x00e1 + ' a alguien</strong>
          <small>Le mand' + [char]0x00e1 + 's un c' + [char]0x00f3 + 'digo y un enlace. Eleg' + [char]0x00ed + 's si es adulto, menor o amigo.</small>
          <button id="cfg-invitar" class="ghost" type="button">Invitar a la familia</button>
        </article>
        <article class="account-card card">
          <span>Lugares, avisos y roles</span>
          <strong>Casa, colegio, trabajo' + [char]0x2026 + '</strong>
          <small>Los lugares se ven y se quitan en el mapa. Para que te avisen cuando alguien llega o sale de un lugar, toc' + [char]0x00e1 + ' a la persona en el mapa y eleg' + [char]0x00ed + ' ' + [char]0x00ab + 'Avisarme cuando llegue o salga' + [char]0x00bb + '. Para cambiarle el rol o quitarla de la familia, toc' + [char]0x00e1 + ' a la persona y eleg' + [char]0x00ed + ' ' + [char]0x00ab + 'Cambiar rol o quitar' + [char]0x00bb + '.</small>
          <button id="cfg-mapa" class="ghost" type="button">Abrir Mapa y Familia</button>
        </article>
          </div>
          <div id="cfg-equipos" class="cfg-panel hidden" data-cfg-panel="equipos">
            <a class="cfg-volver" href="#config">&#8592; Configuraci' + [char]0x00f3 + 'n</a>
            <div class="section-head"><div><p class="eyebrow">CONFIGURACI' + [char]0x00d3 + 'N</p><h2>Equipos y pulseras</h2><p class="section-copy">Agregar, quitar y autorizar equipos. Lo de todos los d' + [char]0x00ed + 'as (ubicar, hacer sonar) sigue en Mis Equipos.</p></div></div>
        <article class="account-card card">
          <span>Agregar un equipo</span>
          <strong>Tel' + [char]0x00e9 + 'fono, tablet o accesorio Bluetooth</strong>
          <small>Te llevamos a Mis Equipos con el cuadro para agregarlo abierto.</small>
          <button id="cfg-agregar" class="ghost" type="button">Agregar un equipo</button>
        </article>
        <article class="account-card card">
          <span>Quitar o autorizar un equipo</span>
          <strong>Se hace desde cada equipo</strong>
          <small>En Mis Equipos, toc' + [char]0x00e1 + ' ' + [char]0x00ab + 'M' + [char]0x00e1 + 's acciones' + [char]0x00bb + ' en el equipo que quieras quitar. Los equipos nuevos quedan pendientes hasta que los autorices ah' + [char]0x00ed + ' mismo.</small>
          <button id="cfg-equipos-ir" class="ghost" type="button">Ir a Mis Equipos</button>
        </article>
        <article class="account-card card">
          <span>Pulseras</span>
          <strong>Reloj GPS con alarmas y salud</strong>
          <small>Una presentaci' + [char]0x00f3 + 'n corta de lo que hace la pulsera.</small>
          <button id="cfg-pulseras" class="ghost" type="button">Ver presentaci' + [char]0x00f3 + 'n</button>
        </article>
          </div>
          <div id="cfg-apariencia" class="cfg-panel hidden" data-cfg-panel="apariencia">
            <a class="cfg-volver" href="#config">&#8592; Configuraci' + [char]0x00f3 + 'n</a>
            <div class="section-head"><div><p class="eyebrow">CONFIGURACI' + [char]0x00d3 + 'N</p><h2>Apariencia y accesibilidad</h2><p class="section-copy">C' + [char]0x00f3 + 'mo se ve y c' + [char]0x00f3 + 'mo se toca este panel. Se guarda en este dispositivo.</p></div></div>
        <article class="account-card card">
          <span>Tema</span>
          <strong id="cfg-tema-estado">Modo claro</strong>
          <small>El modo noche descansa la vista.</small>
          <button id="cfg-tema" class="ghost" type="button">Pasar a modo noche</button>
        </article>
        <article class="account-card card" id="cfg-acc">
          <span>Accesibilidad</span>
          <strong>Que se lea y se toque c' + [char]0x00f3 + 'modo</strong>
          <small>Vale tambi' + [char]0x00e9 + 'n para Tu protecci' + [char]0x00f3 + 'n: lo que elijas ac' + [char]0x00e1 + ' se ve ah' + [char]0x00ed + ' y al rev' + [char]0x00e9 + 's.</small>
          <span class="cfg-rotulo">Tama' + [char]0x00f1 + 'o del texto</span>
          <div class="cfg-chips" role="group" aria-label="Tama' + [char]0x00f1 + 'o del texto">
            <button type="button" class="ghost" data-t="">Normal</button>
            <button type="button" class="ghost" data-t="g">Grande</button>
            <button type="button" class="ghost" data-t="x">Muy grande</button>
          </div>
          <label><input id="cfg-contraste" type="checkbox" /> Alto contraste</label>
          <label><input id="cfg-botones" type="checkbox" /> Botones m' + [char]0x00e1 + 's grandes</label>
        </article>
          </div>
        </section>
')),
    @('src\panel-app.txt', 'programa de Configuracion', 'setTimeout(qaCargar, 2000);', ('setTimeout(qaCargar, 2000);

// ---- Configuraci' + [char]0x00f3 + 'n: la pesta' + [char]0x00f1 + 'a que antes era "Cuenta". Una lista de categor' + [char]0x00ed + 'as y una pantalla por categor' + [char]0x00ed + 'a. ----
// Las tarjetas de antes (correo, acceso, c' + [char]0x00f3 + 'digo de verificaci' + [char]0x00f3 + 'n, avisos, pregunta de emergencia, reconocimiento facial) son las mismas: solo cambiaron de lugar.
const cfgPaneles = Array.from(document.querySelectorAll("[data-cfg-panel]"));
function cfgMostrar(id, desplazar = true) {
  const valido = cfgPaneles.some((p) => p.dataset.cfgPanel === id) ? id : "";
  $("#cfg-lista").classList.toggle("hidden", valido !== "");
  cfgPaneles.forEach((p) => p.classList.toggle("hidden", p.dataset.cfgPanel !== valido));
  if (desplazar) window.scrollTo(0, 0);
}
function cfgDesdeHash() {
  const m = /^#config(?:-([a-z]+))?$/.exec(location.hash);
  if (!m || emergencyMode) return false; // en el modo de emergencia no se ve Configuraci' + [char]0x00f3 + 'n (igual que pasaba con Cuenta)
  setView("account", false);
  cfgMostrar(m[1] || "");
  return true;
}
document.querySelectorAll("[data-cfg]").forEach((b) => b.addEventListener("click", () => { location.hash = "config-" + b.dataset.cfg; }));
window.addEventListener("hashchange", () => { if (!cfgDesdeHash() && currentView === "account") cfgMostrar(""); });
// Al tocar la pesta' + [char]0x00f1 + 'a Configuraci' + [char]0x00f3 + 'n, siempre se ve la lista.
document.querySelectorAll(''[data-view="account"]'').forEach((b) => b.addEventListener("click", () => {
  if (/^#config/.test(location.hash)) history.replaceState(null, "", location.pathname + location.search);
  cfgMostrar("");
}));

// Atajos: llevan a donde ya est' + [char]0x00e1 + ' cada cosa (el mapa, Mis Equipos), sin duplicarla.
function cfgEsperar(selector, hacer, intentos = 40) {
  const reloj = setInterval(() => {
    const elemento = $(selector);
    if (elemento || --intentos <= 0) { clearInterval(reloj); if (elemento) hacer(elemento); }
  }, 150);
}
$("#cfg-mapa").addEventListener("click", () => { $("[data-mapa-tab]")?.click(); });
$("#cfg-invitar").addEventListener("click", () => { $("[data-mapa-tab]")?.click(); cfgEsperar(''#og-mapa [data-ogm="invitar"]'', (b) => b.click()); });
$("#cfg-agregar").addEventListener("click", () => { setView("devices"); $("#add-device-button")?.click(); });
$("#cfg-equipos-ir").addEventListener("click", () => setView("devices"));
$("#cfg-pulseras").addEventListener("click", () => $("#watch-presentation-button")?.click());

// Apariencia: el tema (el mismo bot' + [char]0x00f3 + 'n de siempre, que sigue en la barra de arriba en la pantalla de acceso) y la accesibilidad (misma clave que Tu protecci' + [char]0x00f3 + 'n).
function cfgAccLeer() { try { return JSON.parse(localStorage.getItem("ogAcc") || "{}") || {}; } catch { return {}; } }
function cfgAccGuardar(acc) { try { localStorage.setItem("ogAcc", JSON.stringify(acc)); } catch { /* navegaci' + [char]0x00f3 + 'n privada */ } }
function cfgAccAplicar(acc) {
  const raiz = document.documentElement;
  raiz.style.fontSize = acc.t === "g" ? "118%" : acc.t === "x" ? "136%" : "";
  raiz.classList.toggle("ac", !!acc.c);
  raiz.classList.toggle("ab", !!acc.b);
}
function cfgPintarApariencia() {
  const claro = document.documentElement.getAttribute("data-theme") === "light";
  $("#cfg-tema-estado").textContent = claro ? "Modo claro" : "Modo noche";
  $("#cfg-tema").textContent = claro ? "Pasar a modo noche" : "Pasar a modo claro";
  const acc = cfgAccLeer();
  document.querySelectorAll("#cfg-acc [data-t]").forEach((b) => b.setAttribute("aria-pressed", String((b.dataset.t || "") === (acc.t || ""))));
  $("#cfg-contraste").checked = !!acc.c;
  $("#cfg-botones").checked = !!acc.b;
}
$("#cfg-tema").addEventListener("click", () => { $("#theme-toggle")?.click(); cfgPintarApariencia(); });
new MutationObserver(cfgPintarApariencia).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
document.querySelectorAll("#cfg-acc [data-t]").forEach((b) => b.addEventListener("click", () => { const acc = cfgAccLeer(); acc.t = b.dataset.t; cfgAccGuardar(acc); cfgAccAplicar(acc); cfgPintarApariencia(); }));
$("#cfg-contraste").addEventListener("change", (evento) => { const acc = cfgAccLeer(); acc.c = evento.target.checked; cfgAccGuardar(acc); cfgAccAplicar(acc); });
$("#cfg-botones").addEventListener("change", (evento) => { const acc = cfgAccLeer(); acc.b = evento.target.checked; cfgAccGuardar(acc); cfgAccAplicar(acc); });
cfgPintarApariencia();
// Si se recarga estando en una pantalla de Configuraci' + [char]0x00f3 + 'n, se vuelve a esa pantalla apenas se dibuja el panel (ah' + [char]0x00ed + ' ya se sabe si es modo de emergencia).
if (location.hash) { if ($("#dashboard:not(.hidden)")) cfgDesdeHash(); else cfgEsperar("#dashboard:not(.hidden)", () => cfgDesdeHash()); }
'))
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
    if (Test-Path ($ruta + ".bak-cfgconsola")) { Mal ("Ya existe " + $t + ".bak-cfgconsola. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-cfgconsola"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-cfgconsola): " + ($respaldados -join ", "))

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
foreach ($k in $archivos.Keys) { Chk ($k + ": huella final") ((ShaTexto (Leer (Join-Path $raiz $k)).texto) -eq $finales[$k]) }
foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-cfgconsola") -Destination $ruta -Force }
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
Ok "LISTO: la consola quedo publicada. Abrila con Ctrl+F5 y toca Configuracion (la pestana de abajo, donde antes decia Cuenta)."
Write-Host ""
