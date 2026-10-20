import { createServer } from "node:http";
const hace2 = (min: number) => new Date(Date.now() - min * 60_000).toISOString();
sqlite.prepare("INSERT INTO devices (id,name,owner_email,platform,battery,last_seen_at,last_location_json,last_location_at,push_token,approval_status,device_role) VALUES (?,?,?,?,?,?,?,?,?,?,?)")
  .run("dev1", "Celu de Lucas", "lucas@correo.com", "android", 8, hace2(150), JSON.stringify({ latitude: -34.52, longitude: -58.4, address: "Av. Siempre Viva 742" }), hace2(150), "ExpoPushToken[abc]", "approved", "primary");
sqlite.prepare("INSERT INTO family_members (id,owner_email,member_email,name,owner_name,role,status) VALUES (?,?,?,?,?,?,?)").run("fm1", "lucas@correo.com", "tomi@correo.com", "Tomi", "Lucas", "menor", "activo");
sqlite.prepare("INSERT INTO family_members (id,owner_email,member_email,name,owner_name,role,status) VALUES (?,?,?,?,?,?,?)").run("fm2", "lucas@correo.com", "ana@correo.com", "Ana", "Lucas", "adulto", "activo");
setSesion({ email: "lucas@correo.com", method: "passkey" });
const servidor = createServer(async (req, res) => {
  const origen = "http://localhost:" + (servidor.address() as any).port;
  const url = new URL(req.url!, origen);
  const chunks: Buffer[] = []; for await (const c of req) chunks.push(c as Buffer);
  const cuerpo = chunks.length ? Buffer.concat(chunks).toString() : undefined;
  const request = new Request(url, { method: req.method, headers: { "content-type": "application/json" }, body: req.method === "GET" || !cuerpo ? undefined : cuerpo });
  const ruta = `${req.method} ${url.pathname}`;
  let r: Response;
  try {
    if (ruta === "GET /por-las-dudas") r = pldPaginaDuenio();
    else if (url.pathname === "/api/remote/por-las-dudas") r = await pldApiDuenio(request, env);
    else if (ruta === "GET /referente") r = pldPaginaReferente();
    else if (ruta === "POST /api/referente/estado") r = await pldApiReferenteEstado(request, env);
    else if (ruta === "POST /api/referente/aceptar") r = await pldApiReferenteAceptar(request, env);
    else if (ruta === "POST /api/referente/buscar") r = await pldApiReferenteBuscar(request, env);
    else if (ruta === "GET /estoy-bien") r = pldPaginaEstoyBien();
    else if (ruta === "POST /api/estoy-bien") r = await pldApiEstoyBien(request, env);
    else if (ruta === "GET /__correos") r = json(correos);
    else if (ruta === "POST /__correo-falla") { setCorreoOk(cuerpo !== "1"); r = json({ ok: true }); }
    else if (ruta === "POST /__sesion") { setSesion(JSON.parse(cuerpo || "null")); r = json({ ok: true }); }
    else r = new Response("no", { status: 404 });
  } catch (e) { console.error("ERROR", e); r = new Response("error", { status: 500 }); }
  res.writeHead(r.status, Object.fromEntries(r.headers));
  res.end(Buffer.from(await r.arrayBuffer()));
});
servidor.listen(8799, () => console.log("escuchando 8799"));
