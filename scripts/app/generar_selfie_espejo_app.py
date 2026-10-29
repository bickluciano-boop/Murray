# Genera scripts/aplicar-selfie-espejo-app.ps1: la camara frontal se comporta igual en Android y en iPhone.
#  - Selfie de verificacion: el archivo que va a Didit queda en su orientacion real (mirror={false}) y la imagen en pantalla se muestra en espejo, como la vista previa de la camara.
#  - Foto de perfil (Perfil y arranque): la foto sacada queda igual que la vista previa (mirror), asi lo que ves es lo que se comparte.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
cam_v = '<CameraView ref={camaraRef} facing="front" animateShutter={false}'
img_v = '<Image source={{ uri: selfieUri }} resizeMode="cover" style={{ width: 240, height: 290, borderRadius: 120, borderWidth: 4, borderColor: DORADO }} />'
img_n = '<Image source={{ uri: selfieUri }} resizeMode="cover" style={{ width: 240, height: 290, borderRadius: 120, borderWidth: 4, borderColor: DORADO, transform: [{ scaleX: -1 }] }} />'
filas = [
    ('src\\VerificarIdentidad.tsx', 'selfie de verificacion: archivo en orientacion real', cam_v, '<CameraView ref={camaraRef} facing="front" mirror={false} animateShutter={false}'),
    ('src\\VerificarIdentidad.tsx', 'selfie de verificacion: imagen en pantalla en espejo', img_v, img_n),
    ('src\\FotoPerfil.tsx', 'foto de perfil (Perfil): la foto sale como la vista previa', cam_v, '<CameraView ref={camaraRef} facing="front" mirror animateShutter={false}'),
    ('src\\ArranqueIdentidad.tsx', 'foto de perfil (arranque): la foto sale como la vista previa', cam_v, '<CameraView ref={camaraRef} facing="front" mirror animateShutter={false}'),
]
# cada ancla tiene que existir una sola vez en la copia del repositorio
import os
fuente = {'src\\VerificarIdentidad.tsx': 'app/src/VerificarIdentidad.tsx', 'src\\FotoPerfil.tsx': 'app/src/FotoPerfil.tsx', 'src\\ArranqueIdentidad.tsx': 'app/arranque/ArranqueIdentidad.tsx'}
for arch, _, a, _b in filas:
    t = open(R + fuente[arch], encoding='utf-8').read()
    assert t.count(a) == 1, (arch, t.count(a))
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-selfie-espejo-app.ps1 - App (PROXIMA build): la camara frontal se comporta igual en Android y en iPhone.
# Selfie de verificacion: el archivo que va a Didit queda en su orientacion real y la foto en pantalla se ve en espejo, como la vista previa de la camara.
# Foto de perfil (Perfil y arranque): la foto sacada queda igual que la vista previa (lo que ves es lo que se comparte).
# Cambia src\\VerificarIdentidad.tsx, src\\FotoPerfil.tsx y src\\ArranqueIdentidad.tsx (respaldo .bak-selfie-espejo). Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\VerificarIdentidad.tsx", "src\\FotoPerfil.tsx", "src\\ArranqueIdentidad.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\VerificarIdentidad.tsx")).texto 'mirror={false}') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$tiposCamara = Join-Path $raiz "node_modules\\expo-camera\\build\\Camera.types.d.ts"
if (-not (Test-Path $tiposCamara)) { Mal "No encuentro expo-camera en node_modules."; return }
if ((Contar (Leer $tiposCamara).texto 'should mirror the image when using the front camera') -eq 0) { Mal "Esta version de expo-camera no tiene la opcion mirror en la camara. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-selfie-espejo')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-selfie-espejo-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
