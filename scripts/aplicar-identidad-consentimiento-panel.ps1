# aplicar-identidad-consentimiento-panel.ps1 - Ojo Guard MS: el servidor guarda que version del texto de consentimiento biometrico acepto la persona, y cuando, antes de mandar la selfie a Didit.
# La app nueva (proxima build) muestra el texto de consentimiento antes del DNI y la selfie y manda `consentVersion`. Con IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO = false (hoy) la app vieja sigue verificando sin mandarla; al lanzar se pone en true.
# Cambia SOLO src\index.ts (respaldo .bak-consentimiento). Va en la carpeta del PANEL (la que tiene wrangler.toml). No cambia la app. Instalarlo hoy no cambia nada para nadie. Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\index.ts"))) { Mal "No encuentro src\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'Identidad: columnas del consentimiento e interruptor (apagado)', 'async function idTabla(env: Env) {
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS identity_checks (email TEXT PRIMARY KEY, status TEXT NOT NULL, outcome TEXT, score INTEGER, doc_last3 TEXT, doc_hash TEXT, attempts INTEGER NOT NULL DEFAULT 0, attempts_day TEXT, verified_at TEXT, updated_at TEXT NOT NULL)").run();
}
', '// Consentimiento biometrico (03/11/2026): antes de mandar la selfie a Didit la app muestra el texto de consentimiento y manda su version (`consentVersion`).
// El servidor guarda esa version y cuando la vio por primera vez (columnas consent_version y consent_at de identity_checks).
// IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO = false: mientras queden telefonos con la app vieja, que no manda la version, se sigue verificando sin ella (queda un registro `identity_sin_consentimiento`).
// Al abrir Ojo Guard al publico, o cuando todos los telefonos tengan la app nueva: ponerlo en true; el servidor contesta 400 consent_required ANTES de llamar a Didit.
const IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO = false;
let idColumnasListas = false;

async function idAgregarColumna(env: Env, definicion: string) {
  try {
    await env.DB.prepare(`ALTER TABLE identity_checks ADD COLUMN ${definicion}`).run();
  } catch (error) {
    // Si la columna ya estaba no pasa nada; cualquier otro error se deja pasar para no seguir sin la columna.
    if (!/duplicate column/i.test(String(error))) throw error;
  }
}

async function idTabla(env: Env) {
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS identity_checks (email TEXT PRIMARY KEY, status TEXT NOT NULL, outcome TEXT, score INTEGER, doc_last3 TEXT, doc_hash TEXT, attempts INTEGER NOT NULL DEFAULT 0, attempts_day TEXT, verified_at TEXT, updated_at TEXT NOT NULL)").run();
  if (idColumnasListas) return;
  await idAgregarColumna(env, "consent_version TEXT");
  await idAgregarColumna(env, "consent_at TEXT");
  idColumnasListas = true;
}
'),
    @('src\index.ts', 'Identidad: guardar la version del consentimiento antes de llamar a Didit', '  if (intentos >= ID_INTENTOS_POR_DIA) return json({ error: "too_many_attempts" }, 429);
', '  if (intentos >= ID_INTENTOS_POR_DIA) return json({ error: "too_many_attempts" }, 429);
  // Consentimiento: la app manda la version del texto que la persona acepto. Con el interruptor prendido, sin consentimiento no se manda nada a Didit.
  const consentimiento = String(body.consentVersion ?? "").trim();
  const consentimientoValido = /^\d{4}-\d{2}-\d{2}(\.[a-z0-9]{1,8})?$/i.test(consentimiento);
  if (!consentimientoValido) console.error("identity_sin_consentimiento");
  if (IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO && !consentimientoValido) return json({ error: "consent_required" }, 400);
  if (consentimientoValido) {
    const ahora = now();
    await env.DB.prepare("INSERT INTO identity_checks (email,status,attempts,updated_at,consent_version,consent_at) VALUES (?,?,0,?,?,?) ON CONFLICT(email) DO UPDATE SET consent_at=CASE WHEN identity_checks.consent_version IS excluded.consent_version THEN COALESCE(identity_checks.consent_at, excluded.consent_at) ELSE excluded.consent_at END, consent_version=excluded.consent_version")
      .bind(email, "sin_verificar", ahora, consentimiento, ahora).run();
  }
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
    if (Test-Path ($ruta + ".bak-consentimiento")) { Mal ("Ya existe " + $t + ".bak-consentimiento. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-consentimiento"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-consentimiento): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-consentimiento") -Destination $ruta -Force }
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
Ok "LISTO: el servidor ya guarda la version del consentimiento (todavia no lo exige)."
Write-Host ""
