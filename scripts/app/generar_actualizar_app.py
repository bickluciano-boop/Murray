# Genera scripts/aplicar-actualizar-app.ps1: tarjeta "Actualizar Ojo Guard" en Configuracion (Android) y linea de version en el Dr. Ojo Guard.
import re
R = '/home/user/Murray/scripts/'
U = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/'
COMMIT_ARCHIVOS = '09eb06feb4c263df5437e24f668beead44f43d6b'
SHA_PAGINA = '6d4629ec58cec617bae14d323b2990b145df6eea5e10519a9052488efe7926c6'
SHA_ICONO = 'e51fce92ff23ce827e0a365f86c9938487ef3fd698ecad2f6ce7938bd3c67c5c'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
leer = lambda n: open(U + n, encoding='utf-8').read().replace('\r\n', '\n')
fuentes = {
    'App.tsx': leer('ee1c9a0c-App-actual-263510.tsx'),
    'src\\GruposConfiguracion.tsx': leer('3906475a-GruposConfiguracion-actual.tsx'),
    'src\\PaginaChequeo.tsx': leer('f184dc9c-PaginaChequeo-actual.tsx'),
}
filas = []
def cambio(archivo, rotulo, viejo, nuevo):
    assert fuentes[archivo].count(viejo) == 1, (rotulo, fuentes[archivo].count(viejo))
    filas.append((archivo, rotulo, viejo, nuevo))

# --- GruposConfiguracion.tsx: el grupo nuevo, su texto, su icono y su tarjeta (solo Android) ---
G = 'src\\GruposConfiguracion.tsx'
cambio(G, 'grupo nuevo en el tipo',
 '"proteccion" | "conexion" | "permisos" | "perfil" | "familia";',
 '"proteccion" | "conexion" | "permisos" | "perfil" | "familia" | "actualizacion";')
cambio(G, 'texto del grupo nuevo',
 '  conexion: { titulo: "Ojo Guard MS", resumen: "Cómo se conecta este teléfono con el panel de Ojo Guard MS." },',
 '''  conexion: { titulo: "Ojo Guard MS", resumen: "Cómo se conecta este teléfono con el panel de Ojo Guard MS." },
  actualizacion: { titulo: "Actualizar Ojo Guard", resumen: "La versión instalada, si hay una nueva y cómo volver a instalarla." },''')
cambio(G, 'icono del grupo nuevo',
 '  conexion: require("../assets/config-conexion.png"),\n};',
 '  conexion: require("../assets/config-conexion.png"),\n  actualizacion: require("../assets/config-actualizar.png"),\n};')
cambio(G, 'tarjeta nueva (solo Android) al lado del Dr. Ojo Guard',
 '''    { grupo: "proteccion", detalle: "Chequeo del teléfono y prueba de sirena" },
  ];''',
 '''    { grupo: "proteccion", detalle: "Chequeo del teléfono y prueba de sirena" },
    ...(android ? [{ grupo: "actualizacion" as const, detalle: "Versión instalada y buscar una nueva" }] : []),
  ];''')

# --- PaginaChequeo.tsx: la linea de version arriba del Dr. Ojo Guard ---
C = 'src\\PaginaChequeo.tsx'
cambio(C, 'imports',
 'import { Text } from "react-native";',
 'import { Platform, Text } from "react-native";')
cambio(C, 'import de la linea de version',
 'import { ProteccionBlock } from "./ProteccionBlock";',
 'import { LineaVersion } from "./PaginaActualizar";\nimport { ProteccionBlock } from "./ProteccionBlock";')
cambio(C, 'propiedades nuevas',
 '''  botones: ComponentProps<typeof ProteccionBlock>["botones"];
};''',
 '''  botones: ComponentProps<typeof ProteccionBlock>["botones"];
  /** Número de build instalado (solo Android: con él se ve si hay una versión nueva). */
  build?: string | undefined;
  /** Abre la página "Actualizar Ojo Guard". */
  onActualizar?: (() => void) | undefined;
};''')
cambio(C, 'firma',
 'export function PaginaChequeo({ paleta, botones }: Props) {',
 'export function PaginaChequeo({ paleta, botones, build, onActualizar }: Props) {')
cambio(C, 'linea de version arriba del chequeo',
 '  return <ProteccionBlock abierto enrollment={enrollment} paleta={paleta} botones={botones} visible />;',
 '''  return (
    <>
      {Platform.OS === "android" && build ? <LineaVersion build={build} botones={botones} onActualizar={onActualizar} /> : null}
      <ProteccionBlock abierto enrollment={enrollment} paleta={paleta} botones={botones} visible />
    </>
  );''')

# --- App.tsx: la pagina nueva y los datos para el Dr. Ojo Guard ---
cambio('App.tsx', 'import de la pagina nueva',
 'import { PaginaChequeo } from "./src/PaginaChequeo";',
 'import { PaginaActualizar } from "./src/PaginaActualizar";\nimport { PaginaChequeo } from "./src/PaginaChequeo";')
cambio('App.tsx', 'pagina Actualizar Ojo Guard',
 '          {grupoActual === "proteccion" ? (',
 '''          {grupoActual === "actualizacion" ? (
            <PaginaActualizar
              version={APP_VERSION}
              build={String(APP_BUILD_LABEL)}
              botones={{
                secundario: styles.secondaryButton,
                secundarioTexto: styles.secondaryButtonText,
                ayuda: styles.fieldHelp,
              }}
            />
          ) : null}

          {grupoActual === "proteccion" ? (''')
cambio('App.tsx', 'Dr. Ojo Guard: build y atajo a la pagina nueva',
 '''            <PaginaChequeo
              paleta={P}
''',
 '''            <PaginaChequeo
              paleta={P}
              build={String(APP_BUILD_LABEL)}
              onActualizar={() => elegirGrupo("actualizacion")}
''')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
url = lambda ruta: 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT_ARCHIVOS, ruta)
descargas = "$descargas = @(\n    @(%s, %s, %s),\n    @(%s, %s, %s)\n)\n" % (
    psq(url('src/PaginaActualizar.tsx')), psq('src\\PaginaActualizar.tsx'), psq(SHA_PAGINA),
    psq(url('assets/config-actualizar.png')), psq('assets\\config-actualizar.png'), psq(SHA_ICONO))

cabeza = '''# aplicar-actualizar-app.ps1 - App (PROXIMA build): tarjeta "Actualizar Ojo Guard" en Configuracion (solo Android, al lado del Dr. Ojo Guard) y linea de version dentro del Dr. Ojo Guard.
# Luciano (27/10/2026): "esta muy escondido: tendria que haber un icono al lado del Dr. que diga actualizacion... o adentro del Dr." -> las dos.
#  1) Configuracion: tarjeta nueva "Actualizar Ojo Guard" (icono de descarga): muestra tu version y build, "Buscar actualizacion" y "Volver a instalar la ultima" (abre ojoguard.app/descargar).
#  2) Dr. Ojo Guard: arriba una linea "Version de Ojo Guard: al dia" o "Hay una version nueva... Toca para actualizar" (si no hay dato o no hay internet no muestra nada).
# Archivos nuevos que baja con huella verificada: src\\PaginaActualizar.tsx y assets\\config-actualizar.png. Toca App.tsx, src\\GruposConfiguracion.tsx y src\\PaginaChequeo.tsx (respaldo .bak-actualizar).
# Requiere aplicar-version-captura-app.ps1. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba. Sale en la PROXIMA build.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("App.tsx", "src\\GruposConfiguracion.tsx", "src\\PaginaChequeo.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\GruposConfiguracion.tsx")).texto '"actualizacion"') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'const CLAVE_PASOS_CAPTURA') -eq 0) { Mal "Falta aplicar primero aplicar-version-captura-app.ps1. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-actualizar')
# si falla la revision de tipos tambien se sacan los archivos nuevos
viejo = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-actualizar") -Destination $ruta -Force } }'
assert cola.count(viejo) == 1, cola.count(viejo)
cola = cola.replace(viejo, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-actualizar") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
# al restaurar tambien se borran los respaldos, para que se pueda volver a correr el instalador sin trabas
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2, cola.count(msg)
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-actualizar") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = cola.replace('Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android e iPhone)."', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."')
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-actualizar-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(filas))
