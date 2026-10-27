# Genera scripts/aplicar-unirme-estetica-panel.ps1: la pagina /unirme ("Te invitaron a una familia") pasa al estilo actual y al ojo nuevo.
import re, runpy
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fam = open(R + 'aplicar-familia-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n').replace("''", "'")
a = fam.index('function familyJoinPage(url: URL) {')
b = fam.index('\n}\n', a) + 3
OLD = fam[a:b].rstrip('\n')
assert OLD.count('logo-correo.png') == 1 and OLD.endswith('}')

est = runpy.run_path(R + 'panel/generar_descarga_estetica_panel.py')['NEW']
estilo = re.search(r'const APK_ESTILO = `(.*?)`;\n', est, re.S).group(1).replace('</style>', '')
logo = re.search(r'const APK_LOGO = `(.*?)`;\n', est, re.S).group(1)
extra = '.codigo{font:700 2.6rem/1 "Plus Jakarta Sans",system-ui,sans-serif;letter-spacing:.22em;text-align:center;color:var(--dorado-texto);background:var(--dorado-suave);border-radius:22px;padding:22px 10px 22px 20px;margin:20px 0}ol{margin:0;padding-left:1.3em}.fondo-b{display:block}</style>'
NEW = ('const UNIRME_ESTILO = `' + estilo + extra + '`;\n'
       'const UNIRME_LOGO = `' + logo + '`;\n') + r'''/** Pagina que abre el link de invitacion (WhatsApp, mail): muestra el codigo y como usarlo. */
function familyJoinPage(url: URL) {
  const code = (url.searchParams.get("codigo") ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Unirte a una familia en Ojo Guard</title><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap">${UNIRME_ESTILO}<script>try{if(localStorage.getItem("ojo_ms_tema")==="oscuro")document.documentElement.classList.add("noche")}catch(e){}</script></head>
<body><main>${UNIRME_LOGO}<span class="etiqueta">N&Uacute;CLEO &middot; EN VALIDACI&Oacute;N</span><h1>Te invitaron a una familia</h1><p>Vas a compartir tu ubicaci&oacute;n con esa familia y ver la de ellos en el mapa.</p>
<div class="codigo">${code || "------"}</div>
<div class="tarjeta"><h2>C&oacute;mo te unis</h2><ol><li>Instal&aacute; Ojo Guard en tu tel&eacute;fono y entr&aacute; con tu correo.</li><li>And&aacute; a <b>Familia</b> &rsaquo; <b>Unirme con un c&oacute;digo</b>.</li><li>Escrib&iacute; el c&oacute;digo de arriba.</li></ol></div>
<p><a class="boton" href="ojoguard://familia?codigo=${code}">Abrir Ojo Guard</a></p>
<p class="suave">Si todav&iacute;a no la ten&eacute;s, en Android la bajas desde <a href="/descargar" style="color:var(--azul-link)">ojoguard.app/descargar</a>.</p></main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } });
}'''
NEW = NEW.replace('te unis', 'te unís').replace('bajas desde', 'bajás desde')
NEW = NEW.replace('C&oacute;mo te unís', 'C&oacute;mo te un&iacute;s').replace('la bajás desde', 'la baj&aacute;s desde')
filas = [('src\\index.ts', 'pagina de invitacion (/unirme) con el estilo actual', OLD, NEW)]
cambios = "$cambios = @(\n    ," + ',\n'.join("@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-unirme-estetica-panel.ps1 - Ojo Guard MS: la pagina de invitacion "Te invitaron a una familia" (/unirme) pasa al estilo actual y al ojo nuevo.
# Luciano (27/10/2026): "cambiar el ojo viejo en las otras paginas". Era la que quedaba con el fondo oscuro con dorado de antes y el logo-correo.png viejo.
# Funciona igual: muestra el codigo de 6 letras, los pasos y el boton "Abrir Ojo Guard". Se suma el link a ojoguard.app/descargar para quien todavia no tiene la app (Android).
# Cambia SOLO la funcion familyJoinPage en src\\index.ts (respaldo .bak-unirme). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const UNIRME_ESTILO') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-unirme')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: la pagina de invitacion ya se ve con el estilo actual."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-unirme-estetica-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/unirme_nuevo.ts', 'w').write(NEW)
open('/tmp/unirme_viejo.ts', 'w').write(OLD)
print('ok', len(total))
