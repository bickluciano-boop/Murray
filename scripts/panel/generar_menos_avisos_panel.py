# Genera scripts/aplicar-menos-avisos-panel.ps1: que el Modo Cautela y la vigilancia de silencio no manden avisos todo el tiempo (SMS y mails cuestan, y si avisan de mas nadie les cree el dia que es de verdad).
# Luciano (12/11/2026): "esto es un costo y no vale la pena que todo el tiempo este mandando cuando no esta pasando nada; cuando pase de verdad nadie lo va a creer".
# Causa vista en su base: pld_config con silencio 10/10 min, bateria 50 %, lejos 1 km (valores de prueba) y deviceSilence con 45 min sin causa aparente.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
# 1) minimos de las condiciones (lectura y escritura): los valores de prueba guardados se corrigen solos al leerlos
A1 = ("    silenceNightMin: pldNumero(f.silenceNightMin, 10, 1440, PLD_POR_DEFECTO.silenceNightMin),\n"
      "    silenceDayMin: pldNumero(f.silenceDayMin, 10, 2880, PLD_POR_DEFECTO.silenceDayMin),\n"
      "    farKm: pldNumero(f.farKm, 0.5, 200, PLD_POR_DEFECTO.farKm),\n"
      "    batteryPct: pldNumero(f.batteryPct, 1, 50, PLD_POR_DEFECTO.batteryPct),\n")
B1 = ("    // Minimos y maximos sensatos: con valores de prueba (10 minutos, bateria 50 %, 1 km) el aviso saltaba todo el tiempo. Lo ya guardado se corrige solo al leerlo.\n"
      "    silenceNightMin: pldNumero(f.silenceNightMin, 60, 1440, PLD_POR_DEFECTO.silenceNightMin),\n"
      "    silenceDayMin: pldNumero(f.silenceDayMin, 180, 2880, PLD_POR_DEFECTO.silenceDayMin),\n"
      "    farKm: pldNumero(f.farKm, 2, 200, PLD_POR_DEFECTO.farKm),\n"
      "    batteryPct: pldNumero(f.batteryPct, 1, 30, PLD_POR_DEFECTO.batteryPct),\n")
A2 = ("      silenceNightMin: Math.round(pldNumero(c.silenceNightMin, 10, 1440, cfg.silenceNightMin)),\n"
      "      silenceDayMin: Math.round(pldNumero(c.silenceDayMin, 10, 2880, cfg.silenceDayMin)),\n"
      "      farKm: pldNumero(c.farKm, 0.5, 200, cfg.farKm),\n"
      "      batteryPct: Math.round(pldNumero(c.batteryPct, 1, 50, cfg.batteryPct)),\n")
B2 = ("      silenceNightMin: Math.round(pldNumero(c.silenceNightMin, 60, 1440, cfg.silenceNightMin)),\n"
      "      silenceDayMin: Math.round(pldNumero(c.silenceDayMin, 180, 2880, cfg.silenceDayMin)),\n"
      "      farKm: pldNumero(c.farKm, 2, 200, cfg.farKm),\n"
      "      batteryPct: Math.round(pldNumero(c.batteryPct, 1, 30, cfg.batteryPct)),\n")
A3 = r'id="cSilNoche" type="number" min="10"'
B3 = r'id="cSilNoche" type="number" min="60"'
A4 = r'id="cSilDia" type="number" min="10"'
B4 = r'id="cSilDia" type="number" min="180"'
# 2) Cautela: despues de cerrar un episodio no se abre otro enseguida
A5 = 'async function pldCronPersona(env: Env, email: string) {\n'
B5 = '''// Despues de cerrar un episodio (el telefono volvio a dar senal) no se abre otro hasta pasadas PLD_ENFRIAR_HORAS horas: un telefono que da senal de a ratos
// no tiene que mandar un "¿Estas bien?" cada hora. "Apagado en movimiento con bateria alta" no espera.
const PLD_ENFRIAR_HORAS = 6;
let pldEnfriarTabla = false;
async function pldEnfriarLista(env: Env) {
  if (pldEnfriarTabla) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS pld_enfriar (owner_email TEXT PRIMARY KEY, hasta TEXT NOT NULL)").run();
  pldEnfriarTabla = true;
}
async function pldEnfriar(env: Env, email: string) {
  await pldEnfriarLista(env);
  await env.DB.prepare("INSERT OR REPLACE INTO pld_enfriar (owner_email,hasta) VALUES (?,?)").bind(email, new Date(Date.now() + PLD_ENFRIAR_HORAS * 3_600_000).toISOString()).run();
}
async function pldEnfriando(env: Env, email: string) {
  await pldEnfriarLista(env);
  const f = await env.DB.prepare("SELECT hasta FROM pld_enfriar WHERE owner_email=?").bind(email).first<{ hasta: string }>();
  return Boolean(f && f.hasta > new Date(Date.now()).toISOString());
}

''' + A5
A6 = '    await env.DB.prepare("DELETE FROM pld_episodios WHERE owner_email=?").bind(email).run();\n    let avisados = 0;\n'
B6 = A6 + '    await pldEnfriar(env, email).catch(() => undefined);\n'
A7 = '    if (respondio) return; // dijo que estaba bien hace poco\n'
B7 = A7 + '    if (!estado.apagadoEnMovimiento && (await pldEnfriando(env, email).catch(() => false))) return; // el telefono volvio a dar senal hace poco: no se abre otro episodio enseguida\n'
A8 = '  await borrar("pld_episodios", "DELETE FROM pld_episodios WHERE owner_email=?", 1);\n'
B8 = '  await pldEnfriarLista(env).catch(() => undefined);\n' + A8 + '  await borrar("pld_enfriar", "DELETE FROM pld_enfriar WHERE owner_email=?", 1);\n'
# 3) vigilancia de silencio: despues de volver a dar senal no se rearma hasta pasadas 6 horas del ultimo aviso
A9 = ('        if (device.silenceAlertAt && device.lastSeenAt && device.lastSeenAt > device.silenceAlertAt) {\n'
      '          await env.DB.prepare("UPDATE devices SET silence_alert_at=NULL WHERE id=?").bind(device.id).run();\n'
      '          return;\n        }\n')
B9 = ('        if (device.silenceAlertAt && device.lastSeenAt && device.lastSeenAt > device.silenceAlertAt) {\n'
      '          // Un telefono que da senal de a ratos no puede avisar cada hora: se rearma recien pasadas 6 horas del ultimo aviso.\n'
      '          if (nowMs - Date.parse(device.silenceAlertAt) >= 6 * 3_600_000) {\n'
      '            await env.DB.prepare("UPDATE devices SET silence_alert_at=NULL WHERE id=?").bind(device.id).run();\n'
      '          }\n'
      '          return;\n        }\n')
pares = [(A1, B1), (A2, B2), (A3, B3), (A4, B4), (A5, B5), (A6, B6), (A7, B7), (A8, B8), (A9, B9)]
nombres = ['cautela: minimos de las condiciones (lectura)', 'cautela: minimos de las condiciones (guardado)', 'cautela: minimo de la pantalla (noche)', 'cautela: minimo de la pantalla (dia)',
           'cautela: espera despues de un episodio (funciones)', 'cautela: anotar la espera al cerrar el episodio', 'cautela: no abrir otro episodio enseguida', 'cautela: la espera se borra con la cuenta',
           'silencio: no rearmar hasta pasadas 6 horas']
filas = [('src\\index.ts', n, a, b) for n, (a, b) in zip(nombres, pares)]
C1 = 'export const SILENCE_UNEXPLAINED_MINUTES = 45;'
C2 = 'export const SILENCE_UNEXPLAINED_MINUTES = 240;'
filas.append(('src\\deviceSilence.ts', 'silencio sin causa aparente: 4 horas (antes 45 minutos)', C1, C2))
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-menos-avisos-panel.ps1 - Ojo Guard MS: que el Modo Cautela y la vigilancia de silencio NO manden avisos todo el tiempo (cada SMS y cada mail cuesta, y si avisan de mas nadie les cree el dia que es de verdad).
# Luciano (12/11/2026). En su base: silencio 10 minutos (de dia y de noche), bateria 50 %, "lejos" a 1 km, y la regla de silencio de cada equipo en 45 minutos: un Android en segundo plano reporta cada tanto y saltaba cada hora.
# 1) Minimos sensatos: silencio de noche >= 60 min, de dia >= 180, "lejos" >= 2 km, bateria <= 30 % (lo ya guardado se corrige solo al leerlo; los recomendados 90/360/3/15 no cambian).
# 2) Cautela: despues de cerrar un episodio no se abre otro hasta pasadas 6 horas. 3) Silencio de un equipo: sin causa aparente 4 horas (antes 45 minutos) y no se rearma hasta 6 horas despues del ultimo aviso.
# Cambia src\\index.ts y src\\deviceSilence.ts (respaldo .bak-menos-avisos). Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\deviceSilence.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function pldEnfriando') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-menos-avisos')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el Modo Cautela y la vigilancia de silencio avisan mucho menos."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-menos-avisos-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-remedios.ts', encoding='utf-8').read()
for a, _ in pares:
    assert t.count(a) == 1, (t.count(a), a[:80])
for a, b in pares:
    t = t.replace(a, b)
open(S + 'index-menos.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total))
