# Genera scripts/aplicar-revision-apple-panel.ps1: cuenta de demostracion para la revision de Apple (TestFlight externo).
# Apple pide usuario y contrasena para que su revisor entre a la app; Ojo Guard entra con un codigo de 6 numeros por correo.
# Solucion: el correo revision@ojoguard.app no manda mail y acepta UN codigo de 6 numeros que se guarda como secreto (REVIEW_CODE), distinto en cada instalacion.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

A_ENV = '  USD_ARS_RATE?: string;'
N_ENV = A_ENV + '''
  /** Codigo de 6 numeros de la cuenta de demostracion para la revision de Apple (revision@ojoguard.app). Se carga con `wrangler secret put REVIEW_CODE`; para apagarla: `wrangler secret delete REVIEW_CODE`. */
  REVIEW_CODE?: string;'''

A_FN = 'async function requestAccess(request: Request, env: Env) {'
N_FN = '''// Cuenta de demostracion para la revision de Apple (TestFlight externo). El revisor no puede recibir un codigo por correo:
// con este correo y el codigo guardado como secreto REVIEW_CODE entra a una cuenta vacia (no ve nada de nadie). No manda mails.
const REVISION_EMAIL = "revision@ojoguard.app";
function esCuentaDeRevision(env: Env, email: string, code: string) {
  const secreto = String(env.REVIEW_CODE ?? "").trim();
  return email === REVISION_EMAIL && /^\\d{6}$/.test(secreto) && code === secreto;
}

''' + A_FN

A_REQ = '  const purpose = body.accessType ? "native_enroll" : "access";'
N_REQ = '''  if (email === REVISION_EMAIL) return json({ sent: true, expiresInMinutes: 15 });
''' + A_REQ

A_ENR = '''  if (await isAccessLocked(env, email)) return json({ error: "too_many_attempts" }, 429);
  const candidates = await env.DB.prepare("SELECT id,code_hash FROM access_codes WHERE email=? AND purpose IN ('native_enroll','access')'''
N_ENR = '''  if (await isAccessLocked(env, email)) return json({ error: "too_many_attempts" }, 429);
  // Cuenta de demostracion de Apple: si el codigo es el de REVIEW_CODE se crea un codigo valido por 5 minutos y el resto del ingreso sigue igual.
  const revision = esCuentaDeRevision(env, email, code);
  if (revision) {
    await env.DB.prepare("INSERT INTO access_codes (id,email,code_hash,purpose,expires_at,created_at) VALUES (?,?,?,?,?,?)")
      .bind(randomId("code"), email, await hash(code), "native_enroll", plusMinutes(5), now()).run();
  }
  const candidates = await env.DB.prepare("SELECT id,code_hash FROM access_codes WHERE email=? AND purpose IN ('native_enroll','access')'''

A_APR = '  const approvalStatus = existing?.approvalStatus === "approved" || isPrimary ? "approved" : "pending";'
N_APR = '  const approvalStatus = existing?.approvalStatus === "approved" || isPrimary || revision ? "approved" : "pending";'

A_NOT = '  if (!existing) {'
N_NOT = '  if (!existing && !revision) {'

filas = [
    ('src\\index.ts', 'variable REVIEW_CODE en Env', A_ENV, N_ENV),
    ('src\\index.ts', 'funcion de la cuenta de demostracion', A_FN, N_FN),
    ('src\\index.ts', 'pedido de codigo: la cuenta de demostracion no manda mail', A_REQ, N_REQ),
    ('src\\index.ts', 'ingreso: codigo de la cuenta de demostracion', A_ENR, N_ENR),
    ('src\\index.ts', 'ingreso: la cuenta de demostracion siempre queda aprobada', A_APR, N_APR),
    ('src\\index.ts', 'ingreso: sin aviso de seguridad por mail para la cuenta de demostracion', A_NOT, N_NOT),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-revision-apple-panel.ps1 - Ojo Guard MS: cuenta de demostracion para la revision de Apple (TestFlight con enlace publico).
# Apple pide usuario y contrasena para que su revisor entre a la app; Ojo Guard entra con un codigo de 6 numeros por correo y el revisor no puede recibirlo.
#  - El correo revision@ojoguard.app no manda ningun mail y acepta UN codigo de 6 numeros, que este instalador inventa al azar, guarda como secreto (REVIEW_CODE) y te muestra al final (tambien queda copiado al portapapeles).
#  - Esa cuenta nace vacia: no ve nada de ninguna otra persona. No suena ninguna alerta ni llega ningun mail por sus ingresos.
#  - Los intentos equivocados cuentan para el bloqueo de siempre. Para apagarla despues de que Apple apruebe: npx.cmd wrangler secret delete REVIEW_CODE
# Cambia SOLO src\\index.ts (respaldo .bak-revision). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final carga el secreto y publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const REVISION_EMAIL') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-revision')
viejo = '& npx.cmd wrangler deploy\n'
assert cola.count(viejo) == 1
nuevo = '''Write-Host "Cargando el codigo de la cuenta de demostracion (secreto REVIEW_CODE)..."
$bytesRev = New-Object byte[] 4
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($bytesRev); $rng.Dispose()
$codigoRev = [string](([System.BitConverter]::ToUInt32($bytesRev, 0) % 900000) + 100000)
$salidaSecreto = ($codigoRev | & npx.cmd wrangler secret put REVIEW_CODE 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    Write-Host $salidaSecreto
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-revision") -Destination $ruta -Force } }
    Mal "No se pudo guardar el secreto. Deje todo como estaba. Mandame esta pantalla."; return
}
Ok "Secreto guardado"
& npx.cmd wrangler deploy
'''
cola = cola.replace(viejo, nuevo)
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', '''try { Set-Clipboard -Value $codigoRev } catch { }
Write-Host ""
Ok "LISTO: la cuenta de demostracion para Apple esta activa."
Write-Host "      Correo:  revision@ojoguard.app" -ForegroundColor Cyan
Write-Host ("      Codigo:  " + $codigoRev + "   (ya esta copiado: pegalo en el formulario de Apple)") -ForegroundColor Cyan
Write-Host "      Anotalo en un lugar privado. No me lo mandes por aca." -ForegroundColor Yellow
''', cola)
assert 'bak-raiz' not in cola and 'secret put' in cola and 'revision@ojoguard.app' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-revision-apple-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
