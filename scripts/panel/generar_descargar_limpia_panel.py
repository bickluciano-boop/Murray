# Genera scripts/aplicar-descargar-limpia-panel.ps1: /descargar esconde la tarjeta de iPhone cuando lo abre un Android y manda a /bajar cuando lo abre un iPhone.
import re
R = '/home/user/Murray/scripts/'
U = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
# index.ts tal como esta hoy en la maquina de Luciano: archivo subido + instalador de TestFlight + de /bajar (los dos ya publicados).
fi = open(SC + 'index-bajar.ts', encoding='utf-8').read().replace('\r\n', '\n')
filas = []
def cambio(rotulo, viejo, nuevo):
    assert fi.count(viejo) == 1, (rotulo, fi.count(viejo))
    filas.append(('src\\index.ts', rotulo, viejo, nuevo))

NUEVA = """/** /descargar: para un Android esconde la tarjeta de iPhone (no le sirve); un iPhone pasa a /bajar, que le muestra la guia de TestFlight. */
async function apkPagina(env: Env, request: Request) {
  const ua = request.headers.get("user-agent") ?? "";
  if (/iPhone|iPad|iPod/i.test(ua)) return Response.redirect(new URL("/bajar", request.url).toString(), 302);
  const base = await apkPaginaBase(env);
  if (!/android/i.test(ua)) return base;
  const texto = await base.text();
  const limpio = texto.replace(/<div class="tarjeta"><h2>En iPhone<\\/h2>[\\s\\S]*?Instalar en iPhone<\\/a><\\/p><\\/div>/, "");
  return new Response(limpio, { status: base.status, headers: base.headers });
}
async function apkPaginaBase(env: Env) {"""
cambio('pagina de descarga: version limpia por celular',
 'async function apkPagina(env: Env) {',
 NUEVA)
cambio('ruta /descargar con la solicitud',
 '      if (route === "GET /descargar") return apkPagina(env);',
 '      if (route === "GET /descargar") return apkPagina(env, request);')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-descargar-limpia-panel.ps1 - Ojo Guard MS: /descargar deja de mostrarle a un Android la tarjeta de iPhone; un iPhone que abre /descargar pasa a /bajar (guia de TestFlight).
# Luciano (28/10/2026): vio "Instalar en iPhone" en la pagina de descarga de su Android. Cambia SOLO src\\index.ts (respaldo .bak-descargar-limpia). Va en la carpeta del PANEL (la que tiene wrangler.toml). Requiere aplicar-bajar-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'function apkPaginaBase') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'function apkBajar') -eq 0) { Mal "Falta aplicar primero aplicar-bajar-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-descargar-limpia')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: /descargar ya no le muestra a un Android la tarjeta de iPhone."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-descargar-limpia-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
oi = fi
for _, _, v, n in filas: oi = oi.replace(v, n)
open(SC + 'index-descargar-limpia.ts', 'w', encoding='utf-8').write(oi)
print('ok', len(total), len(filas))
