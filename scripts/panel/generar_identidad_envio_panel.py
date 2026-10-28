# Genera scripts/aplicar-identidad-envio-panel.ps1: el pedido a Didit se arma completo antes de mandarlo (con su largo), para evitar "Network connection lost".
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-identidad.ts', encoding='utf-8').read()
viejo = '    respuesta = await fetch("https://verification.didit.me/v3/database-validation/", { method: "POST", headers: { "x-api-key": env.DIDIT_API_KEY }, body: form, signal: control.signal });'
nuevo = '''    // El cuerpo se arma completo antes de mandarlo, asi viaja con su largo (Content-Length) y no por partes: mandado por partes, Didit cortaba la conexion ("Network connection lost").
    const empaquetado = new Request("https://verification.didit.me/v3/database-validation/", { method: "POST", body: form });
    const cuerpo = await empaquetado.arrayBuffer();
    respuesta = await fetch("https://verification.didit.me/v3/database-validation/", {
      method: "POST",
      headers: { "x-api-key": env.DIDIT_API_KEY, "content-type": empaquetado.headers.get("content-type") ?? "multipart/form-data" },
      body: cuerpo,
      signal: control.signal,
    });'''
assert fi.count(viejo) == 1, fi.count(viejo)
filas = [('src\\index.ts', 'pedido a Didit con largo conocido', viejo, nuevo)]
cambios = "$cambios = @(\n    ," + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in filas[0]) + "\n)\n"
cabeza = '''# aplicar-identidad-envio-panel.ps1 - Ojo Guard MS: el pedido a Didit se arma completo antes de mandarlo. Con wrangler tail se vio "didit_unreachable Error: Network connection lost" al mandar la selfie.
# Cambia SOLO src\\index.ts (respaldo .bak-identidad-envio). Va en la carpeta del PANEL. Requiere aplicar-identidad-didit-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const empaquetado') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'nativeIdentityVerify') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-didit-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad-envio')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el pedido a Didit ahora viaja completo."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-envio-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
