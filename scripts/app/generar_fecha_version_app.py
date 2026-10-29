# Genera scripts/aplicar-fecha-version-app.ps1: en "Actualizar Ojo Guard" se muestra cuando se publico la ultima version (dato que ya manda el servidor: "subido").
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
arch = 'src\\PaginaActualizar.tsx'
fuente = open(R + 'app/src/PaginaActualizar.tsx', encoding='utf-8').read()
HELPER = '''/** "2026-10-29T20:55:00Z" -> "29/10/2026 a las 17:55" (hora del telefono). Vacio si no hay una fecha valida. */
function textoFecha(valor: unknown): string {
  const f = new Date(String(valor ?? ""));
  if (!Number.isFinite(f.getTime())) return "";
  const dos = (n: number) => String(n).padStart(2, "0");
  return `${dos(f.getDate())}/${dos(f.getMonth() + 1)}/${f.getFullYear()} a las ${dos(f.getHours())}:${dos(f.getMinutes())}`;
}

'''
filas = [
    (arch, 'tipo: fecha en "al dia"', '  | { estado: "al-dia"; publicada: string }\n', '  | { estado: "al-dia"; publicada: string; subido: string }\n'),
    (arch, 'tipo: fecha en "nueva"', '  | { estado: "nueva"; publicada: string }\n', '  | { estado: "nueva"; publicada: string; subido: string }\n'),
    (arch, 'tipo: fecha en "sin numero"', '  | { estado: "sin-numero"; publicada: string }\n', '  | { estado: "sin-numero"; publicada: string; subido: string }\n'),
    (arch, 'funcion que da formato a la fecha', 'export async function consultarVersion(build: string): Promise<EstadoVersion> {\n', HELPER + 'export async function consultarVersion(build: string): Promise<EstadoVersion> {\n'),
    (arch, 'leer la fecha que manda el servidor', '    const dato = (await respuesta.json()) as { disponible?: boolean; version?: string };\n', '    const dato = (await respuesta.json()) as { disponible?: boolean; version?: string; subido?: string };\n'),
    (arch, 'devolver la fecha con cada resultado',
     '    if (!Number.isFinite(tengo) || !Number.isFinite(ultima)) return { estado: "sin-numero", publicada };\n    return tengo >= ultima ? { estado: "al-dia", publicada } : { estado: "nueva", publicada };\n',
     '    const subido = textoFecha(dato.subido);\n    if (!Number.isFinite(tengo) || !Number.isFinite(ultima)) return { estado: "sin-numero", publicada, subido };\n    return tengo >= ultima ? { estado: "al-dia", publicada, subido } : { estado: "nueva", publicada, subido };\n'),
    (arch, 'texto: ya tenes la ultima, con la fecha', '      return `Ya tenés la última versión (${e.publicada}).`;\n', '      return `Ya tenés la última versión (${e.publicada})${e.subido ? `, publicada el ${e.subido}` : ""}.`;\n'),
    (arch, 'texto: hay una nueva, con la fecha', '      return `Hay una versión nueva: ${e.publicada}. Tocá "Descargar la nueva versión".`;\n', '      return `Hay una versión nueva: ${e.publicada}${e.subido ? ` (publicada el ${e.subido})` : ""}. Tocá "Descargar la nueva versión".`;\n'),
]
for _, n, a, _b in filas:
    assert fuente.count(a) == 1, (n, fuente.count(a))
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-fecha-version-app.ps1 - App (PROXIMA build): en "Actualizar Ojo Guard" se ve cuando se publico la ultima version ("publicada el 29/10/2026 a las 17:55").
# Idea de Luciano (29/10/2026). La fecha es la de la subida del APK a ojoguard.app/descargar (el servidor ya la manda). Cambia solo src\\PaginaActualizar.tsx (respaldo .bak-fecha-version). Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\PaginaActualizar.tsx"))) { Mal "No encuentro src\\PaginaActualizar.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\PaginaActualizar.tsx")).texto 'textoFecha') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-fecha-version')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-fecha-version-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
