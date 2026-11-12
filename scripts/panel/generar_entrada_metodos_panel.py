# Genera scripts/aplicar-entrada-metodos-panel.ps1: la pantalla de entrada de ojoguard.app pide el correo UNA vez y despues pregunta como queres entrar.
#  - Un solo campo de correo arriba (se copia a las otras formas de entrar, que siguen igual por dentro).
#  - "Como queres entrar?": Codigo por correo / App de verificacion / Huella o Face ID. Solo se ve lo de la opcion elegida; se acuerda de la ultima.
#  - La opcion de emergencia (pregunta secreta) queda abajo, como antes.
# Reemplaza a aplicar-entrada-clara-panel.ps1 (que nunca se aplico). Solo cambia src\panel-index.html. Si el script de la pagina no corre, la pantalla queda como antes.
import re
R = '/home/user/Murray/scripts/'
U = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
arch = 'src\\panel-index.html'
h1a = '        <p class="hero-copy">Ingresá con un código enviado a tu correo. Funciona en iPhone, Android y computadora sin escanear ningún QR.</p>\n'
h1b = h1a + '''        <div id="correo-unico-caja" style="display:none">
          <label>Tu correo<input id="correo-unico" type="email" autocomplete="username webauthn" placeholder="tu@correo.com" /></label>
          <p class="acceso-via">¿Cómo querés entrar?</p>
          <div class="acceso-metodos" role="group" aria-label="Cómo querés entrar">
            <button type="button" data-metodo="correo" aria-pressed="false"><strong>Código por correo</strong><small>Te lo mandamos al mail</small></button>
            <button type="button" data-metodo="app" aria-pressed="false"><strong>App de verificación</strong><small>Google Authenticator u otra</small></button>
            <button type="button" data-metodo="huella" aria-pressed="false"><strong>Huella o Face ID</strong><small>Si ya la configuraste acá</small></button>
          </div>
        </div>
'''
h3a = '          <button>Enviar código de 6 números</button>\n'
h3b = '          <button>Enviar código por correo</button>\n'
h4a = '<label>Código de 6 números<input id="code"'
h4b = '<label>Código que te llegó por correo<input id="code"'
h6a = '<label>Código de 6 números<input id="totp-code"'
h6b = '<label>Código de tu app de verificación<input id="totp-code"'
h7a = '        <p id="access-message" class="message"></p>\n'
h7b = h7a + r'''        <style>
          #access .acceso-via{margin:18px 0 8px;font-weight:800;font-size:1.02rem}
          #correo-unico-caja{margin:14px 0 4px}
          #access .acceso-metodos{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
          #access .acceso-metodos button[data-metodo]{display:flex!important;flex-direction:column;align-items:center;justify-content:center;gap:3px;width:auto!important;margin:0!important;padding:12px 8px!important;min-height:64px;border-radius:14px!important;border:1px solid rgba(217,178,76,.45)!important;background:transparent!important;color:inherit!important;box-shadow:none!important;font:inherit;cursor:pointer;text-align:center;line-height:1.2;text-transform:none;letter-spacing:normal}
          #access .acceso-metodos button[data-metodo] strong{font-size:.92rem;font-weight:700;color:inherit}
          #access .acceso-metodos button[data-metodo] small{font-size:.72rem;opacity:.75;color:inherit;font-weight:400}
          #access .acceso-metodos button[data-metodo]:hover{background:rgba(217,178,76,.1)!important}
          #access .acceso-metodos button[data-metodo][aria-pressed="true"]{border-color:#d9b24c!important;background:rgba(217,178,76,.2)!important;box-shadow:0 0 0 1px #d9b24c inset!important}
          #access .acceso-metodos button[data-metodo]:focus-visible{outline:2px solid #d9b24c;outline-offset:2px}
          @media (max-width:520px){#access .acceso-metodos{grid-template-columns:1fr}#access .acceso-metodos button[data-metodo]{flex-direction:row;justify-content:flex-start;gap:10px;text-align:left;min-height:52px;padding:10px 14px!important}}
          #access.og-metodos #passkey-form>label,#access.og-metodos #email-form>label,#access.og-metodos #totp-login-form>label:first-child,#access.og-metodos #qa-login-form>label:first-child{display:none}
          #access.og-metodos #passkey-details>summary,#access.og-metodos #totp-login-details>summary{display:none}
          #access.og-metodos:not([data-metodo]) #passkey-details,#access.og-metodos:not([data-metodo]) #email-form,#access.og-metodos:not([data-metodo]) #code-form,#access.og-metodos:not([data-metodo]) #totp-login-details{display:none}
          #access.og-metodos[data-metodo="correo"] #passkey-details,#access.og-metodos[data-metodo="correo"] #totp-login-details{display:none}
          #access.og-metodos[data-metodo="app"] #passkey-details,#access.og-metodos[data-metodo="app"] #email-form,#access.og-metodos[data-metodo="app"] #code-form{display:none}
          #access.og-metodos[data-metodo="huella"] #email-form,#access.og-metodos[data-metodo="huella"] #code-form,#access.og-metodos[data-metodo="huella"] #totp-login-details{display:none}
        </style>
        <script>
          (function () {
            var acceso = document.getElementById("access");
            var caja = document.getElementById("correo-unico-caja");
            var unico = document.getElementById("correo-unico");
            var ids = ["passkey-email", "email", "totp-email", "qa-email"];
            var campos = ids.map(function (id) { return document.getElementById(id); }).filter(Boolean);
            var botones = Array.prototype.slice.call(document.querySelectorAll("#correo-unico-caja .acceso-metodos button"));
            if (!acceso || !caja || !unico || campos.length !== ids.length || botones.length !== 3) return;
            function copiar() { campos.forEach(function (c) { c.value = unico.value; }); }
            unico.addEventListener("input", copiar);
            unico.addEventListener("change", copiar);
            // Antes de enviar cualquier forma, el correo de arriba pasa al campo de esa forma (si el de arriba esta vacio, toma el que ya tenia la forma).
            campos.forEach(function (c) {
              if (c.form) c.form.addEventListener("submit", function () { if (unico.value) c.value = unico.value; else unico.value = c.value; }, true);
            });
            function previo() { var p = ""; campos.forEach(function (c) { if (!p && c.value) p = c.value; }); return p; }
            function tomarPrevio() { var p = previo(); if (p && !unico.value) { unico.value = p; copiar(); } }
            tomarPrevio();
            window.addEventListener("load", tomarPrevio);
            function elegir(metodo) {
              acceso.setAttribute("data-metodo", metodo);
              botones.forEach(function (b) { b.setAttribute("aria-pressed", String(b.getAttribute("data-metodo") === metodo)); });
              var pk = document.getElementById("passkey-details"), tp = document.getElementById("totp-login-details");
              if (metodo === "huella" && pk) pk.open = true;
              if (metodo === "app" && tp) tp.open = true;
              try { localStorage.setItem("ojo_ms_metodo", metodo); } catch (e) { /* navegacion privada */ }
            }
            botones.forEach(function (b) { b.addEventListener("click", function () { elegir(b.getAttribute("data-metodo")); }); });
            // Enter en el correo sigue con lo elegido (sin elegir nada, con el codigo por correo).
            unico.addEventListener("keydown", function (ev) {
              if (ev.key !== "Enter") return;
              ev.preventDefault();
              copiar();
              var metodo = acceso.getAttribute("data-metodo") || "correo";
              elegir(metodo);
              var forma = metodo === "correo" ? document.getElementById("email-form") : metodo === "huella" ? document.getElementById("passkey-form") : null;
              if (forma && forma.requestSubmit) forma.requestSubmit();
              else if (metodo === "app") { var cod = document.getElementById("totp-code"); if (cod) cod.focus(); }
            });
            var guardado = "";
            try { guardado = localStorage.getItem("ojo_ms_metodo") || ""; if (!guardado && localStorage.getItem("ojo_ms_usa_passkey") === "1") guardado = "huella"; } catch (e) { /* navegacion privada */ }
            caja.style.display = "block";
            acceso.classList.add("og-metodos");
            if (guardado === "correo" || guardado === "app" || guardado === "huella") elegir(guardado);
          })();
        </script>
'''
filas = [(arch, 'correo unico y "como queres entrar?"', h1a, h1b), (arch, 'boton de enviar el codigo', h3a, h3b),
         (arch, 'nombre del campo del codigo del correo', h4a, h4b), (arch, 'nombre del campo del codigo de la app', h6a, h6b),
         (arch, 'estilo y script de la eleccion', h7a, h7b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-entrada-metodos-panel.ps1 - Ojo Guard MS: la entrada de ojoguard.app pide el correo UNA vez y pregunta como queres entrar.
# Luciano (12/11/2026): "que no sea tan tedioso entrar, que solo este tu mail y te pregunte de que manera queres entrar (codigo por mail, codigo de 6 digitos del autenticador, o la otra), pero que no haya tantos mails".
# Un solo correo; "Como queres entrar?" con Codigo por correo / App de verificacion / Huella o Face ID (se acuerda de la ultima); la emergencia (pregunta secreta) queda abajo. Por dentro las formas de entrar siguen igual.
# Reemplaza a aplicar-entrada-clara-panel.ps1 (no aplicar los dos). Cambia SOLO src\\panel-index.html (respaldo .bak-entrada-metodos). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-index.html"))) { Mal "No encuentro src\\panel-index.html en esta carpeta."; return }
$htmlTexto = (Leer (Join-Path $raiz "src\\panel-index.html")).texto
if ((Contar $htmlTexto 'og-metodos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $htmlTexto 'correo-unico') -ne 0) { Mal "Ya se aplico aplicar-entrada-clara-panel.ps1. Mandame esta pantalla."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-entrada-metodos')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la entrada pide el correo una vez y pregunta como queres entrar (recarga ojoguard.app con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-entrada-metodos-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
h = open(U + '3347fd7c-panel-index-actual.html', encoding='utf-8').read().replace('\r\n', '\n')
for a in (h1a, h3a, h4a, h6a, h7a):
    assert h.count(a) == 1, (h.count(a), a[:70])
for a, b in ((h1a, h1b), (h3a, h3b), (h4a, h4b), (h6a, h6b), (h7a, h7b)):
    h = h.replace(a, b)
open(S + 'panel-index-metodos.html', 'w', encoding='utf-8').write(h)
print('ok', len(total))
