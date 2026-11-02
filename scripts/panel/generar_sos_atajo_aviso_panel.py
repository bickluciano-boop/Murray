# Genera scripts/aplicar-sos-atajo-aviso-panel.ps1: SOS desde el Apple Watch (o cualquier atajo) con un enlace secreto por persona que dispara el mismo SOS de siempre.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"


ancla = '  return ejecutarFamilySos(env, fila.email, fila.deviceId, { action: body.action === "cancel" ? "cancel" : "send", location });\n}\n'
reemplazo = (
'  const respuesta = await ejecutarFamilySos(env, fila.email, fila.deviceId, { action: body.action === "cancel" ? "cancel" : "send", location });\n'
'  // Quien dispara el SOS (el reloj no muestra nada) recibe la confirmacion en su propio telefono; el iPhone la repite en el reloj si esta bloqueado.\n'
'  try {\n'
'    const datos = await respuesta.clone().json<Record<string, unknown>>();\n'
'    let titulo = "", cuerpo = "";\n'
'    if (body.action === "cancel") {\n'
'      if (datos.cancelled) { titulo = "SOS cancelado"; cuerpo = "Avisamos a tu familia que est\\u00e1s bien."; }\n'
'    } else if (datos.sent) {\n'
'      const para = Array.isArray(datos.to) ? (datos.to as unknown[]).map(String).filter(Boolean) : [];\n'
'      const lista = para.length > 1 ? `${para.slice(0, -1).join(", ")} y ${para[para.length - 1]}` : para[0] || "tu familia";\n'
'      titulo = datos.repeated ? "Tu SOS sigue activo" : "SOS enviado";\n'
'      cuerpo = datos.repeated ? "Ya hab\\u00edas pedido ayuda hace poco: tu familia ya fue avisada. Si est\\u00e1s bien, abr\\u00ed Ojo Guard y toc\\u00e1 \\u00abEstoy bien\\u00bb." : `Le avisamos a ${lista}. Si est\\u00e1s bien, abr\\u00ed Ojo Guard y toc\\u00e1 \\u00abEstoy bien\\u00bb.`;\n'
'    } else if (respuesta.status === 409) {\n'
'      titulo = "No se pudo mandar el SOS"; cuerpo = "No hay nadie a quien avisar: sum\\u00e1 a alguien a tu familia.";\n'
'    }\n'
'    if (titulo) for (const token of await pushTokensOf(env, fila.email)) await sendExpoNotice(token, titulo, cuerpo).catch(() => false);\n'
'  } catch (error) {\n'
'    console.error("sos_atajo_aviso_failed", error);\n'
'  }\n'
'  return respuesta;\n}\n')
filas = [('src\\index.ts', 'SOS del reloj: confirmacion a quien lo dispara', ancla, reemplazo)]
cambios = "$cambios = @(\n" + ',\n'.join("    ,@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sos-atajo-aviso-panel.ps1 - Ojo Guard MS: el SOS por enlace del reloj/atajo confirma a quien lo dispara (aviso en su telefono, que el iPhone repite en el reloj).
# Idea de Luciano (01/11/2026): que el ecosistema (iPhone, Android, Mac, reloj) conviva. PRUEBA: hay que ver en el reloj de Luciano si "Obtener contenido de URL" anda en la watchOS actual.
# Pagina para crear/revocar el enlace: ojoguard.app/atajo-sos (con la sesion del panel). Endpoint: POST /api/sos/atajo/<clave> (solo se guarda el hash). Cambia SOLO src\\index.ts (el SOS del telefono se parte en dos funciones, sin cambiar lo que hace). Respaldo .bak-sosatajoaviso. Va en la carpeta del PANEL. Sin build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'sos_atajo_aviso_failed') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function sosAtajoDisparar') -ne 1) { Mal "Primero hay que aplicar el instalador del SOS del reloj (aplicar-sos-atajo-panel)."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-sosatajoaviso')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el SOS por enlace ahora te confirma en tu telefono (y en el reloj, si el iPhone esta bloqueado)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-sos-atajo-aviso-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
