# Genera scripts/aplicar-identidad-matriz-panel.ps1: cuando se corta la conexion con Didit, el servidor prueba pedidos de distintos tamanos y anota cuales pasan.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-sonda.ts', encoding='utf-8').read()
viejo = '    console.error("didit_unreachable", String(error), "bytes=" + tamCuerpo, "sonda=" + sonda);'
nuevo = '''    // Pedidos de prueba de distintos tamanos (bytes al azar con cabecera de JPEG): Didit contesta 400 a todos si el pedido pasa; si se corta la conexion, ese tamano no pasa.
    const matriz: string[] = [];
    for (const [kb, conVd] of [[1, true], [100, false], [300, false], [520, false], [1024, false]] as Array<[number, boolean]>) {
      try {
        const f3 = new FormData();
        f3.append("issuing_state", "ARG");
        f3.append("services", "arg_renaper");
        f3.append("document_number", "12345678");
        f3.append("gender", "M");
        if (conVd) f3.append("vendor_data", "prueba");
        const falsos = new Uint8Array(kb * 1024);
        for (let o = 0; o < falsos.length; o += 65536) crypto.getRandomValues(falsos.subarray(o, Math.min(o + 65536, falsos.length)));
        falsos[0] = 0xff;
        falsos[1] = 0xd8;
        falsos[2] = 0xff;
        f3.append("selfie", new Blob([falsos], { type: "image/jpeg" }), "prueba.jpg");
        const emp3 = new Request("https://verification.didit.me/v3/database-validation/", { method: "POST", body: f3 });
        const cu3 = await emp3.arrayBuffer();
        const r3 = await fetch("https://verification.didit.me/v3/database-validation/", { method: "POST", headers: { "x-api-key": env.DIDIT_API_KEY ?? "", "content-type": emp3.headers.get("content-type") ?? "multipart/form-data" }, body: cu3 });
        matriz.push(kb + "k=" + r3.status);
      } catch {
        matriz.push(kb + "k=CORTA");
      }
    }
    console.error("didit_unreachable", String(error), "bytes=" + tamCuerpo, "sonda=" + sonda, "matriz=" + matriz.join(" "));'''
assert fi.count(viejo) == 1, fi.count(viejo)
filas = [('src\\index.ts', 'pruebas de distintos tamanos', viejo, nuevo)]
cambios = "$cambios = @(\n    ," + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in filas[0]) + "\n)\n"
cabeza = '''# aplicar-identidad-matriz-panel.ps1 - Ojo Guard MS: cuando se corta la conexion con Didit, prueba pedidos de 1, 100, 300, 520 y 1024 KB y anota cuales pasan (sonda=400 mostro que la clave y la conexion andan; la selfie de 535 KB se corta).
# Cambia SOLO src\\index.ts (respaldo .bak-identidad-matriz). Va en la carpeta del PANEL. Requiere aplicar-identidad-sonda-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const matriz') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'let sonda') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-sonda-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad-matriz')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el servidor ahora prueba distintos tamanos cuando falla Didit."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-matriz-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
oi = fi.replace(viejo, nuevo)
open(SC + 'index-matriz.ts', 'w', encoding='utf-8').write(oi)
print('ok', len(total))
