# Genera scripts/aplicar-renombrar-equipo-panel.ps1: desde la tarjeta del mapa, el boton de la foto del equipo abre "Foto y nombre":
# se puede cambiar el nombre del equipo (Celu chapas, Lu ipone...) o la foto. El servidor no deja repetir el nombre de otro equipo del mismo titular.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

# --- servidor (src\index.ts) ---
FUNCION = '''// Cambiar el nombre de un equipo propio ("Celu chapas"). Solo el titular, sin acceso de emergencia, y no puede repetir el nombre de otro equipo suyo.
async function renameDevice(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const deviceId = String(body.deviceId ?? "");
  const name = String(body.name ?? "").replace(/[\\u0000-\\u001f\\u007f]/g, " ").replace(/\\s+/g, " ").trim();
  if (name.length < 1 || name.length > 40) return json({ error: "invalid_name" }, 400);
  const owns = await env.DB.prepare("SELECT id FROM devices WHERE id=? AND owner_email=?").bind(deviceId, sessionInfo.email).first();
  if (!owns) return json({ error: "device_not_found" }, 404);
  const others = await env.DB.prepare("SELECT name FROM devices WHERE owner_email=? AND id<>? AND approval_status<>'revoked'").bind(sessionInfo.email, deviceId).all<{ name: string | null }>();
  const clave = (texto: string) => texto.normalize("NFD").replace(/[\\u0300-\\u036f]/g, "").toLowerCase();
  if (others.results.some((otro) => clave(String(otro.name ?? "")) === clave(name))) return json({ error: "name_in_use" }, 409);
  await env.DB.prepare("UPDATE devices SET name=? WHERE id=? AND owner_email=?").bind(name, deviceId, sessionInfo.email).run();
  return json({ saved: true, name });
}

'''
s1a = 'async function saveDevicePhoto(request: Request, env: Env) {\n'
s1b = FUNCION + s1a
s2a = '      if (route === "POST /api/remote/devices/photo") return saveDevicePhoto(request, env);\n'
s2b = s2a + '      if (route === "POST /api/remote/devices/rename") return renameDevice(request, env);\n'

# --- mapa del panel (src\panel-mapa.txt) ---
m1a = '    if (accion === "foto") return $(\'[data-ogm="archivo"]\', raiz).click();\n'
m1b = '''    if (accion === "foto") return abrirEquipo(equipoElegido());
    if (accion === "foto-elegir") { estado.dialogo = null; dibujarDialogo(); return $('[data-ogm="archivo"]', raiz).click(); }
    if (accion === "nombre-guardar") return guardarNombre(boton);
'''
m2a = '  if (d.paso === "salir") {\n'
m2b = '''  if (d.paso === "equipo") {
    caja.setAttribute("aria-label", "Foto y nombre del equipo");
    caja.innerHTML = `<div class="ogm-dlg">
      <p class="ogm-ceja">TU EQUIPO</p>
      <h3>Foto y nombre</h3>
      <label class="ogm-campo">Nombre del equipo<input data-ogm="nombre-equipo" maxlength="40" autocomplete="off" value="${esc(d.valor)}"></label>
      <p class="ogm-dlg-txt">Así aparece en tu mapa, en tu lista de equipos y en los avisos que te llegan. No puede repetir el nombre de otro equipo tuyo.</p>
      ${d.error ? `<p class="ogm-aviso-vivo">${esc(d.error)}</p>` : ""}
      <div class="ogm-dlg-botones"><button type="button" class="oro" data-accion="nombre-guardar">Guardar nombre</button><button type="button" data-accion="foto-elegir">Cambiar foto</button><button type="button" data-accion="cerrar-dialogo">Cancelar</button></div>
    </div>`;
    const campo = caja.querySelector('[data-ogm="nombre-equipo"]');
    campo?.addEventListener("input", () => { d.valor = campo.value; });
    campo?.addEventListener("keydown", (e) => { if (e.key === "Enter") caja.querySelector('[data-accion="nombre-guardar"]')?.click(); });
    return;
  }
''' + m2a
m3a = '// Administrar a alguien de tu familia (solo el titular): cambiarle el rol o quitarlo.\n'
m3b = '''// Foto y nombre de un equipo tuyo: el boton de la foto en la tarjeta abre este cuadro.
function abrirEquipo(equipo) {
  if (!equipo || equipo.tipo !== "telefono" || DEMO) return;
  estado.dialogo = { paso: "equipo", equipoId: equipo.id, valor: equipo.nombre, error: "" };
  dibujarDialogo();
}

async function guardarNombre(boton) {
  const d = estado.dialogo;
  if (!d || d.paso !== "equipo") return;
  const nombre = String(d.valor || "").replace(/\\s+/g, " ").trim();
  if (!nombre) { d.error = "Escribí un nombre para el equipo."; return dibujarDialogo(); }
  boton.disabled = true;
  boton.textContent = "Guardando…";
  try {
    await pedir("/api/remote/devices/rename", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ deviceId: d.equipoId, name: nombre }) });
    estado.dialogo = null;
    dibujarDialogo();
    estado.elementosMarcador.delete(d.equipoId);
    return refrescar();
  } catch (error) {
    d.error = error.status === 409 ? "Ya tenés otro equipo con ese nombre. Elegí uno distinto." : error.status === 403 ? "Para esto, entrá al panel con tu acceso normal (no con el de emergencia)." : "No se pudo cambiar el nombre. Probá de nuevo.";
    dibujarDialogo();
  }
}

''' + m3a
h1a = '<script type="module" src="/mapa-v1.js?v=3"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=4"></script>'

filas = [
    ('src\\index.ts', 'servidor: funcion para renombrar un equipo', s1a, s1b),
    ('src\\index.ts', 'servidor: ruta para renombrar un equipo', s2a, s2b),
    ('src\\panel-mapa.txt', 'mapa: el boton de la foto abre Foto y nombre', m1a, m1b),
    ('src\\panel-mapa.txt', 'mapa: cuadro Foto y nombre', m2a, m2b),
    ('src\\panel-mapa.txt', 'mapa: funciones para abrir y guardar el nombre', m3a, m3b),
    ('src\\panel-index.html', 'recargar el mapa nuevo (v=4)', h1a, h1b),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-renombrar-equipo-panel.ps1 - Ojo Guard MS: desde la tarjeta del mapa, el boton de la foto del equipo abre "Foto y nombre": se puede cambiar el nombre del equipo (por ejemplo "Celu chapas") o la foto.
# Idea de Luciano (29/10/2026): evitar la confusion cuando hay equipos con el mismo nombre. El servidor no deja repetir el nombre de otro equipo del mismo titular.
# Cambia src\\index.ts, src\\panel-mapa.txt y src\\panel-index.html (solo sube a v=4 el numero del script; respaldo .bak-renombrar). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'renameDevice') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=3') -ne 1) { Mal "Falta aplicar primero aplicar-foto-perfil-mapa2-panel.ps1 (el mapa tiene que estar en v=3). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-renombrar')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: en el mapa, tocá la foto de tu equipo para cambiar su nombre. Recargá la pagina del mapa."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
open(R + 'aplicar-renombrar-equipo-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), 'no ascii raros:', set(bad))
