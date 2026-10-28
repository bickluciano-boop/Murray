# Genera scripts/aplicar-bajar-panel.ps1: un solo enlace para todos, ojoguard.app/bajar (Android -> descarga; iPhone -> guia de TestFlight; compu -> las dos).
import re
R = '/home/user/Murray/scripts/'
U = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
LINK = 'https://testflight.apple.com/join/QcWAsHkG'
# index.ts tal como esta en la maquina de Luciano: archivo subido + instalador de TestFlight (ya publicado).
fi = open(U + '61ee18a5-index.ts', encoding='utf-8').read().replace('\r\n', '\n')
fi = fi.replace('const APK_ESTILO = `<style>', 'const URL_TESTFLIGHT = "%s";\nconst APK_ESTILO = `<style>' % LINK, 1)
filas = []
def cambio(archivo, fuente, rotulo, viejo, nuevo):
    assert fuente.count(viejo) == 1, (rotulo, fuente.count(viejo))
    filas.append((archivo, rotulo, viejo, nuevo))


def entidades(t):
    out = []
    for ch in t:
        out.append(ch if ord(ch) < 128 else '&#%d;' % ord(ch))
    return ''.join(out)

# Los 4 pasos, escritos para quien nunca uso TestFlight (la primera usuaria real se confundio justo ahi).
PASOS = [
 'Tocá <strong>Instalar en iPhone</strong>. Se abre la App Store con <strong>TestFlight</strong>, la app de Apple para probar versiones nuevas. Es normal: primero se instala esa.',
 'Tocá <strong>Obtener</strong> para instalar TestFlight y después volvé a tocar <strong>Instalar en iPhone</strong>.',
 'Aceptá los términos de TestFlight y tocá <strong>Instalar</strong> en la pantalla de Ojo Guard. Si el botón está gris, esperá unos segundos.',
 'Abrí <strong>Ojo Guard</strong>: es el ícono con un ojo dorado sobre fondo azul. Dejá TestFlight instalada: es la que te avisa cuando hay versiones nuevas.',
]
LISTA = '<ol style="margin:8px 0 14px;padding-left:22px;line-height:1.65">' + ''.join('<li>' + entidades(p) + '</li>' for p in PASOS) + '</ol>'
LISTA_LOGIN = '<ol>' + ''.join('<li>' + entidades(p) + '</li>' for p in PASOS) + '</ol>'

FUNCION = """/** ojoguard.app/bajar: un solo enlace para todos. Desde un Android va a la descarga; desde un iPhone muestra la guia de TestFlight; desde una compu (o la vista previa de WhatsApp) muestra las dos. */
function apkBajar(request: Request) {
  const ua = request.headers.get("user-agent") ?? "";
  if (/android/i.test(ua)) return Response.redirect(new URL("/descargar", request.url).toString(), 302);
  const iphone = /iPhone|iPad|iPod/i.test(ua);
  const guia = `<div class="tarjeta"><h2>En iPhone</h2><p>Se instala en 4 pasos con TestFlight, la app de Apple para probar versiones nuevas.</p>__LISTA__<p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>`;
  const android = `<div class="tarjeta"><h2>En Android</h2><p>Se baja el instalador y se instala encima, sin tienda de por medio.</p><p><a class="boton" href="/descargar">Descargar para Android</a></p></div>`;
  const cuerpo = iphone
    ? `<h1>Ojo Guard para iPhone</h1>${guia}`
    : `<h1>Bajar Ojo Guard</h1><p>Si abr&iacute;s este enlace desde tu celular, te lleva directo a la descarga que le corresponde. Desde ac&aacute; pod&eacute;s elegir:</p>${android}${guia}`;
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Bajar Ojo Guard</title><meta property="og:title" content="Ojo Guard"><meta property="og:description" content="Funciona entre iPhone y Android. Toc&aacute; para bajar la app."><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap">${APK_ESTILO}<script>try{if(localStorage.getItem("ojo_ms_tema")==="oscuro")document.documentElement.classList.add("noche")}catch(e){}</script></head><body><main>${APK_LOGO}<span class="etiqueta">N\\u00daCLEO \\u00b7 EN VALIDACI\\u00d3N</span>${cuerpo}</main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "vary": "user-agent", "referrer-policy": "no-referrer" } });
}
""".replace('__LISTA__', LISTA)
I = 'src\\index.ts'
cambio(I, fi, 'pagina del enlace unico /bajar',
 'async function apkDescarga(request: Request, env: Env) {',
 FUNCION + 'async function apkDescarga(request: Request, env: Env) {')
cambio(I, fi, 'ruta /bajar',
 '      if (route === "GET /descargar") return apkPagina(env);',
 '      if (route === "GET /descargar") return apkPagina(env);\n      if (route === "GET /bajar") return apkBajar(request);')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-bajar-panel.ps1 - Ojo Guard MS: enlace unico https://ojoguard.app/bajar para mandar por WhatsApp o en un QR.
# Desde un Android lleva a /descargar; desde un iPhone muestra la guia de 4 pasos con TestFlight; desde una compu muestra las dos opciones.
# Luciano (28/10/2026): "no les puedo mandar un QR o un link?". Cambia SOLO src\\index.ts (respaldo .bak-bajar). Va en la carpeta del PANEL (la que tiene wrangler.toml). Requiere aplicar-testflight-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'function apkBajar') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const URL_TESTFLIGHT') -eq 0) { Mal "Falta aplicar primero aplicar-testflight-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-bajar')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: ojoguard.app/bajar ya funciona."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-bajar-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
oi = fi
for a_, _, v, n in filas: oi = oi.replace(v, n)
open(SC + 'index-bajar.ts', 'w', encoding='utf-8').write(oi)
print('ok', len(total), len(filas))
