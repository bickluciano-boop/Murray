# Genera scripts/aplicar-app-robusta-app.ps1 (app, PROXIMA build). Luciano (13/11/2026), en su Android (Redmi, WebView 157):
#  - El mapa de la app se queda en "Cargando el mapa" y la app lo vuelve a pedir cada ~15 s, sin decir por que.
#  - Las tarjetas Vos / Cuidado / Remedios de Familia se esconden en silencio si no cargan; "Actualizar" no las recarga.
#  - En HOY de Remedios "Mas tarde" se corta y se ve solo "Mas".
# MapaEnApp.tsx: el cartel "Cargando" se saca solo a los 8 s o con el primer latido; las recargas automaticas (ventana web cerrada, mapa sin latido) se frenan en 3 por minuto;
#   el motivo se escribe EN PANTALLA (error de red, error HTTP, "Android cerro la ventana del mapa (poca memoria)"); si a los 20 s no hubo latido aparece "El mapa esta tardando" + Reintentar.
# FamiliaPantalla.tsx: las tarjetas muestran "No se pudo cargar" + Reintentar; "Actualizar" las recarga; "Mas tarde" ya no se corta.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
pares = []   # (archivo, nombre, viejo, nuevo)
def fila(archivo, nombre, viejo, nuevo):
    pares.append((archivo, nombre, viejo, nuevo))

# ---------------- MapaEnApp.tsx ----------------
M = 'src\\MapaEnApp.tsx'
fila(M, 'mapa: estados nuevos (motivo, lento, recargas automaticas)', '  const [carga, setCarga] = useState(0);\n',
 '  const [carga, setCarga] = useState(0);\n'
 '  // Por que fallo (se muestra en pantalla), si el mapa tarda en dar el primer latido, y las recargas automaticas de este minuto (tope de 3).\n'
 '  const [motivo, setMotivo] = useState("");\n'
 '  const [lento, setLento] = useState(false);\n'
 '  const recargasAuto = useRef<number[]>([]);\n')
fila(M, 'mapa: se borra el motivo al volver a cargar', '    setEstado("cargando");\n    try {\n      const vinculo = await loadNativeEnrollment();\n',
 '    setEstado("cargando");\n    setMotivo("");\n    try {\n      const vinculo = await loadNativeEnrollment();\n')
fila(M, 'mapa: motivo si no se pudo pedir el acceso + recarga automatica con tope', '    } catch {\n      setEstado("error");\n    }\n  }, []);\n',
 '    } catch (error) {\n'
 '      setMotivo(`No se pudo pedir el acceso al mapa (${error instanceof Error ? error.message : "sin detalle"}).`);\n'
 '      setEstado("error");\n'
 '    }\n  }, []);\n\n'
 '  // Recargas automaticas (la ventana web se cerro, el mapa dejo de dar latidos): como mucho 3 por minuto. Despues se frena y se dice por que, en vez de reiniciar sin parar.\n'
 '  const recargarSola = useCallback(\n'
 '    (porque: string) => {\n'
 '      const ahora = Date.now();\n'
 '      recargasAuto.current = recargasAuto.current.filter((t) => ahora - t < 60_000);\n'
 '      if (recargasAuto.current.length >= 3) {\n'
 '        setMotivo(`${porque} Se reinició 3 veces en un minuto y se frenó para no gastar batería.`);\n'
 '        setEstado("error");\n'
 '        return;\n'
 '      }\n'
 '      recargasAuto.current.push(ahora);\n'
 '      void cargar();\n'
 '    },\n'
 '    [cargar],\n'
 '  );\n')
fila(M, 'mapa: el primer latido saca el cartel', '        ultimoLatido.current = Date.now();\n        huboLatido.current = true;\n        return;\n',
 '        ultimoLatido.current = Date.now();\n        huboLatido.current = true;\n        setLento(false);\n        setEstado((actual) => (actual === "cargando" ? "listo" : actual));\n        return;\n')
fila(M, 'mapa: el cartel se saca solo a los 8 s y a los 20 s sin latido avisa', '  useEffect(() => {\n    listoRef.current = estado === "listo";\n  }, [estado]);\n',
 '  useEffect(() => {\n    listoRef.current = estado === "listo";\n  }, [estado]);\n\n'
 '  // onLoadEnd espera hasta el ultimo archivo de la pagina: si uno se cuelga, el cartel "Cargando" no se iba nunca. A los 8 segundos se saca y se ve lo que haya;\n'
 '  // si a los 20 segundos el mapa todavia no dio ningun latido, aparece "El mapa esta tardando" con un boton para reintentar.\n'
 '  useEffect(() => {\n'
 '    setLento(false);\n'
 '    if (!uri) return;\n'
 '    const sacarCartel = setTimeout(() => setEstado((actual) => (actual === "cargando" ? "listo" : actual)), 8_000);\n'
 '    const avisarLento = setTimeout(() => {\n'
 '      if (!huboLatido.current) setLento(true);\n'
 '    }, 20_000);\n'
 '    return () => {\n'
 '      clearTimeout(sacarCartel);\n'
 '      clearTimeout(avisarLento);\n'
 '    };\n'
 '  }, [carga, uri]);\n')
fila(M, 'mapa: el vigilante de latidos usa el tope de recargas', '      if (Date.now() - ultimoLatido.current > 25_000 && Date.now() - cargadoEn.current > 60_000) void cargar();\n    }, 5_000);\n    return () => {\n      suscripcion.remove();\n      clearInterval(intervalo);\n    };\n  }, [cargar]);\n',
 '      if (Date.now() - ultimoLatido.current > 25_000 && Date.now() - cargadoEn.current > 60_000) recargarSola("El mapa dejó de responder.");\n    }, 5_000);\n    return () => {\n      suscripcion.remove();\n      clearInterval(intervalo);\n    };\n  }, [recargarSola]);\n')
fila(M, 'mapa: errores de la ventana web con su motivo', '          onError={() => setEstado("error")}\n          onHttpError={() => setEstado("error")}\n          onMessage={alMensaje}\n          // Si el motor del mapa se muere (poca memoria, segundo plano), se vuelve a cargar en vez de quedar en blanco o congelado.\n          onRenderProcessGone={() => void cargar()}\n          onContentProcessDidTerminate={() => void cargar()}\n',
 '          onError={(evento: unknown) => {\n'
 '            const ne = (evento as { nativeEvent?: { description?: string; code?: number } }).nativeEvent;\n'
 '            setMotivo(`No se pudo abrir la página (${ne?.description || ne?.code || "sin detalle"}).`);\n'
 '            setEstado("error");\n'
 '          }}\n'
 '          onHttpError={(evento: unknown) => {\n'
 '            const ne = (evento as { nativeEvent?: { statusCode?: number } }).nativeEvent;\n'
 '            setMotivo(`El servidor contestó con el error ${ne?.statusCode ?? "?"} al abrir el mapa.`);\n'
 '            setEstado("error");\n'
 '          }}\n'
 '          onMessage={alMensaje}\n'
 '          // Si el motor del mapa se muere (poca memoria, segundo plano), se vuelve a cargar (como mucho 3 veces por minuto) en vez de quedar en blanco o congelado.\n'
 '          onRenderProcessGone={(evento: unknown) => {\n'
 '            const ne = (evento as { nativeEvent?: { didCrash?: boolean } }).nativeEvent;\n'
 '            recargarSola(ne?.didCrash ? "La ventana del mapa falló." : "Android cerró la ventana del mapa (poca memoria).");\n'
 '          }}\n'
 '          onContentProcessDidTerminate={() => recargarSola("La ventana del mapa se cerró.")}\n')
fila(M, 'mapa: el motivo se ve en el cartel de error', 'Revisá que haya internet y probá de nuevo.</Text>\n',
 'Revisá que haya internet y probá de nuevo.</Text>\n          {motivo ? <Text style={s.veloMotivo}>{motivo}</Text> : null}\n')
fila(M, 'mapa: aviso "esta tardando" con Reintentar', '      {estado === "sin_vinculo" ? (\n',
 '      {estado === "listo" && lento ? (\n'
 '        <View style={s.avisoLento}>\n'
 '          <Text style={s.avisoLentoTexto}>El mapa está tardando en abrir.</Text>\n'
 '          <Pressable accessibilityRole="button" onPress={() => void cargar()}>\n'
 '            <Text style={s.avisoLentoBoton}>Reintentar</Text>\n'
 '          </Pressable>\n'
 '        </View>\n'
 '      ) : null}\n\n'
 '      {estado === "sin_vinculo" ? (\n')
fila(M, 'mapa: estilos del motivo y del aviso', '    botonTexto: { color: P.doradoTexto, fontSize: 15, fontWeight: "800" },\n  });\n',
 '    botonTexto: { color: P.doradoTexto, fontSize: 15, fontWeight: "800" },\n'
 '    veloMotivo: { color: P.textoDebil ?? P.textoSuave, fontSize: 12, lineHeight: 17, textAlign: "center" },\n'
 '    avisoLento: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 14, borderWidth: 1, bottom: 10, flexDirection: "row", gap: 12, justifyContent: "space-between", left: 10, padding: 12, position: "absolute", right: 10 },\n'
 '    avisoLentoTexto: { color: P.texto, flex: 1, fontSize: 13.5 },\n'
 '    avisoLentoBoton: { color: P.doradoTexto, fontSize: 14, fontWeight: "800", textDecorationLine: "underline" },\n'
 '  });\n')

# ---------------- FamiliaPantalla.tsx ----------------
Fp = 'src\\FamiliaPantalla.tsx'
fila(Fp, 'familia: tarjeta "No se pudo cargar" con Reintentar', '/** "Vos": tu nombre, este telefono,',
 '/** Cuando una tarjeta no se pudo cargar (sin internet, o el servidor no contesto): lo dice y deja reintentar, en vez de desaparecer sin avisar. */\n'
 'function TarjetaFallo({ P, titulo, onReintentar }: { P: Paleta; titulo: string; onReintentar: () => void }) {\n'
 '  return (\n'
 '    <View style={{ alignItems: "center", borderColor: P.borde, borderRadius: 14, borderWidth: 1, flexDirection: "row", gap: 12, justifyContent: "space-between", padding: 12 }}>\n'
 '      <Text style={{ color: P.textoSuave, flex: 1, fontSize: 13.5 }}>{`No se pudo cargar: ${titulo}.`}</Text>\n'
 '      <Pressable accessibilityRole="button" accessibilityLabel={`Reintentar: ${titulo}`} onPress={onReintentar}>\n'
 '        <Text style={{ color: P.doradoTexto, fontSize: 14, fontWeight: "800", textDecorationLine: "underline" }}>Reintentar</Text>\n'
 '      </Pressable>\n'
 '    </View>\n'
 '  );\n'
 '}\n\n'
 '/** "Vos": tu nombre, este telefono,')
fila(Fp, 'familia: Cuidado recuerda si fallo', '  const [cuidado, setCuidado] = useState<CuidadoEstado | null>(null);\n',
 '  const [cuidado, setCuidado] = useState<CuidadoEstado | null>(null);\n  const [fallo, setFallo] = useState(false);\n')
fila(Fp, 'familia: Cuidado marca el fallo', '      setCuidado(await fetchCare(enrollment));\n    } catch {\n      // Sin conexion o con un servidor viejo: la tarjeta simplemente no se muestra.\n    }\n',
 '      setFallo(false);\n      setCuidado(await fetchCare(enrollment));\n    } catch {\n      setFallo(true);\n    }\n')
fila(Fp, 'familia: Cuidado muestra "No se pudo cargar"', '  if (!cuidado) return null;\n',
 '  if (!cuidado) return fallo ? <TarjetaFallo P={P} titulo="Cuidado" onReintentar={() => void cargar()} /> : null;\n')
fila(Fp, 'familia: Remedios recuerda si fallo', '  const [rem, setRem] = useState<RemediosEstado | null>(null);\n',
 '  const [rem, setRem] = useState<RemediosEstado | null>(null);\n  const [fallo, setFallo] = useState(false);\n')
fila(Fp, 'familia: Remedios marca el fallo', '      setRem(await fetchRemedios(enrollment));\n    } catch {\n      // Sin conexion o con un servidor viejo: la tarjeta simplemente no se muestra.\n    }\n',
 '      setFallo(false);\n      setRem(await fetchRemedios(enrollment));\n    } catch {\n      setFallo(true);\n    }\n')
fila(Fp, 'familia: Remedios muestra "No se pudo cargar"', '  if (!rem) return null;\n',
 '  if (!rem) return fallo ? <TarjetaFallo P={P} titulo="Remedios" onReintentar={() => void cargar()} /> : null;\n')
fila(Fp, 'familia: Vos con Reintentar', '  const [vos, setVos] = useState<FamiliaVos | null>(null);\n  useEffect(() => {\n    let cancelado = false;\n    void fetchFamilyMe(enrollment)\n      .then((r) => {\n        if (!cancelado) setVos(r);\n      })\n      .catch(() => undefined);\n    return () => {\n      cancelado = true;\n    };\n  }, [enrollment]);\n  if (!vos) return null;\n',
 '  const [vos, setVos] = useState<FamiliaVos | null>(null);\n  const [fallo, setFallo] = useState(false);\n  const [intento, setIntento] = useState(0);\n'
 '  useEffect(() => {\n    let cancelado = false;\n    setFallo(false);\n    void fetchFamilyMe(enrollment)\n      .then((r) => {\n        if (!cancelado) setVos(r);\n      })\n      .catch(() => {\n        if (!cancelado) setFallo(true);\n      });\n    return () => {\n      cancelado = true;\n    };\n  }, [enrollment, intento]);\n'
 '  if (!vos) return fallo ? <TarjetaFallo P={P} titulo="tu identificación" onReintentar={() => setIntento((n) => n + 1)} /> : null;\n')
fila(Fp, 'familia: "Más tarde" no se corta', '<Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Más tarde</Text>',
 '<Text maxFontSizeMultiplier={TOPE_LETRA} numberOfLines={1} style={[sp.nota, { flexShrink: 0 }]}>Más tarde</Text>')
fila(Fp, 'familia: contador para recargar las tarjetas', 'const [mensaje, setMensaje] = useState("");\n',
 'const [mensaje, setMensaje] = useState("");\n  // "Actualizar" tambien recarga las tarjetas Vos, Cuidado y Remedios (se vuelven a montar con otra clave).\n  const [recarga, setRecarga] = useState(0);\n')
fila(Fp, 'familia: Actualizar recarga las tarjetas', '<Pressable accessibilityRole="button" hitSlop={10} onPress={() => { setMensaje(""); void cargar(enrollment); }}>',
 '<Pressable accessibilityRole="button" hitSlop={10} onPress={() => { setMensaje(""); setRecarga((n) => n + 1); void cargar(enrollment); }}>')
fila(Fp, 'familia: clave de la tarjeta Vos', '<TarjetaVos P={P} enrollment={enrollment} botones={botones} />', '<TarjetaVos key={`vos-${recarga}`} P={P} enrollment={enrollment} botones={botones} />')
fila(Fp, 'familia: clave de la tarjeta Cuidado', '{enrollment ? <TarjetaCuidado P={P} enrollment={enrollment} botones={botones} onSosApagado={setSosApagado} /> : null}',
 '{enrollment ? <TarjetaCuidado key={`cuidado-${recarga}`} P={P} enrollment={enrollment} botones={botones} onSosApagado={setSosApagado} /> : null}')
fila(Fp, 'familia: clave de la tarjeta Remedios', '{enrollment ? <TarjetaRemedios P={P} enrollment={enrollment} botones={botones} /> : null}',
 '{enrollment ? <TarjetaRemedios key={`remedios-${recarga}`} P={P} enrollment={enrollment} botones={botones} /> : null}')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in pares) + "\n)\n"
cabeza = '''# aplicar-app-robusta-app.ps1 - App (PROXIMA build). Luciano (13/11/2026), en su Android: el mapa se queda en "Cargando el mapa" y la app lo pide de nuevo cada ~15 segundos sin decir por que; las tarjetas de Familia se esconden en silencio si no cargan.
#  - MapaEnApp.tsx: el cartel "Cargando" se saca solo (8 s o primer latido); las recargas automaticas se frenan en 3 por minuto; el MOTIVO se escribe en pantalla; a los 20 s sin latido aparece "El mapa esta tardando" + Reintentar.
#  - FamiliaPantalla.tsx: las tarjetas Vos / Cuidado / Remedios muestran "No se pudo cargar" + Reintentar; "Actualizar" las recarga; "Mas tarde" de HOY ya no se corta.
# Requiere aplicar-mapa-latido-app.ps1 y aplicar-remedios3-app.ps1. Toca src\\MapaEnApp.tsx y src\\FamiliaPantalla.tsx (respaldo .bak-robusta). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\MapaEnApp.tsx", "src\\FamiliaPantalla.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function TarjetaFallo') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\MapaEnApp.tsx")).texto 'huboLatido') -eq 0) { Mal "Falta aplicar primero aplicar-mapa-latido-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto '(borrador ? [] : actual.items)') -eq 0) { Mal "Falta aplicar primero aplicar-remedios3-app.ps1."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-robusta')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android e iPhone)."', cola)
assert 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-app-robusta-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# replicas
for origen, destino, archivo in ((S + 'MapaEnApp-latido.tsx', S + 'MapaEnApp-robusta.tsx', M), (S + 'FamiliaPantalla-remedios3.tsx', S + 'FamiliaPantalla-robusta.tsx', Fp)):
    t = open(origen, encoding='utf-8').read().replace('\r\n', '\n')
    for a, nombre, v, nv in pares:
        if a == archivo:
            assert t.count(v) == 1, (nombre, t.count(v))
    for a, nombre, v, nv in pares:
        if a == archivo:
            t = t.replace(v, nv)
    open(destino, 'w', encoding='utf-8').write(t)
print('ok', len(total), len(pares), 'cambios')
