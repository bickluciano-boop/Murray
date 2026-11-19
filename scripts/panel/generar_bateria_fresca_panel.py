# Genera scripts/aplicar-bateria-fresca-panel.ps1 (servidor). Requiere aplicar-cuidado-dueno-panel.ps1.
# Luciano (19/11/2026): el iPhone recibio "Tu bateria esta en 5 %" a las 12:10 cuando tenia ~35 %. Causa (confirmada en el codigo, linea 4477 de src\index.ts):
# `UPDATE devices SET battery=COALESCE(?,battery),last_seen_at=? ...`: si el telefono avisa SIN dato de bateria, se conserva la vieja y la hora de conexion se actualiza igual; el aviso de bateria baja
# (cuidado-dueno) miraba la bateria vieja con una hora de conexion fresca.
# Arreglo: (1) tabla battery_fresh(device_id, at): se anota la hora SOLO cuando llega un dato de bateria real; (2) el aviso de bateria baja exige un dato de menos de 30 minutos; (3) una bateria negativa (el telefono no pudo leerla) se trata como "sin dato" y no como 0 %.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\index.ts'
# 1) el manejador de estado del telefono (texto pegado por Luciano, lineas 4472-4480)
H_A = '''  const rawBattery = body.battery == null ? null : Number(body.battery);
  const battery = rawBattery == null || !Number.isFinite(rawBattery)
    ? null
    : Math.max(0, Math.min(100, Math.round(rawBattery)));
  await env.DB.prepare("UPDATE devices SET push_token=COALESCE(?,push_token),battery=COALESCE(?,battery),last_seen_at=? WHERE id=?")
    .bind(pushToken, battery, now(), deviceId).run();
  return json({ updated: true });
'''
H_B = '''  const rawBattery = body.battery == null ? null : Number(body.battery);
  // Una bateria negativa (el telefono no pudo leerla) es "sin dato", no 0 %.
  const battery = rawBattery == null || !Number.isFinite(rawBattery) || rawBattery < 0
    ? null
    : Math.max(0, Math.min(100, Math.round(rawBattery)));
  await env.DB.prepare("UPDATE devices SET push_token=COALESCE(?,push_token),battery=COALESCE(?,battery),last_seen_at=? WHERE id=?")
    .bind(pushToken, battery, now(), deviceId).run();
  // Se anota la hora SOLO cuando llega un dato de bateria real: COALESCE conserva la bateria vieja si el telefono avisa sin dato, y el aviso de bateria baja
  // (19/11/2026: "5 %" con el iPhone al 35 %) no debe salir con un dato viejo.
  if (battery !== null) {
    await env.DB.prepare("CREATE TABLE IF NOT EXISTS battery_fresh (device_id TEXT PRIMARY KEY, at TEXT NOT NULL)").run().catch(() => undefined);
    await env.DB.prepare("INSERT OR REPLACE INTO battery_fresh (device_id, at) VALUES (?,?)").bind(deviceId, now()).run().catch(() => undefined);
  }
  return json({ updated: true });
'''
# 2) el aviso de bateria baja (texto que dejo aplicar-cuidado-dueno-panel.ps1: se LEE de su generador, no se copia a mano)
g = open(R + 'panel/generar_cuidado_dueno.py', encoding='utf-8').read()
B_B = g[g.index("B_B = '''") + len("B_B = '''"): g.index("'''\nfila('cuidado: el aviso de bateria baja va solo al dueno del telefono'")]
C_A = '          const nocheBat = horaBat >= 23 || horaBat < 7;\n          if (eq.battery <= CUIDADO_BATERIA_BAJA && !bajaAntes && !nocheBat && calladoMin !== null && calladoMin < 360) {'
assert B_B.count(C_A) == 1, B_B.count(C_A)
C_B = ('          const nocheBat = horaBat >= 23 || horaBat < 7;\n'
       '          // Solo se avisa con un dato de bateria RECIENTE (de los ultimos 30 minutos, tabla battery_fresh); si la tabla todavia no existe o el dato es viejo, no se avisa.\n'
       '          const bateriaAt = (await env.DB.prepare("SELECT at FROM battery_fresh WHERE device_id=?").bind(eq.id).first<{ at: string }>().catch(() => null))?.at;\n'
       '          const bateriaFresca = Boolean(bateriaAt) && ahoraMs - Date.parse(String(bateriaAt)) < 30 * 60_000;\n'
       '          if (eq.battery <= CUIDADO_BATERIA_BAJA && bateriaFresca && !bajaAntes && !nocheBat && calladoMin !== null && calladoMin < 360) {')
filas = [(F, 'bateria fresca: el estado del telefono anota la hora del dato de bateria real', H_A, H_B),
         (F, 'bateria fresca: el aviso de bateria baja exige un dato reciente', C_A, C_B)]
def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-bateriafresca')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: el aviso de bateria baja solo sale con un dato de bateria de los ultimos 30 minutos (y una bateria negativa ya no cuenta como 0 %).'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-bateria-fresca-panel.ps1 - Ojo Guard MS (servidor): el aviso de "Bateria baja" solo sale con un dato de bateria RECIENTE (menos de 30 minutos).
# Luciano (19/11/2026): el iPhone recibio "Tu bateria esta en 5 %" con ~35 %. Causa: COALESCE(?,battery) conserva la bateria vieja si el telefono avisa sin dato, mientras la hora de conexion se actualiza (src\\index.ts, estado del telefono).
# Crea la tabla battery_fresh sola. Requiere aplicar-cuidado-dueno-panel.ps1. Cambia src\\index.ts (respaldo .bak-bateriafresca). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'battery_fresh') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'care_bat') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-dueno-panel.ps1."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-bateria-fresca-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
open(S + 'filas_bateria.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
open(S + 'cuidado_B_B.txt', 'w', encoding='utf-8').write(B_B)
print('ok', len(total))
