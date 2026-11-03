# Rutina de cada build de Android (LEER PRIMERO; no preguntar, hacerlo)

Se hizo en las últimas ~10 builds (175, 176, 185, 186, 187…). Si el contexto se reinicia, esto manda.

**Cuando Luciano pegue la salida de `eas build` (termina con "Build finished" y el enlace de la build), o diga "terminó la build" / "ya lo subí a descargas":** el APK ya está en `C:\Users\ng\Downloads` como `application-<id de la build>.apk`. El paso que sigue es SIEMPRE el comando de subida de abajo. No pedirle que revise nada en el teléfono antes: la comprobación en el teléfono es DESPUÉS de subir.

## 1. Armar la build (carpeta de la APP, en PowerShell)

`eas.cmd build --platform android --profile preview`

Carpeta de la APP (tiene `app.json`): `C:\Users\ng\Downloads\CARPETA PRINCIPAL OJO GUARD ANDROID\OJOGUARDANDROIDV30 (1)310826\OJO-GUARD-ANDROID-V30`.
En la salida sale "Incremented versionCode from X to **Y**": Y es el número de build de Android. Luciano baja el APK del enlace de la build a Descargas.
No correr instaladores que toquen la carpeta de la app mientras la build está comprimiendo o subiendo.

## 2. Subir el APK al panel (el comando que le paso, cambiando solo Y)

Va en cualquier PowerShell (entra solo a la carpeta del PANEL, la que tiene `wrangler.toml`: `C:\Users\ng\Downloads\CARPETA PRINCIPAL OJO GUARD MS\OJOGUARDMSV30completo2608\OJO-GUARD-MS-V30`).

```powershell
cd "C:\Users\ng\Downloads\CARPETA PRINCIPAL OJO GUARD MS\OJOGUARDMSV30completo2608\OJO-GUARD-MS-V30"; Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/bickluciano-boop/Murray/b31aca23437d7cde146e592f6695e4785d84e334/scripts/subir-apk-panel.ps1' -OutFile .\subir-apk-panel.ps1; if ((Get-FileHash .\subir-apk-panel.ps1 -Algorithm SHA256).Hash.ToLower() -ne '8ffbe4883a407e6319aedb8aa01ddebecc650e1f42c8bf9164e92290579428b8') { Write-Host 'El archivo no coincide, no lo ejecuto.' -ForegroundColor Red } else { $apk = Get-ChildItem (Join-Path $env:USERPROFILE 'Downloads') -Filter *.apk -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if (-not $apk) { Write-Host 'No encuentro ningun .apk en la carpeta Descargas.' -ForegroundColor Red } elseif ($apk.LastWriteTime -lt (Get-Date).AddDays(-1)) { Write-Host ('El APK mas nuevo de Descargas es de hace mas de un dia (' + $apk.Name + '). No subo nada.') -ForegroundColor Red } else { Write-Host ('Subo: ' + $apk.Name + ' (' + [math]::Round($apk.Length / 1MB, 1) + ' MB, ' + $apk.LastWriteTime + ')'); .\subir-apk-panel.ps1 -Apk $apk.FullName -Version '0.9.1 (Y)' } }
```

- `-Version '0.9.1 (Y)'` va SIEMPRE fijo y con el número de build entre paréntesis: la app compara con ese número. Nunca usar `Read-Host` (con la 176 el Enter del pegado lo contestó en blanco y se subió la versión vieja).
- Toma el `.apk` más nuevo de Descargas; si no hay o es de hace más de un día, no sube nada.
- Tarda unos minutos (~146 MB en partes de 16 MB). Al final verifica por huella que lo que baja la gente de la página es exactamente ese APK, borra las partes de la versión anterior (la página guarda solo la última) y dice "LISTO: el link para pasarle a tu familia es https://ojoguard.app/descargar".
- Requiere haber aplicado antes `aplicar-descarga-panel.ps1` y `aplicar-descarga-kv-panel.ps1` (ya hecho).

## 3. Actualizar cada teléfono Android (lo hace cada persona)

Ojo Guard → Configuración → **Actualizar Ojo Guard** → "Buscar actualización" → "Descargar la nueva versión" → instalar encima. Debe decir "Hay una versión nueva: 0.9.1 (Y)"; después de instalar, "Tu versión … build Y". Si Android dice que no se puede instalar: no borrar la app, avisar. Para la familia: el enlace único es https://ojoguard.app/bajar (Android → /descargar; iPhone → TestFlight).

## iPhone (otra rutina, no usa el panel)

`eas.cmd build --platform ios --profile production --auto-submit` en la carpeta de la APP → TestFlight.

## Reglas

- Una sola cosa por mensaje, en PowerShell (no cmd), sin pedir claves ni códigos por el chat.
- Cuando Luciano dice que algo "ya está hecho", creerle y pasar al paso siguiente de la rutina; si hay duda, el paso siguiente (la subida) es inofensivo: el comando no sube nada si no hay un APK reciente.
