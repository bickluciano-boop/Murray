# Genera scripts/aplicar-entrada-clara-panel.ps1: la pantalla de entrada de ojoguard.app se entiende a primera vista.
#  - Un solo campo de correo arriba (se copia a las demas formas de entrar), en vez de repetirlo tres veces.
#  - Titulos claros: "Con un codigo por correo" y "Con mi app de verificacion (Google Authenticator u otra)".
#  - Los dos "Codigo de 6 numeros" pasan a decir de donde viene cada uno.
# Solo cambia src\panel-index.html. Si el script no corre, la pagina queda como antes (el correo unico solo aparece cuando anda).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
arch = 'src\\panel-index.html'
h1a = '        <p class="hero-copy">Ingresá con un código enviado a tu correo. Funciona en iPhone, Android y computadora sin escanear ningún QR.</p>\n'
h1b = h1a + '''        <div id="correo-unico-caja" style="display:none">
          <label>Tu correo<input id="correo-unico" type="email" autocomplete="username webauthn" placeholder="tu@correo.com" /></label>
          <small>Escribilo una sola vez y elegí cómo querés entrar.</small>
        </div>
'''
h2a = '        <form id="email-form">\n'
h2b = '        <p class="acceso-via">Con un código por correo</p>\n' + h2a
h3a = '          <button>Enviar código de 6 números</button>\n'
h3b = '          <button>Enviar código por correo</button>\n'
h4a = '<label>Código de 6 números<input id="code"'
h4b = '<label>Código que te llegó por correo<input id="code"'
h5a = '<summary>Tengo un código de verificación configurado</summary>'
h5b = '<summary>Con mi app de verificación (Google Authenticator u otra)</summary>'
h6a = '<label>Código de 6 números<input id="totp-code"'
h6b = '<label>Código de tu app de verificación<input id="totp-code"'
h7a = '        <p id="access-message" class="message"></p>\n'
h7b = h7a + '''        <style>
          #access .acceso-via{margin:18px 0 6px;font-weight:800;font-size:1.02rem}
          #correo-unico-caja{margin:14px 0 4px}
          #correo-unico-caja small{display:block;margin-top:6px;opacity:.75}
          #access.og-correo-unico #passkey-form>label,#access.og-correo-unico #email-form>label,#access.og-correo-unico #totp-login-form>label:first-child,#access.og-correo-unico #qa-login-form>label:first-child{display:none}
        </style>
        <script>
          (function () {
            var caja = document.getElementById("correo-unico-caja");
            var unico = document.getElementById("correo-unico");
            var ids = ["passkey-email", "email", "totp-email", "qa-email"];
            var campos = ids.map(function (id) { return document.getElementById(id); }).filter(Boolean);
            if (!caja || !unico || campos.length !== ids.length) return;
            function copiar() { campos.forEach(function (c) { c.value = unico.value; }); }
            unico.addEventListener("input", copiar);
            unico.addEventListener("change", copiar);
            // Antes de enviar cualquier forma, el correo de arriba pasa al campo de esa forma (si el de arriba esta vacio, toma el que ya tenia la forma).
            campos.forEach(function (c) {
              if (c.form) c.form.addEventListener("submit", function () { if (unico.value) c.value = unico.value; else unico.value = c.value; }, true);
            });
            var previo = "";
            campos.forEach(function (c) { if (!previo && c.value) previo = c.value; });
            if (previo) { unico.value = previo; copiar(); }
            caja.style.display = "block";
            var acceso = document.getElementById("access");
            if (acceso) acceso.classList.add("og-correo-unico");
          })();
        </script>
'''
filas = [(arch, 'correo unico arriba', h1a, h1b), (arch, 'titulo "Con un codigo por correo"', h2a, h2b), (arch, 'boton de enviar el codigo', h3a, h3b),
         (arch, 'nombre del campo del codigo del correo', h4a, h4b), (arch, 'titulo de la app de verificacion', h5a, h5b),
         (arch, 'nombre del campo del codigo de la app', h6a, h6b), (arch, 'estilo y script del correo unico', h7a, h7b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-entrada-clara-panel.ps1 - Ojo Guard MS: la pantalla de entrada de ojoguard.app se entiende a primera vista (idea de Luciano, 30/10/2026: "hay 3 maneras y no se entiende cual es cada una").
# Un solo campo de correo arriba; titulos claros ("Con un codigo por correo", "Con mi app de verificacion"); los dos campos de 6 numeros dicen de donde viene cada codigo.
# Cambia SOLO src\\panel-index.html (respaldo .bak-entrada-clara). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-index.html"))) { Mal "No encuentro src\\panel-index.html en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto 'correo-unico') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-entrada-clara')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la pantalla de entrada ya esta ordenada. Recarga ojoguard.app para verla."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-entrada-clara-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
