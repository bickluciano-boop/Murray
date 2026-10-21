# aplicar-estetica-app.ps1 - App Ojo Guard: estetica nueva (azul, blanco y dorado), solo COLORES.
# Luciano (21/10/2026): "no rompamos ningun codigo y no saquemos nada nuestro". La app tiene todos sus colores en un solo lugar (la paleta de App.tsx); las demas pantallas los reciben de ahi.
# Se cambian esos valores y nada mas: ninguna funcion, boton, texto ni pantalla cambia de lugar.
#  - Tema claro: fondo marfil, tarjetas blancas, texto azul marino, bordes azul grisaceo. Tema de noche: azul oscuro (no negro), texto marfil. El dorado queda de detalle (letras, bordes, avisos).
#  - Los botones principales (los que eran dorados) pasan a azul con letra blanca. La pantalla de guardia y la de Modo perdido siguen oscuras y doradas, como antes.
# Cambia solo App.tsx. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-esteticaapp. Es codigo de la app: sale en la PROXIMA build (Android e iPhone).
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
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto '// relleno de los botones principales: azul') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('App.tsx', 'colores comunes: botones principales en azul', '  // relleno de boton dorado: 11,7:1 con el texto en los dos temas
  doradoRelleno: "#f4c64e",
  // relleno de boton dorado secundario
  doradoRellenoMedio: "#d7ad42",
  // texto sobre boton dorado: oscuro SIEMPRE, incluso en tema claro
  sobreDorado: "#111",
', '  // relleno de los botones principales: azul (blanco sobre azul, 7,6:1)
  doradoRelleno: "#1F4FD1",
  // relleno de los botones principales, tono medio
  doradoRellenoMedio: "#3D6BEA",
  // texto sobre los botones principales: blanco en los dos temas
  sobreDorado: "#ffffff",
'),
    @('App.tsx', 'paleta de noche: azul oscuro, marfil y dorado', '  oscuro: {
    ...COMUNES,
    fondo: "#050505",   // fondo de la app
    superficie: "#111111",   // tarjetas y paneles
    superficieHonda: "#1a1a1a",   // cajas dentro de una tarjeta
    campo: "#181818",   // campos de texto
    borde: "#303030",   // bordes normales
    bordeMedio: "#373737",   // bordes algo mas marcados
    bordeFuerte: "#4c4c4c",   // bordes de botones secundarios
    texto: "#ffffff",   // texto principal
    textoSuave: "#eeeeee",   // texto principal atenuado
    textoMedio: "#d6d6d6",   // texto de parrafo
    textoClaro: "#bebebe",   // texto secundario
    textoTenue: "#aaaaaa",   // texto de apoyo
    textoDebil: "#838383",   // etiquetas y notas al pie
    marcador: "#6f6f6f",   // texto de ejemplo dentro de un campo
    doradoTexto: "#f4c64e",   // EL CAMBIO CLAVE: dorado como letra o linea
    doradoTextoSuave: "#f1d78f",   // dorado palido como letra
    doradoTextoMedio: "#dab047",   // dorado medio como letra
    doradoTenue: "#8d8272",   // ayudas en tono calido
    doradoBorde: "#836b2d",   // bordes dorados discretos
    doradoBordeMedio: "#ddb34c",   // bordes dorados medios
    doradoBordeFuerte: "#f4c64e",   // bordes dorados marcados
    doradoFondo: "#1e1a11",   // fondos calidos suaves
    doradoFondoFuerte: "#3b3016",   // fondos calidos marcados
    exito: "#82d896",   // verde de exito
    exitoTenue: "#9aa198",   // verde apagado
    exitoTenueClaro: "#b6c8ac",   // verde apagado claro
    exitoBorde: "#5d6b53",   // borde verde
    exitoFondo: "#17351f",   // fondo verde
    exitoSuperficie: "#1f231e",   // superficie verdosa
    peligro: "#f0b8b8",   // rojo de error
    peligroFuerte: "#ff9d9d",   // rojo de error marcado
    peligroBorde: "#a94a4a",   // borde rojo
    peligroBordeSuave: "#7d4a4a",   // borde rojo suave
    peligroFondo: "#261313",   // fondo rojo
    mapaFondo: "#10141a",   // paneles del mapa
    mapaTexto: "#8e9bad",   // texto sobre paneles del mapa
    mapaTextoFuerte: "#ffffff",   // titulo sobre paneles del mapa
    exitoClaro: "#9fd3a0",   // verde claro de confirmacion
    doradoBordeTenue: "#6b5720",   // borde dorado tenue
  },
', '  oscuro: {
    ...COMUNES,
    fondo: "#0B1020",   // fondo de la app
    superficie: "#121A33",   // tarjetas y paneles
    superficieHonda: "#18213F",   // cajas dentro de una tarjeta
    campo: "#0E1630",   // campos de texto
    borde: "#26304F",   // bordes normales
    bordeMedio: "#2F3A5E",   // bordes algo mas marcados
    bordeFuerte: "#46527A",   // bordes de botones secundarios
    texto: "#F5F0E6",   // texto principal
    textoSuave: "#E8E4DA",   // texto principal atenuado
    textoMedio: "#D5DBEC",   // texto de parrafo
    textoClaro: "#B9C2DB",   // texto secundario
    textoTenue: "#A9B3CE",   // texto de apoyo
    textoDebil: "#8791B0",   // etiquetas y notas al pie
    marcador: "#6F7A9B",   // texto de ejemplo dentro de un campo
    doradoTexto: "#FFC247",   // EL CAMBIO CLAVE: dorado como letra o linea
    doradoTextoSuave: "#FFD477",   // dorado palido como letra
    doradoTextoMedio: "#F0B840",   // dorado medio como letra
    doradoTenue: "#B5A57A",   // ayudas en tono calido
    doradoBorde: "#7A5F22",   // bordes dorados discretos
    doradoBordeMedio: "#E3A92B",   // bordes dorados medios
    doradoBordeFuerte: "#FFC247",   // bordes dorados marcados
    doradoFondo: "#211C12",   // fondos calidos suaves
    doradoFondoFuerte: "#3A2E14",   // fondos calidos marcados
    exito: "#82d896",   // verde de exito
    exitoTenue: "#9aa198",   // verde apagado
    exitoTenueClaro: "#b6c8ac",   // verde apagado claro
    exitoBorde: "#5d6b53",   // borde verde
    exitoFondo: "#17351f",   // fondo verde
    exitoSuperficie: "#1f231e",   // superficie verdosa
    peligro: "#f0b8b8",   // rojo de error
    peligroFuerte: "#ff9d9d",   // rojo de error marcado
    peligroBorde: "#a94a4a",   // borde rojo
    peligroBordeSuave: "#7d4a4a",   // borde rojo suave
    peligroFondo: "#2A1416",   // fondo rojo
    mapaFondo: "#101A33",   // paneles del mapa
    mapaTexto: "#9AA6C2",   // texto sobre paneles del mapa
    mapaTextoFuerte: "#ffffff",   // titulo sobre paneles del mapa
    exitoClaro: "#9fd3a0",   // verde claro de confirmacion
    doradoBordeTenue: "#5B4A1C",   // borde dorado tenue
  },
'),
    @('App.tsx', 'paleta clara: blanco, azul y dorado', '  claro: {
    ...COMUNES,
    fondo: "#f2ede2",   // fondo de la app
    superficie: "#ffffff",   // tarjetas y paneles
    superficieHonda: "#f3eee3",   // cajas dentro de una tarjeta
    campo: "#ffffff",   // campos de texto
    borde: "#ddd5c4",   // bordes normales
    bordeMedio: "#cfc5b0",   // bordes algo mas marcados
    bordeFuerte: "#b9ad94",   // bordes de botones secundarios
    texto: "#14120e",   // texto principal
    textoSuave: "#2a2620",   // texto principal atenuado
    textoMedio: "#3d382f",   // texto de parrafo
    textoClaro: "#4d463c",   // texto secundario
    textoTenue: "#5c564a",   // texto de apoyo
    textoDebil: "#6b6459",   // etiquetas y notas al pie
    marcador: "#8b8478",   // texto de ejemplo dentro de un campo
    doradoTexto: "#7f6727",   // EL CAMBIO CLAVE: dorado como letra o linea
    doradoTextoSuave: "#6b5720",   // dorado palido como letra
    doradoTextoMedio: "#7a5f14",   // dorado medio como letra
    doradoTenue: "#7a6e58",   // ayudas en tono calido
    doradoBorde: "#c9a94a",   // bordes dorados discretos
    doradoBordeMedio: "#c09121",   // bordes dorados medios
    doradoBordeFuerte: "#b8912a",   // bordes dorados marcados
    doradoFondo: "#fbf3df",   // fondos calidos suaves
    doradoFondoFuerte: "#f6e7bc",   // fondos calidos marcados
    exito: "#1e7a3c",   // verde de exito
    exitoTenue: "#4f6b55",   // verde apagado
    exitoTenueClaro: "#5d7a63",   // verde apagado claro
    exitoBorde: "#8fae97",   // borde verde
    exitoFondo: "#dff3e4",   // fondo verde
    exitoSuperficie: "#edf2ec",   // superficie verdosa
    peligro: "#a32020",   // rojo de error
    peligroFuerte: "#8f1515",   // rojo de error marcado
    peligroBorde: "#c97878",   // borde rojo
    peligroBordeSuave: "#d79a9a",   // borde rojo suave
    peligroFondo: "#fbe6e6",   // fondo rojo
    mapaFondo: "#eaeef5",   // paneles del mapa
    mapaTexto: "#4a5567",   // texto sobre paneles del mapa
    mapaTextoFuerte: "#1b2430",   // titulo sobre paneles del mapa
    exitoClaro: "#3d7a4e",   // verde claro de confirmacion
    doradoBordeTenue: "#d4b45e",   // borde dorado tenue
  },', '  claro: {
    ...COMUNES,
    fondo: "#FAF8F3",   // fondo de la app
    superficie: "#ffffff",   // tarjetas y paneles
    superficieHonda: "#EEF2FB",   // cajas dentro de una tarjeta
    campo: "#ffffff",   // campos de texto
    borde: "#E3E7F1",   // bordes normales
    bordeMedio: "#D3D9EA",   // bordes algo mas marcados
    bordeFuerte: "#B4BDD6",   // bordes de botones secundarios
    texto: "#14213D",   // texto principal
    textoSuave: "#1E2B4D",   // texto principal atenuado
    textoMedio: "#2E3B5E",   // texto de parrafo
    textoClaro: "#3E4A6B",   // texto secundario
    textoTenue: "#4C5878",   // texto de apoyo
    textoDebil: "#5B6580",   // etiquetas y notas al pie
    marcador: "#8A93AB",   // texto de ejemplo dentro de un campo
    doradoTexto: "#7A5200",   // EL CAMBIO CLAVE: dorado como letra o linea
    doradoTextoSuave: "#8A6410",   // dorado palido como letra
    doradoTextoMedio: "#7A5200",   // dorado medio como letra
    doradoTenue: "#6E7690",   // ayudas en tono calido
    doradoBorde: "#E3C16A",   // bordes dorados discretos
    doradoBordeMedio: "#E3A92B",   // bordes dorados medios
    doradoBordeFuerte: "#C98F12",   // bordes dorados marcados
    doradoFondo: "#FFF6DD",   // fondos calidos suaves
    doradoFondoFuerte: "#FBE7B0",   // fondos calidos marcados
    exito: "#1e7a3c",   // verde de exito
    exitoTenue: "#4f6b55",   // verde apagado
    exitoTenueClaro: "#5d7a63",   // verde apagado claro
    exitoBorde: "#8fae97",   // borde verde
    exitoFondo: "#dff3e4",   // fondo verde
    exitoSuperficie: "#edf2ec",   // superficie verdosa
    peligro: "#a32020",   // rojo de error
    peligroFuerte: "#8f1515",   // rojo de error marcado
    peligroBorde: "#c97878",   // borde rojo
    peligroBordeSuave: "#d79a9a",   // borde rojo suave
    peligroFondo: "#FBEAE7",   // fondo rojo
    mapaFondo: "#EAF0F7",   // paneles del mapa
    mapaTexto: "#4A5567",   // texto sobre paneles del mapa
    mapaTextoFuerte: "#14213D",   // titulo sobre paneles del mapa
    exitoClaro: "#3d7a4e",   // verde claro de confirmacion
    doradoBordeTenue: "#EBD39A",   // borde dorado tenue
  },')
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
    if (Test-Path ($ruta + ".bak-esteticaapp")) { Mal ("Ya existe " + $t + ".bak-esteticaapp. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-esteticaapp"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-esteticaapp): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-esteticaapp") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: App.tsx quedo con la paleta nueva (azul, blanco y dorado). Sale en la proxima build."
Write-Host ""
