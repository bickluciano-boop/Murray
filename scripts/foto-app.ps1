# foto-app.ps1 - "Foto" de la app antes de reordenar la pantalla. Hace dos cosas y no cambia nada de la app:
#  1) Guarda una copia comprimida de la carpeta de la app (sin node_modules ni carpetas de compilacion) en la carpeta de arriba, con la
#     fecha y la hora en el nombre. Es la marcha atras si algo sale mal.
#  2) Compara el codigo de la app con el que yo tengo descripto en FOTO-APP-NATIVA-14-10-2026.md y avisa si algun archivo es distinto.
# Va en la carpeta de la APP (la que tiene app.json).
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"

# --- 1) Copia comprimida ---
$fecha = Get-Date -Format "yyyy-MM-dd_HHmm"
$zip = Join-Path (Split-Path $raiz -Parent) ("FOTO-OJO-GUARD-APP-" + $fecha + ".zip")
$tmp = Join-Path $env:TEMP ("ojo-foto-" + $fecha)
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
& robocopy $raiz $tmp /E /XD node_modules .git .expo .gradle dist (Join-Path $raiz "android") (Join-Path $raiz "ios") /XF *.zip /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Mal "No pude copiar los archivos para la foto. Mandame esta pantalla."; return }
try { Compress-Archive -Path (Join-Path $tmp "*") -DestinationPath $zip -Force -ErrorAction Stop } catch { Mal ("No pude armar el .zip: " + $_.Exception.Message); return }
Remove-Item -Recurse -Force $tmp
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Ok ("Copia guardada (" + $mb + " MB): " + $zip)

# --- 2) Comparar el codigo con el que tengo descripto ---
$esperado = [ordered]@{
    'App.tsx' = '1d30602bb592ff0579ef8c8735a01669d97207fbca78e8ebf7fc6d8c6343446c'
    'modules\audio-route\android\src\main\java\expo\modules\audioroute\AudioRouteModule.kt' = '712a7c67805866f1a1f73f7d8b4e94d01672521f3934a4505d0f611226dea4b4'
    'modules\exact-alarm\android\src\main\java\expo\modules\exactalarm\ExactAlarmBootReceiver.kt' = '8f2587af4bb5b2567bf4594949c173df622292759715c78dbce2fbd03a2dce29'
    'modules\exact-alarm\android\src\main\java\expo\modules\exactalarm\ExactAlarmModule.kt' = 'a3882699066ee1918390f29587b7c3e428a76aeab43edb90de9c875c9280208f'
    'modules\exact-alarm\android\src\main\java\expo\modules\exactalarm\ExactAlarmReceiver.kt' = 'cffd7011557200cc019e15bd7626a5c073647c19b63373eea708da85298a2d9a'
    'modules\exact-alarm\android\src\main\java\expo\modules\exactalarm\ExactAlarmScheduler.kt' = '9c1214bedffabd1f02c1dfe513e6133ad0bf9c48804805ecaa5908b7dcbc913b'
    'modules\exact-alarm\android\src\main\java\expo\modules\exactalarm\ExactAlarmTaskService.kt' = 'ca141147508ed822a8122072bf8493cd2f98ed3ed54199beb88efa164efbeafe'
    'modules\exact-alarm\index.ts' = 'd3c7d0ce4dcfa427af6a88c2f2b2eae9cccfe6b6b5f1a74f4a6aa29c873f679a'
    'modules\face-filter\android\src\main\java\expo\modules\facefilter\FaceFilterModule.kt' = '93825c9d5217cfe675825575c25f6ee1a1dfc695a6b281f1d38b59daa4e9c5ea'
    'modules\face-filter\index.ts' = 'b29a62cee5690b7d2aa9f621f0032a3da80885aa228e4d44118a7dbea24f3e82'
    'modules\full-screen-alert\android\src\main\java\expo\modules\fullscreenalert\FullScreenAlertModule.kt' = '61597aef16748461483f134c694d59f5b95581da4ee76c2202d581c60a84b3e5'
    'modules\full-screen-alert\android\src\main\java\expo\modules\fullscreenalert\LostModeAlertActivity.kt' = '88cc5b150cd2a08c913a1257ecef71b19ee2071c0601b9a64618bf1fdf77c11e'
    'modules\full-screen-alert\index.ts' = '447a00c5bce2680e605bcdb700c8c9543bed1cf05c3042f3720f23727fd27aba'
    'modules\native-capture\android\src\main\java\expo\modules\nativecapture\CaptureBridgeActivity.kt' = '4215ac18013d6dff97375f7dc5c1b77209ba6341158dc9f81364b37c62c7c329'
    'modules\native-capture\android\src\main\java\expo\modules\nativecapture\NativeCaptureModule.kt' = '5cc2b2a673f2e5dc6b12dab5fcab1d93eb38f1d25f87bc247420f32cace7cb47'
    'modules\native-capture\android\src\main\java\expo\modules\nativecapture\SilentCaptureService.kt' = 'a34ba3135b4db367e9f08f7db61318fd8862e7d286e51e63833fa5a9f7ae7a55'
    'modules\native-capture\index.ts' = '25da4b094913614d277257488d42570e34785224313956f2a89e0d28e30b36c7'
    'modules\screen-pinning\android\src\main\java\expo\modules\screenpinning\ScreenPinningModule.kt' = '993f6955eb96781827e5c81c8aea21aef2ce71c6e989856294f788fcbe82fab0'
    'modules\screen-pinning\index.ts' = '057af1a8f6ce632e430fa04a16a6f3643b42710cd61b8829125d793c54b5667b'
    'modules\sos-trigger\android\src\main\java\expo\modules\sostrigger\SosAccessibilityService.kt' = '3a5c9ee2a49048693a9d715e37f2ad229150a48b667823172a139d817b3ed19b'
    'modules\sos-trigger\android\src\main\java\expo\modules\sostrigger\SosTaskService.kt' = '38bd167022003fcc5a59d6aa2b2cac3db9fbf3bb1b3b7ae3e4bf6971fd53c3d5'
    'modules\sos-trigger\android\src\main\java\expo\modules\sostrigger\SosTrigger.kt' = '3fb7f95d7242317777499fb4cca1999c7d4fd85c0d9ab83fdcb549ddeace3a8f'
    'modules\sos-trigger\android\src\main\java\expo\modules\sostrigger\SosTriggerModule.kt' = 'dfab1d46d4ca06dcf81b2512baa2231423b33a69ec1f24644ab7bdb6b0f9ef20'
    'modules\sos-trigger\index.ts' = '24750f0e4c950dcfa13857364c0a78b58c73d7a3e1667d05bf0e1e9d54e5ef9f'
    'modules\theft-detection\android\src\main\java\expo\modules\theftdetection\PinFailTracker.kt' = '77af579f28fc8bed9ff4a87b69f9ef5d1244043f7bc22700a43228d584abdcfc'
    'modules\theft-detection\android\src\main\java\expo\modules\theftdetection\ScreenEventsReader.kt' = 'c09848bb9fb62872e44f947b9b82eec54ffcf4dc6511252cd95c5c24cbfdad53'
    'modules\theft-detection\android\src\main\java\expo\modules\theftdetection\TheftDetectionModule.kt' = 'c46141372d29a661f1387f23d8f09e933cb4e944c5f9909425cf8929f0bd6f20'
    'modules\theft-detection\android\src\main\java\expo\modules\theftdetection\TheftDetectionTaskService.kt' = 'c6011db8ed87e82578eaf7546ed59f69f0fd8c75352aa4c6ecfdc97c57bbaf77'
    'modules\theft-detection\android\src\main\java\expo\modules\theftdetection\TheftDetectionTrigger.kt' = '718ced1e60c6018a3aedff4a45af50fc0babb2af7e78b06b3cc35ec080e0f3fc'
    'modules\theft-detection\android\src\main\java\expo\modules\theftdetection\TheftDeviceAdminReceiver.kt' = 'a8ac17b66d0faac76346b87d0d82170b0bef73906edbb3b49de12a40b92c7319'
    'modules\theft-detection\android\src\main\java\expo\modules\theftdetection\UsageAccess.kt' = 'ad31fa8c650d6e352eda52f9b1290b2516cd5daaadcf42c59031c602d806c2c3'
    'modules\theft-detection\index.ts' = 'fc38ed037f013cdb03462b8ad3cb5996e0c6445ebf1318c42fc785ffb7d8d9c1'
    'src\FamilySection.tsx' = '56fb99fda71788e2274913db045612e63e661798776248cd16425023d9dee082'
    'src\Plegable.tsx' = '5c61329eaabc09991704a22c30b4997c5e7d059d2aebdd18a43f60b99ce2910f'
    'src\ProteccionBlock.tsx' = 'b075926584a98b8e83dc4323389940cf5a1a60f50d510a9976f45542703af9d2'
    'src\SosBlock.tsx' = '16bf39ba21ea9e116f61007100e16cd9f393e23cbd7c908a698ad2675fe1c775'
    'src\api.ts' = 'b071febf21e902e682135425b1a720125817f0905db85496c088597fce3a00ea'
    'src\attemptCounter.ts' = 'fa2bafe9d585ef35b0c24d2728e5dc52bdeb9cf434189cad91a2b11338f302ca'
    'src\audioRoute.ts' = '6e1d501cf926e56000c1f34c1d32cce941838edfc3441b152fee230bd708e1c3'
    'src\backgroundFetchTask.ts' = '07b290f4bb075a0e9c60e306e221ddc4f49f65adfe07eeba1d6e0e927c5c4bb4'
    'src\backgroundRemoteTask.ts' = '5a23e38844f5bd0f13d193ea3aa0d65252f0d678cc11a66fee3fe97373b3460b'
    'src\bluetoothProximity.ts' = '10cc7949e83dbd1181ddd01f81929670b91d0c545d93a6df0785992d26b9df22'
    'src\domain.ts' = '5e4fb6c036523029ac41004b8e3dd672641832601fee7c4e39d5707550f38576'
    'src\earbudTone.ts' = '377ed356cea48a0eb0d26579b9027efa5bebeaa36cca08c9826ceeb331549149'
    'src\evidenceHistory.ts' = '1e0b7f43a88864d889a2ba4f965ca980bf94fb4c5b3f5ea90028672aaacd59b6'
    'src\faceSearch.ts' = '1832e42af3076b7926e0434702d6c81531818db012600e0b733aec4ea9a83512'
    'src\familyGeofence.ts' = '2bd05b4adca3b3c67c1eae66093a8fd96b1283f0c2fea94d048f28d4a2bffc2c'
    'src\familyLocation.ts' = '1db7c220e9c6650b4772109c720e49b0de9d9a3954455c06728d36fe2ac8a5e7'
    'src\floorEstimate.ts' = '7a974eac9945f72e9bd32bc6f2e32b2b55e6364b2526101e1f787459b400e9c7'
    'src\fullScreenAlertDiagnostics.ts' = 'a82ba900601144777a1e2731d3d649be195f46b83d0ee26ec10d4f12b963bee4'
    'src\galleryFilters.ts' = '997e9e7ff4b05ed535c0a3cd76a7d9e9c8989986a488ab90fa3ff141a89f55e0'
    'src\lastServerContact.ts' = '090aa5f0d3fd9968fe8c4956c4b0972d49f679c2a621a026dcbd04ab3c5de064'
    'src\liveLocation.ts' = '7bca09a250084d593fb99cb8a907e8c0648c025f6cc85322f4172edae863c1a9'
    'src\locationSampling.ts' = '38d082b0029dc4da2b58fedfccc33a49ef37fa7736f8c5dbf52aecb485a36aa2'
    'src\lostModeState.ts' = 'a284c8bd21da78f738ab46f15144da97fee2f8b85d6743908a23fdd208b20e42'
    'src\offlineQueue.ts' = 'a2e3b623457cc254ee9e293a536200a4d3075020457178e91c5cba50cd2f789e'
    'src\pendingSelfTriggeredCapture.ts' = '7553471f45fb3c1ad6cebd1ee504c26065690c7d4b4cab62c32116eff11f8349'
    'src\pendingSystemActivity.ts' = '5151c77b0f1ea5aa29cd2f41c667868a2f43d993e055ee7ada105daebee66e67'
    'src\proteccion.ts' = 'e9fd877e0b7f8c568b98431f11dee5a4ab31c95fc0048366f39c50eccb9eb31c'
    'src\rejectedFaceMatches.ts' = 'eab70968162d4fa3a2b84feb53041524921c2c126ee3f69e79dbc4a3ad7a8b3c'
    'src\reliabilityChecklist.ts' = 'c456c808f13758addad7c23c55a1d7168f907a2db48ddea7cdc3b15631f3e3fe'
    'src\remoteApi.ts' = '9a7e7d35873ba305c6ce3cf02a72931c728e52e947cbaa602c14c0977d28484b'
    'src\remoteStorage.ts' = '7bdb912c459878725c0249f150621ed87f7ecf6ed2cf34a8e5d85b3be8f9799e'
    'src\remoteSync.ts' = 'a25eaa687082f25ab70d8904ca9e356ce13d9a4ce98162efaae79661fb3ec8cd'
    'src\sos.ts' = 'cd7533142e047fe8f95ec3bf357a5d67ae56098dc8a500a6caed32e93983e82c'
    'src\sosMapa.ts' = 'bfee75b99ebb5a2c62a6845ded6b777f11897dbff05aebbf6fc8c2bce737969d'
    'src\sosTask.ts' = 'cd4c622ca494d6bc9e46e847e881d39e5c6991671995e511ca5b14a49ec1db17'
    'src\storage.ts' = '84c2517c6c4ea7c58e743e6629177f9a9acbd48d8723e0f3ec4f179c2df92328'
    'src\trackedItems.ts' = '2d665c10214cc4800e0608628195eb1a48102a37eb77f779f3eb874a67603a7b'
}
function HashTexto([string]$ruta) {
    $t = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    $t = $t -replace "`r`n", "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($t)))).Replace("-", "").ToLower()
}
$faltan = @(); $distintos = @(); $iguales = 0
foreach ($k in $esperado.Keys) {
    $ruta = Join-Path $raiz $k
    if (-not (Test-Path $ruta)) { $faltan += $k; continue }
    if ((HashTexto $ruta) -eq $esperado[$k]) { $iguales = $iguales + 1 } else { $distintos += $k }
}
Write-Host ""
if ($faltan.Count -eq 0 -and $distintos.Count -eq 0) {
    Ok ("El codigo de la app coincide con lo que tengo descripto (" + $iguales + " archivos).")
} else {
    Avi ($iguales.ToString() + " archivos coinciden.")
    if ($distintos.Count -gt 0) { Avi ("Distintos (" + $distintos.Count + "):"); $distintos | Select-Object -First 20 | ForEach-Object { Write-Host ("   " + $_) } }
    if ($faltan.Count -gt 0) { Avi ("Faltan (" + $faltan.Count + "):"); $faltan | Select-Object -First 20 | ForEach-Object { Write-Host ("   " + $_) } }
    Write-Host "Mandame esta pantalla: miro que cambio y ajusto la descripcion antes de tocar nada."
}
Write-Host ""
Ok "LISTO. No se cambio nada de la app. La copia comprimida queda guardada."
Write-Host ""
