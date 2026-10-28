# Genera scripts/aplicar-foto-perfil-mapa-panel.ps1 (cuando Didit da 500 se prueban variantes). Antes: la clave DIDIT_API_KEY se limpia (espacios, comillas, "Bearer") y el registro anota su forma (largos), sin mostrarla. Didit contesta 400 vacio incluso con el pedido multipart bien armado.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
U = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/'
fm = open(U + '7bfd7b7d-panel-mapa.txt', encoding='utf-8').read().replace('\r\n', '\n')
fh = open(U + '3347fd7c-panel-index-actual.html', encoding='utf-8').read().replace('\r\n', '\n')
a1 = '      idFamilia: p.id,\n      plataforma: p.platform || "",\n    };'
b1 = '      idFamilia: p.id,\n      plataforma: p.platform || "",\n      // Version de la foto de perfil de esa persona (vacia si no tiene): cambia cuando la cambia.\n      fotoV: p.photo ? String(p.photo) : "",\n    };'
a2 = '  if (DEMO || equipo.tipo !== "telefono") return null;\n'
b2 = '  if (DEMO) return null;\n  // Las personas muestran su foto de perfil (la que subieron desde la app); el servidor solo la da a quien ya las ve en la lista.\n  if (equipo.tipo === "persona") return equipo.fotoV ? `/api/remote/profile-photo?person=${encodeURIComponent(equipo.idFamilia)}&v=${equipo.fotoV}` : null;\n  if (equipo.tipo !== "telefono") return null;\n'
a3 = '<script type="module" src="/mapa-v1.js?v=1"></script>'
b3 = '<script type="module" src="/mapa-v1.js?v=2"></script>'
for t, v in ((fm, a1), (fm, a2), (fh, a3)):
    assert t.count(v) == 1, (v[:40], t.count(v))
filas = [('src\\panel-mapa.txt', 'version de la foto de cada persona', a1, b1), ('src\\panel-mapa.txt', 'foto de perfil de las personas en el mapa y la lista', a2, b2), ('src\\panel-index.html', 'recargar el mapa nuevo (v=2)', a3, b3)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-foto-perfil-mapa-panel.ps1 - Ojo Guard MS: el mapa y la lista del panel muestran la foto de perfil de cada persona (como Buscar de Apple).
# Luciano (28/10/2026): la foto la tiene que ver la gente con la que se comparte. Usa GET /api/remote/profile-photo (aplicar-foto-perfil-panel.ps1) y el campo "photo" de cada persona.
# Cambia src\\panel-mapa.txt y src\\panel-index.html (solo sube a v=2 el numero del script para que los navegadores lo recarguen; respaldo .bak-foto-perfil-mapa). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'fotoV') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'profile_photos') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil-panel.ps1 (servidor). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-foto-perfil-mapa')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el mapa y la lista del panel muestran la foto de perfil de cada persona."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-foto-perfil-mapa-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
