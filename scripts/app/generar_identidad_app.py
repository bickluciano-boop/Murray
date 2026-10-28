# Genera scripts/aplicar-identidad-app.ps1: verificacion de identidad (DNI + sexo + selfie, Didit/RENAPER) en el arranque y en Configuracion.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/actual/'
COMMIT_ARCHIVOS = 'e470b2275c503d9b265fe457273155ff9c541f9d'
SHA_VERIFICAR = '52d8fcbf8a7d856b9995c7d9a8a73c1db34f9b4f6035dd6cb745b26266010f2c'
SHA_ARRANQUE = 'd2e2080efba714a314045e1e0457cd4be7aa613a775d3b5ed2e6444d707dab87'
SHA_ICONO = '45812c766485a861daf2f016b9ceec0b8a597b864b0fb6946af95d9b76ffb41d'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fuentes = {
    'App.tsx': open(S + 'App.tsx', encoding='utf-8').read(),
    'src\\GruposConfiguracion.tsx': open(S + 'src_GruposConfiguracion.tsx', encoding='utf-8').read(),
}
filas = []
def cambio(archivo, rotulo, viejo, nuevo):
    assert fuentes[archivo].count(viejo) == 1, (rotulo, fuentes[archivo].count(viejo))
    filas.append((archivo, rotulo, viejo, nuevo))

G = 'src\\GruposConfiguracion.tsx'
cambio(G, 'grupo nuevo en el tipo',
 '"proteccion" | "conexion" | "permisos" | "perfil" | "familia" | "actualizacion";',
 '"proteccion" | "conexion" | "permisos" | "perfil" | "familia" | "actualizacion" | "identidad";')
cambio(G, 'texto del grupo nuevo',
 '  actualizacion: { titulo: "Actualizar Ojo Guard", resumen: "La versión instalada, si hay una nueva y cómo volver a instalarla." },',
 '  actualizacion: { titulo: "Actualizar Ojo Guard", resumen: "La versión instalada, si hay una nueva y cómo volver a instalarla." },\n'
 '  identidad: { titulo: "Verificar mi identidad", resumen: "Confirmá que sos vos con tu DNI y una selfie. Hasta hacerlo no podés pedir foto y audio a otras personas de tu familia." },')
cambio(G, 'icono del grupo nuevo',
 '  actualizacion: require("../assets/config-actualizar.png"),\n};',
 '  actualizacion: require("../assets/config-actualizar.png"),\n  identidad: require("../assets/config-identidad.png"),\n};')
cambio(G, 'tarjeta nueva al final de la grilla',
 '    ...(android ? [{ grupo: "actualizacion" as const, detalle: "Versión instalada y buscar una nueva" }] : []),\n  ];',
 '    ...(android ? [{ grupo: "actualizacion" as const, detalle: "Versión instalada y buscar una nueva" }] : []),\n'
 '    { grupo: "identidad", detalle: "Confirmá que sos vos con tu DNI y una selfie" },\n  ];')
cambio('App.tsx', 'import de la pantalla nueva',
 'import { PaginaActualizar } from "./src/PaginaActualizar";',
 'import { PaginaActualizar } from "./src/PaginaActualizar";\nimport { VerificarIdentidad } from "./src/VerificarIdentidad";')
cambio('App.tsx', 'pagina Verificar mi identidad',
 '          {grupoActual === "actualizacion" ? (',
 '''          {grupoActual === "identidad" ? (
            <VerificarIdentidad
              noche={temaActivo === "oscuro"}
              onListo={() => elegirGrupo("configuracion")}
              paleta={P}
              permitirOmitir={false}
              revisarEstado
            />
          ) : null}

          {grupoActual === "actualizacion" ? (''')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
url = lambda ruta: 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT_ARCHIVOS, ruta)
descargas = "$descargas = @(\n    @(%s, %s, %s),\n    @(%s, %s, %s),\n    @(%s, %s, %s)\n)\n" % (
    psq(url('src/VerificarIdentidad.tsx')), psq('src\\VerificarIdentidad.tsx'), psq(SHA_VERIFICAR),
    psq(url('arranque/ArranqueIdentidad.tsx')), psq('src\\ArranqueIdentidad.tsx'), psq(SHA_ARRANQUE),
    psq(url('assets/config-identidad.png')), psq('assets\\config-identidad.png'), psq(SHA_ICONO))
cabeza = '''# aplicar-identidad-app.ps1 - App (PROXIMA build): verificacion de identidad con DNI + sexo + selfie (el servidor usa Didit y RENAPER).
# Luciano (28/10/2026): "Didit renaper"; la verificacion se puede omitir para usar la app, pero sin verificar no se puede pedir foto y audio a otras personas.
#  1) Arranque: despues de la foto de perfil, pantalla para escribir el DNI y elegir el sexo, y despues la selfie. Tiene "Omitir por ahora". Ya NO se pide la foto del documento.
#  2) Configuracion: tarjeta nueva "Verificar mi identidad" (al final de la grilla) para hacerlo mas tarde o ver que ya esta verificada.
#  3) Las fotos viejas del documento y de la cara que guardaban las versiones anteriores se borran del telefono.
# Archivos que baja con huella verificada: src\\VerificarIdentidad.tsx (nuevo), src\\ArranqueIdentidad.tsx (reemplaza al actual) y assets\\config-identidad.png. Toca App.tsx y src\\GruposConfiguracion.tsx (respaldo .bak-identidad).
# Requiere aplicar-actualizar-app.ps1 y el servidor con aplicar-identidad-didit-panel.ps1. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba. Sale en la PROXIMA build.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("App.tsx", "src\\GruposConfiguracion.tsx", "src\\ArranqueIdentidad.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\GruposConfiguracion.tsx")).texto '"identidad"') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\GruposConfiguracion.tsx")).texto '"actualizacion"') -eq 0) { Mal "Falta aplicar primero aplicar-actualizar-app.ps1. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-identidad')
viejo = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad") -Destination $ruta -Force } }'
assert cola.count(viejo) == 1, cola.count(viejo)
cola = cola.replace(viejo, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2, cola.count(msg)
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-identidad") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# copia de App.tsx y GruposConfiguracion resultantes para revisar tipos
for a, _, v, n in filas:
    fuentes[a] = fuentes[a].replace(v, n)
open(S + 'out_App.tsx', 'w', encoding='utf-8').write(fuentes['App.tsx'])
open(S + 'out_Grupos.tsx', 'w', encoding='utf-8').write(fuentes['src\\GruposConfiguracion.tsx'])
print('ok', len(total), len(filas))
