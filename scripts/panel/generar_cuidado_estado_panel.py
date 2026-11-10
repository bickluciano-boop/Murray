# Genera scripts/aplicar-cuidado-estado-panel.ps1: el panel (mapa, tambien dentro de la app) muestra en la tarjeta de cada persona su estado de Cuidado:
# si apago su SOS, si la bateria esta baja o esta sin senal, y como va su "Buen dia" de hoy. Solo lo ve quien recibe el SOS de esa persona.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

# ---------------- servidor (src\index.ts) ----------------
VISTA = r'''/**
 * Como esta la persona en lo de "Cuidado", para quien recibe su SOS (la lista de personas del panel y de la app). Solo lee.
 * buenDiaHoy: null (apagado) | "programado" (todavia no es la hora) | "esperando" (saludo enviado, sin respuesta) | "contesto" | "sin_respuesta" (ya se aviso) | "manana" (hoy no salio).
 */
async function cuidadoVista(env: Env, email: string, bateria: number | null) {
  await cuidadoTabla(env);
  const prefs = await cuidadoPrefs(env, email), e = await cuidadoEstado(env, email);
  const loc = cuidadoLocal(Date.now(), prefs.tz);
  const minutosHora = Number(prefs.hora.slice(0, 2)) * 60 + Number(prefs.hora.slice(3, 5));
  const minutosAhora = Number(loc.hhmm.slice(0, 2)) * 60 + Number(loc.hhmm.slice(3, 5));
  let buenDiaHoy: string | null = null;
  if (prefs.buenDia) {
    if (e.bd_day === loc.dia && e.bd_sent_at) buenDiaHoy = e.bd_ok_at ? "contesto" : e.bd_alert_at ? "sin_respuesta" : "esperando";
    else buenDiaHoy = minutosAhora < minutosHora + CUIDADO_VENTANA_MIN ? "programado" : "manana";
  }
  return {
    sosApagado: await sosApagado(env, email),
    bateria: prefs.bateria,
    bateriaBaja: prefs.bateria && Boolean(e.bat_low) && typeof bateria === "number",
    sinSenal: prefs.bateria && Boolean(e.silence_at),
    buenDia: prefs.buenDia,
    buenDiaHora: prefs.hora,
    buenDiaHoy,
  };
}

'''
A0 = '/** GET /api/native/care: lo que la persona tiene prendido,'
B0 = VISTA + A0
A1 = '    people.push({\n      id: p.id,\n'
B1 = ('    // Cuidado de esa persona: solo lo ve quien recibe su SOS (a esos mismos se les avisa), y no en las consultas livianas.\n'
      '    const cuidado = !liviano && permisos.recibisSuSos.elegible && personas.size <= 12 ? await cuidadoVista(env, p.email, device?.battery ?? null).catch(() => null) : null;\n') + A1
A2 = '      permisos,\n      // Solo para quien administra a esa persona'
B2 = '      permisos,\n      cuidado,\n      // Solo para quien administra a esa persona'

# ---------------- panel (src\panel-mapa.txt) ----------------
P1a = '      cortado: Boolean(p.locCut),\n'
P1b = P1a + '      // Estado de Cuidado (SOS apagado, bateria y senal, Buen dia): solo viene si quien mira recibe el SOS de esa persona.\n      cuidado: p.cuidado || null,\n'
P2a = '/** En la tarjeta de una persona: el botón para avisarte y los avisos que ya armaste sobre ella. */\nfunction htmlAvisos(persona) {\n'
P2b = r'''/**
 * En la tarjeta de una persona: como esta lo suyo de "Cuidado" (lo prende o apaga ella desde su app): SOS, bateria y senal, y el "Buen dia" de hoy.
 * Rojo = hay que mirar; verde = bien; gris = apagado.
 */
function htmlCuidadoPersona(persona) {
  const c = persona.cuidado;
  if (!c) return "";
  const filas = [];
  filas.push(c.sosApagado ? ["off", "Apagó su SOS: si lo toca, no avisa a nadie."] : ["ok", "SOS prendido"]);
  if (!c.bateria) filas.push(["suave", "Aviso de batería y señal: apagado"]);
  else {
    if (c.bateriaBaja) filas.push(["off", `Batería baja${persona.bateria === null ? "" : ` (${Math.round(persona.bateria)} %)`}`]);
    if (c.sinSenal) filas.push(["off", persona.vistoEn ? `Sin señal desde ${haceCuanto(persona.vistoEn)}` : "Sin señal"]);
    if (!c.bateriaBaja && !c.sinSenal) filas.push(["ok", "Batería y señal: bien"]);
  }
  const hora = c.buenDiaHora || "";
  if (!c.buenDia) filas.push(["suave", "Buen día: apagado"]);
  else if (c.buenDiaHoy === "contesto") filas.push(["ok", "Buen día: contestó hoy"]);
  else if (c.buenDiaHoy === "sin_respuesta") filas.push(["off", `Buen día: no contestó el de las ${hora}`]);
  else if (c.buenDiaHoy === "esperando") filas.push(["suave", `Buen día: esperando que conteste (saludo de las ${hora})`]);
  else if (c.buenDiaHoy === "manana") filas.push(["suave", `Buen día: hoy no salió; mañana a las ${hora}`]);
  else filas.push(["suave", `Buen día: hoy a las ${hora}`]);
  const color = { ok: "var(--ogm-vivo)", off: "var(--ogm-off)", suave: "var(--ogm-suave)" };
  return `<div class="ogm-cuidado" style="margin:12px 0 0;padding:10px 12px;border:1px solid var(--ogm-linea);border-radius:12px;display:grid;gap:5px;font-size:0.8rem;line-height:1.35">
    <strong style="font-size:0.68rem;letter-spacing:0.08em;text-transform:uppercase;color:var(--ogm-suave)">Cuidado de ${esc(persona.nombre)}</strong>
    ${filas.map(([clase, texto]) => `<span style="color:${color[clase]}"><b aria-hidden="true">\u25cf </b>${esc(texto)}</span>`).join("")}
  </div>`;
}

''' + P2a
P3a = '    ${e.tipo === "persona" ? htmlAvisos(e) : ""}\n'
P3b = '    ${e.tipo === "persona" ? htmlCuidadoPersona(e) : ""}\n' + P3a
P4a = '    ${elegido.tipo === "persona" ? htmlAvisos(elegido) : ""}\n'
P4b = '    ${elegido.tipo === "persona" ? htmlCuidadoPersona(elegido) : ""}\n' + P4a

serv = [A0, A1, A2]; serv_n = [B0, B1, B2]
pan = [P1a, P2a, P3a, P4a]; pan_n = [P1b, P2b, P3b, P4b]
filas = [('src\\index.ts', 'cuidado: como esta la persona (funcion)', A0, B0),
         ('src\\index.ts', 'cuidado: se calcula para quien recibe su SOS', A1, B1),
         ('src\\index.ts', 'cuidado: viaja en cada persona', A2, B2),
         ('src\\panel-mapa.txt', 'mapa: la persona trae su cuidado', P1a, P1b),
         ('src\\panel-mapa.txt', 'mapa: bloque "Cuidado de ..." de la tarjeta', P2a, P2b),
         ('src\\panel-mapa.txt', 'mapa: bloque en la tarjeta de la app', P3a, P3b),
         ('src\\panel-mapa.txt', 'mapa: bloque en la tarjeta de la compu', P4a, P4b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-cuidado-estado-panel.ps1 - Ojo Guard MS: en la tarjeta de cada persona (mapa del panel, tambien dentro de la app) se ve como va lo suyo de Cuidado: SOS prendido o apagado, bateria baja / sin senal y el "Buen dia" de hoy.
# Luciano (10/11/2026): "prepara lo del panel". Solo lo ve quien recibe el SOS de esa persona (los mismos a quienes ella les avisa); lo prende o apaga cada persona desde su app. Solo lee: no cambia nada de lo que ya manda avisos.
# Requiere aplicar-cuidado-panel.ps1, aplicar-sos-apagar-panel.ps1 y aplicar-mapa-ubicacion-cortada-panel.ps1. Cambia src\\index.ts y src\\panel-mapa.txt (respaldo .bak-cuidado-estado). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-mapa.txt")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$indexTexto = (Leer (Join-Path $raiz "src\\index.ts")).texto
$mapaTexto = (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto
if ((Contar $indexTexto 'async function cuidadoVista') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'async function cuidadoCron') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-panel.ps1. No toco nada."; return }
if ((Contar $indexTexto 'async function sosApagado') -eq 0) { Mal "Falta aplicar primero aplicar-sos-apagar-panel.ps1. No toco nada."; return }
if ((Contar $mapaTexto 'cortado: Boolean(p.locCut)') -eq 0) { Mal "Falta aplicar primero aplicar-mapa-ubicacion-cortada-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cuidado-estado')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la tarjeta de cada persona muestra su Cuidado (recarga la pagina con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-cuidado-estado-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-vos.ts', encoding='utf-8').read()
for a in serv:
    assert t.count(a) == 1, (t.count(a), a[:60])
for a, b in zip(serv, serv_n):
    t = t.replace(a, b)
open(S + 'index-estado.ts', 'w', encoding='utf-8').write(t)
m = open(S + 'panel-mapa-ubicortada.txt', encoding='utf-8').read().replace('\r\n', '\n')
for a in pan:
    assert m.count(a) == 1, (m.count(a), a[:60])
for a, b in zip(pan, pan_n):
    m = m.replace(a, b)
open(S + 'panel-mapa-estado.txt', 'w', encoding='utf-8').write(m)
print('ok', len(total))
