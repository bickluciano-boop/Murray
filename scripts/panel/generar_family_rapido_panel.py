# Genera scripts/aplicar-family-rapido-panel.ps1: el pedido /api/remote/family (la lista de personas del mapa) tardaba ~5 s porque hacia unas 60 consultas a la base UNA DETRAS DE OTRA.
# Ahora: (1) las personas se calculan en paralelo, (2) las consultas del arranque van juntas, (3) lugares, avisos y SOS arrancan junto con las personas. El resultado es identico.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A1 = ('  const destinoSos = new Set(await familySosRecipients(env, viewer).catch(() => [] as string[]));\n'
      '  const perms = await permsDe(env, viewer).catch(() => new Map<string, PermFila>());\n'
      '  const baseSos = new Set(liviano ? [] : await familySosRecipients(env, viewer, false).catch(() => [] as string[]));\n')
B1 = ('  // Las tres consultas no dependen entre si: arrancan juntas (antes iban una detras de otra).\n'
      '  const [destinoLista, perms, baseLista] = await Promise.all([\n'
      '    familySosRecipients(env, viewer).catch(() => [] as string[]),\n'
      '    permsDe(env, viewer).catch(() => new Map<string, PermFila>()),\n'
      '    liviano ? Promise.resolve([] as string[]) : familySosRecipients(env, viewer, false).catch(() => [] as string[]),\n'
      '  ]);\n'
      '  const destinoSos = new Set(destinoLista);\n'
      '  const baseSos = new Set(baseLista);\n')
A2 = '  const people: Record<string, unknown>[] = [];\n  for (const p of personas.values()) {\n'
B2 = ('  // Cada persona se calcula en paralelo con las demas (antes eran ~60 consultas una detras de otra y el pedido tardaba ~5 s). El orden de la lista no cambia.\n'
      '  const people: Record<string, unknown>[] = await Promise.all([...personas.values()].map(async (p) => {\n'
      '    // Lo que no depende de lo anterior arranca de entrada, junto con lo demas (se usa mas abajo, en el mismo orden de siempre).\n'
      '    const sinLlavesP = liviano ? Promise.resolve([] as string[]) : familySosRecipients(env, p.email, false).catch(() => [] as string[]);\n'
      '    const susDestinosP = !liviano && personas.size <= 12 ? familySosRecipients(env, p.email).catch(() => [] as string[]) : Promise.resolve([] as string[]);\n'
      '    const nombreP = nombrePerfil(env, p.email);\n'
      '    const fotoP = fotoVersion(env, p.email);\n'
      '    const historialP = p.gestionable ? avisoHistorialActivo(env, p.id) : Promise.resolve(undefined);\n'
      '    for (const x of [sinLlavesP, susDestinosP, nombreP, fotoP, historialP]) x.catch(() => undefined);\n')
A3 = '    people.push({\n      id: p.id,\n'
B3 = '    return {\n      id: p.id,\n'
A4 = ('      notifyHistory: p.gestionable ? await avisoHistorialActivo(env, p.id) : undefined,\n'
      '    });\n  }\n  return people;\n}\n')
B4 = ('      notifyHistory: p.gestionable ? await historialP : undefined,\n'
      '    };\n  }));\n  return people;\n}\n')
A5 = '  const people = await familyPeopleFor(env, email);\n  const invites = await env.DB.prepare(\n    "SELECT id,name,role,invite_code'
B5 = ('  // Las personas, los lugares, los avisos y el SOS no dependen entre si: arrancan juntos (antes iban uno detras del otro).\n'
      '  const peopleP = familyPeopleFor(env, email);\n  peopleP.catch(() => undefined);\n'
      '  const lugaresP = familyPlacesFor(env, email).catch(() => []);\n'
      '  const avisosP = familyAlertsBy(env, email).catch(() => []);\n'
      '  const sosP = familySosFor(env, email).catch(() => []);\n'
      '  const invites = await env.DB.prepare(\n    "SELECT id,name,role,invite_code')
A6 = '  return json({\n    people,\n    invites: invites.results.map('
B6 = '  return json({\n    people: await peopleP,\n    invites: invites.results.map('
A7 = ('    places: await familyPlacesFor(env, email).catch(() => []),\n'
      '    alerts: await familyAlertsBy(env, email).catch(() => []),\n'
      '    sos: await familySosFor(env, email).catch(() => []),\n  });\n}\n')
B7 = ('    places: await lugaresP,\n    alerts: await avisosP,\n    sos: await sosP,\n  });\n}\n')
C2a = '      permisos.recibisSuSos.elegible = (await familySosRecipients(env, p.email, false).catch(() => [] as string[])).includes(viewer);\n'
C2b = '      permisos.recibisSuSos.elegible = (await sinLlavesP).includes(viewer);\n'
C3a = '      const susDestinos = await familySosRecipients(env, p.email).catch(() => [] as string[]);\n'
C3b = '      const susDestinos = await susDestinosP;\n'
C4a = '      name: (await nombrePerfil(env, p.email)) || p.name ||'
C4b = '      name: (await nombreP) || p.name ||'
C5a = '      photo: await fotoVersion(env, p.email),\n      sosTo:'
C5b = '      photo: await fotoP,\n      sosTo:'
D1a = '  const prefs = await cuidadoPrefs(env, email), e = await cuidadoEstado(env, email);\n  const loc = cuidadoLocal(Date.now(), prefs.tz);\n'
D1b = ('  // Las tres consultas no dependen entre si: arrancan juntas.\n'
       '  const [prefs, e, apagado] = await Promise.all([cuidadoPrefs(env, email), cuidadoEstado(env, email), sosApagado(env, email)]);\n'
       '  const loc = cuidadoLocal(Date.now(), prefs.tz);\n')
D2a = '    sosApagado: await sosApagado(env, email),\n    bateria: prefs.bateria,\n'
D2b = '    sosApagado: apagado,\n    bateria: prefs.bateria,\n'
pares = [(A1, B1), (A2, B2), (A3, B3), (A4, B4), (A5, B5), (A6, B6), (A7, B7), (C2a, C2b), (C3a, C3b), (C4a, C4b), (C5a, C5b), (D1a, D1b), (D2a, D2b)]
nombres = ['familia: el arranque de la lista en paralelo', 'familia: cada persona en paralelo (apertura)', 'familia: cada persona en paralelo (resultado)', 'familia: cada persona en paralelo (cierre)',
           'familia: personas, lugares, avisos y SOS arrancan juntos', 'familia: usar las personas ya pedidas', 'familia: usar lugares, avisos y SOS ya pedidos',
           'familia: SOS sin llaves ya pedido', 'familia: SOS con llaves ya pedido', 'familia: nombre ya pedido', 'familia: foto ya pedida', 'cuidado: consultas juntas', 'cuidado: SOS apagado ya pedido']
filas = [('src\\index.ts', n, a, b) for n, (a, b) in zip(nombres, pares)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-family-rapido-panel.ps1 - Ojo Guard MS: el mapa carga mucho mas rapido. El pedido de la lista de personas (/api/remote/family) tardaba unos 5 segundos porque hacia unas 60 consultas a la base una detras de otra.
# Luciano (12/11/2026): el mapa tarda 8 a 13 s en cargar en los celulares; con F12 se vio que cada pedido "family" tardaba ~5 s. Ahora las personas se calculan en paralelo y lo demas arranca junto. El resultado es el mismo.
# Cambia SOLO src\\index.ts (respaldo .bak-family-rapido). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Requiere aplicar-cuidado-estado-panel.ps1 (ya aplicado). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$indexTexto = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $indexTexto 'peopleP') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'async function cuidadoVista') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-estado-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-family-rapido')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la lista de personas del mapa responde mucho mas rapido (recarga la pagina con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-family-rapido-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-estado2.ts', encoding='utf-8').read()
for a, _ in pares:
    assert t.count(a) == 1, (t.count(a), a[:70])
for a, b in pares:
    t = t.replace(a, b)
open(S + 'index-rapido.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total))
