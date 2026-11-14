# Genera scripts/aplicar-orden-sonido-app.ps1 y scripts/aplicar-orden-sonido-panel.ps1.
# Luciano (14/11/2026), probando la rueda en el iPhone: "estaria bueno que despues lo ordene por horario... manana, tarde y noche" y
# "las notificaciones por lo general no tienen sonido; no una alarma molesta, sino un pip para reconocer que tiene una pequena alerta".
# Causa del silencio (Android): los avisos de medicamentos y el Buen dia salian por el canal "ojo-familia-aviso", que es SILENCIOSO (importancia baja, sin sonido).
# Un canal de Android ya creado no puede cambiar de sonido: se crea uno nuevo, "ojo-medicamentos" (sonido corto por defecto del telefono, vibracion suave), y el servidor lo usa.
# En iPhone los avisos ya llevaban sonido por defecto: no cambia nada ahi.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F, APP, IDX = 'src\\FamiliaPantalla.tsx', 'App.tsx', 'src\\index.ts'

AYUDAS = '''// Momento del dia de cada medicamento (por su primera hora): manana 05:00-11:59, tarde 12:00-19:59, noche 20:00-04:59.
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

'''
LISTA_A = '        {(borrador ? [] : actual.items).map((it) => (\n          <View key={it.id} style={{ borderColor: P.borde, borderRadius: 12, borderWidth: 1, gap: 6, padding: 10 }}>\n'
LISTA_B = '''        {(borrador ? [] : ordenarMedicamentos(actual.items)).map((it, orden, lista) => (
          <Fragment key={it.id}>
            {orden === 0 || momentoDelDia(primeraHora(lista[orden - 1])) !== momentoDelDia(primeraHora(it)) ? (
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoDebil, fontSize: 12, fontWeight: "800", letterSpacing: 1.1, marginTop: orden === 0 ? 0 : 6 }}>{NOMBRES_MOMENTO[momentoDelDia(primeraHora(it))]}</Text>
            ) : null}
          <View style={{ borderColor: P.borde, borderRadius: 12, borderWidth: 1, gap: 6, padding: 10 }}>
'''
CANAL_A = '      void notifications.setNotificationChannelAsync("ojo-alertas", {\n'
CANAL_B = '''      // Avisos de medicamentos y "Buen dia": un sonido corto (el aviso normal del telefono) y una vibracion suave, sin alarma. Un canal ya creado no puede cambiar de sonido, por eso es uno nuevo.
      void notifications.setNotificationChannelAsync("ojo-medicamentos", {
        name: "Medicamentos y Buen día",
        description: "Recordatorios de tus medicamentos y el saludo del Buen día: un sonido corto.",
        importance: notifications.AndroidImportance.DEFAULT,
        sound: "default",
        enableVibrate: true,
        vibrationPattern: [0, 200],
        lockscreenVisibility: notifications.AndroidNotificationVisibility.PUBLIC,
      });
''' + CANAL_A
app_filas = [
 (F, 'orden: importar Fragment', 'import { useCallback, useEffect, useRef, useState, type ComponentType, type ReactNode } from "react";\n',
  'import { Fragment, useCallback, useEffect, useRef, useState, type ComponentType, type ReactNode } from "react";\n'),
 (F, 'orden: funciones para ordenar por momento del dia', 'function moverHoraRemedio(hhmm: string, pasos: number): string {\n', AYUDAS + 'function moverHoraRemedio(hhmm: string, pasos: number): string {\n'),
 (F, 'orden: la lista de medicamentos va por horario (manana, tarde, noche)', LISTA_A, LISTA_B),
 (F, 'orden: cierre del grupo de cada medicamento', '          </View>\n        ))}\n        {borrador ? (\n', '          </View>\n          </Fragment>\n        ))}\n        {borrador ? (\n'),
 (APP, 'sonido: canal nuevo con un sonido corto para medicamentos y Buen dia', CANAL_A, CANAL_B),
]
panel_filas = [
 (IDX, 'sonido: el aviso de medicamentos usa el canal con sonido corto', 'motivo, { channelId: "ojo-familia-aviso", data })', 'motivo, { channelId: "ojo-medicamentos", data })'),
 (IDX, 'sonido: el aviso del Buen dia usa el canal con sonido corto', '"buen dia", { channelId: "ojo-familia-aviso", data:', '"buen dia", { channelId: "ojo-medicamentos", data:'),
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
cab_a = '''# aplicar-orden-sonido-app.ps1 - App (PROXIMA build). Luciano (14/11/2026): "estaria bueno que lo ordene por horario: manana, tarde y noche" y "las notificaciones no tienen sonido: un pip, no una alarma molesta".
# 1) La lista MIS MEDICAMENTOS sale ordenada por horario y separada en MAÑANA / TARDE / NOCHE (un medicamento con varias horas va en el grupo de su primera hora).
# 2) Android: se crea el canal de avisos "Medicamentos y Buen día" con un sonido corto del telefono (antes salian por un canal silencioso). iPhone ya sonaba: no cambia.
# Toca src\\FamiliaPantalla.tsx y App.tsx (respaldo .bak-ordensonido). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
g_a = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FamiliaPantalla.tsx", "App.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'ojo-medicamentos') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cab_p = '''# aplicar-orden-sonido-panel.ps1 - Ojo Guard MS (servidor): los avisos de medicamentos y el "Buen dia" salen por el canal "ojo-medicamentos" (sonido corto) en vez del canal silencioso de avisos de familia.
# Luciano (14/11/2026): "las notificaciones por lo general no tienen sonido: un pip, no una alarma molesta". Cambia src\\index.ts (respaldo .bak-ordensonido). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
# Orden: aplicar primero el instalador de la app y hacer la build; los telefonos que todavia no la tengan reciben el aviso por el canal de respaldo del sistema (con sonido).
'''
g_p = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'ojo-medicamentos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
print('app', instalador('app', app_filas, 'aplicar-orden-sonido-app.ps1', 'ordensonido', cab_a, g_a, 'LISTO: la app compila bien. Medicamentos ordenados por horario y avisos con sonido corto (sale en la PROXIMA build, Android e iPhone).'))
print('panel', instalador('panel', panel_filas, 'aplicar-orden-sonido-panel.ps1', 'ordensonido', cab_p, g_p, 'LISTO: los avisos de medicamentos y el Buen dia salen con sonido corto.'))
# replicas
def replica(origen, destino, filas):
    t = open(S + origen, encoding='utf-8').read().replace('\r\n', '\n')
    for a, n, v, nv in filas:
        assert t.count(v) == 1, (n, t.count(v))
    for a, n, v, nv in filas:
        t = t.replace(v, nv)
    open(S + destino, 'w', encoding='utf-8').write(t)
replica('FamiliaPantalla-horas4.tsx', 'FamiliaPantalla-orden.tsx', app_filas[:4])
replica('prueba_ci/App.tsx', 'App-sonido.tsx', app_filas[4:])
replica('index-med.ts', 'index-sonido.ts', panel_filas)
print('replicas ok')
