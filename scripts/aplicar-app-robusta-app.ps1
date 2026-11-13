# aplicar-app-robusta-app.ps1 - App (PROXIMA build). Luciano (13/11/2026), en su Android: el mapa se queda en "Cargando el mapa" y la app lo pide de nuevo cada ~15 segundos sin decir por que; las tarjetas de Familia se esconden en silencio si no cargan.
#  - MapaEnApp.tsx: el cartel "Cargando" se saca solo (8 s o primer latido); las recargas automaticas se frenan en 3 por minuto; el MOTIVO se escribe en pantalla; a los 20 s sin latido aparece "El mapa esta tardando" + Reintentar.
#  - FamiliaPantalla.tsx: las tarjetas Vos / Cuidado / Remedios muestran "No se pudo cargar" + Reintentar; "Actualizar" las recarga; "Mas tarde" de HOY ya no se corta.
# Requiere aplicar-mapa-latido-app.ps1 y aplicar-remedios3-app.ps1. Toca src\MapaEnApp.tsx y src\FamiliaPantalla.tsx (respaldo .bak-robusta). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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
foreach ($f in @("src\MapaEnApp.tsx", "src\FamiliaPantalla.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function TarjetaFallo') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\MapaEnApp.tsx")).texto 'huboLatido') -eq 0) { Mal "Falta aplicar primero aplicar-mapa-latido-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto '(borrador ? [] : actual.items)') -eq 0) { Mal "Falta aplicar primero aplicar-remedios3-app.ps1."; return }
$cambios = @(
    @('src\MapaEnApp.tsx', 'mapa: estados nuevos (motivo, lento, recargas automaticas)', '  const [carga, setCarga] = useState(0);
', '  const [carga, setCarga] = useState(0);
  // Por que fallo (se muestra en pantalla), si el mapa tarda en dar el primer latido, y las recargas automaticas de este minuto (tope de 3).
  const [motivo, setMotivo] = useState("");
  const [lento, setLento] = useState(false);
  const recargasAuto = useRef<number[]>([]);
'),
    @('src\MapaEnApp.tsx', 'mapa: se borra el motivo al volver a cargar', '    setEstado("cargando");
    try {
      const vinculo = await loadNativeEnrollment();
', '    setEstado("cargando");
    setMotivo("");
    try {
      const vinculo = await loadNativeEnrollment();
'),
    @('src\MapaEnApp.tsx', 'mapa: motivo si no se pudo pedir el acceso + recarga automatica con tope', '    } catch {
      setEstado("error");
    }
  }, []);
', '    } catch (error) {
      setMotivo(`No se pudo pedir el acceso al mapa (${error instanceof Error ? error.message : "sin detalle"}).`);
      setEstado("error");
    }
  }, []);

  // Recargas automaticas (la ventana web se cerro, el mapa dejo de dar latidos): como mucho 3 por minuto. Despues se frena y se dice por que, en vez de reiniciar sin parar.
  const recargarSola = useCallback(
    (porque: string) => {
      const ahora = Date.now();
      recargasAuto.current = recargasAuto.current.filter((t) => ahora - t < 60_000);
      if (recargasAuto.current.length >= 3) {
        setMotivo(`${porque} Se reinició 3 veces en un minuto y se frenó para no gastar batería.`);
        setEstado("error");
        return;
      }
      recargasAuto.current.push(ahora);
      void cargar();
    },
    [cargar],
  );
'),
    @('src\MapaEnApp.tsx', 'mapa: el primer latido saca el cartel', '        ultimoLatido.current = Date.now();
        huboLatido.current = true;
        return;
', '        ultimoLatido.current = Date.now();
        huboLatido.current = true;
        setLento(false);
        setEstado((actual) => (actual === "cargando" ? "listo" : actual));
        return;
'),
    @('src\MapaEnApp.tsx', 'mapa: el cartel se saca solo a los 8 s y a los 20 s sin latido avisa', '  useEffect(() => {
    listoRef.current = estado === "listo";
  }, [estado]);
', '  useEffect(() => {
    listoRef.current = estado === "listo";
  }, [estado]);

  // onLoadEnd espera hasta el ultimo archivo de la pagina: si uno se cuelga, el cartel "Cargando" no se iba nunca. A los 8 segundos se saca y se ve lo que haya;
  // si a los 20 segundos el mapa todavia no dio ningun latido, aparece "El mapa esta tardando" con un boton para reintentar.
  useEffect(() => {
    setLento(false);
    if (!uri) return;
    const sacarCartel = setTimeout(() => setEstado((actual) => (actual === "cargando" ? "listo" : actual)), 8_000);
    const avisarLento = setTimeout(() => {
      if (!huboLatido.current) setLento(true);
    }, 20_000);
    return () => {
      clearTimeout(sacarCartel);
      clearTimeout(avisarLento);
    };
  }, [carga, uri]);
'),
    @('src\MapaEnApp.tsx', 'mapa: el vigilante de latidos usa el tope de recargas', '      if (Date.now() - ultimoLatido.current > 25_000 && Date.now() - cargadoEn.current > 60_000) void cargar();
    }, 5_000);
    return () => {
      suscripcion.remove();
      clearInterval(intervalo);
    };
  }, [cargar]);
', '      if (Date.now() - ultimoLatido.current > 25_000 && Date.now() - cargadoEn.current > 60_000) recargarSola("El mapa dejó de responder.");
    }, 5_000);
    return () => {
      suscripcion.remove();
      clearInterval(intervalo);
    };
  }, [recargarSola]);
'),
    @('src\MapaEnApp.tsx', 'mapa: errores de la ventana web con su motivo', '          onError={() => setEstado("error")}
          onHttpError={() => setEstado("error")}
          onMessage={alMensaje}
          // Si el motor del mapa se muere (poca memoria, segundo plano), se vuelve a cargar en vez de quedar en blanco o congelado.
          onRenderProcessGone={() => void cargar()}
          onContentProcessDidTerminate={() => void cargar()}
', '          onError={(evento: unknown) => {
            const ne = (evento as { nativeEvent?: { description?: string; code?: number } }).nativeEvent;
            setMotivo(`No se pudo abrir la página (${ne?.description || ne?.code || "sin detalle"}).`);
            setEstado("error");
          }}
          onHttpError={(evento: unknown) => {
            const ne = (evento as { nativeEvent?: { statusCode?: number } }).nativeEvent;
            setMotivo(`El servidor contestó con el error ${ne?.statusCode ?? "?"} al abrir el mapa.`);
            setEstado("error");
          }}
          onMessage={alMensaje}
          // Si el motor del mapa se muere (poca memoria, segundo plano), se vuelve a cargar (como mucho 3 veces por minuto) en vez de quedar en blanco o congelado.
          onRenderProcessGone={(evento: unknown) => {
            const ne = (evento as { nativeEvent?: { didCrash?: boolean } }).nativeEvent;
            recargarSola(ne?.didCrash ? "La ventana del mapa falló." : "Android cerró la ventana del mapa (poca memoria).");
          }}
          onContentProcessDidTerminate={() => recargarSola("La ventana del mapa se cerró.")}
'),
    @('src\MapaEnApp.tsx', 'mapa: el motivo se ve en el cartel de error', 'Revisá que haya internet y probá de nuevo.</Text>
', 'Revisá que haya internet y probá de nuevo.</Text>
          {motivo ? <Text style={s.veloMotivo}>{motivo}</Text> : null}
'),
    @('src\MapaEnApp.tsx', 'mapa: aviso "esta tardando" con Reintentar', '      {estado === "sin_vinculo" ? (
', '      {estado === "listo" && lento ? (
        <View style={s.avisoLento}>
          <Text style={s.avisoLentoTexto}>El mapa está tardando en abrir.</Text>
          <Pressable accessibilityRole="button" onPress={() => void cargar()}>
            <Text style={s.avisoLentoBoton}>Reintentar</Text>
          </Pressable>
        </View>
      ) : null}

      {estado === "sin_vinculo" ? (
'),
    @('src\MapaEnApp.tsx', 'mapa: estilos del motivo y del aviso', '    botonTexto: { color: P.doradoTexto, fontSize: 15, fontWeight: "800" },
  });
', '    botonTexto: { color: P.doradoTexto, fontSize: 15, fontWeight: "800" },
    veloMotivo: { color: P.textoDebil ?? P.textoSuave, fontSize: 12, lineHeight: 17, textAlign: "center" },
    avisoLento: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 14, borderWidth: 1, bottom: 10, flexDirection: "row", gap: 12, justifyContent: "space-between", left: 10, padding: 12, position: "absolute", right: 10 },
    avisoLentoTexto: { color: P.texto, flex: 1, fontSize: 13.5 },
    avisoLentoBoton: { color: P.doradoTexto, fontSize: 14, fontWeight: "800", textDecorationLine: "underline" },
  });
'),
    @('src\FamiliaPantalla.tsx', 'familia: tarjeta "No se pudo cargar" con Reintentar', '/** "Vos": tu nombre, este telefono,', '/** Cuando una tarjeta no se pudo cargar (sin internet, o el servidor no contesto): lo dice y deja reintentar, en vez de desaparecer sin avisar. */
function TarjetaFallo({ P, titulo, onReintentar }: { P: Paleta; titulo: string; onReintentar: () => void }) {
  return (
    <View style={{ alignItems: "center", borderColor: P.borde, borderRadius: 14, borderWidth: 1, flexDirection: "row", gap: 12, justifyContent: "space-between", padding: 12 }}>
      <Text style={{ color: P.textoSuave, flex: 1, fontSize: 13.5 }}>{`No se pudo cargar: ${titulo}.`}</Text>
      <Pressable accessibilityRole="button" accessibilityLabel={`Reintentar: ${titulo}`} onPress={onReintentar}>
        <Text style={{ color: P.doradoTexto, fontSize: 14, fontWeight: "800", textDecorationLine: "underline" }}>Reintentar</Text>
      </Pressable>
    </View>
  );
}

/** "Vos": tu nombre, este telefono,'),
    @('src\FamiliaPantalla.tsx', 'familia: Cuidado recuerda si fallo', '  const [cuidado, setCuidado] = useState<CuidadoEstado | null>(null);
', '  const [cuidado, setCuidado] = useState<CuidadoEstado | null>(null);
  const [fallo, setFallo] = useState(false);
'),
    @('src\FamiliaPantalla.tsx', 'familia: Cuidado marca el fallo', '      setCuidado(await fetchCare(enrollment));
    } catch {
      // Sin conexion o con un servidor viejo: la tarjeta simplemente no se muestra.
    }
', '      setFallo(false);
      setCuidado(await fetchCare(enrollment));
    } catch {
      setFallo(true);
    }
'),
    @('src\FamiliaPantalla.tsx', 'familia: Cuidado muestra "No se pudo cargar"', '  if (!cuidado) return null;
', '  if (!cuidado) return fallo ? <TarjetaFallo P={P} titulo="Cuidado" onReintentar={() => void cargar()} /> : null;
'),
    @('src\FamiliaPantalla.tsx', 'familia: Remedios recuerda si fallo', '  const [rem, setRem] = useState<RemediosEstado | null>(null);
', '  const [rem, setRem] = useState<RemediosEstado | null>(null);
  const [fallo, setFallo] = useState(false);
'),
    @('src\FamiliaPantalla.tsx', 'familia: Remedios marca el fallo', '      setRem(await fetchRemedios(enrollment));
    } catch {
      // Sin conexion o con un servidor viejo: la tarjeta simplemente no se muestra.
    }
', '      setFallo(false);
      setRem(await fetchRemedios(enrollment));
    } catch {
      setFallo(true);
    }
'),
    @('src\FamiliaPantalla.tsx', 'familia: Remedios muestra "No se pudo cargar"', '  if (!rem) return null;
', '  if (!rem) return fallo ? <TarjetaFallo P={P} titulo="Remedios" onReintentar={() => void cargar()} /> : null;
'),
    @('src\FamiliaPantalla.tsx', 'familia: Vos con Reintentar', '  const [vos, setVos] = useState<FamiliaVos | null>(null);
  useEffect(() => {
    let cancelado = false;
    void fetchFamilyMe(enrollment)
      .then((r) => {
        if (!cancelado) setVos(r);
      })
      .catch(() => undefined);
    return () => {
      cancelado = true;
    };
  }, [enrollment]);
  if (!vos) return null;
', '  const [vos, setVos] = useState<FamiliaVos | null>(null);
  const [fallo, setFallo] = useState(false);
  const [intento, setIntento] = useState(0);
  useEffect(() => {
    let cancelado = false;
    setFallo(false);
    void fetchFamilyMe(enrollment)
      .then((r) => {
        if (!cancelado) setVos(r);
      })
      .catch(() => {
        if (!cancelado) setFallo(true);
      });
    return () => {
      cancelado = true;
    };
  }, [enrollment, intento]);
  if (!vos) return fallo ? <TarjetaFallo P={P} titulo="tu identificación" onReintentar={() => setIntento((n) => n + 1)} /> : null;
'),
    @('src\FamiliaPantalla.tsx', 'familia: "Más tarde" no se corta', '<Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Más tarde</Text>', '<Text maxFontSizeMultiplier={TOPE_LETRA} numberOfLines={1} style={[sp.nota, { flexShrink: 0 }]}>Más tarde</Text>'),
    @('src\FamiliaPantalla.tsx', 'familia: contador para recargar las tarjetas', 'const [mensaje, setMensaje] = useState("");
', 'const [mensaje, setMensaje] = useState("");
  // "Actualizar" tambien recarga las tarjetas Vos, Cuidado y Remedios (se vuelven a montar con otra clave).
  const [recarga, setRecarga] = useState(0);
'),
    @('src\FamiliaPantalla.tsx', 'familia: Actualizar recarga las tarjetas', '<Pressable accessibilityRole="button" hitSlop={10} onPress={() => { setMensaje(""); void cargar(enrollment); }}>', '<Pressable accessibilityRole="button" hitSlop={10} onPress={() => { setMensaje(""); setRecarga((n) => n + 1); void cargar(enrollment); }}>'),
    @('src\FamiliaPantalla.tsx', 'familia: clave de la tarjeta Vos', '<TarjetaVos P={P} enrollment={enrollment} botones={botones} />', '<TarjetaVos key={`vos-${recarga}`} P={P} enrollment={enrollment} botones={botones} />'),
    @('src\FamiliaPantalla.tsx', 'familia: clave de la tarjeta Cuidado', '{enrollment ? <TarjetaCuidado P={P} enrollment={enrollment} botones={botones} onSosApagado={setSosApagado} /> : null}', '{enrollment ? <TarjetaCuidado key={`cuidado-${recarga}`} P={P} enrollment={enrollment} botones={botones} onSosApagado={setSosApagado} /> : null}'),
    @('src\FamiliaPantalla.tsx', 'familia: clave de la tarjeta Remedios', '{enrollment ? <TarjetaRemedios P={P} enrollment={enrollment} botones={botones} /> : null}', '{enrollment ? <TarjetaRemedios key={`remedios-${recarga}`} P={P} enrollment={enrollment} botones={botones} /> : null}')
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
    if (Test-Path ($ruta + ".bak-robusta")) { Mal ("Ya existe " + $t + ".bak-robusta. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-robusta"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-robusta): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-robusta") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-robusta") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android e iPhone)."
Write-Host ""
