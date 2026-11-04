# Genera scripts/aplicar-familia-sos-nombres-app.ps1: "Familia y amigos" dice con nombres quien te ve y a quien le suena tu SOS (sin pantalla nueva).
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = 'type Paleta = { [clave: string]: string };\n'
b1 = a1 + '''
/** "Papá, Guido y 3 más": nombres para decir con quien se comparte, sin que un grupo grande ocupe media pantalla. */
function listaDeNombres(nombres: string[], max = 4): string {
  const limpios = nombres.map((n) => n.trim()).filter(Boolean);
  if (limpios.length <= max) return limpios.length > 1 ? `${limpios.slice(0, -1).join(", ")} y ${limpios[limpios.length - 1]}` : (limpios[0] ?? "");
  return `${limpios.slice(0, max).join(", ")} y ${limpios.length - max} más`;
}

/** A quien le suena el SOS de esta persona (lo decide el servidor y lo manda en `sosTo`). null si el servidor todavia no lo manda. */
function sosA(people: FamilyPerson[]): string[] | null {
  const marcadas = people as (FamilyPerson & { sosTo?: boolean })[];
  if (!marcadas.some((p) => p.sosTo !== undefined)) return null;
  return marcadas.filter((p) => p.sosTo === true).map((p) => p.name);
}
'''
a2 = '<Text style={botones.ayuda}>Tu familia ve dónde estás. Podés pausarlo un rato y volver a compartir cuando quieras.</Text>'
b2 = '<Text style={botones.ayuda}>{people.length ? `Te ven: ${listaDeNombres(people.map((p) => p.name))}.` : "Tu familia ve dónde estás."} Podés pausarlo un rato y volver a compartir cuando quieras.</Text>'
a3 = 'Compartís tu ubicación con tu familia. Tus tutores pueden ver dónde estás; siempre vas a ver acá con quién la compartís.'
b3 = '{people.length ? `Compartís tu ubicación con ${listaDeNombres(people.map((p) => p.name))}.` : "Compartís tu ubicación con tu familia."} Tus tutores pueden ver dónde estás.'
a4 = '            {/* El SOS trae su propio espacio de arriba (18 y 8): se descuenta para que no quede un hueco dentro de la tarjeta. */}\n'
b4 = ('            {sosA(people) !== null ? (\n'
      '              <Text style={botones.ayuda}>\n'
      '                {(sosA(people) ?? []).length ? `Tu SOS les suena en la app a: ${listaDeNombres(sosA(people) ?? [])}.` : "Hoy tu SOS no le suena a nadie en la app. Sumá a alguien desde el mapa del Inicio."}\n'
      '              </Text>\n'
      '            ) : null}\n') + a4
filas = [('src\\FamiliaPantalla.tsx', 'listas de nombres (ayudas)', a1, b1),
         ('src\\FamiliaPantalla.tsx', 'Mi ubicacion: quien te ve', a2, b2),
         ('src\\FamiliaPantalla.tsx', 'Mi ubicacion (menor): con quien compartis', a3, b3),
         ('src\\FamiliaPantalla.tsx', 'SOS: a quien le suena', a4, b4)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-familia-sos-nombres-app.ps1 - App (PROXIMA build): "Familia y amigos" dice con nombres quien te ve y a quien le suena tu SOS.
# Luciano (04/11/2026): "donde aparece con quien estoy compartiendo la ubicacion y a quien le mandas el SOS" (como lo muestran Apple y Google, dentro de la pantalla que ya existe, sin una nueva).
#  - Tarjeta "MI UBICACION": "Te ven: Papa, Guido y 3 mas." (la regla de quien se ve con quien es simetrica; un grupo grande se resume).
#  - Tarjeta "SOS Y AYUDA": "Tu SOS les suena en la app a: ...". Necesita aplicar antes aplicar-familia-sos-nombres-panel.ps1 (el servidor manda sosTo); sin eso la linea no se muestra.
# Toca solo src\\FamiliaPantalla.tsx (respaldo .bak-sosnombres). Va en la carpeta de la APP (la que tiene app.json).
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function listaDeNombres') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-sosnombres')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + base[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-familia-sos-nombres-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
