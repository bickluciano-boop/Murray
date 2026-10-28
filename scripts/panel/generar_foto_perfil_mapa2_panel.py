# Genera scripts/aplicar-foto-perfil-mapa2-panel.ps1 (cuando Didit da 500 se prueban variantes). Antes: la clave DIDIT_API_KEY se limpia (espacios, comillas, "Bearer") y el registro anota su forma (largos), sin mostrarla. Didit contesta 400 vacio incluso con el pedido multipart bien armado.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
U = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/'
fm = open(U + '7bfd7b7d-panel-mapa.txt', encoding='utf-8').read().replace('\r\n', '\n')
fh = open(U + '3347fd7c-panel-index-actual.html', encoding='utf-8').read().replace('\r\n', '\n')
# El texto del mapa ya con el instalador anterior (aplicar-foto-perfil-mapa2-panel.ps1) puesto.
p1a = '      idFamilia: p.id,\n      plataforma: p.platform || "",\n    };'
p1b = '      idFamilia: p.id,\n      plataforma: p.platform || "",\n      // Version de la foto de perfil de esa persona (vacia si no tiene): cambia cuando la cambia.\n      fotoV: p.photo ? String(p.photo) : "",\n    };'
p2a = '  if (DEMO || equipo.tipo !== "telefono") return null;\n'
p2b = '  if (DEMO) return null;\n  // Las personas muestran su foto de perfil (la que subieron desde la app); el servidor solo la da a quien ya las ve en la lista.\n  if (equipo.tipo === "persona") return equipo.fotoV ? `/api/remote/profile-photo?person=${encodeURIComponent(equipo.idFamilia)}&v=${equipo.fotoV}` : null;\n  if (equipo.tipo !== "telefono") return null;\n'
fm = fm.replace(p1a, p1b).replace(p2a, p2b)
a1 = '  if (equipo.tipo !== "telefono") return null;\n'
b1 = """  if (equipo.tipo !== "telefono") return null;
  // Un celular tuyo sin foto propia muestra tu foto de perfil (la de la app). Se anota cuales no tienen foto propia para no pedirla en cada dibujo.
  if (SIN_FOTO_EQUIPO.has(equipo.id)) return fotoPerfilPropia();
"""
a2 = 'function urlFoto(equipo) {\n'
b2 = """const SIN_FOTO_EQUIPO = (window.__ogmSinFoto = window.__ogmSinFoto || new Set());
function fotoPerfilPropia() {
  return `/api/remote/profile-photo?person=me&v=${Math.floor(Date.now() / 60000)}`;
}
""" + a2
a3 = '${foto ? `<img src="${foto}" alt="" onerror="this.remove()">` : ""}'
b3 = '${foto ? `<img src="${esc(foto)}" alt="" onerror="${esc(errorFoto(equipo, dibujo))}">` : ""}'
a4 = 'function avatarHtml(equipo, clase = "") {\n'
b4 = """/** Si la foto del equipo no esta: en un celular se prueba con la foto de perfil de la cuenta; si tampoco esta, se saca la imagen y queda el dibujo. */
function errorFoto(equipo, dibujo) {
  if (equipo.tipo === "telefono" && dibujo === DIBUJO_CELULAR && !SIN_FOTO_EQUIPO.has(equipo.id)) {
    return `window.__ogmSinFoto.add(${JSON.stringify(equipo.id)});this.onerror=function(){this.remove()};this.src=${JSON.stringify(fotoPerfilPropia())}`;
  }
  return "this.remove()";
}

""" + a4
a5 = '<script type="module" src="/mapa-v1.js?v=2"></script>'
b5 = '<script type="module" src="/mapa-v1.js?v=3"></script>'
fh = fh.replace('<script type="module" src="/mapa-v1.js?v=1"></script>', a5)
for t, v in ((fm, a1), (fm, a2), (fm, a3), (fm, a4), (fh, a5)):
    assert t.count(v) == 1, (v[:50], t.count(v))
filas = [('src\\panel-mapa.txt', 'tu celular muestra tu foto de perfil (aviso de equipos sin foto)', a1, b1), ('src\\panel-mapa.txt', 'funciones de la foto de perfil propia', a2, b2), ('src\\panel-mapa.txt', 'si falla la foto del equipo se prueba la de perfil', a3, b3), ('src\\panel-mapa.txt', 'funcion errorFoto', a4, b4), ('src\\panel-index.html', 'recargar el mapa nuevo (v=3)', a5, b5)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
open('/tmp/mapa2-test.mjs', 'w', encoding='utf-8').write(fm.replace(a1, b1).replace(a2, b2).replace(a3, b3).replace(a4, b4))
cabeza = '''# aplicar-foto-perfil-mapa2-panel.ps1 - Ojo Guard MS: tu celular, en el mapa y en la lista, muestra tu foto de perfil (si no le pusiste una foto propia con el lapiz).
# Luciano (28/10/2026): "si no aparece aca, mucho sentido no tiene". Requiere aplicar-foto-perfil-mapa-panel.ps1. Cambia src\\panel-mapa.txt y src\\panel-index.html (solo sube a v=3 el numero del script; respaldo .bak-foto-perfil-mapa2). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'SIN_FOTO_EQUIPO') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'fotoV') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil-mapa-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-foto-perfil-mapa2')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: tu celular muestra tu foto de perfil en el mapa y la lista."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-foto-perfil-mapa2-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
