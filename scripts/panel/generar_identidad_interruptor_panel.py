# Genera scripts/aplicar-identidad-interruptor-panel.ps1: interruptor IDENTIDAD_OBLIGATORIA en el servidor. En false, pedir foto y audio a otra persona NO exige tener la identidad verificada
# (mientras Didit no funcione y se prueba entre amigos y conocidos). En true es la regla de siempre. Volver a true antes de abrirlo al publico.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = 'async function identidadVerificada(env: Env, email: string) {\n  await idTabla(env);\n'
b1 = '''// INTERRUPTOR (30/10/2026): mientras la verificacion de identidad (Didit) no funcione y se prueba entre amigos y conocidos, en false se deja pedir foto y audio a otra persona
// sin verificar. Es una regla de privacidad: VOLVER A true antes de abrir Ojo Guard al publico o de mandarlo a revision de Apple.
const IDENTIDAD_OBLIGATORIA = false;

async function identidadVerificada(env: Env, email: string) {
  if (!IDENTIDAD_OBLIGATORIA) return true;
  await idTabla(env);
'''
filas = [('src\\index.ts', 'interruptor de identidad obligatoria', a1, b1)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-identidad-interruptor-panel.ps1 - Ojo Guard MS: interruptor IDENTIDAD_OBLIGATORIA (queda en false). Mientras Didit no ande y se prueba entre amigos y conocidos, pedir foto y audio a otra persona no exige verificar la identidad.
# Idea de Luciano (30/10/2026). Cambia SOLO src\\index.ts (respaldo .bak-identidad-interruptor). IMPORTANTE: volver a true antes de abrirlo al publico. Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'IDENTIDAD_OBLIGATORIA') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-identidad-interruptor')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: pedir foto y audio a otra persona ya no exige identidad verificada (modo prueba). Acordate de volver a true antes de abrirlo al publico."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-identidad-interruptor-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
