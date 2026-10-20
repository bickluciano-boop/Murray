# aplicar-ms-en-claves-app.ps1 - Ojo Guard MS deja de ser una tarjeta aparte de Ajustes: pasa adentro de "Claves y Seguridad" (con los dos iconos).
# Luciano (20/10/2026): "en Ajustes esta Ojo Guard MS y abajo a la derecha dice Panel y es el mismo boton repetido... no puede estar en Claves y Seguridad con los dos iconos?"
# (la tarjeta y el boton Panel usaban el mismo icono y el mismo nombre, y parecian lo mismo; no lo son: Panel abre la consola y la tarjeta vincula y sincroniza este telefono).
#  - Ajustes: desaparece la tarjeta "Ojo Guard MS". La tarjeta "Claves y Seguridad" muestra los dos iconos (llave y conexion) y dice "PIN de admin, evidencia y Ojo Guard MS (sin vincular / conectado...)".
#  - Adentro de Claves y Seguridad estan, como antes, las claves y, abajo, la seccion "Ojo Guard MS - Telefono principal" con todos sus botones (enviar codigo, vincular, sincronizar, acceso seguro).
#  - "Vincular" del Inicio sigue llevando a esa seccion. El boton Panel de la barra de abajo no cambia. No se saca ninguna funcion.
# Cambia solo src\GruposConfiguracion.tsx (y solo si es el que mando Luciano el 20/10/2026: se comprueba con una huella SHA-256). Va en la carpeta de la APP (la que tiene app.json).
# Respaldo .bak-msclaves. Es codigo de la app: sale en la PROXIMA build (Android e iPhone).
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
$archivo = "src\GruposConfiguracion.tsx"
if (-not (Test-Path (Join-Path $raiz $archivo))) { Mal ("No encuentro " + $archivo + " en esta carpeta."); return }
$f = Leer (Join-Path $raiz $archivo)
if ((Contar $f.texto 'iconosDobles') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
function ShaTexto([string]$t) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($t -replace "`r`n", "`n"))))).Replace("-", "").ToLower()
}
$original = "0274dc667cca1b5c7f7fe77b0298138daaa13d97ae570d691ca55b1019bd967d"
$final = "2e6014efe0303cf7b2602d44457bd72eacec0a3fe1ea622c7b8b37db56fb1b74"
$huella = ShaTexto $f.texto
if ($huella -ne $original) { Mal ($archivo + " no es el del 20/10/2026 (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
Ok "GruposConfiguracion.tsx es el del 20/10/2026"
$cambios = @(
    @('src\GruposConfiguracion.tsx', 'conexion se ve dentro de Claves y Seguridad', '  return grupo === actual;
}
', ('  // La conexi' + [char]0x00f3 + 'n con Ojo Guard MS se ve dentro de Claves y Seguridad (ya no tiene tarjeta propia); sigue abri' + [char]0x00e9 + 'ndose sola desde "Vincular" del Inicio.
  if (actual === "claves" && grupo === "conexion") return true;
  return grupo === actual;
}
')),
    @('src\GruposConfiguracion.tsx', 'texto de Claves y Seguridad', ('resumen: "Tus claves, la detecci' + [char]0x00f3 + 'n de intentos de desbloqueo y lo que se guarda como evidencia." },'), ('resumen: "Tus claves, la detecci' + [char]0x00f3 + 'n de intentos de desbloqueo, lo que se guarda como evidencia y c' + [char]0x00f3 + 'mo se conecta este tel' + [char]0x00e9 + 'fono con el panel de Ojo Guard MS." },')),
    @('src\GruposConfiguracion.tsx', 'estado de la conexion dentro de la tarjeta de Claves', ('  const tarjetas: Array<{ grupo: Exclude<GrupoConfiguracion, "permisos" | "perfil">; detalle: string }> = [
    { grupo: "claves", detalle: "PIN de admin, se' + [char]0x00f1 + 'uelo y evidencia" },'), ('  const estadoMs = conexion === "not-linked" ? "sin vincular" : conexion === "syncing" ? "buscando' + [char]0x2026 + '" : conexion === "executed" ? "orden ejecutada" : conexion === "offline" ? "sin conexi' + [char]0x00f3 + 'n" : "conectado";
  const tarjetas: Array<{ grupo: Exclude<GrupoConfiguracion, "permisos" | "perfil">; detalle: string }> = [
    { grupo: "claves", detalle: `PIN de admin, evidencia y Ojo Guard MS (${estadoMs})` },')),
    @('src\GruposConfiguracion.tsx', 'sin tarjeta propia de Ojo Guard MS', ('    { grupo: "proteccion", detalle: "Chequeo del tel' + [char]0x00e9 + 'fono y prueba de sirena" },
    {
      grupo: "conexion",
      detalle: conexion === "not-linked" ? "Sin vincular" : conexion === "syncing" ? "Buscando' + [char]0x2026 + '" : conexion === "executed" ? "Orden ejecutada" : conexion === "offline" ? "Sin conexi' + [char]0x00f3 + 'n" : "Conectado",
    },
'), ('    { grupo: "proteccion", detalle: "Chequeo del tel' + [char]0x00e9 + 'fono y prueba de sirena" },
')),
    @('src\GruposConfiguracion.tsx', 'los dos iconos en la tarjeta de Claves', '                <Image source={ICONOS[grupo]} style={s.icono} resizeMode="contain" />
', '                {grupo === "claves" ? (
                  <View style={s.iconosDobles}>
                    <Image source={ICONOS.claves} style={s.iconoDoble} resizeMode="contain" />
                    <Image source={ICONOS.conexion} style={s.iconoDoble} resizeMode="contain" />
                  </View>
                ) : (
                  <Image source={ICONOS[grupo]} style={s.icono} resizeMode="contain" />
                )}
'),
    @('src\GruposConfiguracion.tsx', 'la ultima fila queda con su lugar', '          })}
        </View>
      ))}
    </View>
  );
}

type CabeceraPantallaProps', '          })}
          {fila.length === 1 ? <View style={{ flex: 1 }} /> : null}
        </View>
      ))}
    </View>
  );
}

type CabeceraPantallaProps'),
    @('src\GruposConfiguracion.tsx', 'estilos de los dos iconos', '    icono: { height: 46, width: 46 },
', '    icono: { height: 46, width: 46 },
    iconosDobles: { alignItems: "center", flexDirection: "row", gap: 8, height: 46 },
    iconoDoble: { height: 38, width: 38 },
')
)
$ruta = Join-Path $raiz $archivo
$ok = $true
foreach ($c in $cambios) {
    $ancla = Ajustar $c[2] $f.crlf
    $cuantos = Contar $f.texto $ancla
    if ($cuantos -eq 1) { Ok ($c[1] + ": 1") } else { Mal ($c[1] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
if (Test-Path ($ruta + ".bak-msclaves")) { Mal "Ya existe src\GruposConfiguracion.tsx.bak-msclaves. No toco nada."; return }
Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-msclaves")
Ok "Respaldo creado: src\GruposConfiguracion.tsx.bak-msclaves"
$nuevo = $f.texto
foreach ($c in $cambios) { $nuevo = $nuevo.Replace((Ajustar $c[2] $f.crlf), (Ajustar $c[3] $f.crlf)) }
[System.IO.File]::WriteAllText($ruta, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
$v = Leer $ruta
if ((ShaTexto $v.texto) -ne $final) {
    Mal "Algo no salio bien (la huella final no coincide). Restauro desde el respaldo."
    Copy-Item -LiteralPath ($ruta + ".bak-msclaves") -Destination $ruta -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("src\GruposConfiguracion.tsx: largo " + $v.texto.Length + ", huella final correcta")
Write-Host ""
Ok "Archivo listo. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) { Mal "La revision de tipos encontro errores (arriba). No hagas la build todavia: mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: la app compila bien. Ojo Guard MS quedo adentro de Claves y Seguridad (con los dos iconos). Sale en la proxima BUILD."
Write-Host ""
