# Genera scripts/aplicar-mapa-otro-dia-v3-panel.ps1: el selector "Un dia" aguanta letras grandes (Android): botones sin partir en dos renglones, barra del dia en una sola fila y mas baja.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
# El CSS que dejo el instalador "compacto" (hay que reconocerlo exacto para reemplazarlo).
old = open(R + 'panel/generar_mapa_otro_dia_compacto_panel.py', encoding='utf-8').read()
ns = {}
exec(old[old.index("CSS_NUEVO = ("):old.index("a1 = ")], ns)
CSS_V2 = ns['CSS_NUEVO']
CSS_V3 = ('/*v3*/#og-mapa .ogm-dia,#og-mapa .ogm-dia *{box-sizing:border-box}'
          '#og-mapa .ogm-dia{position:absolute;z-index:3;top:72px;left:18px;display:grid;grid-template-columns:32px 122px 32px;align-items:center;gap:0 2px;padding:3px;background:var(--ogm-panel);border:1px solid var(--ogm-linea);border-radius:14px;box-shadow:var(--ogm-sombra);width:max-content;max-width:calc(100% - 96px)}'
          '#og-mapa .ogm-dia.hidden{display:none}'
          '#og-mapa .ogm-dia button{flex:none;width:32px;height:30px;padding:0;border-radius:10px;font-size:1.15rem;line-height:1;color:var(--ogm-oro-vivo)}'
          '#og-mapa .ogm-dia input{flex:none;width:122px;min-width:0;height:30px;padding:0 4px;border-radius:10px;border:1px solid var(--ogm-linea);background:transparent;color:var(--ogm-texto);font:inherit;font-size:.78rem;color-scheme:dark light}'
          '#og-mapa .ogm-dia-txt{grid-column:1/-1;font-size:.72rem;line-height:1.15;color:var(--ogm-suave);padding:1px 6px 2px}'
          '#og-mapa .ogm-dia-txt:empty{display:none}'
          '@media (max-width:899px){#og-mapa .ogm-dia{top:calc(max(12px, env(safe-area-inset-top)) + 52px);left:12px;max-width:calc(100% - 112px)}'
          '#og-mapa .ogm-seg{max-width:calc(100% - 76px);overflow-x:auto;scrollbar-width:none}'
          '#og-mapa .ogm-seg::-webkit-scrollbar{display:none}'
          '#og-mapa .ogm-seg button{padding:7px 6px;font-size:.74rem;gap:4px;white-space:nowrap;flex:none}'
          '#og-mapa .ogm-seg i{width:6px;height:6px;box-shadow:0 0 0 3px color-mix(in srgb, var(--ogm-vivo) 22%, transparent)}}')
a1 = '<style id="ogm-dia-css">' + CSS_V2 + '</style>'
b1 = '<style id="ogm-dia-css">' + CSS_V3 + '</style>'
h1a = '<script type="module" src="/mapa-v1.js?v=6"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=7"></script>'
filas = [('src\\panel-mapa.txt', 'mapa: selector de dia que aguanta letras grandes', a1, b1),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=7)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-otro-dia-v3-panel.ps1 - Ojo Guard MS: el selector "Un dia" del mapa aguanta letras grandes (Android).
# Motivo (31/10/2026, captura de Luciano en el Android): con el texto mas grande los botones de arriba se partian en dos renglones y la barra del dia ocupaba mucho; en iPhone se veia bien. Ahora los botones no se parten (y si no entran, se deslizan), y la barra del dia va en una sola fila mas baja.
# Cambia SOLO el estilo en src\\panel-mapa.txt y src\\panel-index.html (v=7). Respaldo .bak-otrodia3. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto '/*v3*/') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=6') -ne 1) { Mal "El mapa no esta en v=6 (falta aplicar primero aplicar-mapa-otro-dia-compacto-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-otrodia3')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el selector Un dia aguanta letras grandes. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›']
assert not bad, set(bad)
open(R + 'aplicar-mapa-otro-dia-v3-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
