# aplicar-orden-sonido-app.ps1 - App (PROXIMA build). Luciano (14/11/2026): "estaria bueno que lo ordene por horario: manana, tarde y noche" y "las notificaciones no tienen sonido: un pip, no una alarma molesta".
# 1) La lista MIS MEDICAMENTOS sale ordenada por horario y separada en MAÑANA / TARDE / NOCHE (un medicamento con varias horas va en el grupo de su primera hora).
# 2) Android: se crea el canal de avisos "Medicamentos y Buen día" con un sonido corto del telefono (antes salian por un canal silencioso). iPhone ya sonaba: no cambia.
# Toca src\FamiliaPantalla.tsx y App.tsx (respaldo .bak-ordensonido). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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

if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\FamiliaPantalla.tsx", "App.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'ojo-medicamentos') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\FamiliaPantalla.tsx', 'orden: importar Fragment', 'import { useCallback, useEffect, useRef, useState, type ComponentType, type ReactNode } from "react";
', 'import { Fragment, useCallback, useEffect, useRef, useState, type ComponentType, type ReactNode } from "react";
'),
    @('src\FamiliaPantalla.tsx', 'orden: funciones para ordenar por momento del dia', 'function moverHoraRemedio(hhmm: string, pasos: number): string {
', '// Momento del dia de cada medicamento (por su primera hora): manana 05:00-11:59, tarde 12:00-19:59, noche 20:00-04:59.
const NOMBRES_MOMENTO = ["MAÑANA", "TARDE", "NOCHE"];
function minutosDesdeLasCinco(hhmm: string): number {
  const [h, m] = hhmm.split(":").map((x) => Number(x));
  return (((h || 0) * 60 + (m || 0) - 300) % 1440 + 1440) % 1440;
}
/** La primera hora del dia en que se toma (la noche termina de madrugada: 00:30 va despues de 23:00). */
function primeraHora(it: { horas: string[] } | undefined): string {
  return [...(it?.horas ?? [])].sort((a, b) => minutosDesdeLasCinco(a) - minutosDesdeLasCinco(b))[0] ?? "12:00";
}
function momentoDelDia(hhmm: string): number {
  const m = minutosDesdeLasCinco(hhmm);
  return m < 7 * 60 ? 0 : m < 15 * 60 ? 1 : 2;
}
/** Ordena por horario: primero los de la manana, despues los de la tarde y al final los de la noche. */
function ordenarMedicamentos<T extends { horas: string[]; nombre: string }>(items: T[]): T[] {
  return [...items].sort((a, b) => minutosDesdeLasCinco(primeraHora(a)) - minutosDesdeLasCinco(primeraHora(b)) || a.nombre.localeCompare(b.nombre));
}

function moverHoraRemedio(hhmm: string, pasos: number): string {
'),
    @('src\FamiliaPantalla.tsx', 'orden: la lista de medicamentos va por horario (manana, tarde, noche)', '        {(borrador ? [] : actual.items).map((it) => (
          <View key={it.id} style={{ borderColor: P.borde, borderRadius: 12, borderWidth: 1, gap: 6, padding: 10 }}>
', '        {(borrador ? [] : ordenarMedicamentos(actual.items)).map((it, orden, lista) => (
          <Fragment key={it.id}>
            {orden === 0 || momentoDelDia(primeraHora(lista[orden - 1])) !== momentoDelDia(primeraHora(it)) ? (
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoDebil, fontSize: 12, fontWeight: "800", letterSpacing: 1.1, marginTop: orden === 0 ? 0 : 6 }}>{NOMBRES_MOMENTO[momentoDelDia(primeraHora(it))]}</Text>
            ) : null}
          <View style={{ borderColor: P.borde, borderRadius: 12, borderWidth: 1, gap: 6, padding: 10 }}>
'),
    @('src\FamiliaPantalla.tsx', 'orden: cierre del grupo de cada medicamento', '          </View>
        ))}
        {borrador ? (
', '          </View>
          </Fragment>
        ))}
        {borrador ? (
'),
    @('App.tsx', 'sonido: canal nuevo con un sonido corto para medicamentos y Buen dia', '      void notifications.setNotificationChannelAsync("ojo-alertas", {
', '      // Avisos de medicamentos y "Buen dia": un sonido corto (el aviso normal del telefono) y una vibracion suave, sin alarma. Un canal ya creado no puede cambiar de sonido, por eso es uno nuevo.
      void notifications.setNotificationChannelAsync("ojo-medicamentos", {
        name: "Medicamentos y Buen día",
        description: "Recordatorios de tus medicamentos y el saludo del Buen día: un sonido corto.",
        importance: notifications.AndroidImportance.DEFAULT,
        sound: "default",
        enableVibrate: true,
        vibrationPattern: [0, 200],
        lockscreenVisibility: notifications.AndroidNotificationVisibility.PUBLIC,
      });
      void notifications.setNotificationChannelAsync("ojo-alertas", {
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
    if (Test-Path ($ruta + ".bak-ordensonido")) { Mal ("Ya existe " + $t + ".bak-ordensonido. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-ordensonido"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-ordensonido): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-ordensonido") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-ordensonido") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Medicamentos ordenados por horario y avisos con sonido corto (sale en la PROXIMA build, Android e iPhone)."
Write-Host ""
