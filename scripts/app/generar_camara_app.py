# Genera scripts/aplicar-identidad-camara-app.ps1: reemplaza src/VerificarIdentidad.tsx y src/ArranqueIdentidad.tsx por la version que mantiene el aviso de camara abierta unos segundos.
import re, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = 'e4d14655d3904a5bcb38cdb808dc85f1370e2510'
def sha(ruta): return subprocess.check_output(['sha256sum', R + 'app/' + ruta]).decode().split()[0]
SHA_VERIFICAR = sha('src/VerificarIdentidad.tsx')
SHA_ARRANQUE = sha('arranque/ArranqueIdentidad.tsx')
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
url = lambda ruta: 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT_ARCHIVOS, ruta)
descargas = "$descargas = @(\n    @(%s, %s, %s),\n    @(%s, %s, %s)\n)\n" % (
    psq(url('src/VerificarIdentidad.tsx')), psq('src\\VerificarIdentidad.tsx'), psq(SHA_VERIFICAR),
    psq(url('arranque/ArranqueIdentidad.tsx')), psq('src\\ArranqueIdentidad.tsx'), psq(SHA_ARRANQUE))
cambios = "$cambios = @(\n)\n"
cabeza = '''# aplicar-identidad-camara-app.ps1 - App (PROXIMA build): al sacar la selfie (o la foto de perfil) la app ya no te saca a la pantalla del codigo.
# Luciano (28/10/2026, Xiaomi): "cuando saco la foto automaticamente volvio a la pantalla numerica principal". Android devuelve la foto ANTES de avisar que la app volvio al frente;
# si el aviso de "camara abierta" se bajaba apenas llegaba la foto, esa vuelta tardia se tomaba por una salida real. Ahora el aviso se mantiene 5 segundos mas.
# Reemplaza src\\VerificarIdentidad.tsx y src\\ArranqueIdentidad.tsx (descarga con huella verificada, respaldo .bak-camara). Requiere aplicar-identidad-app.ps1. Va en la carpeta de la APP (la que tiene app.json). Sale en la PROXIMA build.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\VerificarIdentidad.tsx", "src\\ArranqueIdentidad.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta. Falta aplicar aplicar-identidad-app.ps1."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\VerificarIdentidad.tsx")).texto 'avisarCamaraAbierta') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-camara')
viejo = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-camara") -Destination $ruta -Force } }'
assert cola.count(viejo) == 1, cola.count(viejo)
cola = cola.replace(viejo, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-camara") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2, cola.count(msg)
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-camara") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-camara-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
