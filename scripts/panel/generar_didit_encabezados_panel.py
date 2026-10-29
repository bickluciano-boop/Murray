# Genera scripts/aplicar-didit-encabezados-panel.ps1: cuando Didit contesta con error, el registro (wrangler tail) tambien anota
# TODOS los encabezados de la respuesta (id de la solicitud, servidor, fecha), que es lo que pide el soporte de Didit para ubicar el error 500.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '    // Diagnostico: lo que contesto Didit (tipo, largo y cuerpo) y lo que se le mando (selfie en bytes, largo del DNI, sexo).\n'
b1 = a1 + '    const encabezadosDidit: string[] = [];\n    respuesta.headers.forEach((valor, nombre) => encabezadosDidit.push(nombre + ": " + valor));\n'
a2 = '"sexo=" + sexo, "clave:", formaClave);'
b2 = '"sexo=" + sexo, "encabezados=" + JSON.stringify(encabezadosDidit.join(" | ")), "clave:", formaClave);'
filas = [('src\\index.ts', 'Didit: juntar los encabezados de la respuesta', a1, b1), ('src\\index.ts', 'Didit: anotar los encabezados en el registro', a2, b2)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-didit-encabezados-panel.ps1 - Ojo Guard MS: cuando Didit contesta con error, el registro anota tambien los encabezados de la respuesta (id de la solicitud, servidor, fecha).
# Es lo que pide el soporte de Didit para ubicar el error 500 de /v3/database-validation/. No cambia nada de lo que ve la app.
# Cambia SOLO src\\index.ts (respaldo .bak-diditenc). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$txt = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $txt 'encabezadosDidit') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-diditenc')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: si Didit vuelve a fallar, el registro anota sus encabezados."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-didit-encabezados-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
