# Genera scripts/aplicar-cuidado-dueno-panel.ps1 (servidor).
# Luciano (17/11/2026): "lo del aviso de bateria solamente al dueno el aviso; que vean la bateria todos los que te pueden ver, pero el aviso al dueno del telefono"
# y "sin senal por 8 horas (o seis); 3 es comun: puede que esten en un lugar sin senal y despues una siesta".
# 1) El aviso de BATERIA BAJA (15%) le llega solo al dueno del telefono ("Tu bateria esta en N%. Conecta el cargador."), ya no a la familia. La familia sigue viendo el porcentaje en el mapa.
#    Se anota por telefono (tabla care_bat): un aviso por bajada, se rearma al subir a 30%.
# 2) El aviso de SIN SENAL a la familia pasa de 3 a 6 horas y el reloj se PAUSA de 23 a 7 (dormir con el telefono apagado o sin senal no cuenta). De noche tampoco se avisa la bateria baja.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/priv/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
g = open(R + 'panel/generar_cuidado_panel.py', encoding='utf-8').read()
BLOQUE = g[g.index("BLOQUE = r'''") + len("BLOQUE = r'''"): g.index("'''\nA0 = ")]
def psq(s):
    return "'" + s.replace("'", "''") + "'"
IDX = 'src\\index.ts'
filas = []
def fila(nombre, viejo, nuevo):
    filas.append((IDX, nombre, viejo, nuevo))

fila('cuidado: sin senal a la familia a las 6 horas (antes 3)',
     'CUIDADO_SIN_SENAL_MIN = 180,', 'CUIDADO_SIN_SENAL_MIN = 360,')

T_A = '  await env.DB.prepare("CREATE TABLE IF NOT EXISTS care_state (email TEXT PRIMARY KEY, bat_low INTEGER NOT NULL DEFAULT 0, silence_at TEXT, bd_day TEXT, bd_sent_at TEXT, bd_ok_at TEXT, bd_alert_at TEXT)").run();\n'
fila('cuidado: tabla care_bat (bateria baja por telefono)', T_A,
     T_A + '  await env.DB.prepare("CREATE TABLE IF NOT EXISTS care_bat (device_id TEXT PRIMARY KEY, low INTEGER NOT NULL DEFAULT 0)").run();\n')

E_A = '''    const equipos = await env.DB.prepare("SELECT owner_email AS email, battery, last_seen_at AS lastSeenAt FROM devices WHERE approval_status='approved' AND device_role='primary'")
      .all<{ email: string; battery: number | null; lastSeenAt: string | null }>();'''
E_B = '''    const equipos = await env.DB.prepare("SELECT id AS id, push_token AS pushToken, owner_email AS email, battery, last_seen_at AS lastSeenAt FROM devices WHERE approval_status='approved' AND device_role='primary'")
      .all<{ id: string; pushToken: string | null; email: string; battery: number | null; lastSeenAt: string | null }>();'''
fila('cuidado: la lista de telefonos trae su id y su token de aviso', E_A, E_B)

B_A = '''        if (typeof eq.battery === "number") {
          if (eq.battery <= CUIDADO_BATERIA_BAJA && !e.bat_low && calladoMin !== null && calladoMin < 360) {
            const n = eq.battery;
            await cuidadoAvisar(env, eq.email, (nombre) => `${nombre} tiene la batería baja (${n}%).`, "cuidado bateria");
            e.bat_low = 1; cambio = true;
          } else if (eq.battery >= CUIDADO_BATERIA_OK && e.bat_low) { e.bat_low = 0; cambio = true; }
        }'''
B_B = '''        // El aviso es SOLO para el dueno del telefono (la familia sigue viendo el porcentaje en el mapa, pero no recibe este aviso). Un aviso por bajada y por telefono; se rearma al volver a subir. De 23 a 7 no se avisa: si sigue baja a las 7, ahi se avisa.
        if (typeof eq.battery === "number") {
          const bajaAntes = Boolean((await env.DB.prepare("SELECT low FROM care_bat WHERE device_id=?").bind(eq.id).first<{ low: number }>())?.low);
          const horaBat = cuidadoLocal(ahoraMs, prefs.tz).hora;
          const nocheBat = horaBat >= 23 || horaBat < 7;
          if (eq.battery <= CUIDADO_BATERIA_BAJA && !bajaAntes && !nocheBat && calladoMin !== null && calladoMin < 360) {
            await env.DB.prepare("INSERT OR REPLACE INTO care_bat (device_id, low) VALUES (?,1)").bind(eq.id).run();
            if (eq.pushToken) await sendExpoNoticeLogged(env, eq.pushToken, "Batería baja", `Tu batería está en ${eq.battery}%. Conecta el cargador.`, "cuidado bateria propia", { channelId: "ojo-alertas" }).catch(() => false);
          } else if (eq.battery >= CUIDADO_BATERIA_OK && bajaAntes) {
            await env.DB.prepare("INSERT OR REPLACE INTO care_bat (device_id, low) VALUES (?,0)").bind(eq.id).run();
          }
        }'''
fila('cuidado: el aviso de bateria baja va solo al dueno del telefono', B_A, B_B)


S_A = '''          const hora = cuidadoLocal(ahoraMs, prefs.tz).hora;
          const deNoche = hora >= 23 || hora < 7;
          if (!e.silence_at && calladoMin >= CUIDADO_SIN_SENAL_MIN && !deNoche) {'''
S_B = '''          const hora = cuidadoLocal(ahoraMs, prefs.tz).hora;
          const deNoche = hora >= 23 || hora < 7;
          // El reloj del "sin senal" se PAUSA de 23 a 7 (hora de la persona): dormir con el telefono apagado o sin senal no cuenta, asi no se avisa a la familia justo al despertar.
          const despiertoMin = cuidadoMinutosDespierto(visto, ahoraMs, prefs.tz);
          if (!e.silence_at && despiertoMin >= CUIDADO_SIN_SENAL_MIN && !deNoche) {'''
fila('cuidado: el reloj de sin senal se pausa de 23 a 7', S_A, S_B)

F_A = 'function cuidadoLocal(ahoraMs: number, tzMin: number) {\n'
F_B = '''/** Minutos de silencio contando solo las horas despierto (de 7 a 23, hora de la persona): de 23 a 7 el reloj se pausa. */
function cuidadoMinutosDespierto(desdeMs: number, hastaMs: number, tzMin: number) {
  let despierto = 0;
  for (let t = Math.max(desdeMs, hastaMs - 72 * 3600_000); t < hastaMs; t += 15 * 60_000) {
    const h = cuidadoLocal(t, tzMin).hora;
    if (h >= 7 && h < 23) despierto += Math.min(15, (hastaMs - t) / 60_000);
  }
  return despierto;
}
''' + F_A
fila('cuidado: funcion que cuenta el silencio solo despierto', F_A, F_B)

def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"

i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cuidadodueno')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: el aviso de bateria baja le llega solo al dueno del telefono y el aviso de sin senal a la familia pasa a las 6 horas.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-cuidado-dueno-panel.ps1 - Ojo Guard MS (servidor): (1) el aviso de BATERIA BAJA (15%) le llega solo al dueno del telefono, ya no a la familia (la familia sigue viendo el porcentaje en el mapa);
# (2) el aviso de SIN SENAL a la familia pasa de 3 a 6 horas. Luciano (17/11/2026): "3 es comun: puede que esten en un lugar sin senal y despues una siesta".
# Cambia src\\index.ts (respaldo .bak-cuidadodueno). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'care_bat') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-cuidado-dueno-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = BLOQUE
for a, n, v, nv in filas:
    assert t.count(v) == 1, (n, t.count(v))
for a, n, v, nv in filas:
    t = t.replace(v, nv)
open(S + 'cuidado-dueno.ts', 'w', encoding='utf-8').write(t)
open(S + 'cuidado-base.ts', 'w', encoding='utf-8').write(BLOQUE)
print('ok', len(total), len(filas), 'filas')
