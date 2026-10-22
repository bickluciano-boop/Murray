# Genera scripts/aplicar-arranque2-app.ps1: bienvenida de 13 diapositivas + pasos de identidad (foto de perfil, documento, cara)
# + acceso solo con prueba (se esconde Empresa, sin borrar su codigo) + formularios redondeados + logo en el acceso.
# Los archivos nuevos (src/Bienvenida.tsx, src/ArranqueIdentidad.tsx, src/Iconos.tsx, assets/ojo-logo.png) se descargan de un commit
# fijo y se verifican con SHA-256; App.tsx se cambia solo con anclas exactas (cada una tiene que aparecer una vez).
import re, sys, hashlib
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/app/'
COMMIT = sys.argv[1]
base = open(R + 'aplicar-estetica-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')

def psq(s):
    out = []; conv = False
    for ch in s:
        if ord(ch) > 127:
            assert ord(ch) <= 0xFFFF
            out.append("' + [char]0x%04x + '" % ord(ch)); conv = True
        elif ch == "'": out.append("''")
        else: out.append(ch)
    t = "'" + ''.join(out) + "'"
    return '(' + t + ')' if conv else t

def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()

CAMBIOS = [
    ('Preparar este telefono: barra de 6 pasos (paso 6 de 6)',
     '          {firstRun ? <Text style={styles.setupTitle}>Preparar este tel\u00e9fono</Text> : null}\n',
     '          {firstRun ? (\n'
     '            <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between", marginTop: 14 }}>\n'
     '              <View style={{ flexDirection: "row", gap: 5 }}>\n'
     '                {[1, 2, 3, 4, 5, 6].map((paso) => (\n'
     '                  <View key={paso} style={{ backgroundColor: P.doradoRelleno, borderRadius: 3, height: 6, width: 18 }} />\n'
     '                ))}\n'
     '              </View>\n'
     '              <Text style={{ color: P.textoDebil, fontSize: 13, fontWeight: "700" }}>Paso 6 de 6</Text>\n'
     '            </View>\n'
     '          ) : null}\n'
     '          {firstRun ? <Text style={styles.setupTitle}>Preparar este tel\u00e9fono</Text> : null}\n'),
]

orig = open(S + 'App.arranque.tsx', encoding='utf-8').read().replace('\r\n', '\n')
final = orig
for nombre, viejo, nuevo in CAMBIOS:
    assert final.count(viejo) == 1, (nombre, final.count(viejo))
    final = final.replace(viejo, nuevo)
open(S + 'App.arranque2.tsx', 'w', encoding='utf-8', newline='').write(final)

cambios = "$cambios = @(\n" + ",\n".join("    ,@('App.tsx', %s, %s, %s)" % (psq(n), psq(v), psq(nw)) for n, v, nw in CAMBIOS) + "\n)\n"

# ---- archivos nuevos (descargas fijas) ----
A = R + 'app/arranque/'
URL = 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/arranque/' % COMMIT
NUEVOS = [('Bienvenida.tsx', 'src/Bienvenida.tsx'), ('ArranqueIdentidad.tsx', 'src/ArranqueIdentidad.tsx')]
descargas = "$descargas = @(\n" + ",\n".join("    @('%s', '%s', '%s')" % (URL + a, dest, sha(A + a)) for a, dest in NUEVOS) + "\n)\n"

# ---- instalador: motor del de la estetica ----
ini = base.index('$ErrorActionPreference')
j = base.index('if (-not (Test-Path (Join-Path $raiz "app.json"))')
motor = base[ini:j]
cabeza = '''# aplicar-arranque2-app.ps1 - App Ojo Guard: barra de 6 pasos y texto de bienvenida (segunda parte del arranque).
# El arranque del usuario nuevo tiene 6 pasos (cuenta, codigo, foto de perfil, documento, cara, preparar el telefono); vincular personas queda para despues, como pediste.
#  - "Preparar este telefono" muestra la barra y dice "Paso 6 de 6". Los pasos de foto dicen "de 6".
#  - Diapositiva 11 de la bienvenida: suma que los movimientos del circulo llegan como aviso en el telefono.
# Cambia App.tsx (una sola ancla) y reemplaza src/Bienvenida.tsx y src/ArranqueIdentidad.tsx por la version nueva. Va en la carpeta de la APP. Respaldo .bak-arranque2. Sale en la PROXIMA build.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if (-not (Test-Path (Join-Path $raiz "src\\ArranqueIdentidad.tsx"))) { Mal "Falta aplicar-arranque-app.ps1 primero (no encuentro src\\ArranqueIdentidad.tsx)."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'Paso 6 de 6') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):]
cola = cola.replace('$descargas = @()\n', descargas, 1)
cola = cola.replace('.bak-esteticaapp', '.bak-arranque2')
# asegurar que exista la carpeta de destino antes de mover cada archivo nuevo
mov = 'foreach ($d in $descargas) { Move-Item -LiteralPath ((Join-Path $raiz $d[1]) + ".descarga") -Destination (Join-Path $raiz $d[1]) -Force }'
assert mov in cola
cola = cola.replace(mov, 'foreach ($d in $descargas) { $dest = Join-Path $raiz $d[1]; $carpeta = Split-Path -Parent $dest; if (-not (Test-Path $carpeta)) { New-Item -ItemType Directory -Path $carpeta -Force | Out-Null }; Move-Item -LiteralPath ($dest + ".descarga") -Destination $dest -Force }')
# la descarga se hace en la carpeta de destino: crearla tambien antes de bajar
dl = '    $tmp = (Join-Path $raiz $d[1]) + ".descarga"\n'
assert dl in cola
cola = cola.replace(dl, dl + '    $carpetaTmp = Split-Path -Parent $tmp; if (-not (Test-Path $carpetaTmp)) { New-Item -ItemType Directory -Path $carpetaTmp -Force | Out-Null }\n')
fin_msg = cola.index('Write-Host ""\nOk "LISTO: App.tsx quedo con la paleta nueva')
cola = cola[:fin_msg] + '''Write-Host ""
Ok "LISTO: el arranque quedo en 6 pasos y la bienvenida con el texto nuevo. Sale en la proxima build."
Write-Host ""
'''
assert 'wrangler' not in cola
total = cabeza + motor + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-arranque2-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(orig), len(final), COMMIT[:8])
