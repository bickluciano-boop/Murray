# Genera scripts/aplicar-identidad-diag-panel.ps1: el servidor anota en el registro lo que contesta Didit cuando falla (estado y los primeros 400 caracteres de la respuesta).
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-identidad.ts', encoding='utf-8').read()
filas = []
def cambio(rotulo, viejo, nuevo):
    assert fi.count(viejo) == 1, (rotulo, fi.count(viejo))
    filas.append(('src\\index.ts', rotulo, viejo, nuevo))
cambio('registro cuando no se puede llegar a Didit',
 '  } catch {\n    return json({ error: "identity_unreachable" }, 502);\n  } finally {',
 '  } catch (error) {\n    console.error("didit_unreachable", String(error));\n    return json({ error: "identity_unreachable" }, 502);\n  } finally {')
cambio('registro de lo que contesta Didit cuando falla',
 '  const datos = await respuesta.json<Record<string, unknown>>().catch(() => null);\n  if (!respuesta.ok || !datos) {\n    console.error("didit_failed", respuesta.status);\n    return json({ error: "identity_provider_error", status: respuesta.status }, 502);\n  }',
 '  const texto = await respuesta.text().catch(() => "");\n  let datos: Record<string, unknown> | null = null;\n  try {\n    datos = JSON.parse(texto) as Record<string, unknown>;\n  } catch {\n    datos = null;\n  }\n  if (!respuesta.ok || !datos) {\n    console.error("didit_failed", respuesta.status, texto.slice(0, 400));\n    return json({ error: "identity_provider_error", status: respuesta.status }, 502);\n  }')
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-identidad-diag-panel.ps1 - Ojo Guard MS: cuando Didit falla, el servidor anota el estado y el principio de su respuesta (no incluye claves ni la selfie), para poder ver la causa con "wrangler tail".
# 28/10/2026: la verificacion de identidad mostro "El servicio de verificacion no esta disponible" con la clave de prueba (Sandbox). Cambia SOLO src\\index.ts (respaldo .bak-identidad-diag). Va en la carpeta del PANEL. Requiere aplicar-identidad-didit-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'didit_unreachable') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'nativeIdentityVerify') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-didit-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad-diag')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el servidor ya anota lo que contesta Didit cuando falla."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-diag-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(filas))
