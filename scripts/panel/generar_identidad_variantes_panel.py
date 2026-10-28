# Genera scripts/aplicar-identidad-variantes-panel.ps1 (cuando Didit da 500 se prueban variantes). Antes: la clave DIDIT_API_KEY se limpia (espacios, comillas, "Bearer") y el registro anota su forma (largos), sin mostrarla. Didit contesta 400 vacio incluso con el pedido multipart bien armado.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-clave.ts', encoding='utf-8').read()
CHICA = re.search(r'atob\("(/9j/4AAQ[^"]*)"\)', fi).group(1)
a1 = 'export default {\n  async scheduled(_controller'
b1 = """// Diagnostico: arma un pedido multipart (campos de texto + una selfie) con su propio limite.
function multipartDidit(campos: Array<[string, string]>, archivo: Uint8Array) {
  const limite = "----ojoguard" + crypto.randomUUID().replace(/-/g, "");
  const codificador = new TextEncoder();
  const partes: Uint8Array[] = [];
  for (const [nombre, valor] of campos) partes.push(codificador.encode(`--${limite}\\r\\nContent-Disposition: form-data; name="${nombre}"\\r\\n\\r\\n${valor}\\r\\n`));
  partes.push(codificador.encode(`--${limite}\\r\\nContent-Disposition: form-data; name="selfie"; filename="selfie.jpg"\\r\\nContent-Type: image/jpeg\\r\\n\\r\\n`));
  partes.push(archivo);
  partes.push(codificador.encode(`\\r\\n--${limite}--\\r\\n`));
  const cuerpo = new Uint8Array(partes.reduce((suma, parte) => suma + parte.length, 0));
  let punto = 0;
  for (const parte of partes) {
    cuerpo.set(parte, punto);
    punto += parte.length;
  }
  return { cuerpo, tipo: `multipart/form-data; boundary=${limite}` };
}

""" + a1
a2 = '    return json({ error: "identity_provider_error", status: respuesta.status }, 502);'
b2 = """    if (respuesta.status >= 500) {
      // Didit se rompio por dentro (500): se prueban variantes del mismo pedido para ver cual lo hace fallar. Se anota cada resultado.
      const chica = Uint8Array.from(atob("%s"), (c) => c.charCodeAt(0));
      const base: Array<[string, string]> = [["issuing_state", "ARG"], ["services", "arg_renaper"], ["document_number", documento], ["gender", sexo]];
      const pruebas: Array<[string, Array<[string, string]>, Uint8Array]> = [
        ["sinVd", base, bytes],
        ["conDatos", [...base, ["first_name", "Prueba"], ["last_name", "Prueba"], ["date_of_birth", "1980-01-01"]], bytes],
        ["sinServices", base.filter(([clave]) => clave !== "services"), bytes],
        ["fotoChica", base, chica],
        ["conVd", [...base, ["vendor_data", "prueba"]], chica],
      ];
      const salidas = await Promise.all(pruebas.map(async ([nombre, campos, archivo]) => {
        try {
          const armado = multipartDidit(campos, archivo);
          const r = await fetch("https://verification.didit.me/v3/database-validation/", { method: "POST", headers: { "x-api-key": claveDidit, "content-type": armado.tipo }, body: armado.cuerpo, signal: AbortSignal.timeout(20000) });
          const t = await r.text();
          return nombre + "=" + r.status + " " + JSON.stringify(t.slice(0, 160));
        } catch (error) {
          return nombre + "=ERROR " + String(error).slice(0, 60);
        }
      }));
      console.error("didit_variantes", salidas.join(" | "));
    }
""" % CHICA + a2
for v in (a1, a2):
    assert fi.count(v) == 1, (v, fi.count(v))
filas = [('src\\index.ts', 'funcion de pedido multipart de prueba', a1, b1), ('src\\index.ts', 'variantes del pedido cuando Didit da 500', a2, b2)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-identidad-variantes-panel.ps1 - Ojo Guard MS: con la clave bien cargada Didit contesta 500 (error interno, HTML) a la consulta RENAPER. Cuando pasa, el servidor manda 5 variantes del pedido (sin vendor_data, con nombre y fecha, sin services, selfie chica) y anota cual funciona.
# Cambia SOLO src\\index.ts (respaldo .bak-identidad-variantes). Va en la carpeta del PANEL. Requiere aplicar-identidad-clave-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'didit_variantes') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const claveDidit') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-clave-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad-variantes')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: si Didit da 500 el servidor prueba variantes del pedido."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-variantes-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(SC + 'index-variantes.ts', 'w', encoding='utf-8').write(fi.replace(a1, b1).replace(a2, b2))
print('ok', len(total))
