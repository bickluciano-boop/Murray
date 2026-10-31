# Genera scripts/aplicar-mapa-otro-dia-compacto-panel.ps1: achica el selector "Otro dia" para que no lo tape la columna de botones de la derecha (se vio en Android e iPhone el 31/10/2026).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
# El CSS que puso el instalador anterior (hay que reconocerlo igual para reemplazarlo).
old = open(R + 'panel/generar_mapa_otro_dia_panel.py', encoding='utf-8').read()
ns = {}
exec(old[old.index("CSS = ("):old.index("m1a = ")], ns)
CSS_VIEJO = ns['CSS']
CSS_NUEVO = ('#og-mapa .ogm-dia{position:absolute;z-index:3;top:72px;left:18px;display:flex;flex-wrap:wrap;align-items:center;gap:2px 4px;padding:4px;background:var(--ogm-panel);border:1px solid var(--ogm-linea);border-radius:14px;box-shadow:var(--ogm-sombra);max-width:calc(100% - 96px);box-sizing:border-box}'
             '#og-mapa .ogm-dia.hidden{display:none}'
             '#og-mapa .ogm-dia button{flex:none;width:34px;height:34px;border-radius:10px;font-size:1.2rem;color:var(--ogm-oro-vivo)}'
             '#og-mapa .ogm-dia input{flex:none;width:132px;min-width:0;height:34px;padding:0 6px;border-radius:10px;border:1px solid var(--ogm-linea);background:transparent;color:var(--ogm-texto);font:inherit;font-size:.82rem;color-scheme:dark light}'
             '#og-mapa .ogm-dia-txt{flex-basis:100%;font-size:.76rem;color:var(--ogm-suave);padding:0 6px 3px}'
             '#og-mapa .ogm-dia-txt:empty{display:none}'
             '@media (max-width:899px){#og-mapa .ogm-dia{top:calc(max(12px, env(safe-area-inset-top)) + 56px);left:12px;max-width:calc(100% - 112px)}#og-mapa .ogm-seg{max-width:calc(100% - 80px)}#og-mapa .ogm-seg button{padding:8px 7px;font-size:.78rem;gap:5px}}')
a1 = '<style id="ogm-dia-css">' + CSS_VIEJO + '</style>'
b1 = '<style id="ogm-dia-css">' + CSS_NUEVO + '</style>'
a2 = '<button type="button" data-rango="dia">Otro día</button>'
b2 = '<button type="button" data-rango="dia">Un día</button>'
h1a = '<script type="module" src="/mapa-v1.js?v=5"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=6"></script>'
filas = [('src\\panel-mapa.txt', 'mapa: selector de dia mas chico', a1, b1),
         ('src\\panel-mapa.txt', 'mapa: boton Un dia (mas corto)', a2, b2),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=6)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-otro-dia-compacto-panel.ps1 - Ojo Guard MS: achica el selector del mapa "Otro dia" (ahora "Un dia") para que no lo tape la columna de botones de la derecha.
# Motivo (31/10/2026, capturas de Luciano en Android e iPhone): el calendario y el boton quedaban debajo de los botones de la derecha y el resumen se cortaba. Cambia solo src\\panel-mapa.txt (el estilo y el nombre del boton) y src\\panel-index.html (v=6). Respaldo .bak-otrodia2. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'max-width:calc(100% - 96px)') -ne 0) { Avi "Esto ya estaba aplicado (o ya aplicaste la version anterior del selector chico: avisame y lo ajusto). No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=5') -ne 1) { Mal "El mapa no esta en v=5 (falta aplicar primero aplicar-mapa-otro-dia-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-otrodia2')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el selector del mapa es mas chico. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›']
assert not bad, set(bad)
open(R + 'aplicar-mapa-otro-dia-compacto-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
