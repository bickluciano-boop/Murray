# Genera scripts/aplicar-correos-marca-panel.ps1: los mails salen con la imagen nueva (azul, blanco y dorado) y los links salen con ms.ojoguard.app.
# Cambia SOLO src\index.ts del panel. El cuerpo de cada mail se sigue escribiendo igual; la franja de arriba y los colores se pasan en un solo lugar (claroCorreo / conMarcaCorreoNuevo).
import re, base64
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
b64 = base64.b64encode(open(R + 'correos/ojo-guard-correo.png', 'rb').read()).decode()
bloque = open(R + 'correos/correos-marca.ts', encoding='utf-8').read().replace('__LOGO_B64__', b64).rstrip('\n') + '\n'
assert "'" not in b64

A1 = 'const DEFAULT_PANEL_URL = "https://ojo-guard-ms-api.bickluciano.workers.dev/";'
N1 = 'const DEFAULT_PANEL_URL = "https://ms.ojoguard.app/";'
A2 = 'conMarcaCorreo(datos.html, datos.subject)'
N2 = 'conMarcaCorreoNuevo(datos.html, datos.subject)'
A3 = 'if (route === "GET /marca/logo-correo.png") return logoCorreoResponse();'
N3 = 'if (route === "GET /marca/ojo-guard-correo.png") return logoCorreoNuevoResponse();\n      ' + A3
A4 = 'export default {'
N4 = bloque + '\n' + A4
A5 = '<h1>${code}</h1><p>'
N5 = ('<div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px">'
      '<p style="margin:0 0 8px"><span style="display:block;text-align:center;font-size:42px;font-weight:800;letter-spacing:.14em;padding:14px 8px;border-radius:12px;background:#EEF2FB;color:#14213D">${code}</span></p>'
      '<p style="color:#d2d2ce;line-height:1.45;font-size:14px;margin:0 0 4px">')
A6 = '<p>Vence en 15 minutos y funciona una sola vez.</p>'
N6 = '<p style="color:#8f8d85;font-size:12px;margin:0">Vence en 15 minutos y funciona una sola vez.</p></div>'
filas = [
    ('direccion del panel en mails y SMS (ms.ojoguard.app)', A1, N1),
    ('mails: se arma con la franja nueva', A2, N2),
    ('ruta del logo nuevo', A3, N3),
    ('funciones nuevas de los mails', A4, N4),
    ('mail del codigo: encabezado y codigo grande', A5, N5),
    ('mail del codigo: aviso de vencimiento', A6, N6),
]
cambios = "$cambios = @(\n" + ''.join("    %s@('src\\index.ts', %s, %s, %s)%s\n" % (',' if i == 0 else '', psq(l), psq(a), psq(n), ',' if i < len(filas)-1 else '') for i, (l, a, n) in enumerate(filas)) + ")\n"
# el primer elemento lleva coma delante solo si fuera el unico; con varios no hace falta
cambios = cambios.replace("    ,@(", "    @(", 1)
cabeza = '''# aplicar-correos-marca-panel.ps1 - Ojo Guard MS: los mails salen con la imagen nueva y los links con ms.ojoguard.app.
# Luciano (22/10/2026): "corregir los envios de los mails con el nuevo formato de imagen".
#  - Todos los mails (codigo de ingreso, avisos de seguridad, "Estas bien?", "Llegaste bien?", SOS, referentes, Modo Guardian) salen con franja azul marino + logo nuevo (ojo dorado y "Ojo Guard") y el cuerpo en blanco, texto azul oscuro, botones azules.
#  - El mail del codigo de ingreso pasa a tener el codigo grande en una caja.
#  - Los links de los mails y de los SMS (y la direccion del logo) pasan de ojo-guard-ms-api.bickluciano.workers.dev a ms.ojoguard.app.
# No se saca ningun dato ni funcion de los mails: solo cambia el aspecto. Cambia SOLO src\\index.ts (respaldo index.ts.bak-correosmarca).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'function conMarcaCorreoNuevo') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-correosmarca')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: los mails salen con la imagen nueva y los links con ms.ojoguard.app. Pedi un codigo de ingreso para ver el mail nuevo."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-correos-marca-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
