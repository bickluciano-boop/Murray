# Genera scripts/aplicar-buscador-ajustes-app.ps1 (app, PROXIMA build, Android e iPhone).
# Luciano (20/11/2026): en Salud, la tarjeta del reloj con deteccion de caidas. Es SOLO informativa (no se conecta con ningun reloj, sin precios ni tiendas).
# Agrega src\RelojCaidasAviso.tsx y toca src\TarjetaSaludEntrada.tsx en dos puntos (un import y una linea debajo de "Salud y emergencias"). NO toca App.tsx, el mapa ni el Inicio.
import re, hashlib, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = '6bb907e6c7f8bf023bbcb2fa79510fab980545f7'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('indiceBusqueda.ts', 'src\\indiceBusqueda.ts'), ('BuscadorAjustes.tsx', 'src\\BuscadorAjustes.tsx')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
IMP_A = 'import { TarjetaPermisos } from "./src/TarjetaPermisos";\n'
IMP_B = IMP_A + 'import { BuscadorAjustes } from "./src/BuscadorAjustes";\n'
HUB_A = '              <TarjetaPermisos\n                paleta={P}\n'
HUB_B = '              {/* Buscador de Ajustes (20/11/2026): reconoce lo que se escribe y lleva a la seccion; el grupo es el mismo valor que usa elegirGrupo. */}\n              <BuscadorAjustes android={Platform.OS === "android"} onElegir={(grupo) => elegirGrupo(grupo as never)} paleta={P} />\n' + HUB_A
filas = [('App.tsx', 'buscador: importar', IMP_A, IMP_B),
         ('App.tsx', 'buscador: el cuadro Buscar en Ajustes arriba de Configuracion', HUB_A, HUB_B)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-buscador-ajustes-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (20/11/2026): un buscador en Ajustes que reconozca lo que se escribe y lleve a la seccion.
# Agrega src\\indiceBusqueda.ts (la logica: sin tildes ni mayusculas, tolera errores de tipeo, sinonimos) y src\\BuscadorAjustes.tsx (el cuadro y la hoja de busqueda); toca App.tsx en dos puntos (un import y el cuadro arriba de la tarjeta de permisos de Ajustes). No cambia ninguna seccion, el mapa ni el Inicio. No agrega librerias.
# Requiere la tarjeta de permisos (aplicar-permisos-registro-app.ps1). Respaldo .bak-buscador. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'BuscadorAjustes') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto '<TarjetaPermisos') -eq 0) { Mal "Falta aplicar primero la tarjeta de permisos (aplicar-permisos-registro-app.ps1)."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-buscador')
MENSAJE = 'LISTO: la app compila bien. Ajustes tiene el cuadro Buscar en Ajustes (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›→']
assert not bad, set(bad)
open(R + 'aplicar-buscador-ajustes-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
muestra = '''import { TarjetaPermisos } from "./src/TarjetaPermisos";
import { compartirRegistroSoporte } from "./src/compartirRegistro";
function X() { return (<>
          {grupoActual === "configuracion" ? (
            <>
              <TarjetaPermisos
                paleta={P}
                android={Platform.OS === "android"}
                permisosEnOrden={permisosEnOrden}
                permisosTotal={4}
                onPress={() => elegirGrupo("permisos")}
              />
              <TarjetaSaludAjustes paleta={P} />
            </>
          ) : null}
</>); }
'''
for a, n, v, nv in filas:
    assert muestra.count(v) == 1, (n, muestra.count(v))
out = muestra
for a, n, v, nv in filas:
    out = out.replace(v, nv)
assert out.index('<BuscadorAjustes') < out.index('<TarjetaPermisos') and out.count('<TarjetaPermisos') == 1
print('ok', len(total))
