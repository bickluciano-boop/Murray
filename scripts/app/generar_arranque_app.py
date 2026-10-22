# Genera scripts/aplicar-arranque-app.ps1: bienvenida de 13 diapositivas + pasos de identidad (foto de perfil, documento, cara)
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
    ('importar la bienvenida y los pasos de identidad',
     'import { PaginaChequeo } from "./src/PaginaChequeo";\n',
     'import { PaginaChequeo } from "./src/PaginaChequeo";\nimport { Bienvenida } from "./src/Bienvenida";\nimport { ArranqueIdentidad, cargarIdentidad } from "./src/ArranqueIdentidad";\n'),
    ('pantallas nuevas: bienvenida e identidad',
     'type Screen = "loading" | "access" | "setup" | "guard" | "settings";',
     'type Screen = "loading" | "welcome" | "access" | "identity" | "setup" | "guard" | "settings";'),
    ('constantes: Empresa escondida y marca de bienvenida vista',
     'const APP_VERSION = Constants.expoConfig?.version ?? "0.0.0";\n',
     'const APP_VERSION = Constants.expoConfig?.version ?? "0.0.0";\n'
     '// La opcion Empresa ya no se ofrece al abrir la cuenta. El codigo de Empresa sigue en la app: solo se esconde la tarjeta.\n'
     'const MOSTRAR_ACCESO_EMPRESA = false;\n'
     '// Se guarda al terminar la bienvenida, para mostrarla una sola vez.\n'
     'const CLAVE_BIENVENIDA_VISTA = "ojo_bienvenida_vista_v1";\n'),
    ('el acceso arranca como prueba de 3 dias',
     'useState<AccessType | null>(null)',
     'useState<AccessType | null>("trial")'),
    ('primer arranque: bienvenida antes del acceso',
     '        if (!stored) {\n          setScreen("access");\n          return;\n        }\n',
     '        if (!stored) {\n'
     '          void AsyncStorage.getItem(CLAVE_BIENVENIDA_VISTA).then(\n'
     '            (visto) => setScreen(visto === "1" ? "access" : "welcome"),\n'
     '            () => setScreen("access"),\n'
     '          );\n'
     '          return;\n'
     '        }\n'),
    ('despues del acceso: pasos de identidad si faltan',
     'if (screen === "access") setScreen("setup");',
     'if (screen === "access") {\n'
     '        void cargarIdentidad().then((identidad) => setScreen(identidad ? "setup" : "identity"));\n'
     '      }'),
    ('mostrar la bienvenida y los pasos de identidad',
     '  if (screen === "access") {\n    return (\n      <AccessScreen\n',
     '  if (screen === "welcome") {\n'
     '    return (\n'
     '      <Bienvenida\n'
     '        noche={temaActivo === "oscuro"}\n'
     '        onTerminar={() => {\n'
     '          void AsyncStorage.setItem(CLAVE_BIENVENIDA_VISTA, "1").catch(() => undefined);\n'
     '          setScreen("access");\n'
     '        }}\n'
     '        paleta={P}\n'
     '      />\n'
     '    );\n'
     '  }\n\n'
     '  if (screen === "identity") {\n'
     '    return (\n'
     '      <ArranqueIdentidad\n'
     '        noche={temaActivo === "oscuro"}\n'
     '        onTerminar={() => setScreen("setup")}\n'
     '        paleta={P}\n'
     '      />\n'
     '    );\n'
     '  }\n\n'
     '  if (screen === "access") {\n    return (\n      <AccessScreen\n'),
    ('acceso: logo y titulo',
     '          <Text style={styles.brand}>OJO GUARD®</Text>\n          <Text style={styles.versionLabel}>VERSIÓN {APP_VERSION}</Text>\n          <Text style={styles.setupTitle}>Elegí cómo ingresar</Text>\n',
     '          <Image\n            resizeMode="contain"\n            source={require("./assets/ojo-logo.png")}\n            style={{ height: 58, width: 96 }}\n          />\n'
     '          <Text style={styles.brand}>OJO GUARD®</Text>\n          <Text style={styles.versionLabel}>VERSIÓN {APP_VERSION}</Text>\n          <Text style={styles.setupTitle}>Creá tu cuenta o ingresá</Text>\n'),
    ('acceso: etiqueta del primer paso',
     '1 · ELEGÍ EL TIPO DE ACCESO',
     '1 · TU ACCESO'),
    ('acceso: Empresa escondida (abre)',
     '          <Pressable\n            onPress={() => onAccessType("company")}\n',
     '          {MOSTRAR_ACCESO_EMPRESA ? (\n          <Pressable\n            onPress={() => onAccessType("company")}\n'),
    ('acceso: Empresa escondida (cierra)',
     '          </Pressable>\n          <Pressable\n            onPress={() => onAccessType("trial")}\n',
     '          </Pressable>\n          ) : null}\n          <Pressable\n            onPress={() => onAccessType("trial")}\n'),
    ('formularios: campos mas redondeados',
     '    borderRadius: 14,\n    borderWidth: 1,\n    color: P.texto,\n    fontSize: 16,\n    paddingHorizontal: 16,\n    paddingVertical: 15,\n',
     '    borderRadius: 18,\n    borderWidth: 1,\n    color: P.texto,\n    fontSize: 16,\n    paddingHorizontal: 16,\n    paddingVertical: 15,\n'),
    ('formularios: boton principal redondeado',
     '    backgroundColor: P.doradoRelleno,\n    borderRadius: 14,\n    marginTop: 4,\n    paddingVertical: 16,\n',
     '    backgroundColor: P.doradoRelleno,\n    borderRadius: 26,\n    marginTop: 4,\n    paddingVertical: 16,\n'),
]

orig = open('/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/d7cc35eb-App.tsx', encoding='utf-8').read().replace('\r\n', '\n')
final = orig
for nombre, viejo, nuevo in CAMBIOS:
    assert final.count(viejo) == 1, (nombre, final.count(viejo))
    final = final.replace(viejo, nuevo)
open(S + 'App.arranque.tsx', 'w', encoding='utf-8', newline='').write(final)

cambios = "$cambios = @(\n" + ",\n".join("    @('App.tsx', %s, %s, %s)" % (psq(n), psq(v), psq(nw)) for n, v, nw in CAMBIOS) + "\n)\n"

# ---- archivos nuevos (descargas fijas) ----
A = R + 'app/arranque/'
URL = 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/arranque/' % COMMIT
NUEVOS = [('Bienvenida.tsx', 'src/Bienvenida.tsx'), ('ArranqueIdentidad.tsx', 'src/ArranqueIdentidad.tsx'), ('Iconos.tsx', 'src/Iconos.tsx'), ('ojo-logo.png', 'assets/ojo-logo.png')]
descargas = "$descargas = @(\n" + ",\n".join("    @('%s', '%s', '%s')" % (URL + a, dest, sha(A + a)) for a, dest in NUEVOS) + "\n)\n"

# ---- instalador: motor del de la estetica ----
ini = base.index('$ErrorActionPreference')
j = base.index('if (-not (Test-Path (Join-Path $raiz "app.json"))')
motor = base[ini:j]
cabeza = '''# aplicar-arranque-app.ps1 - App Ojo Guard: bienvenida (13 diapositivas), pasos de identidad y acceso nuevo.
# Luciano (22/10/2026): bienvenida para el usuario nuevo, foto de perfil, foto del documento (DNI o pasaporte) y foto de la cara, todo obligatorio; "lo de empresa no va mas".
#  - Bienvenida: 13 diapositivas, una sola vez, antes del acceso (src/Bienvenida.tsx).
#  - Despues de abrir la cuenta: foto de perfil, foto del documento y foto de la cara (src/ArranqueIdentidad.tsx). No se pueden saltar.
#    Las fotos quedan guardadas en el telefono con estado "pendiente de verificar": la comparacion entre la cara y el documento NO existe todavia.
#  - Acceso: arranca como prueba de 3 dias; la tarjeta Empresa se esconde (su codigo queda). Logo arriba. Campos y boton principal mas redondeados.
#  - Quien ya tiene la app abierta con su cuenta NO ve nada de esto: solo el usuario nuevo.
# Cambia App.tsx y agrega 3 archivos en src y el logo en assets. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-arranque. Sale en la PROXIMA build.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if (-not (Test-Path (Join-Path $raiz "src"))) { Mal "No encuentro la carpeta src."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'ojo_bienvenida_vista_v1') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):]
cola = cola.replace('$descargas = @()\n', descargas, 1)
cola = cola.replace('.bak-esteticaapp', '.bak-arranque')
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
Ok "LISTO: la app tiene bienvenida, pasos de identidad y el acceso nuevo. Sale en la proxima build."
Avi "Las fotos de identidad quedan guardadas en el telefono, pendientes de verificar: la comparacion cara/documento todavia no esta conectada."
Write-Host ""
'''
assert 'wrangler' not in cola
total = cabeza + motor + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-arranque-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(orig), len(final), COMMIT[:8])
