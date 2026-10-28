# Genera scripts/aplicar-identidad-sonda-panel.ps1: cuando falla la conexion con Didit, el servidor anota el tamano del pedido y manda una prueba chica para ver que contesta Didit.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-actual-id.ts', encoding='utf-8').read()
filas = []
def cambio(rotulo, viejo, nuevo):
    assert fi.count(viejo) == 1, (rotulo, fi.count(viejo))
    filas.append(('src\\index.ts', rotulo, viejo, nuevo))
cambio('tamano del pedido (variable)', '  let respuesta: Response;', '  let respuesta: Response;\n  let tamCuerpo = 0;')
cambio('tamano del pedido (valor)', '    const cuerpo = await empaquetado.arrayBuffer();', '    const cuerpo = await empaquetado.arrayBuffer();\n    tamCuerpo = cuerpo.byteLength;')
SONDA = '''    // Prueba chica: si Didit corta la conexion apenas llega un pedido grande (clave invalida o tamano), una prueba con una imagen diminuta deja ver el motivo real.
    let sonda = "sin respuesta";
    try {
      const f2 = new FormData();
      f2.append("issuing_state", "ARG");
      f2.append("services", "arg_renaper");
      f2.append("document_number", "12345678");
      f2.append("gender", "M");
      const chica = Uint8Array.from(atob("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="), (c) => c.charCodeAt(0));
      f2.append("selfie", new Blob([chica], { type: "image/jpeg" }), "chica.jpg");
      const r2 = await fetch("https://verification.didit.me/v3/database-validation/", { method: "POST", headers: { "x-api-key": env.DIDIT_API_KEY ?? "" }, body: f2 });
      sonda = r2.status + " " + (await r2.text().catch(() => "")).slice(0, 300);
    } catch (error2) {
      sonda = "tambien falla: " + String(error2);
    }
    console.error("didit_unreachable", String(error), "bytes=" + tamCuerpo, "sonda=" + sonda);'''
cambio('prueba chica cuando falla la conexion',
 '    console.error("didit_unreachable", String(error));',
 SONDA)
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-identidad-sonda-panel.ps1 - Ojo Guard MS: cuando la conexion con Didit se corta ("Network connection lost"), el servidor anota el tamano del pedido y manda una prueba chica para ver que contesta Didit (sin la selfie ni la clave en el registro).
# Cambia SOLO src\\index.ts (respaldo .bak-identidad-sonda). Va en la carpeta del PANEL. Requiere aplicar-identidad-diag-panel.ps1 y aplicar-identidad-envio-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'let sonda') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const empaquetado') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-envio-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad-sonda')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el servidor ahora anota el motivo real cuando se corta la conexion con Didit."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-sonda-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
oi = fi
for _, _, v, n in filas: oi = oi.replace(v, n)
open(SC + 'index-sonda.ts', 'w', encoding='utf-8').write(oi)
print('ok', len(total), len(filas))
