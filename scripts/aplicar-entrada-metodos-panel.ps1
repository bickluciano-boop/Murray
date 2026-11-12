# aplicar-entrada-metodos-panel.ps1 - Ojo Guard MS: la entrada de ojoguard.app pide el correo UNA vez y pregunta como queres entrar.
# Luciano (12/11/2026): "que no sea tan tedioso entrar, que solo este tu mail y te pregunte de que manera queres entrar (codigo por mail, codigo de 6 digitos del autenticador, o la otra), pero que no haya tantos mails".
# Un solo correo; "Como queres entrar?" con Codigo por correo / App de verificacion / Huella o Face ID (se acuerda de la ultima); la emergencia (pregunta secreta) queda abajo. Por dentro las formas de entrar siguen igual.
# Reemplaza a aplicar-entrada-clara-panel.ps1 (no aplicar los dos). Cambia SOLO src\panel-index.html (respaldo .bak-entrada-metodos). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\panel-index.html"))) { Mal "No encuentro src\panel-index.html en esta carpeta."; return }
$htmlTexto = (Leer (Join-Path $raiz "src\panel-index.html")).texto
if ((Contar $htmlTexto 'og-metodos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $htmlTexto 'correo-unico') -ne 0) { Mal "Ya se aplico aplicar-entrada-clara-panel.ps1. Mandame esta pantalla."; return }
$cambios = @(
    @('src\panel-index.html', 'correo unico y "como queres entrar?"', '        <p class="hero-copy">Ingresá con un código enviado a tu correo. Funciona en iPhone, Android y computadora sin escanear ningún QR.</p>
', '        <p class="hero-copy">Ingresá con un código enviado a tu correo. Funciona en iPhone, Android y computadora sin escanear ningún QR.</p>
        <div id="correo-unico-caja" style="display:none">
          <label>Tu correo<input id="correo-unico" type="email" autocomplete="username webauthn" placeholder="tu@correo.com" /></label>
          <p class="acceso-via">¿Cómo querés entrar?</p>
          <div class="acceso-metodos" role="group" aria-label="Cómo querés entrar">
            <button type="button" data-metodo="correo" aria-pressed="false"><strong>Código por correo</strong><small>Te lo mandamos al mail</small></button>
            <button type="button" data-metodo="app" aria-pressed="false"><strong>App de verificación</strong><small>Google Authenticator u otra</small></button>
            <button type="button" data-metodo="huella" aria-pressed="false"><strong>Huella o Face ID</strong><small>Si ya la configuraste acá</small></button>
          </div>
        </div>
'),
    @('src\panel-index.html', 'boton de enviar el codigo', '          <button>Enviar código de 6 números</button>
', '          <button>Enviar código por correo</button>
'),
    @('src\panel-index.html', 'nombre del campo del codigo del correo', '<label>Código de 6 números<input id="code"', '<label>Código que te llegó por correo<input id="code"'),
    @('src\panel-index.html', 'nombre del campo del codigo de la app', '<label>Código de 6 números<input id="totp-code"', '<label>Código de tu app de verificación<input id="totp-code"'),
    @('src\panel-index.html', 'estilo y script de la eleccion', '        <p id="access-message" class="message"></p>
', '        <p id="access-message" class="message"></p>
        <style>
          #access .acceso-via{margin:18px 0 8px;font-weight:800;font-size:1.02rem}
          #correo-unico-caja{margin:14px 0 4px}
          #access .acceso-metodos{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
          #access .acceso-metodos button[data-metodo]{display:flex!important;flex-direction:column;align-items:center;justify-content:center;gap:3px;width:auto!important;margin:0!important;padding:12px 8px!important;min-height:64px;border-radius:14px!important;border:1px solid rgba(217,178,76,.45)!important;background:transparent!important;color:inherit!important;box-shadow:none!important;font:inherit;cursor:pointer;text-align:center;line-height:1.2;text-transform:none;letter-spacing:normal}
          #access .acceso-metodos button[data-metodo] strong{font-size:.92rem;font-weight:700;color:inherit}
          #access .acceso-metodos button[data-metodo] small{font-size:.72rem;opacity:.75;color:inherit;font-weight:400}
          #access .acceso-metodos button[data-metodo]:hover{background:rgba(217,178,76,.1)!important}
          #access .acceso-metodos button[data-metodo][aria-pressed="true"]{border-color:#d9b24c!important;background:rgba(217,178,76,.2)!important;box-shadow:0 0 0 1px #d9b24c inset!important}
          #access .acceso-metodos button[data-metodo]:focus-visible{outline:2px solid #d9b24c;outline-offset:2px}
          @media (max-width:520px){#access .acceso-metodos{grid-template-columns:1fr}#access .acceso-metodos button[data-metodo]{flex-direction:row;justify-content:flex-start;gap:10px;text-align:left;min-height:52px;padding:10px 14px!important}}
          #access.og-metodos #passkey-form>label,#access.og-metodos #email-form>label,#access.og-metodos #totp-login-form>label:first-child,#access.og-metodos #qa-login-form>label:first-child{display:none}
          #access.og-metodos #passkey-details>summary,#access.og-metodos #totp-login-details>summary{display:none}
          #access.og-metodos:not([data-metodo]) #passkey-details,#access.og-metodos:not([data-metodo]) #email-form,#access.og-metodos:not([data-metodo]) #code-form,#access.og-metodos:not([data-metodo]) #totp-login-details{display:none}
          #access.og-metodos[data-metodo="correo"] #passkey-details,#access.og-metodos[data-metodo="correo"] #totp-login-details{display:none}
          #access.og-metodos[data-metodo="app"] #passkey-details,#access.og-metodos[data-metodo="app"] #email-form,#access.og-metodos[data-metodo="app"] #code-form{display:none}
          #access.og-metodos[data-metodo="huella"] #email-form,#access.og-metodos[data-metodo="huella"] #code-form,#access.og-metodos[data-metodo="huella"] #totp-login-details{display:none}
        </style>
        <script>
          (function () {
            var acceso = document.getElementById("access");
            var caja = document.getElementById("correo-unico-caja");
            var unico = document.getElementById("correo-unico");
            var ids = ["passkey-email", "email", "totp-email", "qa-email"];
            var campos = ids.map(function (id) { return document.getElementById(id); }).filter(Boolean);
            var botones = Array.prototype.slice.call(document.querySelectorAll("#correo-unico-caja .acceso-metodos button"));
            if (!acceso || !caja || !unico || campos.length !== ids.length || botones.length !== 3) return;
            function copiar() { campos.forEach(function (c) { c.value = unico.value; }); }
            unico.addEventListener("input", copiar);
            unico.addEventListener("change", copiar);
            // Antes de enviar cualquier forma, el correo de arriba pasa al campo de esa forma (si el de arriba esta vacio, toma el que ya tenia la forma).
            campos.forEach(function (c) {
              if (c.form) c.form.addEventListener("submit", function () { if (unico.value) c.value = unico.value; else unico.value = c.value; }, true);
            });
            function previo() { var p = ""; campos.forEach(function (c) { if (!p && c.value) p = c.value; }); return p; }
            function tomarPrevio() { var p = previo(); if (p && !unico.value) { unico.value = p; copiar(); } }
            tomarPrevio();
            window.addEventListener("load", tomarPrevio);
            function elegir(metodo) {
              acceso.setAttribute("data-metodo", metodo);
              botones.forEach(function (b) { b.setAttribute("aria-pressed", String(b.getAttribute("data-metodo") === metodo)); });
              var pk = document.getElementById("passkey-details"), tp = document.getElementById("totp-login-details");
              if (metodo === "huella" && pk) pk.open = true;
              if (metodo === "app" && tp) tp.open = true;
              try { localStorage.setItem("ojo_ms_metodo", metodo); } catch (e) { /* navegacion privada */ }
            }
            botones.forEach(function (b) { b.addEventListener("click", function () { elegir(b.getAttribute("data-metodo")); }); });
            // Enter en el correo sigue con lo elegido (sin elegir nada, con el codigo por correo).
            unico.addEventListener("keydown", function (ev) {
              if (ev.key !== "Enter") return;
              ev.preventDefault();
              copiar();
              var metodo = acceso.getAttribute("data-metodo") || "correo";
              elegir(metodo);
              var forma = metodo === "correo" ? document.getElementById("email-form") : metodo === "huella" ? document.getElementById("passkey-form") : null;
              if (forma && forma.requestSubmit) forma.requestSubmit();
              else if (metodo === "app") { var cod = document.getElementById("totp-code"); if (cod) cod.focus(); }
            });
            var guardado = "";
            try { guardado = localStorage.getItem("ojo_ms_metodo") || ""; if (!guardado && localStorage.getItem("ojo_ms_usa_passkey") === "1") guardado = "huella"; } catch (e) { /* navegacion privada */ }
            caja.style.display = "block";
            acceso.classList.add("og-metodos");
            if (guardado === "correo" || guardado === "app" || guardado === "huella") elegir(guardado);
          })();
        </script>
')
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
    if (Test-Path ($ruta + ".bak-entrada-metodos")) { Mal ("Ya existe " + $t + ".bak-entrada-metodos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-entrada-metodos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-entrada-metodos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-entrada-metodos") -Destination $ruta -Force }
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
Ok "LISTO: la entrada pide el correo una vez y pregunta como queres entrar (recarga ojoguard.app con Ctrl+F5)."
Write-Host ""
