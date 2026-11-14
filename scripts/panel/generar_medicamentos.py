# Genera scripts/aplicar-medicamentos-panel.ps1 y scripts/aplicar-medicamentos-app.ps1: la palabra "remedio(s)" pasa a "medicamento(s)" en lo que se VE (avisos, panel, app).
# Luciano (14/11/2026): "podemos cambiar la palabra remedios por medicamentos, porque despues en ingles tambien es medicine".
# Solo cambia textos visibles: NO se tocan nombres internos (type: "remedio", cuidado.remedios, TarjetaRemedios, etc.).
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
IDX, MAPA, FAM, APP = 'src\\index.ts', 'src\\panel-mapa.txt', 'src\\FamiliaPantalla.tsx', 'App.tsx'
panel_filas = [
 (IDX, 'avisos: titulo del aviso (Remedio -> Medicamento)', 'varios ? "Remedios" : "Remedio"', 'varios ? "Medicamentos" : "Medicamento"'),
 (IDX, 'avisos: "Es hora de tus medicamentos"', 'Es hora de ${varios ? "tus remedios" : "tu remedio"}', 'Es hora de ${varios ? "tus medicamentos" : "tu medicamento"}'),
 (IDX, 'avisos: titulo del recordatorio repetido', 'medAvisar(env, primero.email, "Remedio", ', 'medAvisar(env, primero.email, "Medicamento", '),
 (IDX, 'avisos: a la familia "todavia no confirmo su medicamento"', 'todavía no confirmó su remedio de las', 'todavía no confirmó su medicamento de las'),
 (IDX, 'avisos: a la familia "ya confirmo su medicamento"', 'ya confirmó su remedio.', 'ya confirmó su medicamento.'),
 (MAPA, 'mapa: "Medicamentos: X de Y tomados hoy"', '`Remedios: ${rem.tomadas} de ${rem.total} tomados hoy`', '`Medicamentos: ${rem.tomadas} de ${rem.total} tomados hoy`'),
]
app_filas = [
 (FAM, 'app: titulo del aviso "No se pudo cargar"', 'titulo="Remedios"', 'titulo="Medicamentos"'),
 (FAM, 'app: "Puedes cargar hasta N medicamentos"', 'hasta ${actual.max.items} remedios.', 'hasta ${actual.max.items} medicamentos.'),
 (FAM, 'app: "Escribe el nombre del medicamento"', 'Escribe el nombre del remedio.', 'Escribe el nombre del medicamento.'),
 (FAM, 'app: "Hasta N horas por medicamento"', 'horas por remedio.', 'horas por medicamento.'),
 (FAM, 'app: encabezado MEDICAMENTOS', '}>REMEDIOS</Text>', '}>MEDICAMENTOS</Text>'),
 (FAM, 'app: explicacion "todos los medicamentos de esa hora"', 'con todos los remedios de esa hora', 'con todos los medicamentos de esa hora'),
 (FAM, 'app: MIS MEDICAMENTOS', '>MIS REMEDIOS</Text>', '>MIS MEDICAMENTOS</Text>'),
 (FAM, 'app: EDITAR / NUEVO MEDICAMENTO', '"EDITAR REMEDIO" : "NUEVO REMEDIO"', '"EDITAR MEDICAMENTO" : "NUEVO MEDICAMENTO"'),
 (FAM, 'app: etiqueta del nombre (accesibilidad)', 'accessibilityLabel="Nombre del remedio"', 'accessibilityLabel="Nombre del medicamento"'),
 (FAM, 'app: texto de ayuda del nombre', 'placeholder="Nombre del remedio"', 'placeholder="Nombre del medicamento"'),
 (FAM, 'app: "Si tomas varios medicamentos a la misma hora"', 'Si tomas varios remedios a la misma hora', 'Si tomas varios medicamentos a la misma hora'),
 (FAM, 'app: boton Guardar medicamento', '"Guardando…" : "Guardar remedio"', '"Guardando…" : "Guardar medicamento"'),
 (FAM, 'app: boton Agregar otro / un medicamento', '"Agregar otro remedio" : "Agregar un remedio"', '"Agregar otro medicamento" : "Agregar un medicamento"'),
 (FAM, 'app: "No decimos que medicamento"', 'No decimos qué remedio.', 'No decimos qué medicamento.'),
 (APP, 'app: titulo de la pregunta al tocar el aviso', 'Alert.alert("Remedio", ', 'Alert.alert("Medicamento", '),
 (APP, 'app: pregunta "Tomaste tu medicamento?"', '"¿Tomaste tu remedio?"', '"¿Tomaste tu medicamento?"'),
 (APP, 'app: "busca Medicamentos y toca Lo tome"', 'busca Remedios y toca', 'busca Medicamentos y toca'),
]
def cambios_ps(filas):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
def instalador(tipo, filas, archivo, etiqueta, cabeza, guardas, mensaje):
    t = tpl if tipo == 'panel' else base
    i0 = t.index('$ErrorActionPreference'); j0 = t.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))') if tipo == 'panel' else t.index('Ok "Carpeta correcta"')
    cola = t[t.index('$descargas = @()'):].replace('.bak-audioandroid' if tipo == 'panel' else '.bak-version', '.bak-' + etiqueta)
    if tipo == 'panel':
        cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
        cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % mensaje, cola)
    else:
        cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % mensaje, cola)
    total = cabeza + t[i0:j0] + guardas + cambios_ps(filas) + cola
    bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
    assert not bad, set(bad)
    open(R + archivo, 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
    return len(total)
cab_p = '''# aplicar-medicamentos-panel.ps1 - Ojo Guard MS: la palabra "remedio(s)" pasa a "medicamento(s)" en lo que se ve del servidor y del panel: el aviso a la hora ("Es hora de tus medicamentos"), los avisos a la familia y la linea "Medicamentos: X de Y tomados hoy" del mapa.
# Luciano (14/11/2026): "podemos cambiar la palabra remedios por medicamentos, porque despues en ingles tambien es medicine". Solo textos visibles: no se tocan nombres internos. Cambia src\\index.ts y src\\panel-mapa.txt (respaldo .bak-medic).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build. Al final publica el panel solo.
'''
g_p = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-mapa.txt")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'Medicamentos: ${rem.tomadas}') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cab_a = '''# aplicar-medicamentos-app.ps1 - App (PROXIMA build): la palabra "remedio(s)" pasa a "medicamento(s)" en todo lo que se ve (tarjeta de Familia y la pregunta al tocar el aviso).
# Luciano (14/11/2026): "podemos cambiar la palabra remedios por medicamentos, porque despues en ingles tambien es medicine". Solo textos visibles: no se tocan nombres internos. Cambia src\\FamiliaPantalla.tsx y App.tsx (respaldo .bak-medic).
# Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
g_a = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FamiliaPantalla.tsx", "App.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto '>MIS MEDICAMENTOS</Text>') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
print('panel', instalador('panel', panel_filas, 'aplicar-medicamentos-panel.ps1', 'medic', cab_p, g_p, 'LISTO: el aviso y el panel dicen medicamentos en vez de remedios.'))
print('app', instalador('app', app_filas, 'aplicar-medicamentos-app.ps1', 'medic', cab_a, g_a, 'LISTO: la app compila bien. Dice medicamentos en vez de remedios (sale en la PROXIMA build, Android e iPhone).'))
# replicas
for origen, destino, filas in ((S + 'index-diag.ts.neutro', S + 'index-med.ts', panel_filas[:5]), (S + 'panel-mapa-diag.txt.neutro', S + 'panel-mapa-med.txt', panel_filas[5:]),
                               (S + 'FamiliaPantalla-horas.tsx.neutro', S + 'FamiliaPantalla-med.tsx', app_filas[:14]), (S + 'App-remedios2-bloque.txt.neutro', S + 'App-med-bloque.txt', app_filas[14:])):
    t = open(origen, encoding='utf-8').read()
    for a, n, v, nv in filas:
        assert t.count(v) == 1, (n, t.count(v))
    for a, n, v, nv in filas:
        t = t.replace(v, nv)
    open(destino, 'w', encoding='utf-8').write(t)
print('replicas ok')
