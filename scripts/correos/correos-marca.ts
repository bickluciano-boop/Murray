// Correos con la imagen nueva de Ojo Guard (azul, blanco y dorado). Logo en PNG 588x108 (los correos no muestran SVG).
const LOGO_CORREO_NUEVO_B64 = "__LOGO_B64__";
function logoCorreoNuevoResponse() {
  const bytes = Uint8Array.from(atob(LOGO_CORREO_NUEVO_B64), (c) => c.charCodeAt(0));
  return new Response(bytes, { headers: { "content-type": "image/png", "cache-control": "public, max-age=86400", "x-content-type-options": "nosniff" } });
}
// Los cuerpos de los correos estan escritos con la paleta oscura de antes; aca se pasan a la paleta clara de la marca.
function claroCorreo(html: string) {
  const mapa: Array<[string, string]> = [
    ["background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px", "background:#ffffff;color:#14213D;padding:28px;border:1px solid #E3E7F1;border-top:0;border-radius:0 0 16px 16px"],
    ["max-width:560px", "max-width:620px"],
    ["background:#d9b24c;color:#111", "background:#1F4FD1;color:#ffffff"],
    ["background:#201c12;border:1px solid #56461d;border-radius:12px;color:#e4d7ad", "background:#FFF3D6;border:1px solid #F0D79A;border-radius:12px;color:#7A5200"],
    ["<strong style=\"color:#fff\">", "<strong style=\"color:#14213D\">"],
    ["background:#0c0d0f", "background:#ffffff"],
    ["color:#f6f6f2", "color:#14213D"],
    ["color:#d2d2ce", "color:#3E4A6B"],
    ["color:#8f8d85", "color:#5B6580"],
    ["color:#8d8d88", "color:#5B6580"],
    ["color:#f4c64e", "color:#7A5200"],
    ["color:#ff8a7a", "color:#C62828"],
    ["color:#d9b24c", "color:#1F4FD1"],
    ["ojo guard &middot; modo cautela", "Ojo Guard &middot; modo cautela"],
  ];
  let r = html;
  for (const [viejo, nuevo] of mapa) r = r.split(viejo).join(nuevo);
  return r;
}
// Arriba: franja azul marino con el logo y, al lado, que se pidio o que paso y de que equipo. Abajo: el cuerpo en blanco.
function conMarcaCorreoNuevo(html: string, asunto?: unknown) {
  if (html.includes("data-og-marca")) return html;
  const logo = `${DEFAULT_PANEL_URL}marca/ojo-guard-correo.png`;
  let titulo = String(asunto ?? "").replace(/^(Aviso de seguridad|Alerta de seguridad|Ojo Guard)\s*[\u00b7\u2014:-]\s*/i, "").trim().slice(0, 90);
  let equipo = ((html.match(/<strong[^>]*>\s*Dispositivo:\s*<\/strong>\s*([^<]{1,60})/) || [])[1] ?? "").trim();
  const corte = titulo.lastIndexOf(" \u00b7 ");
  if (corte > 0) {
    const cola = textoCorreo(titulo.slice(corte + 3).trim());
    if (!equipo) equipo = cola;
    if (cola === equipo) titulo = titulo.slice(0, corte).trim();
  }
  const resumen = titulo || equipo
    ? `<div style="font-family:Arial,sans-serif;padding-top:14px">${titulo ? `<div style="color:#ffffff;font-size:15px;font-weight:700;line-height:1.35">${textoCorreo(titulo)}</div>` : ""}${equipo ? `<div style="color:#F1D58A;font-size:13px;margin-top:3px">${equipo}</div>` : ""}</div>`
    : "";
  return `<div style="background:#EEF2FB;padding:18px 10px"><div data-og-marca="1" style="max-width:620px;margin:0 auto;padding:18px 22px 16px;background:#0F1A3A;border-radius:16px 16px 0 0"><img src="${logo}" width="196" height="36" alt="Ojo Guard" style="display:block;border:0;outline:none;text-decoration:none">${resumen}</div>${claroCorreo(html)}<div style="max-width:620px;margin:0 auto;padding:16px 22px 0;text-align:center;font-family:Arial,sans-serif;font-size:13px;line-height:1.6;color:#5B6580">Tu panel de Ojo Guard: <a href="${DEFAULT_PANEL_URL}" style="color:#1F4FD1;font-weight:700;text-decoration:none">${DEFAULT_PANEL_URL.replace(/^https?:\/\//, "").replace(/\/$/, "")}</a><br>Guard&#225; este link: lo vas a necesitar si perd&#233;s el acceso. Soporte: soporte@ojoguard.app</div></div>`;
}
