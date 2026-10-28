# Genera scripts/aplicar-identidad-variantes2-panel.ps1 (cuando Didit da 500 se prueban variantes). Antes: la clave DIDIT_API_KEY se limpia (espacios, comillas, "Bearer") y el registro anota su forma (largos), sin mostrarla. Didit contesta 400 vacio incluso con el pedido multipart bien armado.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-variantes.ts', encoding='utf-8').read()
GRIS = open('/tmp/gris.b64').read().strip()
a1 = """      const pruebas: Array<[string, Array<[string, string]>, Uint8Array]> = [
        ["sinVd", base, bytes],
        ["conDatos", [...base, ["first_name", "Prueba"], ["last_name", "Prueba"], ["date_of_birth", "1980-01-01"]], bytes],
        ["sinServices", base.filter(([clave]) => clave !== "services"), bytes],
        ["fotoChica", base, chica],
        ["conVd", [...base, ["vendor_data", "prueba"]], chica],
      ];"""
b1 = """      // Segunda ronda: Didit acepta la selfie real (no da 400 de imagen) y se rompe adentro. Se prueba una imagen valida SIN cara, otro DNI y otro sexo, para ver si el 500 depende de la cara o de los datos.
      const gris = Uint8Array.from(atob("%s"), (c) => c.charCodeAt(0));
      const otroDni = base.map(([clave, valor]): [string, string] => (clave === "document_number" ? [clave, "20123456"] : [clave, valor]));
      const otroSexo = base.map(([clave, valor]): [string, string] => (clave === "gender" ? [clave, "F"] : [clave, valor]));
      const pruebas: Array<[string, Array<[string, string]>, Uint8Array]> = [
        ["imagenSinCara", base, gris],
        ["imagenSinCaraConVd", [...base, ["vendor_data", "prueba"]], gris],
        ["otroDni", otroDni, bytes],
        ["otroSexo", otroSexo, bytes],
        ["otroDniSinCara", otroDni, gris],
      ];""" % GRIS
assert fi.count(a1) == 1, fi.count(a1)
filas = [('src\\index.ts', 'segunda ronda de variantes (imagen sin cara, otro DNI, otro sexo)', a1, b1)]
cambios = "$cambios = @(\n    ," + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in filas[0]) + "\n)\n"
cabeza = '''# aplicar-identidad-variantes2-panel.ps1 - Ojo Guard MS: segunda ronda de pruebas contra Didit (que sigue dando 500 con la selfie real): imagen valida SIN cara, otro DNI y otro sexo.
# Cambia SOLO src\\index.ts (respaldo .bak-identidad-variantes2). Va en la carpeta del PANEL. Requiere aplicar-identidad-variantes-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'imagenSinCara') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'didit_variantes') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-variantes-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad-variantes2')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: segunda ronda de variantes lista."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-variantes2-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(SC + 'index-variantes2.ts', 'w', encoding='utf-8').write(fi.replace(a1, b1))
print('ok', len(total))
