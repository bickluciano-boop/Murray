import re, json
exec(open('../gen/generar.py').read().split("viejo=open")[0])   # psq
R='/home/user/Murray/scripts/'
base=open(R+'aplicar-mapa-audio-android-panel.ps1',encoding='utf-8-sig').read().replace('\r\n','\n')
codigo=open('pld_ascii.ts',encoding='ascii').read().rstrip('\n')
A1='async function fetchCorreo(input: string, init: RequestInit) {'
N1=codigo+'\n'+A1
A2='if (route === "GET /unirme") return familyJoinPage(url);'
N2='''if (route === "GET /por-las-dudas") return pldPaginaDuenio();
      if (url.pathname === "/api/remote/por-las-dudas") return pldApiDuenio(request, env);
      if (route === "GET /referente") return pldPaginaReferente();
      if (route === "POST /api/referente/estado") return pldApiReferenteEstado(request, env);
      if (route === "POST /api/referente/aceptar") return pldApiReferenteAceptar(request, env);
      if (route === "POST /api/referente/buscar") return pldApiReferenteBuscar(request, env);
      if (route === "GET /estoy-bien") return pldPaginaEstoyBien();
      if (route === "POST /api/estoy-bien") return pldApiEstoyBien(request, env);
      '''+A2
sql=' '.join(l.strip() for l in open('tablas.sql',encoding='ascii').read().strip().split('\n'))
assert "'" not in sql
cabeza='''# aplicar-por-las-dudas-panel.ps1 - "Por las dudas": referentes de emergencia, primera parte (servidor). Estado: NUCLEO - EN VALIDACION.
# Idea de Luciano (17/10/2026) a partir de un caso real: un chico de 16 anos desaparecio y la familia no tenia como saber donde estuvo por ultima vez.
# La persona elige de antemano a sus REFERENTES. En el dia a dia nadie ve nada. Si algo parece raro, un referente preocupado aprieta "No lo encuentro"
# (en una pagina web con su enlace personal, sin app): se le manda a la persona un "Estas bien?" (mail y aviso en el telefono) y, solo si se cumplen
# las condiciones que ella permitio (sin senal hace rato, lejos de casa, bateria baja, de noche; o apagado en movimiento con bateria alta; o emergencia
# tras unas horas), se le muestra la ULTIMA SENAL del telefono. Cada consulta le llega a la persona y queda en su registro.
# Que agrega (todo nuevo, no cambia nada de lo que ya anda):
#  - Paginas: /por-las-dudas (la persona elige referentes y condiciones), /referente (el enlace del referente) y /estoy-bien.
#  - Cuatro tablas nuevas: pld_config, pld_referentes, pld_log, pld_checkins. Se enganchan solo las rutas nuevas y el codigo va junto a fetchCorreo.
#  - Todavia NO hay avisos automaticos del cron (eso es la segunda parte): por ahora el referente tiene que apretar el boton.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\\index.ts (respaldo .bak-pld), crea las tablas en la base y publica solo.
'''
i=base.index('$ErrorActionPreference'); j=base.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini=base[i:j]
cuerpo='''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
$indice = Join-Path $raiz "src\\index.ts"
if (-not (Test-Path $indice)) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$f = Leer $indice
$yaAplicado = ((Contar $f.texto 'async function pldApiDuenio') -ne 0)
$anclas = @(
    @('codigo de Por las dudas junto a fetchCorreo', %s, %s),
    @('rutas de Por las dudas', %s, %s)
)
if ($yaAplicado) {
    Avi "El codigo de Por las dudas ya estaba en src\\index.ts. Solo reviso las tablas y publico de nuevo."
} else {
    $ok = $true
    foreach ($c in $anclas) {
        $cuantos = Contar $f.texto (Ajustar $c[1] $f.crlf)
        if ($cuantos -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
    }
    if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
    if (Test-Path ($indice + ".bak-pld")) { Mal "Ya existe src\\index.ts.bak-pld. No toco nada."; return }
    Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-pld")
    Ok "Respaldo creado: src\\index.ts.bak-pld"
    $nuevo = $f.texto
    $esperado = $f.texto.Length
    foreach ($c in $anclas) {
        $a = Ajustar $c[1] $f.crlf; $r = Ajustar $c[2] $f.crlf
        $nuevo = $nuevo.Replace($a, $r)
        $esperado = $esperado + ($r.Length - $a.Length)
    }
    [System.IO.File]::WriteAllText($indice, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
    $v = Leer $indice
    $bien = ($v.texto.Length -eq $esperado) -and ((Contar $v.texto 'async function pldApiDuenio') -eq 1) -and ((Contar $v.texto 'GET /por-las-dudas') -eq 1) -and ((Contar $v.texto 'async function fetchCorreo') -eq 1)
    if (-not $bien) {
        Mal "Algo no salio bien. Restauro src\\index.ts desde el respaldo."
        Copy-Item -LiteralPath ($indice + ".bak-pld") -Destination $indice -Force
        Mal "Restaurado. Mandame esta pantalla."
        return
    }
    Ok ("src\\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
}
Write-Host ""
Ok "Creo las cuatro tablas de Por las dudas en la base y publico el panel..."
$sqlPld = '%s'
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command $sqlPld
if ($LASTEXITCODE -ne 0) { Mal "No se pudieron crear las tablas, asi que no publique nada. Mandame esta pantalla."; return }
Ok "Tablas listas"
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: Por las dudas esta publicado."
Ok "Tu pagina: https://ojo-guard-ms-api.bickluciano.workers.dev/por-las-dudas (abrila en el navegador donde ya entraste al panel)."
Write-Host ""
''' % (psq(A1),psq(N1),psq(A2),psq(N2),sql)
total=cabeza+motor_ini+cuerpo
bad=[c for c in total if ord(c)>127]
assert not bad, set(bad)
open(R+'aplicar-por-las-dudas-panel.ps1','wb').write(b'\xef\xbb\xbf'+total.replace('\n','\r\n').encode('ascii'))
json.dump({'A1':A1,'N1':N1,'A2':A2,'N2':N2,'sql':sql},open('anclas_pld.json','w'))
print('ok',len(total))
