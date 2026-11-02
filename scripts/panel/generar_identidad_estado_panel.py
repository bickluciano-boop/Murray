# Genera scripts/aplicar-identidad-estado-panel.ps1: SOS desde el Apple Watch (o cualquier atajo) con un enlace secreto por persona que dispara el mismo SOS de siempre.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"



a1 = '  const validaciones = Array.isArray(datos.validations) ? (datos.validations as Array<Record<string, unknown>>) : [];\n  const primera = validaciones[0] ?? {};\n  const outcome = String(primera.outcome_code ?? "UNKNOWN");\n'
b1 = (
'  // La guia de Didit pide mirar tambien `status` y `errors[]` (aun con HTTP 200): un servicio caido y reintentable no es un "no coincide".\n'
'  const bloqueDidit = (datos.database_validation && typeof datos.database_validation === "object" ? datos.database_validation : datos) as Record<string, unknown>;\n'
'  const erroresDidit = Array.isArray(bloqueDidit.errors) ? (bloqueDidit.errors as Array<Record<string, unknown>>) : Array.isArray(datos.errors) ? (datos.errors as Array<Record<string, unknown>>) : [];\n'
'  if (erroresDidit.length) console.error("didit_errors", JSON.stringify(erroresDidit.map((e) => ({ code: e?.code, retryable: e?.retryable }))).slice(0, 300));\n'
'  const servicioCaido = erroresDidit.some((e) => e?.retryable === true);\n'
'  const estadoDidit = String(bloqueDidit.status ?? datos.status ?? "");\n'
'  const validaciones = Array.isArray(bloqueDidit.validations) ? (bloqueDidit.validations as Array<Record<string, unknown>>) : Array.isArray(datos.validations) ? (datos.validations as Array<Record<string, unknown>>) : [];\n'
'  const primera = validaciones[0] ?? {};\n'
'  // Sin resultado y con un error reintentable: el registro no contesto (no se cobra ni cuenta como intento).\n'
'  const outcome = !validaciones.length && servicioCaido ? "REGISTRY_UNAVAILABLE" : String(primera.outcome_code ?? "UNKNOWN");\n')
a2 = '  const verificada = outcome === "MATCH";\n'
b2 = ('  // Solo se da por verificada si Didit tambien la aprobo (si manda estado): "Declined" o "In Review" nunca verifican, aunque el registro coincida.\n'
      '  const verificada = outcome === "MATCH" && (estadoDidit === "" || estadoDidit === "Approved");\n')
filas = [('src\\index.ts', 'Didit: leer status y errors[] de la respuesta', a1, b1),
         ('src\\index.ts', 'Didit: verificada solo si el estado es Approved', a2, b2)]
cambios = "$cambios = @(\n" + ',\n'.join(("    ,@(%s, %s, %s, %s)" if len(filas) == 1 else "    @(%s, %s, %s, %s)") % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-identidad-estado-panel.ps1 - Ojo Guard MS: la verificacion de identidad lee `status` y `errors[]` de Didit (como pide su guia): un servicio caido y reintentable ya no gasta el intento de la persona, y solo queda "verificada" si Didit tambien la aprobo (Approved).
# Cambia SOLO src\\index.ts (respaldo .bak-identidadestado). Va en la carpeta del PANEL (la que tiene wrangler.toml). No cambia la app. Requiere aplicar-identidad-didit-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'didit_errors') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-identidadestado')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la verificacion de identidad ahora mira el estado y los errores de Didit."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-identidad-estado-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
