# aplicar-permisos-ojo-app.ps1 - App (PROXIMA build): tarjeta PERMISOS ("el ojo") dentro de Familia y amigos.
# Luciano (04/11/2026): una tarjeta adentro de Familia y amigos, con la estructura "PAPA -> VOS" / "VOS -> PAPA": te ve (ojo), recibe tu SOS (sirena), lo ves, recibis su SOS. Uno o el otro puede cortar; el otro recibe un aviso; siempre queda al menos una persona que reciba el SOS.
# Requiere aplicar antes aplicar-familia-sos-nombres-app.ps1 y el instalador del servidor aplicar-permisos-ojo-panel.ps1 (sin el servidor la tarjeta no se muestra). Toca src\FamiliaPantalla.tsx y src\remoteApi.ts (respaldo .bak-permisos).
# Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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
foreach ($f in @("src\FamiliaPantalla.tsx", "src\remoteApi.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function listaDeNombres') -eq 0) { Mal "Falta aplicar primero aplicar-familia-sos-nombres-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function BloquePersona') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\remoteApi.ts', 'permisos: llamada al servidor', '/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */
', '/** Prende o apaga UNA llave de los permisos con otra persona. El servidor le avisa a ella y no deja apagar al ultimo que recibe un SOS. */
export async function setFamilyPermission(
  enrollment: NativeEnrollment,
  personId: string,
  key: "teVe" | "recibeTuSos" | "loVes" | "recibisSuSos",
  on: boolean,
) {
  await nativeRequest(enrollment, "/api/native/family/perm", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, personId, key, on }),
  });
}

/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */
'),
    @('src\FamiliaPantalla.tsx', 'permisos: importar la llamada', 'import { fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, type FamilyPerson } from "./remoteApi";', 'import { fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, setFamilyPermission, type FamilyPerson } from "./remoteApi";'),
    @('src\FamiliaPantalla.tsx', 'permisos: ojo, filas y bloque por persona', '/** A quien le suena el SOS de esta persona', '// ---------------------------------------------------------------------------
// Permisos (el ojo). Cada persona de la lista trae `permisos` del servidor: cuatro llaves, dos de cada lado ("Papa -> vos" y "vos -> Papa").
// Una llave vale si los DOS lados estan prendidos: `mine` es el mio y `theirs` el de la otra persona; uno o el otro puede cortarla.
// El servidor no deja apagar al ULTIMO que recibe un SOS (siempre tiene que quedar al menos una persona) y con un menor no se corta nada.
// ---------------------------------------------------------------------------
type Llave = { on: boolean; mine: boolean; theirs: boolean; ultimo?: boolean };
type ClavePermiso = "teVe" | "recibeTuSos" | "loVes" | "recibisSuSos";
type Permisos = { locked: boolean; teVe: Llave; recibeTuSos: Llave; loVes: Llave; recibisSuSos: Llave };
type PersonaConPermisos = FamilyPerson & { permisos?: Permisos };

const ROL_CHIP: Record<string, string> = { adulto: "Adulto", menor: "Menor", amigo: "Amigo" };

/** Texto de cada error del servidor al tocar una llave. */
function textoDeLlave(nombre: string, codigo: string): string | null {
  if (codigo === "last_recipient_other") return `Sos la única persona que recibe el SOS de ${nombre}. Pedile que sume a otra antes de apagarlo.`;
  if (codigo === "last_recipient_me") return `${nombre} es la única persona que recibe tu SOS. Sumá a otra antes de sacarla.`;
  if (codigo === "minor_locked") return "Con un menor no se puede cortar la ubicación ni el SOS.";
  return null;
}

/** El ojo (abierto / cerrado) y la sirena (con sonido / tachada), dibujados con vistas: sin librerias nuevas. */
function IconoPermiso({ tipo, apagado, color, tam = 24 }: { tipo: "ojo" | "sirena"; apagado: boolean; color: string | undefined; tam?: number }) {
  const g = Math.max(2, Math.round(tam / 12));
  const caja = { width: tam, height: tam, alignItems: "center", justifyContent: "center" } as const;
  if (tipo === "ojo") {
    if (apagado) {
      return (
        <View style={caja}>
          <View style={{ width: tam * 0.94, height: tam * 0.42, borderBottomLeftRadius: tam, borderBottomRightRadius: tam, borderBottomWidth: g, borderColor: color }} />
          <View style={{ position: "absolute", top: tam * 0.6, width: tam * 0.7, flexDirection: "row", justifyContent: "space-between" }}>
            <View style={{ width: g, height: tam * 0.16, borderRadius: g, backgroundColor: color, transform: [{ rotate: "28deg" }] }} />
            <View style={{ width: g, height: tam * 0.18, borderRadius: g, backgroundColor: color }} />
            <View style={{ width: g, height: tam * 0.16, borderRadius: g, backgroundColor: color, transform: [{ rotate: "-28deg" }] }} />
          </View>
        </View>
      );
    }
    return (
      <View style={caja}>
        <View style={{ width: tam, height: tam * 0.62, borderRadius: tam * 0.4, borderWidth: g, borderColor: color, alignItems: "center", justifyContent: "center" }}>
          <View style={{ width: tam * 0.3, height: tam * 0.3, borderRadius: tam, backgroundColor: color }} />
        </View>
      </View>
    );
  }
  return (
    <View style={caja}>
      <View style={{ width: tam * 0.1, height: tam * 0.14, borderRadius: g, backgroundColor: color, marginBottom: tam * 0.04 }} />
      <View style={{ width: tam * 0.64, height: tam * 0.5, borderTopLeftRadius: tam * 0.32, borderTopRightRadius: tam * 0.32, borderWidth: g, borderBottomWidth: 0, borderColor: color }} />
      <View style={{ width: tam * 0.92, height: g * 1.3, borderRadius: g, backgroundColor: color }} />
      {apagado ? <View style={{ position: "absolute", width: tam * 1.18, height: g * 1.3, borderRadius: g, backgroundColor: color, transform: [{ rotate: "-45deg" }] }} /> : null}
    </View>
  );
}

function estilosPermisos(P: Paleta) {
  return StyleSheet.create({
    persona: { borderColor: P.borde, borderRadius: 14, borderWidth: 1, overflow: "hidden" },
    cabecera: { alignItems: "center", flexDirection: "row", gap: 10, padding: 12 },
    avatar: { alignItems: "center", backgroundColor: P.campo, borderColor: P.borde, borderRadius: 18, borderWidth: 1, height: 36, justifyContent: "center", width: 36 },
    avatarLetra: { color: P.doradoTexto, fontSize: 16, fontWeight: "800" },
    nombre: { color: P.texto, flexShrink: 1, fontSize: 16, fontWeight: "800" },
    rol: { color: P.textoClaro, fontSize: 11.5, marginLeft: 2 },
    resumen: { flexDirection: "row", gap: 6, marginLeft: "auto" },
    cuerpo: { borderTopColor: P.borde, borderTopWidth: 1, gap: 10, padding: 12 },
    separador: { color: P.textoDebil, fontSize: 11.5, fontWeight: "800", letterSpacing: 1 },
    fila: { alignItems: "center", flexDirection: "row", gap: 12 },
    icono: { alignItems: "center", borderRadius: 14, borderWidth: 1, height: 44, justifyContent: "center", width: 44 },
    titulo: { color: P.texto, fontSize: 15, fontWeight: "700" },
    detalle: { color: P.textoDebil, fontSize: 12.5, lineHeight: 17 },
    pastilla: { alignItems: "center", borderRadius: 99, borderWidth: 1, flexDirection: "row", gap: 6, paddingHorizontal: 10, paddingVertical: 5 },
    punto: { borderRadius: 5, height: 9, width: 9 },
    pastillaTexto: { fontSize: 12.5, fontWeight: "800" },
    cartel: { backgroundColor: P.peligroFondo, borderColor: P.peligroBorde, borderRadius: 12, borderWidth: 1, padding: 10 },
    cartelTexto: { color: P.peligro, fontSize: 13, lineHeight: 18 },
    nota: { color: P.textoDebil, fontSize: 12.5, lineHeight: 17 },
  });
}

function FilaLlave({ P, tipo, titulo, base, nombre, llave, bloqueada, onPress }: { P: Paleta; tipo: "ojo" | "sirena"; titulo: string; base: string; nombre: string; llave: Llave; bloqueada: boolean; onPress: () => void }) {
  const sp = estilosPermisos(P);
  const encendida = llave.on;
  const tono = encendida ? P.exito : (P.peligroFuerte ?? P.peligro);
  const detalle = encendida ? base : !llave.mine ? "Lo apagaste vos." : `Lo apagó ${nombre} de su lado.`;
  const fija = bloqueada || (encendida && llave.ultimo === true);
  return (
    <Pressable accessibilityRole="switch" accessibilityState={{ checked: encendida, disabled: fija }} disabled={fija} onPress={onPress} style={[sp.fila, fija ? { opacity: 0.6 } : null]}>
      <View style={[sp.icono, { backgroundColor: encendida ? P.exitoFondo : P.peligroFondo, borderColor: encendida ? P.exitoBorde : P.peligroBorde }]}>
        <IconoPermiso tipo={tipo} apagado={!encendida} color={tono} tam={26} />
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text style={sp.titulo}>{titulo}</Text>
        <Text style={sp.detalle}>{detalle}</Text>
      </View>
      <View style={[sp.pastilla, { backgroundColor: encendida ? P.exitoFondo : P.peligroFondo, borderColor: encendida ? P.exitoBorde : P.peligroBorde }]}>
        <View style={[sp.punto, { backgroundColor: tono }]} />
        <Text style={[sp.pastillaTexto, { color: tono }]}>{encendida ? "Sí" : "No"}</Text>
      </View>
    </Pressable>
  );
}

function BloquePersona({ P, persona, abierta, onAbrir, onCambiar, aviso }: { P: Paleta; persona: PersonaConPermisos; abierta: boolean; onAbrir: () => void; onCambiar: (clave: ClavePermiso, encender: boolean) => void; aviso: string | null }) {
  const sp = estilosPermisos(P);
  const permisos = persona.permisos;
  if (!permisos) return null;
  const bloqueada = permisos.locked;
  const nombre = persona.name;
  const MAYUS = nombre.toUpperCase();
  const mini = (tipo: "ojo" | "sirena", llave: Llave) => <IconoPermiso key={`${tipo}-${llave === permisos.teVe ? "a" : llave === permisos.loVes ? "b" : llave === permisos.recibeTuSos ? "c" : "d"}`} tipo={tipo} apagado={!llave.on} color={llave.on ? P.exito : (P.peligroFuerte ?? P.peligro)} tam={18} />;
  const alternar = (clave: ClavePermiso) => () => onCambiar(clave, !permisos[clave].mine);
  const ultimoRecibe = permisos.recibisSuSos.on && permisos.recibisSuSos.ultimo === true;
  const ultimoEnvia = permisos.recibeTuSos.on && permisos.recibeTuSos.ultimo === true;
  return (
    <View style={sp.persona}>
      <Pressable accessibilityRole="button" accessibilityState={{ expanded: abierta }} onPress={onAbrir} style={sp.cabecera}>
        <View style={sp.avatar}><Text style={sp.avatarLetra}>{nombre.trim().slice(0, 1).toUpperCase()}</Text></View>
        <Text numberOfLines={1} style={sp.nombre}>{nombre}</Text>
        <Text style={sp.rol}>{persona.owner ? "Titular" : (ROL_CHIP[persona.role] ?? "")}</Text>
        <View style={sp.resumen}>
          {mini("ojo", permisos.teVe)}
          {mini("sirena", permisos.recibeTuSos)}
          {mini("ojo", permisos.loVes)}
          {mini("sirena", permisos.recibisSuSos)}
        </View>
      </Pressable>
      {abierta ? (
        <View style={sp.cuerpo}>
          <Text style={sp.separador}>{`${MAYUS} \u2192 VOS`}</Text>
          <FilaLlave P={P} tipo="ojo" titulo="Te ve" base="Mira tu ubicación" nombre={nombre} llave={permisos.teVe} bloqueada={bloqueada} onPress={alternar("teVe")} />
          <FilaLlave P={P} tipo="sirena" titulo="Recibe tu SOS" base="Le suena la sirena" nombre={nombre} llave={permisos.recibeTuSos} bloqueada={bloqueada} onPress={alternar("recibeTuSos")} />
          <Text style={sp.separador}>{`VOS \u2192 ${MAYUS}`}</Text>
          <FilaLlave P={P} tipo="ojo" titulo="Lo ves" base="Aparece en tu mapa" nombre={nombre} llave={permisos.loVes} bloqueada={bloqueada} onPress={alternar("loVes")} />
          <FilaLlave P={P} tipo="sirena" titulo="Recibís su SOS" base="Apagalo si estás en el cine o de viaje" nombre={nombre} llave={permisos.recibisSuSos} bloqueada={bloqueada} onPress={alternar("recibisSuSos")} />
          {bloqueada ? <Text style={sp.nota}>Con un menor no se puede cortar la ubicación ni el SOS.</Text> : null}
          {ultimoRecibe ? <View style={sp.cartel}><Text style={sp.cartelTexto}>{textoDeLlave(nombre, "last_recipient_other")}</Text></View> : null}
          {ultimoEnvia ? <View style={sp.cartel}><Text style={sp.cartelTexto}>{textoDeLlave(nombre, "last_recipient_me")}</Text></View> : null}
          {aviso ? <View style={sp.cartel}><Text style={sp.cartelTexto}>{aviso}</Text></View> : null}
        </View>
      ) : null}
    </View>
  );
}

/** A quien le suena el SOS de esta persona'),
    @('src\FamiliaPantalla.tsx', 'permisos: estado de la pantalla', '  const [siempre, setSiempre] = useState(true);
', '  const [siempre, setSiempre] = useState(true);
  const [abierta, setAbierta] = useState<string | null>(null);
  const [avisoPerm, setAvisoPerm] = useState<{ id: string; texto: string } | null>(null);
'),
    @('src\FamiliaPantalla.tsx', 'permisos: cambiar una llave', '  // Cualquiera puede salir de una familia, tambien un menor (al titular le llega un correo).
', '  async function cambiarPermiso(p: PersonaConPermisos, clave: ClavePermiso, encender: boolean) {
    if (!enrollment) return;
    setOcupado(true);
    setAvisoPerm(null);
    try {
      await setFamilyPermission(enrollment, p.id, clave, encender);
      await cargar(enrollment);
    } catch (error) {
      const codigo = error instanceof Error ? error.message : "";
      setAvisoPerm({ id: p.id, texto: textoDeLlave(p.name, codigo) ?? mensajeDeError(error) });
    } finally {
      setOcupado(false);
    }
  }

  // Cualquiera puede salir de una familia, tambien un menor (al titular le llega un correo).
'),
    @('src\FamiliaPantalla.tsx', 'permisos: tarjeta PERMISOS', '      {hayFamilia ? (
        <>
          <Text style={s.etiqueta}>SOS Y AYUDA</Text>
', '      {(people as PersonaConPermisos[]).some((p) => p.permisos) ? (
        <>
          <Text style={s.etiqueta}>PERMISOS</Text>
          <View style={s.tarjeta}>
            <Text style={botones.ayuda}>
              Elegí con quién compartís tu ubicación y a quién le suena tu SOS. Si alguno corta, el otro recibe un aviso. Siempre tiene que quedar al menos una persona que reciba tu SOS.
            </Text>
            {(people as PersonaConPermisos[]).filter((p) => p.permisos).map((p) => (
              <BloquePersona
                key={`perm-${p.id}`}
                P={P}
                persona={p}
                abierta={abierta === p.id}
                onAbrir={() => { setAvisoPerm(null); setAbierta(abierta === p.id ? null : p.id); }}
                onCambiar={(clave, encender) => void cambiarPermiso(p, clave, encender)}
                aviso={avisoPerm?.id === p.id ? avisoPerm.texto : null}
              />
            ))}
          </View>
        </>
      ) : null}

      {hayFamilia ? (
        <>
          <Text style={s.etiqueta}>SOS Y AYUDA</Text>
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
    if (Test-Path ($ruta + ".bak-permisos")) { Mal ("Ya existe " + $t + ".bak-permisos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-permisos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-permisos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-permisos") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-permisos") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
