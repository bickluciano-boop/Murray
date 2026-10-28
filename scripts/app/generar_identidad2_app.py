# Genera scripts/aplicar-identidad2-app.ps1: selfie con la camara DENTRO de la app, sin titulo repetido en Configuracion y sin los botones "Guardar cambios / Volver sin guardar" en las paginas Verificar mi identidad y Actualizar.
import re, subprocess
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/actual/'
COMMIT_ARCHIVOS = '904ada28b91316d4ee5f5fccf0cfa8c63fb4b80f'
SHA_VERIFICAR = subprocess.check_output(['sha256sum', R + 'app/src/VerificarIdentidad.tsx']).decode().split()[0]
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
app = open(S + 'out_App.tsx', encoding='utf-8').read()
viejo = '''          <Pressable onPress={onSave} style={styles.primaryButton}>
            <Text style={styles.primaryButtonText}>
              {firstRun ? "Activar Ojo Guard" : "Guardar cambios"}
            </Text>
          </Pressable>
          {onCancel ? (
            <Pressable onPress={onCancel} style={styles.cancelButton}>
              <Text style={styles.cancelButtonText}>Volver sin guardar</Text>
            </Pressable>
          ) : null}
'''
nuevo = '''          {grupoActual === "identidad" || grupoActual === "actualizacion" ? null : (
            <>
              <Pressable onPress={onSave} style={styles.primaryButton}>
                <Text style={styles.primaryButtonText}>
                  {firstRun ? "Activar Ojo Guard" : "Guardar cambios"}
                </Text>
              </Pressable>
              {onCancel ? (
                <Pressable onPress={onCancel} style={styles.cancelButton}>
                  <Text style={styles.cancelButtonText}>Volver sin guardar</Text>
                </Pressable>
              ) : null}
            </>
          )}
'''
assert app.count(viejo) == 1, app.count(viejo)
filas = [('App.tsx', 'sin Guardar cambios en las paginas Verificar mi identidad y Actualizar', viejo, nuevo)]
# Con un solo cambio hace falta la coma delante: sin ella PowerShell aplana la fila y lee "A" en vez de "App.tsx".
cambios = "$cambios = @(\n" + ",".join("    ,@(%s, %s, %s, %s)\n" % tuple(psq(x) for x in f) for f in filas[:1]) + (',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas[1:]) + "\n" if len(filas) > 1 else "") + ")\n"
url = lambda ruta: 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT_ARCHIVOS, ruta)
descargas = "$descargas = @(\n    @(%s, %s, %s)\n)\n" % (psq(url('src/VerificarIdentidad.tsx')), psq('src\\VerificarIdentidad.tsx'), psq(SHA_VERIFICAR))
cabeza = '''# aplicar-identidad2-app.ps1 - App (PROXIMA build): la selfie se saca con la camara DENTRO de la app; Configuracion > Verificar mi identidad sin titulo repetido ni botones Guardar.
# Luciano (28/10/2026, Xiaomi): con la camara del sistema la app volvia sola a la pantalla del codigo (le pasa tambien en Android al adjuntar fotos en otras apps: el sistema cierra la app por memoria).
# Ahora la selfie usa la camara de la propia app (como la evidencia): no se sale de la app. Tambien: en Verificar mi identidad y Actualizar Ojo Guard ya no aparecen "Guardar cambios" ni "Volver sin guardar".
# Reemplaza src\\VerificarIdentidad.tsx (descarga con huella) y cambia App.tsx (respaldo .bak-identidad2). Requiere aplicar-identidad-app.ps1 y aplicar-identidad-camara-app.ps1. Va en la carpeta de la APP. Sale en la PROXIMA build.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("App.tsx", "src\\VerificarIdentidad.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta. Falta aplicar aplicar-identidad-app.ps1."); return } }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'grupoActual === "identidad" || grupoActual === "actualizacion"') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-identidad2')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad2") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad2") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-identidad2") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad2-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
