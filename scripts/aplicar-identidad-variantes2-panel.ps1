# aplicar-identidad-variantes2-panel.ps1 - Ojo Guard MS: segunda ronda de pruebas contra Didit (que sigue dando 500 con la selfie real): imagen valida SIN cara, otro DNI y otro sexo.
# Cambia SOLO src\index.ts (respaldo .bak-identidad-variantes2). Va en la carpeta del PANEL. Requiere aplicar-identidad-variantes-panel.ps1. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'imagenSinCara') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'didit_variantes') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-variantes-panel.ps1. No toco nada."; return }
$cambios = @(
    ,@('src\index.ts', 'segunda ronda de variantes (imagen sin cara, otro DNI, otro sexo)', '      const pruebas: Array<[string, Array<[string, string]>, Uint8Array]> = [
        ["sinVd", base, bytes],
        ["conDatos", [...base, ["first_name", "Prueba"], ["last_name", "Prueba"], ["date_of_birth", "1980-01-01"]], bytes],
        ["sinServices", base.filter(([clave]) => clave !== "services"), bytes],
        ["fotoChica", base, chica],
        ["conVd", [...base, ["vendor_data", "prueba"]], chica],
      ];', '      // Segunda ronda: Didit acepta la selfie real (no da 400 de imagen) y se rompe adentro. Se prueba una imagen valida SIN cara, otro DNI y otro sexo, para ver si el 500 depende de la cara o de los datos.
      const gris = Uint8Array.from(atob("/9j/4AAQSkZJRgABAQAAAQABAAD/4gHYSUNDX1BST0ZJTEUAAQEAAAHIAAAAAAQwAABtbnRyUkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlkZXNjAAAA8AAAACRyWFlaAAABFAAAABRnWFlaAAABKAAAABRiWFlaAAABPAAAABR3dHB0AAABUAAAABRyVFJDAAABZAAAAChnVFJDAAABZAAAAChiVFJDAAABZAAAAChjcHJ0AAABjAAAADxtbHVjAAAAAAAAAAEAAAAMZW5VUwAAAAgAAAAcAHMAUgBHAEJYWVogAAAAAAAAb6IAADj1AAADkFhZWiAAAAAAAABimQAAt4UAABjaWFlaIAAAAAAAACSgAAAPhAAAts9YWVogAAAAAAAA9tYAAQAAAADTLXBhcmEAAAAAAAQAAAACZmYAAPKnAAANWQAAE9AAAApbAAAAAAAAAABtbHVjAAAAAAAAAAEAAAAMZW5VUwAAACAAAAAcAEcAbwBvAGcAbABlACAASQBuAGMALgAgADIAMAAxADb/2wBDAAoHBwgHBgoICAgLCgoLDhgQDg0NDh0VFhEYIx8lJCIfIiEmKzcvJik0KSEiMEExNDk7Pj4+JS5ESUM8SDc9Pjv/2wBDAQoLCw4NDhwQEBw7KCIoOzs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozv/wAARCAFAAUADASIAAhEBAxEB/8QAGwABAQEBAQEBAQAAAAAAAAAAAAEGBQQDBwL/xAA2EAEAAQMCAwUGBAUFAAAAAAAAAQIDBAURBjFBEiFRcZEiQlJhocETFDLRI0OBsvFykrHh8P/EABkBAQEBAQEBAAAAAAAAAAAAAAEAAgQFA//EABwRAQEBAQEBAAMAAAAAAAAAAAABEQIxEgMhUf/aAAwDAQACEQMRAD8A0sygjgdogFCCECCECCECCFAIQIIQIIQIIUIBAghAghAghQghACECCFCCECCECAQ0KA813CCECCECCECCFAIQIIQIIQIIUIBAghAghAghQghACECCFCCECCECAQIIU0SCPNdoghAghAghQCECCECCECCFCAQIIQIIQIIUIIQAhAghQghAghAgECCFCCENEgjzXaIIQIIUAhAghAghAghQgECCECCECCFCCEAIQIIUIIQIIQIBAghQghAkyTKENEgjzXaIIUAhAghAghAghQgECCECCECCFCCEAIQIIUIIQIIQIBAghQghAkyTKECCENEgjzXcAhAghAghAghQgECCECPviYd/Nu9izRv41Typ82lwdHx8LauY/Eu/HVHLyjo1ILccLF0XMyoiqaYtUeNfd9HWscOYtuIm9XXdnz7MOsHGNee3p+Haj2Ma1G3XsxM+r7xTTTypiPKFCEmmmrnTE+cPhc0/DvfrxbU79ezET6vQJOPkcNYlyJmxXXZn/dH1/dx8zQs3Eiaopi9RHW337f0bASfnko2eoaJi5+9cR+Fen36Y5+cdWUzcHIwL34d+jb4ao5VeUmF5kEaAgECCFCCECTJMoQIIQAhTQgjzXaIIQIIQIIUIBAghA9Wn6fcz7/Yp9min9dfg+ONj3MvIps249qqefhHi2GLi28PHps2o7o5z1mfFqRm3Fxsa1i2YtWaezTHrPzl9QaYAEgBIASAEh8srFs5liqzfo7VM+sT4w+okwuqaZd03I7FXtW6u+ivbnH7vC/Qc3DtZ2NVYvRvFXKetM+MMJmYt3Cya8e7G1VM8+kx4ty6nxQRoCCECTJMoQIIQAhQghDRII812iCECCFCAQIIQIPvhY/5vNtWOlVXf5dSHf0HCixi/mK4/iXY7vlS6pERTTFMRtERtEDb5gCQAkAJACQAkAJDi8TadGTh/mqI/i2I7/nT19Ofq7RVTFVM01RvExtMT1UT81R6dRxZws+9j9+1FXs7+HOPo8r7RkSZJlCBBCAEKEEIEEIaJBHmu0QQoQCBBCBBCB2+GrHavXr8x+mmKY/r/AIcNqOHKOzps1fHcmf8AiDBfHVAaYAEgBIASAEgBIASAEmV4vx+zk2MiI/XTNM+cf5+jOTLZcWW+3pNNfW3difpMfdjH158ZogjbICFCCECCECCENEgjzXcIBAghAghAghQ12gxtpFn5zV/dLINbw/V2tJoj4aqo+u/3MZrpAFkASAEgBIASAEgBIAScriWN9Cvz4TT/AHQwrccUV9nRLkfFXTH13+zDPrx4zQEfRkQQgQQgQQgQCmhQHmu0QQgQQgQQoQQgaThe7E41+zv301xV6x/0zbpcP5P5fU6aJn2b0difPp/75kVrgEyAJACQAkAJACQAkAJM5xlfinFx7G/fXXNfpG33ZJ1+J8v8zq9dFM+zYj8OPPr9e7+jjvvzP0xfRBG2RBCBBCBAKEEIaJBHmu0QQgQQoQQgBCApqqoqiqmdqqZ3iY6SiFN3gZdObhW78bb1R7UeE9XoZLh/UoxMqbF2ra1ennPu1dJa0MgCQAkAJACQAkAJDy6nm06fgXcmrbemNqYnrV0epieJtVjOy4x7NW9ixPOOVVXWft6tczaLccWuuq5XVXVMzVVO8zPWX8iOh8xBCBBCBAKEEIEEIaJBHmu0QQoQQgBCBBChBCBqNB1mL9NOHkVfxaY2oqn348PNliJmJiYnaY6nA/RhntH4ipqinHzqtquVN2eU+f7tDE7xvDGIASAEgBIASAmdo3nkzOt8T00RVjafXvVyqvRyj/T+5ktFuPpxJr0Y9FWDi1b3qo2uVxP6I8PNjyZmZmZneZ5zKOjnnIxbogjTIghAgFCCECCECCFNEgjzXaIIQAhAghQghAghAgEDo6druXp+1G/4tmP5dU8vKejmocTc4WvYObERF2LVz4Lnd6Tyl0X5o9ONqebhxEWMm5RTHu77x6T3M/C1+hDH2uLc+iIi5bs3PntMT9JeiOMqvewYnyu7fYfNWtQMtVxnV7uDEed3f7PNe4uz64mLduzb+e0zP1lfFWxsnMz+INPwYmJuxdufBb7/AFnlDGZWqZ2ZExfyrldM+7vtHpHc8jc/H/RenU1TiDM1Lejtfg2J/l0Tz856uUI+smMaIIQIIQIBQghAghAghQghDRII812gIQIIUIIQIIQIBAghQghAkyTKECCEAIUIIQIIQIIQIBQghAghAghQghACENCCPNdoghQghAghAgECCFCCECTJMoQIIQAhQghAghAghAgFCCECCECCFCCEAIQIIQ0SCPNdwghAghAgECCFCCECTJMoQIIQAhQghAghAghAgFCCECCECCFCCEAIQIIQIIU0SCPNdoghAgECCFCCECTJMoQIIQAhQghAghAghAgFCCECCECCFCCEAIQIIQIIUIIQ0SCPNdogECCFCCECTJMoQIIQAhQghAghAghAgFCCECCECCFCCEAIQIIQIIUIIQIBDQoDzXaIIUIIQJMkyhAghACFCCECCECCECAUIIQIIQIIUIIQAhAghAghQghAgECCFP/Z"), (c) => c.charCodeAt(0));
      const otroDni = base.map(([clave, valor]): [string, string] => (clave === "document_number" ? [clave, "20123456"] : [clave, valor]));
      const otroSexo = base.map(([clave, valor]): [string, string] => (clave === "gender" ? [clave, "F"] : [clave, valor]));
      const pruebas: Array<[string, Array<[string, string]>, Uint8Array]> = [
        ["imagenSinCara", base, gris],
        ["imagenSinCaraConVd", [...base, ["vendor_data", "prueba"]], gris],
        ["otroDni", otroDni, bytes],
        ["otroSexo", otroSexo, bytes],
        ["otroDniSinCara", otroDni, gris],
      ];')
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
    if (Test-Path ($ruta + ".bak-identidad-variantes2")) { Mal ("Ya existe " + $t + ".bak-identidad-variantes2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-identidad-variantes2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-identidad-variantes2): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad-variantes2") -Destination $ruta -Force }
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
Ok "LISTO: segunda ronda de variantes lista."
Write-Host ""
