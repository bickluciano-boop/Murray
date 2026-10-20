# Arma los archivos nuevos de la consola (carpeta nuevo/) a partir de los de tu carpeta (carpeta orig/).
# Cambia solo lo necesario: la pestaña "Cuenta" pasa a ser "Configuracion" con categorias; las tarjetas de antes se mueven intactas.
import os, re, shutil
O = 'orig/'; N = 'nuevo/'
os.makedirs(N, exist_ok=True)
for f in os.listdir(O): shutil.copy(O + f, N + f)
def leer(f):
    raw = open(O + f, 'rb').read().decode('utf-8-sig')
    return raw.replace('\r\n', '\n')
def leer_nuevo(f):
    return open(N + f, 'rb').read().decode('utf-8').replace('\r\n', '\n')
def escribir(f, t):
    open(N + f, 'w', encoding='utf-8', newline='').write(t)
def una_vez(t, a, b=None, donde=''):
    assert t.count(a) == 1, ('ancla', donde, t.count(a), a[:80])
    return t if b is None else t.replace(a, b)

# ===================== panel-index.html =====================
h = leer('panel-index.html')

# 1) Accesibilidad compartida con Tu proteccion (se aplica antes de dibujar la pagina)
acc_script = '''    <script>
      /* Accesibilidad compartida con Tu protección (misma clave "ogAcc" en este mismo sitio): tamaño del texto, alto contraste y botones más grandes. */
      (function () {
        try {
          var q = JSON.parse(localStorage.getItem("ogAcc") || "{}") || {}, r = document.documentElement;
          if (q.t === "g") r.style.fontSize = "118%";
          if (q.t === "x") r.style.fontSize = "136%";
          if (q.c) r.classList.add("ac");
          if (q.b) r.classList.add("ab");
        } catch (e) { /* sin almacenamiento: todo queda como siempre */ }
      })();
    </script>
'''
ancla = '    <style>button.location-guide{display:flex'
h = una_vez(h, ancla, acc_script + ancla, 'script accesibilidad')

# 2) La pestana "Cuenta" pasa a "Configuracion"
h = una_vez(h,
    '<button class="bottom-tab" data-view="account" type="button"><span class="tab-icon" aria-hidden="true">○</span><span>Cuenta</span></button>',
    '<button class="bottom-tab" data-view="account" type="button"><span class="tab-icon" aria-hidden="true">&#9881;&#65038;</span><span>Configuración</span></button>',
    'pestana')

# 2b) Version nueva del programa (para que el navegador no use una copia vieja)
h = una_vez(h, '<script type="module" src="/app-v9.js?v=7"></script>', '<script type="module" src="/app-v9.js?v=8"></script>', 'version del js')

# 3) La pantalla de Cuenta: se reordena. Las tarjetas se sacan tal cual del archivo de antes.
ini = h.index('        <section id="account" class="dashboard-section" data-views="account">')
fin = h.index('        <section id="items" class="dashboard-section" data-views="devices">')
viejo = h[ini:fin]
def trozo(desde, hasta):
    a = viejo.index(desde); b = viejo.index(hasta, a)
    return viejo[a:b]
tarj_correo = trozo('<article class="account-card card"><span>Correo del titular</span>', '<article class="account-card card"><span>Protección de ingreso</span>')
tarj_ingreso = trozo('<article class="account-card card"><span>Protección de ingreso</span>', '        <article class="account-card card" id="totp-card">')
# la tarjeta de ingreso termina junto con el cierre de la tarjeta anterior en una misma linea: se separan por la etiqueta de cierre
tarj_totp = trozo('        <article class="account-card card" id="totp-card">', '        <article class="account-card card" id="notification-prefs-card">')
tarj_avisos = trozo('        <article class="account-card card" id="notification-prefs-card">', '        <article class="account-card card" id="qa-card">')
tarj_qa = trozo('        <article class="account-card card" id="qa-card">', '        <article class="account-card card" id="face-search-card">')
a = viejo.index('        <article class="account-card card" id="face-search-card">'); b = viejo.index('</article></section>', a) + len('</article>')
tarj_facial = viejo[a:b]
sec_personas = viejo[viejo.index('        <section id="people" class="dashboard-section" data-views="account">'):]
assert sec_personas.rstrip().endswith('</section>') and sec_personas.count('<section') == 1
# se comprueba que no se perdio nada: todo lo que habia queda en alguno de los trozos
partes = tarj_correo + tarj_ingreso + tarj_totp + tarj_avisos + tarj_qa + tarj_facial + sec_personas
def ids(t): return sorted(set(re.findall(r'\bid="([^"]+)"', t)))
assert set(ids(viejo)) - {'account'} == set(ids(partes)), (set(ids(viejo)) - {'account'}) ^ set(ids(partes))
assert viejo.count('<article') == 6 and partes.count('<article') == 6

def panel(id_, titulo, copia, cuerpo):
    return f'''          <div id="cfg-{id_}" class="cfg-panel hidden" data-cfg-panel="{id_}">
            <a class="cfg-volver" href="#config">&#8592; Configuración</a>
            <div class="section-head"><div><p class="eyebrow">CONFIGURACIÓN</p><h2>{titulo}</h2><p class="section-copy">{copia}</p></div></div>
{cuerpo}          </div>
'''
def item(id_, titulo, texto):
    return f'''              <button type="button" class="cfg-item" data-cfg="{id_}"><span><strong>{titulo}</strong><small>{texto}</small></span></button>
'''
lista = ('''          <div id="cfg-lista">
            <div class="section-head"><div><p class="eyebrow">AJUSTES</p><h2>Configuración</h2><p class="section-copy">Lo que no usás todos los días está acá, ordenado por tema. Lo de todos los días sigue en cada pestaña.</p></div></div>
            <nav class="card cfg-lista" aria-label="Categorías de Configuración">
'''
 + item('cuenta', 'Cuenta y seguridad', 'Tu correo, cómo entrás, el código de verificación y la pregunta de emergencia.')
 + item('avisos', 'Avisos', 'Cómo te avisamos si pasa algo con tu teléfono: por correo o por SMS.')
 + '''              <a class="cfg-item" href="/guardian#configuracion"><span><strong>Tu protección</strong><small>Referentes, Modo Cautela y Modo Guardián. Se abre en otra pantalla.</small></span></a>
'''
 + item('familia', 'Familia y lugares', 'Invitar a la familia, lugares guardados, avisos de llegada y salida y roles.')
 + item('equipos', 'Equipos y pulseras', 'Agregar un equipo, quitarlo o autorizarlo, y la presentación de las pulseras.')
 + item('facial', 'Reconocimiento facial', 'Búsquedas disponibles y compra.')
 + item('apariencia', 'Apariencia y accesibilidad', 'Modo claro o noche, tamaño del texto, contraste y botones grandes.')
 + '''            </nav>
          </div>
''')

cuerpo_cuenta = tarj_correo + tarj_ingreso + tarj_totp + tarj_qa + sec_personas
p_cuenta = panel('cuenta', 'Cuenta y seguridad', 'Tu correo identifica la cuenta y mantiene la misma información en todos tus dispositivos.', cuerpo_cuenta)
p_avisos = panel('avisos', 'Avisos', 'Cómo querés enterarte si pasa algo con tu teléfono.', tarj_avisos)
p_facial = panel('facial', 'Reconocimiento facial', 'Comparar la cara de una evidencia con tu galería. Es una función paga.', tarj_facial)

p_familia = panel('familia', 'Familia y lugares', 'Todo lo de tu familia se maneja en el mapa; desde acá llegás directo.', '''        <article class="account-card card">
          <span>Invitar a la familia</span>
          <strong>Sumá a alguien</strong>
          <small>Le mandás un código y un enlace. Elegís si es adulto, menor o amigo.</small>
          <button id="cfg-invitar" class="ghost" type="button">Invitar a la familia</button>
        </article>
        <article class="account-card card">
          <span>Lugares, avisos y roles</span>
          <strong>Casa, colegio, trabajo…</strong>
          <small>Los lugares se ven y se quitan en el mapa. Para que te avisen cuando alguien llega o sale de un lugar, tocá a la persona en el mapa y elegí «Avisarme cuando llegue o salga». Para cambiarle el rol o quitarla de la familia, tocá a la persona y elegí «Cambiar rol o quitar».</small>
          <button id="cfg-mapa" class="ghost" type="button">Abrir Mapa y Familia</button>
        </article>
''')
p_equipos = panel('equipos', 'Equipos y pulseras', 'Agregar, quitar y autorizar equipos. Lo de todos los días (ubicar, hacer sonar) sigue en Mis Equipos.', '''        <article class="account-card card">
          <span>Agregar un equipo</span>
          <strong>Teléfono, tablet o accesorio Bluetooth</strong>
          <small>Te llevamos a Mis Equipos con el cuadro para agregarlo abierto.</small>
          <button id="cfg-agregar" class="ghost" type="button">Agregar un equipo</button>
        </article>
        <article class="account-card card">
          <span>Quitar o autorizar un equipo</span>
          <strong>Se hace desde cada equipo</strong>
          <small>En Mis Equipos, tocá «Más acciones» en el equipo que quieras quitar. Los equipos nuevos quedan pendientes hasta que los autorices ahí mismo.</small>
          <button id="cfg-equipos-ir" class="ghost" type="button">Ir a Mis Equipos</button>
        </article>
        <article class="account-card card">
          <span>Pulseras</span>
          <strong>Reloj GPS con alarmas y salud</strong>
          <small>Una presentación corta de lo que hace la pulsera.</small>
          <button id="cfg-pulseras" class="ghost" type="button">Ver presentación</button>
        </article>
''')
p_apar = panel('apariencia', 'Apariencia y accesibilidad', 'Cómo se ve y cómo se toca este panel. Se guarda en este dispositivo.', '''        <article class="account-card card">
          <span>Tema</span>
          <strong id="cfg-tema-estado">Modo claro</strong>
          <small>El modo noche descansa la vista.</small>
          <button id="cfg-tema" class="ghost" type="button">Pasar a modo noche</button>
        </article>
        <article class="account-card card" id="cfg-acc">
          <span>Accesibilidad</span>
          <strong>Que se lea y se toque cómodo</strong>
          <small>Vale también para Tu protección: lo que elijas acá se ve ahí y al revés.</small>
          <span class="cfg-rotulo">Tamaño del texto</span>
          <div class="cfg-chips" role="group" aria-label="Tamaño del texto">
            <button type="button" class="ghost" data-t="">Normal</button>
            <button type="button" class="ghost" data-t="g">Grande</button>
            <button type="button" class="ghost" data-t="x">Muy grande</button>
          </div>
          <label><input id="cfg-contraste" type="checkbox" /> Alto contraste</label>
          <label><input id="cfg-botones" type="checkbox" /> Botones más grandes</label>
        </article>
''')

nuevo_bloque = ('        <section id="account" class="dashboard-section" data-views="account">\n'
                + lista + p_cuenta + p_avisos + p_facial + p_familia + p_equipos + p_apar + '        </section>\n')
h = h[:ini] + nuevo_bloque + h[fin:]
# todo id que habia sigue estando
assert set(ids(leer('panel-index.html'))) <= set(ids(h)), set(ids(leer('panel-index.html'))) - set(ids(h))
escribir('panel-index.html', h)

# ===================== panel-app.txt =====================
a = leer('panel-app.txt')
ultima = 'setTimeout(qaCargar, 2000);'
assert a.endswith(ultima) and a.count(ultima) == 1
js = r'''
// ---- Configuración: la pestaña que antes era "Cuenta". Una lista de categorías y una pantalla por categoría. ----
// Las tarjetas de antes (correo, acceso, código de verificación, avisos, pregunta de emergencia, reconocimiento facial) son las mismas: solo cambiaron de lugar.
const cfgPaneles = Array.from(document.querySelectorAll("[data-cfg-panel]"));
function cfgMostrar(id, desplazar = true) {
  const valido = cfgPaneles.some((p) => p.dataset.cfgPanel === id) ? id : "";
  $("#cfg-lista").classList.toggle("hidden", valido !== "");
  cfgPaneles.forEach((p) => p.classList.toggle("hidden", p.dataset.cfgPanel !== valido));
  if (desplazar) window.scrollTo(0, 0);
}
function cfgDesdeHash() {
  const m = /^#config(?:-([a-z]+))?$/.exec(location.hash);
  if (!m || emergencyMode) return false; // en el modo de emergencia no se ve Configuración (igual que pasaba con Cuenta)
  setView("account", false);
  cfgMostrar(m[1] || "");
  return true;
}
document.querySelectorAll("[data-cfg]").forEach((b) => b.addEventListener("click", () => { location.hash = "config-" + b.dataset.cfg; }));
window.addEventListener("hashchange", () => { if (!cfgDesdeHash() && currentView === "account") cfgMostrar(""); });
// Al tocar la pestaña Configuración, siempre se ve la lista.
document.querySelectorAll('[data-view="account"]').forEach((b) => b.addEventListener("click", () => {
  if (/^#config/.test(location.hash)) history.replaceState(null, "", location.pathname + location.search);
  cfgMostrar("");
}));

// Atajos: llevan a donde ya está cada cosa (el mapa, Mis Equipos), sin duplicarla.
function cfgEsperar(selector, hacer, intentos = 40) {
  const reloj = setInterval(() => {
    const elemento = $(selector);
    if (elemento || --intentos <= 0) { clearInterval(reloj); if (elemento) hacer(elemento); }
  }, 150);
}
$("#cfg-mapa").addEventListener("click", () => { $("[data-mapa-tab]")?.click(); });
$("#cfg-invitar").addEventListener("click", () => { $("[data-mapa-tab]")?.click(); cfgEsperar('#og-mapa [data-ogm="invitar"]', (b) => b.click()); });
$("#cfg-agregar").addEventListener("click", () => { setView("devices"); $("#add-device-button")?.click(); });
$("#cfg-equipos-ir").addEventListener("click", () => setView("devices"));
$("#cfg-pulseras").addEventListener("click", () => $("#watch-presentation-button")?.click());

// Apariencia: el tema (el mismo botón de siempre, que sigue en la barra de arriba en la pantalla de acceso) y la accesibilidad (misma clave que Tu protección).
function cfgAccLeer() { try { return JSON.parse(localStorage.getItem("ogAcc") || "{}") || {}; } catch { return {}; } }
function cfgAccGuardar(acc) { try { localStorage.setItem("ogAcc", JSON.stringify(acc)); } catch { /* navegación privada */ } }
function cfgAccAplicar(acc) {
  const raiz = document.documentElement;
  raiz.style.fontSize = acc.t === "g" ? "118%" : acc.t === "x" ? "136%" : "";
  raiz.classList.toggle("ac", !!acc.c);
  raiz.classList.toggle("ab", !!acc.b);
}
function cfgPintarApariencia() {
  const claro = document.documentElement.getAttribute("data-theme") === "light";
  $("#cfg-tema-estado").textContent = claro ? "Modo claro" : "Modo noche";
  $("#cfg-tema").textContent = claro ? "Pasar a modo noche" : "Pasar a modo claro";
  const acc = cfgAccLeer();
  document.querySelectorAll("#cfg-acc [data-t]").forEach((b) => b.setAttribute("aria-pressed", String((b.dataset.t || "") === (acc.t || ""))));
  $("#cfg-contraste").checked = !!acc.c;
  $("#cfg-botones").checked = !!acc.b;
}
$("#cfg-tema").addEventListener("click", () => { $("#theme-toggle")?.click(); cfgPintarApariencia(); });
new MutationObserver(cfgPintarApariencia).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
document.querySelectorAll("#cfg-acc [data-t]").forEach((b) => b.addEventListener("click", () => { const acc = cfgAccLeer(); acc.t = b.dataset.t; cfgAccGuardar(acc); cfgAccAplicar(acc); cfgPintarApariencia(); }));
$("#cfg-contraste").addEventListener("change", (evento) => { const acc = cfgAccLeer(); acc.c = evento.target.checked; cfgAccGuardar(acc); cfgAccAplicar(acc); });
$("#cfg-botones").addEventListener("change", (evento) => { const acc = cfgAccLeer(); acc.b = evento.target.checked; cfgAccGuardar(acc); cfgAccAplicar(acc); });
cfgPintarApariencia();
// Si se recarga estando en una pantalla de Configuración, se vuelve a esa pantalla apenas se dibuja el panel (ahí ya se sabe si es modo de emergencia).
if (location.hash) { if ($("#dashboard:not(.hidden)")) cfgDesdeHash(); else cfgEsperar("#dashboard:not(.hidden)", () => cfgDesdeHash()); }
'''
a = a + '\n' + js
escribir('panel-app.txt', a)

# ===================== estilos: van adentro de la pagina (un bloque <style> al final del <head>) =====================
# Asi la pagina y sus estilos siempre llegan juntos y no puede quedar una copia vieja de los estilos con la pagina nueva.
h = leer_nuevo('panel-index.html')
assert 'configuracion-v1' not in h
css = r'''
/* configuracion-v1: Configuración de la consola (lista de categorías y una pantalla por categoría). Usa los mismos colores de siempre (variables), así sirve en modo claro y modo noche. */
.cfg-lista { padding: 0; overflow: hidden; }
.cfg-item {
  display: flex; align-items: center; justify-content: space-between; gap: 14px; width: 100%;
  padding: 18px 20px; text-align: left; background: transparent; color: inherit; border: 0; border-top: 1px solid var(--line);
  border-radius: 0; font-weight: inherit; text-decoration: none; cursor: pointer; transform: none;
}
.cfg-item:first-child { border-top: 0; }
.cfg-item:hover, .cfg-item:focus-visible { background: var(--panel-2); filter: none; transform: none; }
.cfg-item::after { content: "\203A"; flex: none; color: var(--muted); font-size: 1.7rem; line-height: 1; }
.cfg-item strong { display: block; font-size: 1.04rem; color: inherit; }
.cfg-item small { display: block; margin-top: 4px; color: var(--muted); font-weight: 400; line-height: 1.4; }
.cfg-volver {
  display: inline-flex; align-items: center; margin: 0 0 18px; padding: 8px 15px; border: 1px solid var(--line); border-radius: 999px;
  color: var(--gold-text, var(--lime)); font-weight: 700; font-size: 0.9rem; text-decoration: none;
}
.cfg-volver:hover, .cfg-volver:focus-visible { background: var(--panel-2); }
#account > #cfg-lista { grid-column: 1 / -1; max-width: 760px; }
#account > .cfg-panel { grid-column: 1 / -1; }
.cfg-panel { display: grid; gap: 18px; align-items: start; }
.cfg-panel > .section-head { margin-bottom: 0; }
.cfg-panel > .account-card { margin: 0; padding: clamp(20px, 3vw, 30px); }
.cfg-panel .dashboard-section { margin: 18px 0 0; }
.cfg-panel .account-card button { justify-self: start; }
@media (min-width: 900px) {
  .cfg-panel { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .cfg-panel > .cfg-volver { justify-self: start; }
  .cfg-panel > .cfg-volver, .cfg-panel > .section-head, .cfg-panel > .dashboard-section { grid-column: 1 / -1; }
}
/* La pestaña "Configuración" es más larga que "Cuenta": en el celular se achica un poco el espacio entre letras para que se lea entera. */
@media (max-width: 520px) {
  .bottom-tab > span:not(.tab-icon) { letter-spacing: -0.015em; }
}
.cfg-rotulo { margin-top: 6px; font-size: 0.82rem; color: var(--muted); }
.cfg-chips { display: flex; flex-wrap: wrap; gap: 8px; }
.cfg-chips button { padding: 10px 16px; font-size: 0.9rem; }
:root .cfg-chips button[aria-pressed="true"] { background: var(--lime); color: var(--ink); border-color: var(--lime); }
/* La barra de arriba se queda con el botón de tema solo en la pantalla de acceso; ya adentro, está en Configuración. */
.shell:has(#dashboard:not(.hidden)) #theme-toggle { display: none; }

/* Accesibilidad (misma clave y mismas ideas que en Tu protección) */
:root.ab button, :root.ab .map-button, :root.ab .app-link, :root.ab .cfg-volver, :root.ab .bottom-tab { min-height: 48px; }
:root.ab button, :root.ab .map-button, :root.ab .app-link { padding-top: 16px; padding-bottom: 16px; font-size: 1.05rem; }
:root.ab .bottom-tab { padding-top: 12px; padding-bottom: 12px; }
:root.ab .cfg-item { padding-top: 24px; padding-bottom: 24px; }
:root.ab input[type="checkbox"] { width: 22px; height: 22px; }
:root.ac { --muted: #e4e6df; --line: #8b9189; --ac-texto: #ffffff; }
:root.ac[data-theme="light"] { --muted: #262723; --line: #6c6b61; --ac-texto: #000000; }
:root.ac small, :root.ac p, :root.ac .section-copy, :root.ac .status-grid span, :root.ac .actions small, :root.ac label, :root.ac .cfg-rotulo,
:root.ac .account-card span, :root.ac .account-card small, :root.ac .device-meta, :root.ac .command-status, :root.ac .bottom-tab { color: var(--ac-texto) !important; }
:root.ac .card, :root.ac .cfg-item, :root.ac .cfg-volver, :root.ac input, :root.ac .ghost, :root.ac .bottom-tabs { border-color: var(--line) !important; }
'''
# El boton OG (entrada a Tu proteccion) solo tenia estilo en el celular: sus reglas quedaron adentro del bloque "max-width: 520px" de explanations.css.
# En la compu se veia un triangulito con "OG" sin estilo, hasta sin sesion abierta. Se repiten esas mismas reglas para pantallas mas anchas.
expl = leer('panel-explanations.css')
a = expl.index('/* OG: entrada a Tu proteccion')
b = expl.index('@media (max-width: 560px) {', a)
reglas_og = expl[a:b]
assert reglas_og.count('.og-guardian') >= 5 and '@media' not in reglas_og and '{' in reglas_og
css = css.rstrip('\n') + '\n\n/* El botón OG tenía estilo solo en el celular (las reglas quedaron adentro de "max-width: 520px"): acá se repiten para pantallas más anchas. */\n@media (min-width: 521px) {\n' + ''.join(('  ' + l if l.strip() else l) for l in reglas_og.splitlines(True)) + '}\n'
css += '''/* En pantalla ancha (desde 1280 px) la franja de arriba recorta lo que se sale de ella; con el menú de OG abierto se la deja de recortar para que se vea entero. */
@media (min-width: 1280px) {
  .shell:has(#dashboard:not(.hidden)) > .topbar:has(.og-guardian[open]) { clip-path: none !important; box-shadow: none !important; }
}
'''
sangria = lambda t: ''.join(('      ' + l if l.strip() else l) for l in t.splitlines(True))
bloque = '    <style id="configuracion-v1">\n' + sangria(css.lstrip('\n')) + '    </style>\n'
h = una_vez(h, '  </head>', bloque + '  </head>', 'cierre del head')
escribir('panel-index.html', h)
print('listo: nuevo/')
