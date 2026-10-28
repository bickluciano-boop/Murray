# Genera scripts/aplicar-identidad-clave-panel.ps1: la clave DIDIT_API_KEY se limpia (espacios, comillas, "Bearer") y el registro anota su forma (largos), sin mostrarla. Didit contesta 400 vacio incluso con el pedido multipart bien armado.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-multipart.ts', encoding='utf-8').read()
a1 = '  let tamCuerpo = 0;\n'
b1 = a1 + """  // La clave se limpia (espacios, saltos de linea, comillas o "Bearer" que pudieron quedar al pegarla) y se anota su forma, sin mostrarla.
  const claveCruda = String(env.DIDIT_API_KEY ?? "");
  const claveDidit = claveCruda.trim().replace(/^["']|["']$/g, "").replace(/^bearer\\s+/i, "").trim();
  const formaClave = "largo=" + claveCruda.length + "/" + claveDidit.length + (/\\s/.test(claveDidit) ? " con-espacios" : "") + (claveCruda !== claveDidit ? " limpiada" : "");
"""
a2 = '"x-api-key": env.DIDIT_API_KEY, "content-type": `multipart'
b2 = '"x-api-key": claveDidit, "content-type": `multipart'
a3 = '"sexo=" + sexo);'
b3 = '"sexo=" + sexo, "clave:", formaClave);'
for v in (a1, a2, a3):
    assert fi.count(v) == 1, (v, fi.count(v))
filas = [('src\\index.ts', 'clave de Didit limpia', a1, b1), ('src\\index.ts', 'clave de Didit en la cabecera', a2, b2), ('src\\index.ts', 'forma de la clave en el registro', a3, b3)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-identidad-clave-panel.ps1 - Ojo Guard MS: Didit sigue contestando 400 vacio con el multipart bien armado; se sospecha de la clave (mal pegada). Limpia la clave (espacios, saltos, comillas, "Bearer") y anota su forma en el registro (largos, nunca la clave).
# Cambia SOLO src\\index.ts (respaldo .bak-identidad-clave). Va en la carpeta del PANEL. Requiere aplicar-identidad-multipart-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const claveDidit') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const limite = "----ojoguard"') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-multipart-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad-clave')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el servidor limpia la clave de Didit y anota su forma."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-clave-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(SC + 'index-clave.ts', 'w', encoding='utf-8').write(fi.replace(a1, b1).replace(a2, b2).replace(a3, b3))
print('ok', len(total))
