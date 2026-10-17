# aplicar-por-las-dudas-enlace-panel.ps1 - Por las dudas: si el mail al referente no llega, la pagina te da su enlace personal para mandarselo vos.
# Luciano (17/10/2026), primera prueba: eligio un referente y "No me llego" el mail. Hasta ahora la pagina decia "Listo" aunque el mail fallara.
# Ahora, al elegir un referente (o apretar "Reenviar"):
#  - Si el mail salio, dice "Le mandamos el mail... Si no le llega (que mire Spam), mandale este enlace vos".
#  - Si el mail fallo, lo dice: "No pudimos mandar el mail... Mandale este enlace vos".
#  - En los dos casos muestra el enlace personal de ese referente con los botones "Copiar enlace" y "Mandar por WhatsApp".
# El enlace solo se le muestra a la persona que entro al panel (la duena de su cuenta). Ocho cambios de texto dentro de src\index.ts, solo en el
# codigo de Por las dudas (nada de lo que ya anda). Requiere aplicar-por-las-dudas-panel.ps1.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo .bak-pldenl. Al final publica el panel solo.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
function Contar([string]$donde, [string]$que) {
    if ([string]::IsNullOrEmpty($que)) { return 0 }
    $n = 0; $i = 0
    while ($true) { $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal); if ($i -lt 0) { break }; $n = $n + 1; $i = $i + $que.Length }
    return $n
}
function Leer([string]$ruta) {
    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $texto = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    return @{ texto = $texto; bom = $bom; crlf = $texto.Contains("`r`n") }
}
function Ajustar([string]$t, [bool]$crlf) { $x = ($t -replace "`r`n", "`n"); if ($crlf) { $x = $x -replace "`n", "`r`n" }; return $x }
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }

if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
$indice = Join-Path $raiz "src\index.ts"
if (-not (Test-Path $indice)) { Mal "No encuentro src\index.ts en esta carpeta."; return }
$f = Leer $indice
if ((Contar $f.texto 'id="invitacion"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $f.texto 'async function pldApiDuenio') -ne 1) { Mal "Falta aplicar antes aplicar-por-las-dudas-panel.ps1."; return }
$cambios = @(
    @('pldInvitar devuelve si salio el mail y el enlace (parte 1)', '  const enlace = `${origen}/referente?t=${referente.id}.${secreto}`;
  await pldCorreo(
    env, referente.email, `${quien} te eligi\u00f3 como referente en Ojo Guard`,', '  const enlace = `${origen}/referente?t=${referente.id}.${secreto}`;
  const enviado = await pldCorreo(
    env, referente.email, `${quien} te eligi\u00f3 como referente en Ojo Guard`,'),
    @('pldInvitar devuelve si salio el mail y el enlace (parte 2)', 'es el que vas a usar si alguna vez necesit\u00e1s el bot\u00f3n <strong>No lo encuentro</strong>.</p>`,
  );
}', 'es el que vas a usar si alguna vez necesit\u00e1s el bot\u00f3n <strong>No lo encuentro</strong>.</p>`,
  );
  return { enviado, enlace };
}'),
    @('la API del duenio guarda la invitacion (preparacion)', '  const origen = new URL(request.url).origin;

  if (accion === "config") {', '  const origen = new URL(request.url).origin;
  let extra: Record<string, unknown> = {};

  if (accion === "config") {'),
    @('al agregar, devuelve la invitacion', '    await pldInvitar(env, origen, email, cfg, { id, name: nombre, email: correo }, secreto);', '    const inv = await pldInvitar(env, origen, email, cfg, { id, name: nombre, email: correo }, secreto);
    extra = { invitacion: { nombre, enlace: inv.enlace, enviado: inv.enviado } };'),
    @('al reenviar, devuelve la invitacion', '    await pldInvitar(env, origen, email, cfg, r, secreto);', '    const inv = await pldInvitar(env, origen, email, cfg, r, secreto);
    extra = { invitacion: { nombre: r.name, enlace: inv.enlace, enviado: inv.enviado } };'),
    @('la API del duenio responde con la invitacion', '    return json({ error: "accion_desconocida" }, 400);
  }
  return json(await pldPanorama(env, email));', '    return json({ error: "accion_desconocida" }, 400);
  }
  return json({ ...(await pldPanorama(env, email)), ...extra });'),
    @('la pagina tiene el lugar del enlace', '<p><button id="rAgregar">Elegir referente</button></p>', '<p><button id="rAgregar">Elegir referente</button></p><div id="invitacion"></div>'),
    @('la pagina muestra el enlace con Copiar y WhatsApp', 'function accion(cuerpo,ok){aviso("");return api(cuerpo).then(function(d){pintar(d);if(ok)aviso(ok)}).catch(function(e){aviso(e.message)})}', 'function mostrarInvitacion(i){
  var c=$("invitacion");limpiar(c);if(!i)return;
  var caja=document.createElement("div");caja.className="tarjeta";
  var tx=document.createElement("p");tx.className=i.enviado?"":"mal";
  tx.textContent=i.enviado?("Le mandamos el mail a "+i.nombre+". Si no le llega (que mire Spam), mandale este enlace vos:"):("No pudimos mandar el mail a "+i.nombre+". Mandale este enlace vos:");
  caja.appendChild(tx);
  var inp=document.createElement("input");inp.readOnly=true;inp.value=i.enlace;inp.onclick=function(){inp.select()};caja.appendChild(inp);
  var b1=document.createElement("button");b1.className="sec chico";b1.textContent="Copiar enlace";b1.style.margin="10px 8px 0 0";
  b1.onclick=function(){inp.select();try{navigator.clipboard.writeText(i.enlace).then(function(){b1.textContent="Copiado"},function(){document.execCommand("copy");b1.textContent="Copiado"})}catch(e){document.execCommand("copy");b1.textContent="Copiado"}};
  caja.appendChild(b1);
  var b2=document.createElement("button");b2.className="sec chico";b2.textContent="Mandar por WhatsApp";b2.style.marginTop="10px";
  b2.onclick=function(){window.open("https://wa.me/?text="+encodeURIComponent("Te eleg\u00ed como mi referente en Ojo Guard, por las dudas. Entr\u00e1 a este enlace para aceptar y guardalo: "+i.enlace),"_blank")};
  caja.appendChild(b2);c.appendChild(caja);
}
function accion(cuerpo,ok){aviso("");return api(cuerpo).then(function(d){pintar(d);mostrarInvitacion(d.invitacion);if(d.invitacion&&!d.invitacion.enviado)aviso("No pudimos mandar el mail. Us\u00e1 el enlace de abajo.");else if(ok)aviso(ok)}).catch(function(e){aviso(e.message)})}')
)
$ok = $true
foreach ($c in $cambios) {
    $cuantos = Contar $f.texto (Ajustar $c[1] $f.crlf)
    if ($cuantos -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
if (Test-Path ($indice + ".bak-pldenl")) { Mal "Ya existe src\index.ts.bak-pldenl. No toco nada."; return }
Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-pldenl")
Ok "Respaldo creado: src\index.ts.bak-pldenl"
$nuevo = $f.texto
$esperado = $f.texto.Length
foreach ($c in $cambios) {
    $a = Ajustar $c[1] $f.crlf; $r = Ajustar $c[2] $f.crlf
    $nuevo = $nuevo.Replace($a, $r)
    $esperado = $esperado + ($r.Length - $a.Length)
}
[System.IO.File]::WriteAllText($indice, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
$v = Leer $indice
if (($v.texto.Length -ne $esperado) -or ((Contar $v.texto 'id="invitacion"') -ne 1)) {
    Mal "Algo no salio bien. Restauro src\index.ts desde el respaldo."
    Copy-Item -LiteralPath ($indice + ".bak-pldenl") -Destination $indice -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("src\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
Write-Host ""
Ok "Archivo listo. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: al elegir un referente, la pagina te muestra su enlace personal (Copiar / WhatsApp) y te dice si el mail salio o fallo."
Write-Host ""
