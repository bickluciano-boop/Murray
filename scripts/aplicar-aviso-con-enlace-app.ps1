# aplicar-aviso-con-enlace-app.ps1 - App: al tocar el aviso "Estas bien?" (Modo Cautela) o un aviso del Modo Guardian, se abre su enlace.
# Luciano (20/10/2026): "pantalla Estoy bien al tocar el aviso (no depender del mail)".
#  - El servidor ya manda el enlace dentro del aviso (campo data: tipo y url). La app, al tocar el aviso (con la app abierta, en segundo plano o cerrada),
#    abre ese enlace en el navegador: la pagina "Estoy bien" o la del camino del Modo Guardian. Solo abre enlaces de https://ojo-guard-ms-api.bickluciano.workers.dev/
#    y solo de avisos de las ultimas 2 horas. No cambia nada mas de la app.
#  - Toca una sola cosa en App.tsx (el detector de toques en avisos). Respaldo .bak-avisoenlace. Es solo JavaScript: sale en la PROXIMA build, sin codigo nativo nuevo.
# Va en la carpeta de la APP (la que tiene app.json). El servidor lo trae el instalador del Modo Guardian (aplicar-guardian-camino-panel.ps1); sin eso la app no rompe: simplemente no hay enlace que abrir.
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

if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
$ruta = Join-Path $raiz "App.tsx"
if (-not (Test-Path $ruta)) { Mal "No encuentro App.tsx en esta carpeta."; return }
$f = Leer $ruta
if ((Contar $f.texto 'abrirEnlaceDelAviso') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $f.texto 'Linking.openURL') -lt 1) { Mal "No encuentro Linking.openURL en App.tsx. No toco nada. Mandame esta pantalla."; return }
$ancla = Ajustar '      opened = notifications.addNotificationResponseReceivedListener(() => {
        void syncRemoteCommands();
      });' $f.crlf
$nuevo = Ajustar '      // Avisos con enlace (el "Estas bien?" del Modo Cautela y los avisos del Modo Guardian): al tocarlos se abre ese enlace.
      const abrirEnlaceDelAviso = (respuesta: unknown) => {
        const r = respuesta as { notification?: { date?: number; request?: { identifier?: string; content?: { data?: Record<string, unknown> } } } } | null;
        const datos = r?.notification?.request?.content?.data;
        const url = typeof datos?.url === "string" ? datos.url : "";
        if (!url.startsWith("https://ojo-guard-ms-api.bickluciano.workers.dev/")) return;
        if (datos?.tipo !== "pld-estoy-bien" && datos?.tipo !== "guardian") return;
        const fecha = Number(r?.notification?.date);
        if (Number.isFinite(fecha) && Date.now() - fecha > 2 * 3_600_000) return;
        const id = String(r?.notification?.request?.identifier ?? "");
        const memoria = globalThis as { __ojoAvisoAbierto?: string };
        if (id && memoria.__ojoAvisoAbierto === id) return;
        memoria.__ojoAvisoAbierto = id;
        void Linking.openURL(url).catch(() => undefined);
      };
      opened = notifications.addNotificationResponseReceivedListener((respuesta) => {
        abrirEnlaceDelAviso(respuesta);
        void syncRemoteCommands();
      });
      // Si la app estaba cerrada cuando se toco el aviso, se mira cual fue.
      const ultima = (notifications as unknown as { getLastNotificationResponseAsync?: () => Promise<unknown> }).getLastNotificationResponseAsync?.();
      if (ultima) void ultima.then(abrirEnlaceDelAviso).catch(() => undefined);' $f.crlf
$n = Contar $f.texto $ancla
if ($n -eq 1) { Ok "el detector de toques en avisos de App.tsx: 1" } else { Mal ("el detector de toques en avisos de App.tsx: " + $n + " (esperaba 1). No toco nada. Mandame esta pantalla."); return }
if (Test-Path ($ruta + ".bak-avisoenlace")) { Mal "Ya existe App.tsx.bak-avisoenlace. No toco nada."; return }
Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-avisoenlace")
Ok "Respaldo creado: App.tsx.bak-avisoenlace"
$esperado = $f.texto.Length + ($nuevo.Length - $ancla.Length)
$nuevoTexto = $f.texto.Replace($ancla, $nuevo)
[System.IO.File]::WriteAllText($ruta, $nuevoTexto, (New-Object System.Text.UTF8Encoding($f.bom)))
$v = Leer $ruta
$bien = ($v.texto.Length -eq $esperado) -and ((Contar $v.texto 'abrirEnlaceDelAviso') -eq 3) -and ((Contar $v.texto 'addNotificationResponseReceivedListener') -eq 1)
if (-not $bien) {
    Mal "Algo no salio bien. Restauro App.tsx desde el respaldo."
    Copy-Item -LiteralPath ($ruta + ".bak-avisoenlace") -Destination $ruta -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("App.tsx: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
Write-Host ""
Ok "LISTO: al tocar el aviso Estas bien o uno del Modo Guardian, la app abre su enlace. Sale en la proxima build."
Write-Host ""
