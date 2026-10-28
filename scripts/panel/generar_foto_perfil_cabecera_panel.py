# Genera scripts/aplicar-foto-perfil-cabecera-panel.ps1 (cuando Didit da 500 se prueban variantes). Antes: la clave DIDIT_API_KEY se limpia (espacios, comillas, "Bearer") y el registro anota su forma (largos), sin mostrarla. Didit contesta 400 vacio incluso con el pedido multipart bien armado.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
U = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/'
fa = open(U + '1b87a220-panel-app.txt', encoding='utf-8').read().replace('\r\n', '\n')
fh = open(U + '3347fd7c-panel-index-actual.html', encoding='utf-8').read().replace('\r\n', '\n')
a1 = 'function renderDashboard(account) {\n'
b1 = """/** Mi foto de perfil al lado del correo (la que subi desde la app). Si todavia no hay, no se muestra nada. */
function ponerFotoCuenta() {
  const lugar = $("#account-email");
  if (!lugar || demoMode) return;
  const foto = new Image();
  foto.className = "account-foto";
  foto.alt = "";
  foto.onload = () => { if (!lugar.querySelector(".account-foto")) lugar.prepend(foto); };
  foto.src = `/api/remote/profile-photo?person=me&v=${Math.floor(Date.now() / 60000)}`;
}

""" + a1
a2 = '  $("#account-email-copy").textContent = account.email || "Correo no disponible";\n'
b2 = a2 + '  ponerFotoCuenta();\n'
a3 = '    </style>\n  </head>'
b3 = '/* foto de perfil al lado del correo */\n.account-foto{width:36px;height:36px;border-radius:50%;object-fit:cover;vertical-align:middle;margin-right:10px;border:2px solid #D4A94D}\n' + a3
a4 = '<script type="module" src="/app-v9.js?v=8"></script>'
b4 = '<script type="module" src="/app-v9.js?v=9"></script>'
for t, v in ((fa, a1), (fa, a2), (fh, a3), (fh, a4)):
    assert t.count(v) == 1, (v[:40], t.count(v))
filas = [('src\\panel-app.txt', 'funcion de la foto junto al correo', a1, b1), ('src\\panel-app.txt', 'mostrar la foto junto al correo', a2, b2), ('src\\panel-index.html', 'estilo de la foto junto al correo', a3, b3), ('src\\panel-index.html', 'recargar el script nuevo (v=9)', a4, b4)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-foto-perfil-cabecera-panel.ps1 - Ojo Guard MS: tu foto de perfil al lado del correo, arriba en el panel.
# Luciano (28/10/2026): "al lado del mail". Usa GET /api/remote/profile-photo?person=me (aplicar-foto-perfil-panel.ps1). Si todavia no subiste tu foto desde la app, no se muestra nada.
# Cambia src\\panel-app.txt y src\\panel-index.html (respaldo .bak-foto-perfil-cabecera; sube a v=9 el numero del script para que los navegadores lo recarguen). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-app.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'ponerFotoCuenta') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'profile_photos') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil-panel.ps1 (servidor). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-foto-perfil-cabecera')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: tu foto de perfil aparece al lado del correo."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-foto-perfil-cabecera-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
