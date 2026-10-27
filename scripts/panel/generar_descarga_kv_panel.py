# Genera scripts/aplicar-descarga-kv-panel.ps1: corrige la pagina de descarga (v1 asumia R2, pero EVIDENCE_FILES es un KV de 25 MB por valor).
# El APK pasa a guardarse en partes de 16 MB dentro del KV: descargas/<id>/<n>, con descargas/version.json (se escribe al final) que dice cual es la version vigente.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
v1 = open(R + 'panel/generar_descarga_panel.py', encoding='utf-8').read()
OLD = re.search(r"CODIGO = r'''(.*?)'''\n", v1, re.S).group(1)
cola_old = '\n\nfunction familyJoinPage(url: URL) {'
assert OLD.endswith(cola_old)
OLD = OLD[:-len(cola_old)]

NEW = OLD
def cambiar(viejo, nuevo):
    global NEW
    assert NEW.count(viejo) == 1, viejo
    NEW = NEW.replace(viejo, nuevo)

cambiar('El APK vive en R2 con clave fija y solo esa clave se sirve. */\nconst APK_CLAVE = "descargas/ojo-guard.apk";\n',
        'El APK vive en el KV del panel (EVIDENCE_FILES) en partes de 16 MB: descargas/<id>/<n>. Solo se sirven esas claves. */\n')
cambiar('type ApkInfo = { version: string; subido: string; bytes: number; sha256: string };',
        'type ApkInfo = { version: string; subido: string; bytes: number; sha256: string; partes: number };')
cambiar('''  const objeto = await env.EVIDENCE_FILES.get(APK_INFO_CLAVE);
  if (!objeto) return null;
  try {
    const dato = JSON.parse(await objeto.text()) as Partial<ApkInfo>;
    if (!dato.bytes || !dato.subido) return null;
    return { version: String(dato.version || ""), subido: String(dato.subido), bytes: Number(dato.bytes), sha256: String(dato.sha256 || "") };''',
'''  const texto = await env.EVIDENCE_FILES.get(APK_INFO_CLAVE);
  if (!texto) return null;
  try {
    const dato = JSON.parse(texto) as Partial<ApkInfo>;
    if (!dato.bytes || !dato.subido || !dato.partes || !/^[0-9a-f]{16,64}$/.test(String(dato.sha256 || ""))) return null;
    return { version: String(dato.version || ""), subido: String(dato.subido), bytes: Number(dato.bytes), sha256: String(dato.sha256), partes: Number(dato.partes) };''')
a = NEW.index('async function apkDescarga(')
b = NEW.index('/** Para que la app sepa')
NEW = NEW[:a] + r'''async function apkDescarga(request: Request, env: Env) {
  const info = await apkInfo(env);
  const kv = env.EVIDENCE_FILES;
  if (!kv || !info) return new Response("Todav\u00eda no hay una versi\u00f3n para bajar.", { status: 404, headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" } });
  const encabezados = {
    "content-type": "application/vnd.android.package-archive",
    "content-disposition": 'attachment; filename="ojo-guard.apk"',
    "content-length": String(info.bytes),
    "cache-control": "no-store"
  };
  if (request.method === "HEAD") return new Response(null, { headers: encabezados });
  const id = info.sha256.slice(0, 16);
  let n = 0;
  const flujo = new ReadableStream<Uint8Array>({
    async pull(control) {
      if (n >= info.partes) { control.close(); return; }
      const parte = await kv.get(`descargas/${id}/${n}`, "arrayBuffer");
      if (!parte) { control.error(new Error("falta la parte " + n)); return; }
      n += 1;
      control.enqueue(new Uint8Array(parte));
    }
  });
  return new Response(flujo, { headers: encabezados });
}
''' + NEW[b:]

filas = [('src\\index.ts', 'pagina de descarga: el APK va en partes dentro del KV', OLD, NEW)]
cambios = "$cambios = @(\n    ," + ',\n'.join("@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-descarga-kv-panel.ps1 - Ojo Guard MS: corrige la pagina de descarga https://ojoguard.app/descargar (va DESPUES de aplicar-descarga-panel.ps1).
# El primer instalador asumio que EVIDENCE_FILES era un R2; es un KV (25 MB por valor). Ahora el APK se guarda en partes de 16 MB dentro de ese KV
# (descargas/<id>/<n>) y descargas/version.json, que se escribe al final, dice cual es la version vigente. Asi nunca se arma un APK mezclando versiones.
# Cambia SOLO src\\index.ts (respaldo .bak-descargakv). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$indice = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $indice 'descargas/${id}/${n}') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indice 'function apkPagina(') -eq 0) { Mal "Falta aplicar primero aplicar-descarga-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-descargakv')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: la pagina https://ojoguard.app/descargar ya guarda el APK en partes. Falta subirlo (subir-apk-panel.ps1)."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-descarga-kv-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/nuevo_bloque.ts', 'w').write(NEW)
print('ok', len(total))
