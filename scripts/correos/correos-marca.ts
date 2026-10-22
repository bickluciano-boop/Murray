// Correos con la imagen nueva de Ojo Guard (azul, blanco y dorado). Logo en PNG 588x108 (los correos no muestran SVG).
const LOGO_CORREO_NUEVO_B64 = "__LOGO_B64__";
function logoCorreoNuevoResponse() {
  const bytes = Uint8Array.from(atob(LOGO_CORREO_NUEVO_B64), (c) => c.charCodeAt(0));
  return new Response(bytes, { headers: { "content-type": "image/png", "cache-control": "public, max-age=86400", "x-content-type-options": "nosniff" } });
}
// Los cuerpos de los correos estan escritos con la paleta oscura de antes; aca se pasan a la paleta clara de la marca y se compactan para el celular.
function claroCorreo(html: string) {
  const mapa: Array<[string, string]> = [
    ["background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px", "background:#ffffff;color:#14213D;padding:16px 18px;border:1px solid #E3E7F1;border-top:0;border-radius:0 0 14px 14px"],
    ["max-width:560px", "max-width:620px"],
    ["background:#d9b24c;color:#111", "background:#1F4FD1;color:#ffffff"],
    ["background:#201c12;border:1px solid #56461d;border-radius:12px;color:#e4d7ad", "background:#FFF3D6;border:1px solid #F0D79A;border-radius:12px;color:#7A5200"],
    ["margin-top:22px;padding:16px", "margin-top:12px;padding:12px;font-size:14px;line-height:1.4"],
    ["font-size:26px;margin:10px 0 18px", "font-size:21px;line-height:1.2;margin:4px 0 10px"],
    ["font-size:20px;font-weight:700;margin:0 0 14px", "font-size:17px;font-weight:700;margin:0 0 8px"],
    ["font-size:20px;font-weight:700;margin:0 0 12px", "font-size:17px;font-weight:700;margin:0 0 8px"],
    ["font-size:12px;font-weight:800;letter-spacing:.16em", "font-size:11px;font-weight:800;letter-spacing:.14em;margin:0"],
    ["padding:13px 22px", "padding:11px 20px"],
    ["padding:12px 16px", "padding:10px 16px"],
    ["margin:22px 0", "margin:12px 0"],
    ["margin:20px 0", "margin:12px 0"],
    ["margin:26px 0 0", "margin:12px 0 0"],
    ["<p style=\"color:#d2d2ce;line-height:1.55\">", "<p style=\"color:#3E4A6B;line-height:1.45;font-size:14px;margin:8px 0\">"],
    ["<p style=\"color:#d2d2ce\">", "<p style=\"color:#3E4A6B;font-size:14px;margin:6px 0\">"],
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
    ["<p>", "<p style=\"margin:6px 0;font-size:14px\">"],
  ];
  let r = html;
  for (const [viejo, nuevo] of mapa) r = r.split(viejo).join(nuevo);
  return r;
}
// Arriba: franja azul marino con el logo (y el titulo solo si el cuerpo no trae uno grande). Abajo: el cuerpo en blanco, compacto para verse entero en el celular.
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
  const resumen = (titulo || equipo) && !html.includes("<h1")
    ? `<div style="font-family:Arial,sans-serif;padding-top:10px;color:#ffffff;font-size:14px;font-weight:700;line-height:1.35">${textoCorreo(titulo)}</div>`
    : "";
  return `<div style="background:#EEF2FB;padding:8px 6px;-webkit-text-size-adjust:100%;text-size-adjust:100%"><div data-og-marca="1" style="max-width:620px;margin:0 auto;padding:12px 16px;background:#0F1A3A;border-radius:14px 14px 0 0"><img src="${logo}" width="150" height="28" alt="Ojo Guard" style="display:block;border:0;outline:none;text-decoration:none">${resumen}</div>${claroCorreo(html)}<div style="max-width:620px;margin:0 auto;padding:10px 12px 2px;text-align:center;font-family:Arial,sans-serif;font-size:12px;line-height:1.5;color:#5B6580">Tu panel de Ojo Guard: <a href="${DEFAULT_PANEL_URL}" style="color:#1F4FD1;font-weight:700;text-decoration:none">${DEFAULT_PANEL_URL.replace(/^https?:\/\//, "").replace(/\/$/, "")}</a><br>Guard&#225; este link por si perd&#233;s el acceso</div></div>`;
}
