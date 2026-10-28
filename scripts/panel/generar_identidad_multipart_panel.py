# Genera scripts/aplicar-identidad-multipart-panel.ps1: el pedido a Didit se arma a mano (multipart con su propio limite), porque el "content-type" sacado de Request venia vacio y Didit contestaba 400 sin cuerpo.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-cuerpo.ts', encoding='utf-8').read()
v1 = '''  const form = new FormData();
  form.append("issuing_state", "ARG");
  form.append("services", "arg_renaper");
  form.append("document_number", documento);
  form.append("gender", sexo);
  form.append("vendor_data", (await hash(`ojo-guard:${email}`)).slice(0, 24));
  form.append("selfie", new Blob([bytes], { type: "image/jpeg" }), "selfie.jpg");
  const control = new AbortController();'''
n1 = '''  // El pedido multipart se arma a mano, con su propio limite: el "content-type" que daba Request venia vacio (sin limite) y Didit contestaba 400 sin cuerpo.
  const limite = "----ojoguard" + crypto.randomUUID().replace(/-/g, "");
  const codificador = new TextEncoder();
  const partes: Uint8Array[] = [];
  const campo = (nombre: string, valor: string) => partes.push(codificador.encode(`--${limite}\\r\\nContent-Disposition: form-data; name="${nombre}"\\r\\n\\r\\n${valor}\\r\\n`));
  campo("issuing_state", "ARG");
  campo("services", "arg_renaper");
  campo("document_number", documento);
  campo("gender", sexo);
  campo("vendor_data", (await hash(`ojo-guard:${email}`)).slice(0, 24));
  partes.push(codificador.encode(`--${limite}\\r\\nContent-Disposition: form-data; name="selfie"; filename="selfie.jpg"\\r\\nContent-Type: image/jpeg\\r\\n\\r\\n`));
  partes.push(bytes);
  partes.push(codificador.encode(`\\r\\n--${limite}--\\r\\n`));
  const cuerpo = new Uint8Array(partes.reduce((suma, parte) => suma + parte.length, 0));
  let punto = 0;
  for (const parte of partes) {
    cuerpo.set(parte, punto);
    punto += parte.length;
  }
  const control = new AbortController();'''
v2 = '''    const empaquetado = new Request("https://verification.didit.me/v3/database-validation/", { method: "POST", body: form });
    const cuerpo = await empaquetado.arrayBuffer();
    tamCuerpo = cuerpo.byteLength;
    respuesta = await fetch("https://verification.didit.me/v3/database-validation/", {
      method: "POST",
      headers: { "x-api-key": env.DIDIT_API_KEY, "content-type": empaquetado.headers.get("content-type") ?? "multipart/form-data" },
      body: cuerpo,
      signal: control.signal,
    });'''
n2 = '''    tamCuerpo = cuerpo.byteLength;
    respuesta = await fetch("https://verification.didit.me/v3/database-validation/", {
      method: "POST",
      headers: { "x-api-key": env.DIDIT_API_KEY, "content-type": `multipart/form-data; boundary=${limite}` },
      body: cuerpo,
      signal: control.signal,
    });'''
for v in (v1, v2):
    assert fi.count(v) == 1, fi.count(v)
filas = [('src\\index.ts', 'pedido multipart armado a mano (datos)', v1, n1), ('src\\index.ts', 'pedido multipart armado a mano (envio)', v2, n2)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-identidad-multipart-panel.ps1 - Ojo Guard MS: el pedido a Didit se arma a mano con su limite multipart. Con wrangler tail se vio "didit_failed status=400 tipo=- largo=0": el content-type sacado de Request venia vacio (sin boundary).
# Cambia SOLO src\\index.ts (respaldo .bak-identidad-multipart). Va en la carpeta del PANEL. Requiere aplicar-identidad-cuerpo-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const limite = "----ojoguard"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto '"cuerpo=" + JSON.stringify') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-cuerpo-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad-multipart')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el pedido a Didit ahora lleva su limite multipart."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-multipart-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(SC + 'index-multipart.ts', 'w', encoding='utf-8').write(fi.replace(v1, n1).replace(v2, n2))
print('ok', len(total))
