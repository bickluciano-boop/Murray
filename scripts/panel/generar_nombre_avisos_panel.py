# Genera scripts/aplicar-nombre-avisos-panel.ps1: los avisos de la familia ("<Nombre> miro tu recorrido", "vio donde estas", SOS...) usan primero el "Mi nombre" que eligio cada persona.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = 'async function familyNameSeenBy(env: Env, aQuien: string, porQuien: string) {\n'
b1 = a1 + '  // El nombre que la persona eligio para si (Perfil > Mi nombre) gana siempre: asi la ven los demas en el mapa y en los avisos.\n  const propio = await nombrePerfil(env, aQuien);\n  if (propio) return propio;\n'
filas = [('src\\index.ts', 'avisos de la familia: primero el Mi nombre de cada persona', a1, b1)]
cambios = "$cambios = @(\n" + "    ,@(%s, %s, %s, %s)" % tuple(psq(x) for x in filas[0]) + "\n)\n"
cabeza = '''# aplicar-nombre-avisos-panel.ps1 - Ojo Guard MS: los avisos de la familia usan primero el "Mi nombre" que cada persona eligio para si.
# Motivo (01/11/2026, Luciano probo el aviso "miro tu recorrido"): al iPhone X le llego "Prueba menor miro tu recorrido" (el nombre con que la otra cuenta carga a Luciano en su propia familia) en vez del nombre que Luciano eligio en Perfil > Mi nombre.
# Cambia SOLO src\\index.ts (familyNameSeenBy): afecta a todos los avisos con nombre ("vio donde estas", "hizo sonar tu telefono", SOS, "miro tu recorrido"). Respaldo .bak-nombreavisos. Va en la carpeta del PANEL. Sin build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const propio = await nombrePerfil(env, aQuien)') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function nombrePerfil') -ne 1) { Mal "Falta aplicar primero aplicar-mi-nombre-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-nombreavisos')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: los avisos de la familia usan el Mi nombre de cada persona."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-nombre-avisos-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
