# Genera scripts/aplicar-descarga-estetica-panel.ps1: la pagina ojoguard.app/descargar pasa al estilo actual (marfil con degradado azul, botones azules en pastilla, Plus Jakarta Sans, logo nuevo).
import re, runpy
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
v2 = runpy.run_path(R + 'panel/generar_descarga_kv_panel.py')
BLOQUE = v2['NEW']
a = BLOQUE.index('async function apkPagina(env: Env) {')
b = BLOQUE.index('async function apkDescarga(')
OLD = BLOQUE[a:b].rstrip('\n')

NEW = r'''const APK_ESTILO = `<style>:root{color-scheme:light;--fondo:#FAF8F3;--tarjeta:#fff;--linea:#E3E7F1;--texto:#14213D;--texto2:#3E4A6B;--suave:#5B6580;--azul:#1F4FD1;--azul-link:#1F4FD1;--azul-suave:#EEF2FB;--dorado:#E3A92B;--dorado-suave:#FFF3D6;--dorado-texto:#7A5200;--sombra:0 6px 24px rgba(20,33,61,.08)}html.noche{color-scheme:dark;--fondo:#0B1020;--tarjeta:#121A33;--linea:rgba(255,255,255,.12);--texto:#F5F0E6;--texto2:#D5DBEC;--suave:#A9B3CE;--azul:#3D6BEA;--azul-link:#9DBBFF;--azul-suave:rgba(255,255,255,.07);--dorado:#FFC247;--dorado-suave:rgba(255,194,71,.16);--dorado-texto:#FFD477;--sombra:0 6px 24px rgba(0,0,0,.35)}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:linear-gradient(180deg,#E3EBFF 0,var(--fondo) 340px) no-repeat,var(--fondo);color:var(--texto);font-family:"Plus Jakarta Sans",system-ui,-apple-system,Segoe UI,sans-serif;line-height:1.45;padding:22px 16px 60px}html.noche body{background:linear-gradient(180deg,#17285F 0,var(--fondo) 380px) no-repeat,var(--fondo)}main{max-width:560px;margin:0 auto}.marca{display:flex;align-items:center;gap:12px;font-weight:600;font-size:1.3rem;letter-spacing:-.01em;margin:6px 0 14px}.ojo{flex:none;display:block}.nom .o{position:relative;display:inline-block;line-height:1}.nom .o::after{content:"";position:absolute;left:50%;top:54%;width:.2em;height:.2em;border-radius:50%;background:var(--dorado);transform:translate(-50%,-50%)}.etiqueta{display:inline-block;font:700 .68rem/1 "Plus Jakarta Sans",system-ui,sans-serif;letter-spacing:.07em;color:var(--dorado-texto);background:var(--dorado-suave);border-radius:999px;padding:6px 10px;margin:0 0 14px}h1{font-size:2rem;line-height:1.2;letter-spacing:-.02em;font-weight:700;margin:.2rem 0 .6rem}h2{font-size:1.05rem;font-weight:700;margin:0 0 10px}p,li{color:var(--texto2);line-height:1.55}li{margin:6px 0}ol{margin:0;padding-left:1.3em}small,.suave{color:var(--suave)}.tarjeta{background:var(--tarjeta);border:1px solid var(--linea);border-radius:26px;padding:18px;margin:14px 0;box-shadow:var(--sombra)}.boton{display:block;text-align:center;background:var(--azul);color:#fff;border-radius:999px;padding:18px 22px;font:700 1.15rem "Plus Jakarta Sans",system-ui,sans-serif;text-decoration:none;box-shadow:0 12px 28px rgba(31,79,209,.3)}.boton:focus-visible{outline:3px solid var(--azul-link);outline-offset:3px}</style>`;
const APK_LOGO = `<span class="marca"><svg class="ojo" viewBox="0 0 120 72" width="44" height="26" aria-hidden="true" focusable="false"><defs><linearGradient id="ogOro" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F1D58A"/><stop offset=".5" stop-color="#D4A94D"/><stop offset="1" stop-color="#A67C32"/></linearGradient></defs><path d="M4 36C30 10 62 6 84 8C104 10 116 22 116 36C116 50 104 62 84 64C62 66 30 62 4 36Z" fill="#0F1A3A" stroke="#B48A3C" stroke-width="1"/><path d="M10 36C32 15 60 12 82 14C98 16 107 25 107 36C107 47 98 56 82 58C60 60 32 57 10 36Z" fill="none" stroke="url(#ogOro)" stroke-width="3.4" stroke-linejoin="round"/><path d="M30 36Q66 -6 101 36Q66 78 30 36Z" fill="none" stroke="url(#ogOro)" stroke-width="2.6" stroke-linejoin="round"/><circle cx="66" cy="36" r="17" fill="#1B2D5E" stroke="url(#ogOro)" stroke-width="2.2"/><circle cx="66" cy="36" r="8.6" fill="#05060B"/><circle cx="60.6" cy="30.2" r="2.8" fill="#EEF2FF" fill-opacity=".92"/></svg><span class="nom"><span class="o">O</span>jo Guard</span></span>`;
async function apkPagina(env: Env) {
  const info = await apkInfo(env);
  let cuerpo = `<h1>Ojo Guard para Android</h1><p>Todav\u00eda no hay una versi\u00f3n para bajar. Prob\u00e1 de nuevo en un rato.</p>`;
  if (info) {
    const cuando = new Date(info.subido).toLocaleString("es-AR", { timeZone: "America/Argentina/Buenos_Aires", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" });
    const mb = (info.bytes / 1048576).toFixed(1).replace(".", ",");
    const version = info.version ? " (" + apkEscapar(info.version) + ")" : "";
    const huella = info.sha256 ? `<small class="suave">Huella SHA-256: ${apkEscapar(info.sha256.slice(0, 16))}\u2026</small>` : "";
    cuerpo = `<h1>Ojo Guard para Android</h1><p>La \u00faltima versi\u00f3n${version}.</p><p class="suave">Subida el ${cuando} \u00b7 ${mb} MB</p>
<p><a class="boton" href="/descargar/ojo-guard.apk" download="ojo-guard.apk">Actualizar Ojo Guard</a></p>
<div class="tarjeta"><h2>C\u00f3mo se instala</h2><ol>
<li>Toc\u00e1 <b>Actualizar Ojo Guard</b> y esper\u00e1 a que termine la descarga.</li>
<li>Abr\u00ed el archivo desde la notificaci\u00f3n o desde la carpeta Descargas.</li>
<li>Si el celular pregunta por instalar apps de esta fuente, permitilo. Es solo la primera vez.</li>
<li>Toc\u00e1 Instalar. Si ya ten\u00e9s Ojo Guard, se instala encima.</li>
</ol><p class="suave">Si no se puede instalar, no borres la app: avisanos.</p></div>
<p class="suave">iPhone: esta descarga es solo para Android. En iPhone la app se actualiza desde la App Store o TestFlight.</p>${huella}`;
  }
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Descargar Ojo Guard</title><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap">${APK_ESTILO}<script>try{if(localStorage.getItem("ojo_ms_tema")==="oscuro")document.documentElement.classList.add("noche")}catch(e){}</script></head><body><main>${APK_LOGO}<span class="etiqueta">N\u00daCLEO \u00b7 EN VALIDACI\u00d3N</span>${cuerpo}</main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "referrer-policy": "no-referrer" } });
}'''

filas = [('src\\index.ts', 'pagina de descarga con el estilo actual', OLD, NEW)]
cambios = "$cambios = @(\n    ," + ',\n'.join("@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-descarga-estetica-panel.ps1 - Ojo Guard MS: la pagina https://ojoguard.app/descargar pasa al estilo actual (va DESPUES de aplicar-descarga-kv-panel.ps1).
# Luciano (27/10/2026): "lastima que lo hiciste con la estetica anterior". Ahora: fondo marfil con degradado azul (azul tinta en Modo noche), boton azul en pastilla,
# Plus Jakarta Sans, logo nuevo y la etiqueta "Nucleo - en validacion". Tambien se arregla la fecha, que salia con un punto doble ("a. m..").
# Cambia SOLO la funcion apkPagina en src\\index.ts (respaldo .bak-descargaestetica). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$indice = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $indice 'const APK_ESTILO') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indice 'descargas/${id}/${n}') -eq 0) { Mal "Falta aplicar primero aplicar-descarga-kv-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-descargaestetica')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: https://ojoguard.app/descargar ya se ve con el estilo actual."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-descarga-estetica-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
