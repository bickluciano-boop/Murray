import { createServer } from "node:http";
const hace2 = (min: number) => new Date(Date.now() - min * 60_000).toISOString();
sqlite.prepare("INSERT INTO devices (id,name,owner_email,platform,battery,last_seen_at,last_location_json,last_location_at,push_token,approval_status,device_role) VALUES (?,?,?,?,?,?,?,?,?,?,?)")
  .run("dev1", "Celu de Lucas", "lucas@correo.com", "android", 8, hace2(150), JSON.stringify({ latitude: -34.52, longitude: -58.4, address: "Av. Siempre Viva 742" }), hace2(150), "ExpoPushToken[abc]", "approved", "primary");
sqlite.prepare("INSERT INTO family_members (id,owner_email,member_email,name,owner_name,role,status) VALUES (?,?,?,?,?,?,?)").run("fm1", "lucas@correo.com", "tomi@correo.com", "Tomi", "Lucas", "menor", "activo");
sqlite.prepare("INSERT INTO family_members (id,owner_email,member_email,name,owner_name,role,status) VALUES (?,?,?,?,?,?,?)").run("fm2", "lucas@correo.com", "ana@correo.com", "Ana", "Lucas", "adulto", "activo");
sqlite.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)").run("pl1", "lucas@correo.com", "Casa", -34.49, -58.4, 150, new Date().toISOString());
setSesion({ email: "lucas@correo.com", method: "passkey" });
// Google Rutas de mentira (para ver la pantalla con el tiempo calculado por mapas): 13 minutos, termina en la Casa de prueba
const fetchReal = globalThis.fetch;
globalThis.fetch = (async (url: any, init: any) => String(url).includes("routes.googleapis.com")
  ? new Response(JSON.stringify({ routes: [{ duration: "780s", distanceMeters: 3000, legs: [{ endLocation: { latLng: { latitude: -34.49, longitude: -58.4 } } }] }] }), { status: 200 })
  : String(url).includes("places.googleapis.com")
    ? new Response(JSON.stringify({ suggestions: [
      { placePrediction: { placeId: "ChIJabcdefghij1", structuredFormat: { mainText: { text: "Av. Cabildo 2359" }, secondaryText: { text: "Belgrano, Buenos Aires" } } } },
      { placePrediction: { placeId: "ChIJabcdefghij2", structuredFormat: { mainText: { text: "Av. Cabildo 2359" }, secondaryText: { text: "Rosario, Santa Fe" } } } },
    ] }), { status: 200 })
    : fetchReal(url, init)) as any;
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
    else if (ruta === "GET /camino") r = gdPaginaCamino();
    else if (url.pathname === "/api/guardian") r = await gdApi(request, env);
    else if (ruta === "POST /__clave") { (env as any).GOOGLE_ROUTES_KEY = cuerpo === "1" ? "clave-de-prueba" : ""; r = json({ ok: true }); }
    else if (ruta === "POST /__gd-cron") { await gdCron(env); r = json({ ok: true }); }
    else if (ruta === "POST /__gd-minutos") { sqlite.prepare("UPDATE gd_viajes SET deadline_at=? WHERE estado IN ('en_camino','aviso','alerta')").run(new Date(Date.now() + Number(cuerpo) * 60_000).toISOString()); r = json({ ok: true }); }
    else if (ruta === "GET /__correos") r = json(correos);
    else if (ruta === "POST /__correo-falla") { setCorreoOk(cuerpo !== "1"); r = json({ ok: true }); }
    else if (ruta === "POST /__sesion") { setSesion(JSON.parse(cuerpo || "null")); r = json({ ok: true }); }
    else r = new Response("no", { status: 404 });
  } catch (e) { console.error("ERROR", e); r = new Response("error", { status: 500 }); }
  res.writeHead(r.status, Object.fromEntries(r.headers));
  res.end(Buffer.from(await r.arrayBuffer()));
});
servidor.listen(8799, () => console.log("escuchando 8799"));
