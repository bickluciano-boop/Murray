# Genera scripts/aplicar-identidad-cuerpo-panel.ps1: cuando Didit contesta un error (400), el servidor anota el cuerpo completo de la respuesta.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-matriz.ts', encoding='utf-8').read()
viejo = '    console.error("didit_failed", respuesta.status, texto.slice(0, 400));'
nuevo = '''    // Diagnostico: lo que contesto Didit (tipo, largo y cuerpo) y lo que se le mando (selfie en bytes, largo del DNI, sexo).
    console.error("didit_failed", "status=" + respuesta.status, "tipo=" + (respuesta.headers.get("content-type") ?? "-"), "largo=" + texto.length, "cuerpo=" + JSON.stringify(texto.slice(0, 900)), "selfie=" + bytes.length, "dni=" + documento.length, "sexo=" + sexo);'''
assert fi.count(viejo) == 1, fi.count(viejo)
filas = [('src\\index.ts', 'cuerpo completo del error de Didit', viejo, nuevo)]
cambios = "$cambios = @(\n    ," + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in filas[0]) + "\n)\n"
cabeza = '''# aplicar-identidad-cuerpo-panel.ps1 - Ojo Guard MS: Didit ya recibe la selfie chica (build 180) pero contesta 400; el servidor anota el cuerpo completo de la respuesta para ver el motivo.
# Cambia SOLO src\\index.ts (respaldo .bak-identidad-cuerpo). Va en la carpeta del PANEL. Requiere aplicar-identidad-matriz-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto '"cuerpo=" + JSON.stringify') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const matriz') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-matriz-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad-cuerpo')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el servidor ahora anota el motivo del error de Didit."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-cuerpo-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(SC + 'index-cuerpo.ts', 'w', encoding='utf-8').write(fi.replace(viejo, nuevo))
print('ok', len(total))
