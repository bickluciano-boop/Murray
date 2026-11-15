# Genera scripts/aplicar-medicamentos-pendientes-panel.ps1 (servidor) y scripts/aplicar-medicamentos-pendientes-app.ps1 (app, PROXIMA build).
# Luciano (15/11/2026, 00:22, viendo la tarjeta): "porque poner mas tarde? El que no se tomo tiene que aparecer pendiente hasta que lo tome".
# Causa: la lista solo miraba el dia de HOY; al pasar la medianoche, las tomas de ayer que avisaron y nunca se confirmaron desaparecian y todo quedaba como "Mas tarde".
# Ahora el servidor manda tambien "atrasadas" (tomas de dias anteriores, con aviso enviado y sin confirmar, hasta 3 dias) y la app las muestra arriba en PENDIENTES con su boton "Lo tome".
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F, API, IDX = 'src\\FamiliaPantalla.tsx', 'src\\remoteApi.ts', 'src\\index.ts'

SERV_A = '  const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow, loc.dia);\n  const destinos'
SERV_B = '''  const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow, loc.dia);
  // Tomas de dias anteriores que ya avisaron y nunca se confirmaron: siguen PENDIENTES hasta que la persona las toma (se muestran hasta 3 dias atras).
  const [anio, mes, diaMes] = loc.dia.split("-").map(Number);
  const desdeDia = new Date(Date.UTC(anio ?? 1970, (mes ?? 1) - 1, (diaMes ?? 1) - 3)).toISOString().slice(0, 10);
  const filasAtrasadas = await env.DB.prepare(
    "SELECT d.id AS dosisId, d.day AS dia, d.hhmm AS hhmm, i.nombre AS nombre FROM med_dosis d JOIN med_items i ON i.id=d.item_id WHERE d.email=? AND d.ok_at IS NULL AND d.sent_at IS NOT NULL AND d.day<? AND d.day>=? ORDER BY d.day ASC, d.hhmm ASC LIMIT 20",
  ).bind(email, loc.dia, desdeDia).all<{ dosisId: string; dia: string; hhmm: string; nombre: string }>();
  const atrasadas = filasAtrasadas.results.map((x) => ({ dosisId: x.dosisId, nombre: x.nombre, hhmm: x.hhmm, hace: Math.max(1, Math.round((Date.UTC(anio ?? 1970, (mes ?? 1) - 1, diaMes ?? 1) - Date.parse(`${x.dia}T00:00:00Z`)) / 86_400_000)) }));
  const destinos'''
SERV_C_A = '    hoy,\n    destinatarios: destinos,\n'
SERV_C_B = '    hoy,\n    atrasadas,\n    destinatarios: destinos,\n'
panel_filas = [
 (IDX, 'pendientes: el servidor busca las tomas de dias anteriores sin confirmar', SERV_A, SERV_B),
 (IDX, 'pendientes: se mandan a la app como "atrasadas"', SERV_C_A, SERV_C_B),
]

TIPO_A = 'export type RemedioToma = { itemId: string; nombre: string; hhmm: string; dosisId: string | null; estado: string };\n'
TIPO_B = TIPO_A + '/** Una toma de un dia anterior que avisaron y no se confirmo: sigue pendiente. hace = cuantos dias atras. */\nexport type RemedioAtrasada = { dosisId: string; nombre: string; hhmm: string; hace: number };\n'
EST_A = '  hoy: RemedioToma[];\n  destinatarios: string[];\n'
EST_B = '  hoy: RemedioToma[];\n  atrasadas: RemedioAtrasada[];\n  destinatarios: string[];\n'
LEE_A = '    destinatarios: Array.isArray(r.destinatarios) ? r.destinatarios.map((x) => String(x)) : [],\n    max: { items: Number(r.max?.items) || 8, horas: Number(r.max?.horas) || 6 },\n'
LEE_B = '    atrasadas: Array.isArray(r.atrasadas)\n      ? r.atrasadas.map((t) => ({ dosisId: String(t.dosisId), nombre: String(t.nombre ?? ""), hhmm: String(t.hhmm ?? ""), hace: Math.max(1, Number(t.hace) || 1) }))\n      : [],\n' + LEE_A
UI_A = '        {hoy.length ? (\n          <>\n            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>HOY</Text>\n'
UI_B = '''        {actual.atrasadas.length ? (
          <>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>PENDIENTES</Text>
            {actual.atrasadas.map((t) => (
              <View key={t.dosisId} style={sp.fila}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.texto, fontSize: 14.5, fontWeight: "800", width: 54 }}>{t.hhmm}</Text>
                <View style={{ flex: 1, minWidth: 0 }}>
                  <Text maxFontSizeMultiplier={TOPE_LETRA} numberOfLines={1} style={{ color: P.textoClaro, fontSize: 14 }}>{t.nombre}</Text>
                  <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.detalle}>{t.hace === 1 ? "De ayer, sin confirmar" : `De hace ${t.hace} días, sin confirmar`}</Text>
                </View>
                <Pressable accessibilityRole="button" accessibilityLabel={`Lo tomé: ${t.nombre}`} disabled={ocupado(`ok-${t.dosisId}`)} onPress={() => void correr(`ok-${t.dosisId}`, () => confirmRemedio(enrollment, { dosisId: t.dosisId }))} style={chip(true)}>
                  <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>Lo tomé</Text>
                </Pressable>
              </View>
            ))}
          </>
        ) : null}
''' + UI_A
app_filas = [
 (API, 'pendientes: tipo de una toma atrasada', TIPO_A, TIPO_B),
 (API, 'pendientes: el estado trae las atrasadas', EST_A, EST_B),
 (API, 'pendientes: se leen las atrasadas que manda el servidor', LEE_A, LEE_B),
 (F, 'pendientes: seccion PENDIENTES arriba de HOY, con su boton Lo tome', UI_A, UI_B),
]
def cambios_ps(filas):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
def instalador(tipo, filas, archivo, etiqueta, cabeza, guardas, mensaje):
    t = tpl if tipo == 'panel' else base
    i0 = t.index('$ErrorActionPreference'); j0 = t.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))') if tipo == 'panel' else t.index('Ok "Carpeta correcta"')
    cola = t[t.index('$descargas = @()'):].replace('.bak-audioandroid' if tipo == 'panel' else '.bak-version', '.bak-' + etiqueta)
    if tipo == 'panel':
        cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
        cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % mensaje, cola)
    else:
        cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % mensaje, cola)
    assert mensaje in cola, 'no se pudo poner el mensaje final'
    total = cabeza + t[i0:j0] + guardas + cambios_ps(filas) + cola
    bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
    assert not bad, set(bad)
    open(R + archivo, 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
    return len(total)
cab_p = '''# aplicar-medicamentos-pendientes-panel.ps1 - Ojo Guard MS (servidor): las tomas de dias anteriores que avisaron y no se confirmaron siguen PENDIENTES (hasta 3 dias) y se mandan a la app.
# Luciano (15/11/2026): "porque poner mas tarde? El que no se tomo tiene que aparecer pendiente hasta que lo tome". Antes, al pasar la medianoche desaparecian. Cambia src\\index.ts (respaldo .bak-pendientes). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
# Se puede aplicar antes o despues de la app: las versiones viejas de la app ignoran el dato nuevo.
'''
g_p = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'filasAtrasadas') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cab_a = '''# aplicar-medicamentos-pendientes-app.ps1 - App (PROXIMA build). Luciano (15/11/2026): "porque poner mas tarde? El que no se tomo tiene que aparecer pendiente hasta que lo tome".
# En la tarjeta MEDICAMENTOS aparece arriba la seccion PENDIENTES con las tomas de dias anteriores que avisaron y no se confirmaron ("De ayer, sin confirmar") y su boton "Lo tome". Requiere el instalador del servidor (aplicar-medicamentos-pendientes-panel.ps1).
# Toca src\\remoteApi.ts y src\\FamiliaPantalla.tsx (respaldo .bak-pendientes). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
g_a = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FamiliaPantalla.tsx", "src\\remoteApi.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\remoteApi.ts")).texto 'RemedioAtrasada') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
print('panel', instalador('panel', panel_filas, 'aplicar-medicamentos-pendientes-panel.ps1', 'pendientes', cab_p, g_p, 'LISTO: las tomas sin confirmar de dias anteriores siguen pendientes.'))
print('app', instalador('app', app_filas, 'aplicar-medicamentos-pendientes-app.ps1', 'pendientes', cab_a, g_a, 'LISTO: la app compila bien. Las tomas sin confirmar quedan en PENDIENTES (sale en la PROXIMA build, Android e iPhone).'))
def replica(origen, destino, filas):
    t = open(S + origen, encoding='utf-8').read().replace('\r\n', '\n')
    for a, n, v, nv in filas:
        assert t.count(v) == 1, (n, t.count(v))
    for a, n, v, nv in filas:
        t = t.replace(v, nv)
    open(S + destino, 'w', encoding='utf-8').write(t)
replica('index-sonido.ts', 'index-pendientes.ts', panel_filas)
replica('remoteApi-remedios2-bloque.ts', 'remoteApi-pendientes-bloque.ts', app_filas[:3])
replica('FamiliaPantalla-orden.tsx', 'FamiliaPantalla-pendientes.tsx', app_filas[3:])
print('replicas ok')
