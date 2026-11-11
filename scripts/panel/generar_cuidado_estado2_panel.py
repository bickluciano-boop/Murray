# Genera scripts/aplicar-cuidado-estado2-panel.ps1: el panel no dice "Sin senal" si la persona ya volvio a conectarse, ni "Bateria baja" si ya subio de 30 %.
# (La marca de "sin senal" se limpia en el cron cada 5 minutos: hasta entonces el panel mostraba "Sin senal desde hace 5 s" junto a "En vivo".)
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A0 = 'async function cuidadoVista(env: Env, email: string, bateria: number | null) {\n  await cuidadoTabla(env);\n'
B0 = ('async function cuidadoVista(env: Env, email: string, bateria: number | null, vistoEn: string | null = null) {\n  await cuidadoTabla(env);\n')
A1 = ('    bateriaBaja: prefs.bateria && Boolean(e.bat_low) && typeof bateria === "number",\n'
      '    sinSenal: prefs.bateria && Boolean(e.silence_at),\n')
B1 = ('    // La marca la limpia el cron cada 5 minutos: aca se mira ya mismo si la persona volvio a conectarse o si la bateria ya subio.\n'
      '    bateriaBaja: prefs.bateria && Boolean(e.bat_low) && typeof bateria === "number" && bateria < CUIDADO_BATERIA_OK,\n'
      '    sinSenal: prefs.bateria && Boolean(e.silence_at) && !(vistoEn && Number.isFinite(Date.parse(vistoEn)) && Date.parse(vistoEn) > Date.parse(String(e.silence_at))),\n')
A2 = 'await cuidadoVista(env, p.email, device?.battery ?? null)'
B2 = 'await cuidadoVista(env, p.email, device?.battery ?? null, device?.lastSeenAt ?? null)'
filas = [('src\\index.ts', 'cuidado: firma con la ultima conexion', A0, B0),
         ('src\\index.ts', 'cuidado: sin senal y bateria baja solo si siguen asi', A1, B1),
         ('src\\index.ts', 'cuidado: se pasa la ultima conexion', A2, B2)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-cuidado-estado2-panel.ps1 - Ojo Guard MS: el estado de Cuidado del panel no dice "Sin senal" si la persona ya volvio a conectarse (decia "Sin senal desde hace 5 s" junto a "En vivo"), ni "Bateria baja" si ya subio de 30 %.
# Requiere aplicar-cuidado-estado-panel.ps1. Cambia SOLO src\\index.ts (respaldo .bak-cuidado-estado2). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$indexTexto = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $indexTexto 'vistoEn: string | null = null') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'async function cuidadoVista') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-estado-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cuidado-estado2')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el panel ya no marca sin senal ni bateria baja cuando la persona ya se recupero."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-cuidado-estado2-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-estado.ts', encoding='utf-8').read()
for a in (A0, A1, A2):
    assert t.count(a) == 1, (t.count(a), a[:60])
for a, b in ((A0, B0), (A1, B1), (A2, B2)):
    t = t.replace(a, b)
open(S + 'index-estado2.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total))
