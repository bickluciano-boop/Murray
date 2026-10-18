let fallos = 0, total = 0;
function ok(cond: unknown, texto: string) { total++; if (!cond) { fallos++; console.log("  FALLA:", texto); } else console.log("  ok:", texto); }
const ORIGEN = "https://panel.test";
const DUENIO = "lucas@correo.com";
const hace = (min: number) => new Date(Date.now() - min * 60_000).toISOString();
function dispositivo(o: { seen: number; bat: number; lat: number; lng: number; plat?: string }) {
  sqlite.exec("DELETE FROM devices");
  sqlite.prepare("INSERT INTO devices (id,name,owner_email,platform,battery,last_seen_at,last_location_json,last_location_at,push_token,approval_status,device_role) VALUES (?,?,?,?,?,?,?,?,?,?,?)")
    .run("dev1", "Celu de Lucas", DUENIO, o.plat ?? "android", o.bat, hace(o.seen), JSON.stringify({ latitude: o.lat, longitude: o.lng, address: "Av. Siempre Viva 742" }), hace(o.seen), "ExpoPushToken[abc]", "approved", "primary");
}
function token(correo: string) { const m = /t=([a-z0-9.]+)/.exec(correo); return m ? m[1] : ""; }
const hora = pldHoraBA(Date.now());
const ventanaAhora = { nightFrom: hora, nightTo: (hora + 1) % 24 };       // ahora es "de noche"
const ventanaOtra = { nightFrom: (hora + 3) % 24, nightTo: (hora + 5) % 24 }; // ahora es "de dia"
async function api(cuerpo?: unknown) { return pldApiDuenio(pedido(ORIGEN + "/api/remote/por-las-dudas", cuerpo === undefined ? "GET" : "POST", cuerpo), env); }

console.log("== Dueno: referentes y condiciones");
setSesion({ email: DUENIO, method: "passkey" });
let r = await api();
ok(r.status === 200, "GET panorama 200");
let d: any = await r.json();
ok(d.config.minSignals === 3 && d.referentes.length === 0, "valores por defecto y sin referentes");
r = await api({ accion: "agregar", name: "Mama", email: "mama@correo.com" });
ok(r.status === 200, "agregar referente");
ok(correos.length === 1 && correos[0].to === "mama@correo.com" && /referente/.test(correos[0].subject), "le llega el mail de invitacion");
const tokenMama = token(correos[0].html);
ok(/^ref[a-f0-9]+\.[a-f0-9]{36}$/.test(tokenMama), "el mail trae un enlace personal con token");
ok((await api({ accion: "agregar", name: "X", email: "lucas@correo.com" })).status === 400, "no se puede ser referente de uno mismo");
ok((await api({ accion: "agregar", name: "Mama2", email: "MAMA@correo.com" })).status === 409, "correo repetido (sin mirar mayusculas)");
ok((await api({ accion: "agregar", name: "", email: "x@y.com" })).status === 400, "nombre vacio");
ok((await api({ accion: "agregar", name: "Mal", email: "no-es-un-correo" })).status === 400, "correo invalido");
for (const [n, c] of [["Papa", "papa@c.com"], ["Tia", "tia@c.com"], ["Amigo", "amigo@c.com"], ["Hermana", "her@c.com"]]) await api({ accion: "agregar", name: n, email: c });
ok((await api({ accion: "agregar", name: "Sexto", email: "sexto@c.com" })).status === 409, "maximo 5 referentes");
d = await (await api()).json();
ok(d.referentes.length === 5 && d.referentes.every((x: any) => !("token_hash" in x) && !("tokenHash" in x)), "la lista no expone el token");
const idTia = d.referentes.find((x: any) => x.name === "Tia").id;
ok((await api({ accion: "quitar", id: idTia })).status === 200, "quitar un referente");
ok((await api({ accion: "quitar", id: idTia })).status === 404, "quitar dos veces da 404");
r = await api({ accion: "config", config: { nightFrom: 22, nightTo: 7, minSignals: 9, farKm: 0, batteryPct: 99, displayName: "Lucas B" } });
d = await r.json();
ok(d.config.nightFrom === 22 && d.config.minSignals === 4 && d.config.farKm === 0.5 && d.config.batteryPct === 50 && d.config.displayName === "Lucas B", "las condiciones se guardan y se limitan a rangos validos");
setSesion({ email: DUENIO, method: "emergency" });
ok((await api()).status === 403, "con acceso de emergencia no se puede");
setSesion(null);
ok((await api()).status === 401, "sin sesion 401");
setSesion({ email: DUENIO, method: "passkey" });

console.log("== Referente: aceptar");
let est = await (await pldApiReferenteEstado(pedido(ORIGEN + "/api/referente/estado", "POST", { t: tokenMama }), env)).json() as any;
ok(est.ok && est.quien === "Lucas B" && est.status === "pendiente", "el enlace muestra de quien es y que falta aceptar");
ok((await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: tokenMama + "0" }), env)).status === 404, "token alterado: 404");
ok((await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).status === 409, "no puede buscar sin aceptar");
await pldApiReferenteAceptar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env);
est = await (await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json() as any;
ok(est.status === "aceptado", "aceptado");
ok(correos.some((c) => c.to === DUENIO && /acept/.test(c.subject)), "se le avisa al dueno que acepto");

console.log("== No lo encuentro: telefono con normalidad");
await api({ accion: "config", config: { ...ventanaAhora, nightFrom: ventanaAhora.nightFrom, nightTo: ventanaAhora.nightTo, minSignals: 3, silenceNightMin: 90, silenceDayMin: 360, farKm: 3, batteryPct: 15 } });
dispositivo({ seen: 2, bat: 80, lat: -34.6, lng: -58.4 });
const antes = correos.length;
let b: any = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json();
ok(b.ok && b.mostrar === false && /normalidad/.test(b.mensaje), "con el telefono normal NO se muestra la ubicacion");
ok(!JSON.stringify(b).includes("-34.6"), "la respuesta no filtra coordenadas");
ok(correos.length === antes + 1 && correos[antes].to === DUENIO && /Est\u00e1s bien/.test(correos[antes].html) && /estoy-bien\?t=/.test(correos[antes].html), "se le manda el Estas bien? a la persona con su enlace");
ok(avisos.length === 1 && avisos[0].token === "ExpoPushToken[abc]", "y un aviso en su telefono");
ok(pings.length === 1, "en Android se pide una ubicacion nueva");
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json();
ok(correos.length === antes + 1, "apretar de nuevo antes de 10 minutos no manda otro mail");

console.log("== No lo encuentro: condiciones cumplidas (de noche, lejos, bateria baja, sin senal)");
await api({ accion: "casa", lat: -34.6, lng: -58.4 });
dispositivo({ seen: 150, bat: 8, lat: -34.52, lng: -58.4 }); // ~8.9 km de casa
sqlite.exec("DELETE FROM pld_checkins");
const antes2 = correos.length;
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json();
ok(b.mostrar === true && b.ubicacion.lat === -34.52 && /google\.com\/maps/.test(b.ubicacion.mapa), "se muestra la ultima senal con el mapa");
ok(b.senales.filter((s: any) => s.cumple).length === 4, "las 4 senales se cumplen: " + b.senales.map((s: any) => s.texto + (s.cumple ? "*" : "")).join(" | "));
ok(correos.some((c, i) => i >= antes2 && c.to === DUENIO && /consult/.test(c.subject)), "se le avisa a la persona que consultaron");

console.log("== La persona responde Estoy bien");
const mailChk = correos.filter((c) => c.to === DUENIO && /estoy-bien/.test(c.html)).pop()!;
const tokenChk = token(mailChk.html);
ok((await pldApiEstoyBien(pedido(ORIGEN + "/x", "POST", { t: tokenChk + "9" }), env)).status === 404, "enlace de Estoy bien alterado: 404");
const antes3 = correos.length;
ok((await pldApiEstoyBien(pedido(ORIGEN + "/x", "POST", { t: tokenChk }), env)).status === 200, "Estoy bien");
ok(correos.length === antes3 + 1 && correos[antes3].to === "mama@correo.com" && /bien/.test(correos[antes3].subject), "se le avisa al referente que esta bien");
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json();
ok(b.mostrar === false && b.estaBien === true && !JSON.stringify(b).includes("-34.52"), "despues de Estoy bien no se muestra nada");

console.log("== Emergencia (de dia, cerca de casa, bateria alta, 200 min sin senal)");
sqlite.exec("DELETE FROM pld_checkins");
await api({ accion: "config", config: { ...ventanaOtra } });
dispositivo({ seen: 200, bat: 80, lat: -34.6, lng: -58.4 });
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama, emergencia: false }), env)).json();
ok(b.mostrar === false, "sin marcar emergencia no se muestra");
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama, emergencia: true }), env)).json();
ok(b.mostrar === true, "marcando emergencia y pasadas 3 horas, se muestra");
dispositivo({ seen: 100, bat: 80, lat: -34.6, lng: -58.4 });
sqlite.exec("DELETE FROM pld_checkins");
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama, emergencia: true }), env)).json();
ok(b.mostrar === false, "emergencia pero solo 100 minutos: no se muestra");

console.log("== Apagado en movimiento con bateria alta");
sqlite.exec("DELETE FROM pld_checkins");
dispositivo({ seen: 15, bat: 70, lat: -34.6, lng: -58.4 });
sqlite.exec("DELETE FROM location_history");
sqlite.prepare("INSERT INTO location_history (id,device_id,latitude,longitude,captured_at) VALUES (?,?,?,?,?)").run("h1", "dev1", -34.60, -58.40, hace(25));
sqlite.prepare("INSERT INTO location_history (id,device_id,latitude,longitude,captured_at) VALUES (?,?,?,?,?)").run("h2", "dev1", -34.65, -58.40, hace(15)); // ~5.5 km en 10 min
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json();
ok(b.mostrar === true && b.apagadoEnMovimiento === true, "silencio repentino yendo en vehiculo con bateria alta: se muestra enseguida");
sqlite.exec("DELETE FROM location_history");

console.log("== Lugares seguros y pausa");
sqlite.exec("DELETE FROM pld_checkins");
await api({ accion: "config", config: { ...ventanaAhora } });
dispositivo({ seen: 150, bat: 8, lat: -34.52, lng: -58.4 });
sqlite.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)").run("p1", DUENIO, "Casa de Mati", -34.52, -58.4, 300, now());
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json();
ok(b.senales.find((x: any) => x.clave === "lejos").cumple === false && b.senales.filter((x: any) => x.cumple).length === 3, "estar en un lugar seguro de la familia no cuenta como lejos (quedan 3 de 4)");
sqlite.exec("DELETE FROM pld_checkins");
await api({ accion: "config", config: { minSignals: 4 } });
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json();
ok(b.mostrar === false, "pidiendo 4 de 4, el lugar seguro evita que se muestre");
await api({ accion: "config", config: { minSignals: 3 } });
sqlite.exec("DELETE FROM family_places");
sqlite.exec("DELETE FROM pld_checkins");
await api({ accion: "pausa", horas: 8 });
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json();
ok(b.mostrar === false && /paus/.test(b.mensaje), "con la pausa no se muestra: " + b.mensaje);
await api({ accion: "pausa", horas: 0 });
sqlite.exec("DELETE FROM pld_checkins");
await api({ accion: "config", config: { enabled: false } });
b = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).json();
ok(b.mostrar === false, "apagado: no se muestra");
await api({ accion: "config", config: { enabled: true } });

console.log("== Baja del referente y paginas");
await api({ accion: "quitar", id: tokenMama.split(".")[0] });
ok((await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: tokenMama }), env)).status === 404, "un referente dado de baja ya no puede buscar");
for (const [nombre, f] of [["duenio", pldPaginaDuenio], ["referente", pldPaginaReferente], ["estoy-bien", pldPaginaEstoyBien]] as const) {
  const p = (f as any)(); const t = await p.text();
  ok(p.status === 200 && /NÚCLEO · EN VALIDACIÓN/.test(t) && /<script>/.test(t) && !/\$\{/.test(t), "pagina " + nombre + " bien formada y con la etiqueta de estado");
}
const reg = (await (await api()).json() as any).registro;
ok(reg.length > 5 && reg.some((x: any) => x.kind === "consulta") && reg.some((x: any) => x.kind === "estoy-bien"), "el registro guarda consultas y respuestas");
console.log("== Enlace del referente (por si el mail no llega)");
setSesion({ email: DUENIO, method: "passkey" });
sqlite.exec("DELETE FROM pld_referentes");
let rr: any = await (await api({ accion: "agregar", name: "Tio", email: "tio@correo.com" })).json();
ok(rr.invitacion && rr.invitacion.enviado === true && /\/referente\?t=ref[a-f0-9]+\.[a-f0-9]{36}$/.test(rr.invitacion.enlace), "al agregar la API devuelve el enlace y que el mail salio");
const tokenTio = rr.invitacion.enlace.split("t=")[1];
let es: any = await (await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: tokenTio }), env)).json();
ok(es.ok && es.referente === "Tio", "ese enlace sirve para entrar como referente");
setCorreoOk(false);
rr = await (await api({ accion: "agregar", name: "Prima", email: "prima@correo.com" })).json();
ok(rr.invitacion && rr.invitacion.enviado === false && rr.invitacion.enlace.includes("/referente?t="), "si el mail falla, lo dice y igual da el enlace");
setCorreoOk(true);
const idTio = rr.referentes.find((x: any) => x.name === "Tio").id;
rr = await (await api({ accion: "reenviar", id: idTio })).json();
const tokenTio2 = rr.invitacion.enlace.split("t=")[1];
ok(rr.invitacion.enviado === true && tokenTio2 === tokenTio, "reenviar manda el mismo enlace (no deja sin efecto el anterior)");
ok((await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: tokenTio }), env)).status === 200, "el enlace del primer mail sigue sirviendo");
ok(correos.filter((c) => c.to === "tio@correo.com").length === 2 && token(correos.filter((c) => c.to === "tio@correo.com")[1].html) === tokenTio, "los dos mails llevan el mismo enlace");
const mailTio = correos.filter((c) => c.to === "tio@correo.com")[0].html;
ok((mailTio.match(new RegExp("referente\\?t=" + tokenTio.replace(".", "\\."), "g")) ?? []).length === 2, "el mail trae el enlace en el boton y escrito debajo");
const panorama: any = await (await api()).json();
ok(!("invitacion" in panorama), "una consulta comun no repite el enlace");

console.log("== Enlaces que el servidor puede rearmar");
{
  sqlite.exec("DELETE FROM pld_referentes; DELETE FROM pld_checkins; DELETE FROM pld_episodios");
  // referente de la primera version: el secreto es al azar y solo se guardo su huella
  sqlite.prepare("INSERT INTO pld_referentes (id,owner_email,name,email,token_hash,status,created_at) VALUES (?,?,?,?,?,?,?)").run("refviejo1", DUENIO, "Viejo", "viejo@correo.com", await hash("secretoviejo"), "aceptado", now());
  ok((await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: "refviejo1.secretoviejo" }), env)).status === 200, "un enlace de la primera version sigue sirviendo");
  const enlaceNuevo = await pldEnlaceReferente(env, ORIGEN, { id: "refviejo1", tokenHash: await hash("secretoviejo") });
  ok((await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: enlaceNuevo.split("t=")[1] }), env)).status === 200, "al referente viejo tambien se le puede armar un enlace firmado");
  ok((await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: "refviejo1.otro" }), env)).status === 404, "un secreto cualquiera no sirve");
  ok((await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: "refviejo1." + "0".repeat(36) }), env)).status === 404, "una firma inventada no sirve");
  const firmaChk = await pldFirma(env, "chk", "refviejo1", await hash("secretoviejo"));
  ok((await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: "refviejo1." + firmaChk }), env)).status === 404, "la firma de un 'Estoy bien' no sirve como enlace de referente");
  sqlite.exec("UPDATE pld_referentes SET status='baja' WHERE id='refviejo1'");
  ok((await pldApiReferenteEstado(pedido(ORIGEN + "/x", "POST", { t: enlaceNuevo.split("t=")[1] }), env)).status === 404, "dado de baja, ni el enlace firmado sirve");
}

console.log("== Aviso automatico (cron)");
const mailsDesde = (n: number) => correos.slice(n);
const episodio = () => sqlite.prepare("SELECT * FROM pld_episodios WHERE owner_email=?").get(DUENIO) as any;
function limpiar() { sqlite.exec("DELETE FROM pld_referentes; DELETE FROM pld_checkins; DELETE FROM pld_episodios; DELETE FROM pld_log; DELETE FROM family_places; DELETE FROM location_history"); avisos.length = 0; pings.length = 0; }
async function altaAceptada(nombre: string, correo: string) {
  const x: any = await (await api({ accion: "agregar", name: nombre, email: correo })).json();
  const t = x.invitacion.enlace.split("t=")[1];
  await pldApiReferenteAceptar(pedido(ORIGEN + "/x", "POST", { t }), env);
  return t as string;
}
async function preparar(cfg: Record<string, unknown> = {}) {
  limpiar();
  setSesion({ email: DUENIO, method: "passkey" });
  await api({ accion: "pausa", horas: 0 });
  await api({ accion: "config", config: { ...ventanaAhora, enabled: true, displayName: "Lucas", minSignals: 2, silenceNightMin: 90, silenceDayMin: 90, farKm: 3, batteryPct: 15, emergencyHours: 3, ...cfg } });
  const t = { mama: await altaAceptada("Mama", "mama@correo.com"), papa: await altaAceptada("Papa", "papa@correo.com") };
  await api({ accion: "agregar", name: "Pendiente", email: "pend@correo.com" }); // no acepto: no recibe nada
  dispositivo({ seen: 150, bat: 80, lat: -34.6, lng: -58.4 }); // sin senal hace 150 min y "de noche": 2 de 4
  return t;
}

{
  const t = await preparar();
  let n = correos.length;
  await pldCron(env);
  let nuevos = mailsDesde(n);
  ok(nuevos.length === 1 && nuevos[0].to === DUENIO && /Estás bien/.test(nuevos[0].subject) && /estoy-bien\?t=/.test(nuevos[0].html), "primera corrida: solo se le pregunta a la persona si esta bien (mail con su boton)");
  ok(/2 de 4/.test(nuevos[0].html) && /unos 15 minutos/.test(nuevos[0].html), "el mail explica por que y que pasa si no responde");
  ok(avisos.length === 1 && avisos[0].token === "ExpoPushToken[abc]" && /Estoy bien/.test(avisos[0].body), "y un aviso en el telefono");
  ok(avisos[0].body.indexOf("Abrí tu correo") === -1, "el aviso del telefono ya no manda a 'abrir el correo'");
  ok(pings.length === 1, "en Android se pide una ubicacion nueva");
  let ep = episodio();
  ok(ep && ep.alerts === 0 && ep.state === "abierto" && ep.checkin_at, "queda un episodio abierto");
  n = correos.length;
  await pldCron(env);
  ok(correos.length === n, "segunda corrida enseguida: todavia se espera la respuesta (no se avisa a los referentes)");

  sqlite.prepare("UPDATE pld_episodios SET checkin_at=? WHERE owner_email=?").run(hace(16), DUENIO);
  n = correos.length;
  await pldCron(env);
  nuevos = mailsDesde(n);
  const aReferentes = nuevos.filter((c) => /lleva rato sin dar señales/.test(c.subject));
  ok(aReferentes.length === 2 && aReferentes.map((c) => c.to).sort().join() === "mama@correo.com,papa@correo.com", "a los 15 minutos sin respuesta se les avisa a los 2 referentes que aceptaron (no al pendiente)");
  ok(!nuevos.some((c) => c.to === "pend@correo.com"), "el que no acepto no recibe nada");
  const linkMama = token(aReferentes.find((c) => c.to === "mama@correo.com")!.html);
  const linkPapa = token(aReferentes.find((c) => c.to === "papa@correo.com")!.html);
  ok(linkMama === t.mama && linkPapa === t.papa, "cada mail lleva el enlace personal del referente (el mismo de su invitacion)");
  ok(/Ver su última señal/.test(aReferentes[0].html) && (aReferentes[0].html.match(/referente\?t=/g) ?? []).length === 2, "con el boton y el enlace escrito");
  ok(/Se cumplen 2 de 4/.test(aReferentes[0].html) && /Sin señal hace/.test(aReferentes[0].html) && /De noche/.test(aReferentes[0].html), "y dice que condiciones se cumplen");
  const alPersona = nuevos.filter((c) => c.to === DUENIO);
  ok(alPersona.length === 1 && /Les avisamos a tus referentes/.test(alPersona[0].subject) && /Mama, Papa/.test(alPersona[0].html) && /estoy-bien\?t=/.test(alPersona[0].html), "la persona se entera a quienes se les aviso, con su boton Estoy bien");
  ok(episodio().alerts === 1, "el episodio cuenta 1 aviso");
  // con ese enlace el referente puede ver la ultima senal
  const buscar: any = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: linkMama }), env)).json();
  ok(buscar.mostrar === true && buscar.ubicacion.lat === -34.6, "con el enlace del aviso el referente ve la ultima senal");

  n = correos.length;
  await pldCron(env);
  ok(correos.length === n, "otra corrida enseguida: no se repite el aviso");
  sqlite.prepare("UPDATE pld_episodios SET last_alert_at=? WHERE owner_email=?").run(hace(31), DUENIO);
  n = correos.length;
  await pldCron(env);
  nuevos = mailsDesde(n);
  ok(nuevos.filter((c) => /lleva rato/.test(c.subject)).length === 2 && !nuevos.some((c) => /Les avisamos/.test(c.subject)) && /aviso 2 de 4/.test(nuevos.find((c) => /lleva rato/.test(c.subject))!.html), "a los 30 minutos se repite el aviso (2 de 4) y no se vuelve a avisar a la persona");
  sqlite.prepare("UPDATE pld_episodios SET alerts=4,last_alert_at=? WHERE owner_email=?").run(hace(60), DUENIO);
  n = correos.length;
  await pldCron(env);
  ok(correos.length === n, "despues de 4 avisos no se manda mas");

  // el telefono vuelve a dar senal
  sqlite.prepare("UPDATE pld_episodios SET alerts=2 WHERE owner_email=?").run(DUENIO);
  dispositivo({ seen: 1, bat: 79, lat: -34.6, lng: -58.4 });
  n = correos.length;
  await pldCron(env);
  nuevos = mailsDesde(n);
  ok(nuevos.length === 2 && nuevos.every((c) => /volvió a dar señal/.test(c.subject)) && episodio() === undefined, "al volver a dar senal se les avisa a los referentes y se cierra el episodio");
  n = correos.length;
  await pldCron(env);
  ok(correos.length === n, "con el telefono normal no pasa nada");
}

console.log("== Aviso automatico: la persona responde Estoy bien");
{
  await preparar();
  await pldCron(env);
  sqlite.prepare("UPDATE pld_episodios SET checkin_at=? WHERE owner_email=?").run(hace(16), DUENIO);
  await pldCron(env);
  const mailAviso = correos.filter((c) => c.to === DUENIO && /Les avisamos/.test(c.subject)).pop()!;
  const tokenChk2 = token(mailAviso.html);
  let n = correos.length;
  ok((await pldApiEstoyBien(pedido(ORIGEN + "/x", "POST", { t: tokenChk2 }), env)).status === 200, "toca Estoy bien en el mail de 'Les avisamos'");
  const nuevos = mailsDesde(n);
  ok(nuevos.length === 2 && nuevos.every((c) => /dice que está bien/.test(c.subject)) && /No hace falta hacer nada/.test(nuevos[0].html), "se les cuenta a los dos referentes que esta bien");
  ok(episodio().state === "respondio", "el episodio queda en 'respondio'");
  sqlite.prepare("UPDATE pld_episodios SET last_alert_at=? WHERE owner_email=?").run(hace(90), DUENIO);
  n = correos.length;
  await pldCron(env);
  ok(correos.length === n, "ya no se avisa mas mientras el telefono siga sin dar senal");
  dispositivo({ seen: 1, bat: 70, lat: -34.6, lng: -58.4 });
  await pldCron(env);
  ok(correos.length === n && episodio() === undefined, "cuando el telefono vuelve, el episodio se cierra sin mandar mas mails");
}

console.log("== Aviso automatico: respuesta antes de los 15 minutos");
{
  await preparar();
  await pldCron(env);
  const mailChk3 = correos.filter((c) => c.to === DUENIO && /estoy-bien/.test(c.html)).pop()!;
  const n0 = correos.length;
  ok((await pldApiEstoyBien(pedido(ORIGEN + "/x", "POST", { t: token(mailChk3.html) }), env)).status === 200, "toca Estoy bien en el primer mail");
  ok(correos.length === n0, "como todavia no se avisó a nadie, no se manda nada a los referentes");
  sqlite.prepare("UPDATE pld_episodios SET checkin_at=? WHERE owner_email=?").run(hace(20), DUENIO);
  const n = correos.length;
  await pldCron(env);
  ok(correos.length === n && episodio().alerts === 0, "no se les avisa a los referentes");
  sqlite.exec("DELETE FROM pld_episodios");
  await pldCron(env);
  ok(correos.length === n && episodio() === undefined, "dijo que estaba bien hace poco: no empieza otro episodio");
}

console.log("== Aviso automatico: apagado en movimiento con bateria alta");
{
  await preparar({ minSignals: 4 });
  dispositivo({ seen: 15, bat: 70, lat: -34.6, lng: -58.4 });
  sqlite.prepare("INSERT INTO location_history (id,device_id,latitude,longitude,captured_at) VALUES (?,?,?,?,?)").run("h1", "dev1", -34.60, -58.40, hace(25));
  sqlite.prepare("INSERT INTO location_history (id,device_id,latitude,longitude,captured_at) VALUES (?,?,?,?,?)").run("h2", "dev1", -34.65, -58.40, hace(15));
  const n = correos.length;
  await pldCron(env);
  const nuevos = mailsDesde(n);
  ok(nuevos.some((c) => c.to === DUENIO && /Estás bien/.test(c.subject) && /en movimiento/.test(c.html)), "se le pregunta a la persona (y el mail dice que paso en movimiento)");
  const avs = nuevos.filter((c) => /lleva rato/.test(c.subject));
  ok(avs.length === 2 && /yendo en vehículo/.test(avs[0].html), "y a los referentes se les avisa enseguida, sin esperar los 15 minutos");
}

console.log("== Aviso automatico: casos en que NO avisa");
{
  await preparar();
  dispositivo({ seen: 2, bat: 80, lat: -34.6, lng: -58.4 });
  let n = correos.length;
  await pldCron(env);
  ok(correos.length === n && episodio() === undefined, "con el telefono normal no se hace nada");
  dispositivo({ seen: 150, bat: 80, lat: -34.6, lng: -58.4 });
  await api({ accion: "pausa", horas: 8 });
  await pldCron(env);
  ok(correos.length === n && episodio() === undefined, "con la pausa 'Esta noche, afuera' no se hace nada");
  await api({ accion: "pausa", horas: 0 });
  await api({ accion: "config", config: { enabled: false } });
  await pldCron(env);
  ok(correos.length === n && episodio() === undefined, "con Por las dudas apagado no se hace nada");
  await api({ accion: "config", config: { enabled: true, ...ventanaOtra } }); // de dia, 150 min sin senal, cerca de casa: 1 de 4
  await pldCron(env);
  ok(correos.length === n && episodio() === undefined, "con solo 1 de 4 condiciones no se hace nada");
  await api({ accion: "config", config: { ...ventanaAhora } });
  sqlite.exec("UPDATE pld_referentes SET status='pendiente'");
  await pldCron(env);
  ok(correos.length === n && episodio() === undefined, "si ningun referente acepto no se hace nada");
}

console.log("== Aviso automatico: referente silenciado y mail que falla");
{
  const t = await preparar();
  sqlite.prepare("UPDATE pld_referentes SET muted_until=? WHERE id=?").run(pldEnMinutos(600), t.papa.split(".")[0]);
  await pldCron(env);
  sqlite.prepare("UPDATE pld_episodios SET checkin_at=? WHERE owner_email=?").run(hace(16), DUENIO);
  let n = correos.length;
  await pldCron(env);
  const avs = mailsDesde(n).filter((c) => /lleva rato/.test(c.subject));
  ok(avs.length === 1 && avs[0].to === "mama@correo.com", "el referente que silencio los avisos no recibe el aviso");
  sqlite.exec("UPDATE pld_referentes SET muted_until=NULL");
  sqlite.prepare("UPDATE pld_episodios SET alerts=0,last_alert_at=NULL WHERE owner_email=?").run(DUENIO);
  setCorreoOk(false);
  n = correos.length;
  await pldCron(env);
  ok(correos.length === n && episodio().alerts === 0, "si los mails fallan no se cuenta el aviso (se reintenta)");
  setCorreoOk(true);
  await pldCron(env);
  ok(mailsDesde(n).filter((c) => /lleva rato/.test(c.subject)).length === 2 && episodio().alerts === 1, "en la proxima corrida sale");
}

console.log("== Pulidos");
{
  const pr: any = pldPaginaReferente(); const txt = await pr.text();
  ok(/Coordenadas /.test(txt) && !/Sin dirección/.test(txt), "la ultima senal sin calle muestra las coordenadas");
  ok(/emergenciaHoras===1\?" hora":" horas"/.test(txt), "plural de 'hora' en la emergencia");
  ok(pldTiempo(1) === "1 minuto" && pldTiempo(5) === "5 minutos" && pldTiempo(60) === "1 hora" && pldTiempo(150) === "3 horas", "textos de tiempo");
}

console.log(`\n${total - fallos}/${total} pruebas ok`);
if (fallos) process.exit(1);
