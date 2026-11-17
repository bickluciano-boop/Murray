# Genera scripts/aplicar-cuidado-lugares-panel.ps1 (servidor).
# Luciano (17/11/2026): "preocuparemos a todos por nada. Tiene que ser algo pensante: si la geolocalizacion es un lugar conocido frecuente no tendria que alarmarse; si es la primera vez, llama la atencion".
# El aviso de SIN SENAL a la familia ahora mira la ULTIMA UBICACION conocida del telefono:
#  - dentro de un lugar guardado (family_places: Casa, Trabajo...; los propios y los de las familias de las que la persona es miembro): no se avisa hasta las 24 h despierto.
#  - fuera de todo lugar conocido: se avisa a las 6 h despierto, y el aviso dice la ultima ubicacion conocida (direccion).
# Se apoya en cuidado-dueno (reloj pausado de 23 a 7). Etapa 2 (a futuro): lugares frecuentes aprendidos del historial (location_history).
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/priv/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
IDX = 'src\\index.ts'
filas = []
def fila(nombre, viejo, nuevo):
    filas.append((IDX, nombre, viejo, nuevo))

fila('lugares: limite de 24 h cuando la ultima ubicacion era un lugar conocido',
     'CUIDADO_SIN_SENAL_MIN = 360,', 'CUIDADO_SIN_SENAL_MIN = 360, CUIDADO_SIN_SENAL_CONOCIDO_MIN = 1440,')

F_A = '/** Minutos de silencio contando solo las horas despierto (de 7 a 23, hora de la persona): de 23 a 7 el reloj se pausa. */\n'
F_B = '''/** La ultima ubicacion conocida del telefono, y si estaba dentro de un lugar guardado (los propios o los de las familias de las que la persona es miembro). */
async function cuidadoLugarConocido(env: Env, dispositivo: string, email: string) {
  const ult = await env.DB.prepare("SELECT latitude, longitude, address FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT 1").bind(dispositivo)
    .first<{ latitude: number; longitude: number; address: string | null }>().catch(() => null);
  if (!ult || !Number.isFinite(Number(ult.latitude)) || !Number.isFinite(Number(ult.longitude))) return { conocido: false, direccion: null as string | null };
  const lugares = await env.DB.prepare("SELECT latitude, longitude, radius FROM family_places WHERE owner_email=? OR owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status='activo')").bind(email, email)
    .all<{ latitude: number; longitude: number; radius: number }>().catch(() => ({ results: [] as Array<{ latitude: number; longitude: number; radius: number }> }));
  const punto = { latitude: Number(ult.latitude), longitude: Number(ult.longitude) };
  const conocido = lugares.results.some((l) => metersBetween(punto, { latitude: Number(l.latitude), longitude: Number(l.longitude) }) <= Number(l.radius) + 100);
  return { conocido, direccion: ult.address ? String(ult.address).slice(0, 120) : null };
}
''' + F_A
fila('lugares: funcion que dice si la ultima ubicacion era un lugar conocido', F_A, F_B)

S_A = '''          if (!e.silence_at && despiertoMin >= CUIDADO_SIN_SENAL_MIN && !deNoche) {
            const horas = Math.floor(calladoMin / 60), bat = typeof eq.battery === "number" ? ` Su batería era ${eq.battery}%.` : "";
            await cuidadoAvisar(env, eq.email, (nombre) => `No tenemos señal de ${nombre} desde hace ${horas} h.${bat}`, "cuidado sin senal");
            e.silence_at = new Date(ahoraMs).toISOString(); cambio = true;
          }'''
S_B = '''          if (!e.silence_at && despiertoMin >= CUIDADO_SIN_SENAL_MIN && !deNoche) {
            // Si la ultima ubicacion era un lugar conocido (Casa, Trabajo...), no se alarma a nadie hasta las 24 h; si era un lugar desconocido, se avisa y se dice donde fue.
            const lugar = await cuidadoLugarConocido(env, eq.id, eq.email);
            if (!lugar.conocido || despiertoMin >= CUIDADO_SIN_SENAL_CONOCIDO_MIN) {
              const horas = Math.floor(calladoMin / 60), bat = typeof eq.battery === "number" ? ` Su batería era ${eq.battery}%.` : "", donde = lugar.direccion ? ` Última ubicación conocida: ${lugar.direccion}.` : "";
              await cuidadoAvisar(env, eq.email, (nombre) => `No tenemos señal de ${nombre} desde hace ${horas} h.${bat}${donde}`, "cuidado sin senal");
              e.silence_at = new Date(ahoraMs).toISOString(); cambio = true;
            }
          }'''
fila('lugares: el aviso de sin senal decide segun la ultima ubicacion conocida', S_A, S_B)

def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cuidadolugares')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: el aviso de sin senal mira la ultima ubicacion: en un lugar conocido espera 24 h, en uno desconocido avisa a las 6 h con la direccion.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-cuidado-lugares-panel.ps1 - Ojo Guard MS (servidor): el aviso de SIN SENAL a la familia mira la ultima ubicacion conocida del telefono.
# Luciano (17/11/2026): "preocuparemos a todos por nada; tiene que ser algo pensante: si es un lugar conocido frecuente no tendria que alarmarse; si es la primera vez, llama la atencion".
# En un lugar guardado (Casa, Trabajo...) espera hasta 24 h; en un lugar desconocido avisa a las 6 h y dice la ultima ubicacion conocida. Requiere aplicar-cuidado-dueno-panel.ps1. Cambia src\\index.ts (respaldo .bak-cuidadolugares). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'cuidadoLugarConocido') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'care_bat') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-dueno-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'function metersBetween') -eq 0) { Mal "Falta la funcion de distancias (aplicar-en-vivo-panel.ps1). No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-cuidado-lugares-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'cuidado-dueno.ts', encoding='utf-8').read()
for a, n, v, nv in filas:
    assert t.count(v) == 1, (n, t.count(v))
for a, n, v, nv in filas:
    t = t.replace(v, nv)
open(S + 'cuidado-lugares.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total), len(filas), 'filas')
