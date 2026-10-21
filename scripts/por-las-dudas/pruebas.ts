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
  ok(correos.length === n && episodio() === undefined, "con la pausa de avisos no se hace nada");
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

console.log("== SOS: tambien se les avisa a los referentes");
{
  const t = await preparar();
  const ubic = { latitude: -34.6, longitude: -58.4, address: "Av. Siempre Viva 742" };
  ok((await pldTieneGuardianes(env, DUENIO)) === true, "con referentes que aceptaron, el SOS tiene a quien avisar aunque no haya familia");
  let n = correos.length;
  const e1 = await pldAvisarSos(env, DUENIO, ubic);
  let nuevos = mailsDesde(n);
  ok(e1 === 2 && nuevos.length === 2 && nuevos.every((c) => /SOS/.test(c.subject)) && nuevos.map((c) => c.to).sort().join() === "mama@correo.com,papa@correo.com", "al apretar el SOS les llega un mail a los 2 referentes que aceptaron (no al pendiente)");
  ok(/google\.com\/maps\?q=-34\.6,-58\.4/.test(nuevos[0].html) && /Av\. Siempre Viva 742/.test(nuevos[0].html) && /911/.test(nuevos[0].html), "con el mapa, la direccion y el aviso de llamar al 911");
  ok(token(nuevos.find((c) => c.to === "mama@correo.com")!.html) === t.mama, "y con su enlace personal para ver la ultima senal");
  ok(sqlite.prepare("SELECT COUNT(*) AS n FROM pld_log WHERE kind='sos'").get().n === 2, "queda en el registro");
  n = correos.length;
  const c1 = await pldAvisarSosCancelado(env, DUENIO, hace(2));
  nuevos = mailsDesde(n);
  ok(c1 === 2 && nuevos.every((c) => /cancel\u00f3 el SOS/.test(c.subject)), "si la persona cancela, se les cuenta a los 2 que habian recibido el aviso");
  n = correos.length;
  ok((await pldAvisarSosCancelado(env, DUENIO, new Date(Date.now() + 5000).toISOString())) === 0 && correos.length === n, "una cancelacion sin aviso previo no manda nada");
  // sin ubicacion
  n = correos.length;
  await pldAvisarSos(env, DUENIO, null);
  nuevos = mailsDesde(n);
  ok(nuevos.length === 2 && !/google\.com\/maps/.test(nuevos[0].html), "sin ubicacion igual avisa (sin el mapa)");
  // con el SOS en marcha, el enlace del referente muestra la ultima senal aunque no se cumplan las condiciones; al cancelarlo vuelve a lo de siempre
  const esp = () => new Promise((r) => setTimeout(r, 15));
  sqlite.exec("DELETE FROM pld_log; DELETE FROM pld_checkins; DELETE FROM pld_episodios");
  dispositivo({ seen: 2, bat: 80, lat: -34.6, lng: -58.4 });
  let bs: any = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: t.mama }), env)).json();
  ok(bs.ok && bs.mostrar === false && !bs.sos, "sin SOS y con el telefono normal el referente no ve la ubicacion");
  await esp(); await pldAvisarSos(env, DUENIO, ubic); await esp();
  n = correos.length;
  bs = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: t.mama }), env)).json();
  ok(bs.mostrar === true && bs.sos === true && bs.ubicacion.lat === -34.6 && !correos.slice(n).some((c) => /Est\u00e1s bien/.test(c.subject)), "con un SOS en marcha ve la ultima senal sin condiciones y sin mandarle un \u00bfEst\u00e1s bien? a quien pidio ayuda");
  ok(correos.slice(n).some((c) => c.to === DUENIO && /pediste ayuda con el SOS/.test(c.html)), "y a la persona se le cuenta que lo vio");
  await esp(); await pldAvisarSosCancelado(env, DUENIO, hace(1)); await esp();
  bs = await (await pldApiReferenteBuscar(pedido(ORIGEN + "/x", "POST", { t: t.mama }), env)).json();
  ok(bs.mostrar === false && !bs.sos, "cancelado el SOS vuelve a lo de siempre");
  ok((await (pldPaginaReferente() as any).text()).includes("SOS en marcha: "), "la pagina del referente avisa SOS en marcha");
  sqlite.exec("DELETE FROM pld_log; DELETE FROM pld_checkins");
  // la pausa no lo frena
  await api({ accion: "pausa", horas: 8 });
  n = correos.length;
  ok((await pldAvisarSos(env, DUENIO, ubic)) === 2 && correos.length === n + 2, "la pausa de avisos no frena un SOS");
  await api({ accion: "pausa", horas: 0 });
  // un referente silenciado no recibe
  sqlite.prepare("UPDATE pld_referentes SET muted_until=? WHERE id=?").run(pldEnMinutos(600), t.papa.split(".")[0]);
  n = correos.length;
  ok((await pldAvisarSos(env, DUENIO, ubic)) === 1 && mailsDesde(n)[0].to === "mama@correo.com", "el que silencio los avisos no lo recibe");
  sqlite.exec("UPDATE pld_referentes SET muted_until=NULL");
  // si los mails fallan no se cuenta
  setCorreoOk(false);
  n = correos.length;
  const antesLog = sqlite.prepare("SELECT COUNT(*) AS n FROM pld_log WHERE kind='sos'").get().n;
  ok((await pldAvisarSos(env, DUENIO, ubic)) === 0 && sqlite.prepare("SELECT COUNT(*) AS n FROM pld_log WHERE kind='sos'").get().n === antesLog, "si los mails fallan no se registra como avisado");
  setCorreoOk(true);
  // con el Modo Cautela apagado, el SOS avisa igual (es algo que la persona aprieta a proposito)
  await api({ accion: "config", config: { enabled: false } });
  n = correos.length;
  ok((await pldAvisarSos(env, DUENIO, ubic)) === 2 && correos.length === n + 2 && (await pldTieneGuardianes(env, DUENIO)) === true, "con el Modo Cautela apagado el SOS avisa igual y los referentes cuentan como destinatarios");
  await api({ accion: "config", config: { enabled: true } });
  // nadie acepto
  sqlite.exec("UPDATE pld_referentes SET status='pendiente'");
  ok((await pldTieneGuardianes(env, DUENIO)) === false && (await pldAvisarSos(env, DUENIO, ubic)) === 0, "si ningun referente acepto no hay a quien avisar");
  ok(/tambi\u00e9n se les avisa a ellos/.test(await (pldPaginaDuenio() as any).text()), "la pagina de la persona cuenta que el SOS tambien les avisa");
}

console.log("== Estado de tu telefono (panorama)");
{
  await preparar();
  dispositivo({ seen: 2, bat: 80, lat: -34.6, lng: -58.4 });
  let pn: any = await (await api()).json();
  ok(pn.hoy.hayDatos === true && pn.hoy.mostrar === false && pn.hoy.cumplen <= 1, "con el telefono normal: todo tranquilo (mostrar = false)");
  dispositivo({ seen: 150, bat: 8, lat: -34.52, lng: -58.4 });
  pn = await (await api()).json();
  ok(pn.hoy.mostrar === true && pn.hoy.cumplen >= 2, "con el telefono sin senal y con poca bateria: con senales de alerta (mostrar = true)");
  await api({ accion: "config", config: { enabled: false } });
  pn = await (await api()).json();
  ok(pn.hoy.mostrar === true, "el estado del telefono se ve aunque el Modo Cautela este apagado");
  await api({ accion: "config", config: { enabled: true } });
}

console.log("== Pausar o apagar el Modo Cautela");
{
  await preparar();
  dispositivo({ seen: 150, bat: 8, lat: -34.52, lng: -58.4 });
  for (const h of [8, 12, 24, 36]) {
    const rp: any = await (await api({ accion: "pausa", horas: h })).json();
    ok(Math.abs((Date.parse(rp.config.pausedUntil) - Date.now()) / 3_600_000 - h) < 0.05, `pausa de ${h} horas`);
  }
  let rp: any = await (await api({ accion: "pausa", horas: 500 })).json();
  ok(Math.abs((Date.parse(rp.config.pausedUntil) - Date.now()) / 3_600_000 - 72) < 0.05, "la pausa no pasa de 72 horas");
  rp = await (await api({ accion: "pausa", horas: 1 })).json();
  ok(rp.registro.some((x: any) => x.detail === "Pausa de 1 hora (pausa de avisos)."), "en el registro, una hora va en singular");
  ok(rp.registro.some((x: any) => /Pausa de 72 horas/.test(x.detail)), "en el registro queda cuanto duro la pausa");
  rp = await (await api({ accion: "pausa", horas: 0 })).json();
  ok(rp.config.pausedUntil === null && rp.registro.some((x: any) => x.detail === "Se quit\u00f3 la pausa."), "quitar la pausa");

  // apagar y encender
  rp = await (await api({ accion: "config", config: { enabled: false } })).json();
  ok(rp.config.enabled === false && rp.registro.some((x: any) => x.detail === "La persona apag\u00f3 el Modo Cautela."), "apagar queda en el registro");
  rp = await (await api({ accion: "config", config: { enabled: true } })).json();
  ok(rp.config.enabled === true && rp.registro.some((x: any) => x.detail === "La persona encendi\u00f3 el Modo Cautela."), "encender queda en el registro");
  rp = await (await api({ accion: "config", config: { farKm: 4 } })).json();
  ok(rp.config.enabled === true && rp.config.farKm === 4 && rp.registro[0].detail === "La persona cambi\u00f3 sus condiciones.", "guardar condiciones no toca el encendido");
}

console.log("== Pausar o apagar con un aviso en marcha");
{
  async function conAvisoEnMarcha() {
    await preparar();
    dispositivo({ seen: 150, bat: 8, lat: -34.52, lng: -58.4 });
    await pldCron(env);
    sqlite.prepare("UPDATE pld_episodios SET checkin_at=? WHERE owner_email=?").run(hace(20), DUENIO);
    await pldCron(env);
    ok(episodio() && episodio().alerts === 1, "(preparacion) ya se les aviso a los referentes");
  }
  await conAvisoEnMarcha();
  let n = correos.length;
  await api({ accion: "pausa", horas: 8 });
  let avs = mailsDesde(n).filter((c) => /entr\u00f3 a su cuenta/.test(c.subject));
  ok(episodio() === undefined && avs.length === 2 && avs.every((c) => /paus\u00f3 los avisos por 8 horas/.test(c.html)), "al pausar, se cierra el aviso y se les cuenta a los referentes");
  ok((await (await api()).json() as any).registro.some((x: any) => /Se les avis\u00f3 a tus referentes que paus\u00f3 los avisos por 8 horas/.test(x.detail)), "y queda en el registro");
  n = correos.length;
  await pldCron(env);
  ok(correos.length === n, "mientras dura la pausa no se manda nada");
  await api({ accion: "pausa", horas: 0 });
  n = correos.length;
  await pldCron(env);
  const tras = mailsDesde(n);
  ok(episodio() && episodio().alerts === 0 && tras.length === 1 && tras[0].to === DUENIO && /Est\u00e1s bien/.test(tras[0].subject), "al terminar la pausa, primero se le pregunta a la persona y no se avisa enseguida a los referentes");

  await conAvisoEnMarcha();
  n = correos.length;
  await api({ accion: "config", config: { enabled: false } });
  avs = mailsDesde(n).filter((c) => /entr\u00f3 a su cuenta/.test(c.subject));
  ok(episodio() === undefined && avs.length === 2 && avs.every((c) => /apag\u00f3 el Modo Cautela/.test(c.html)), "al apagar, se cierra el aviso y se les cuenta a los referentes");
  n = correos.length;
  await pldCron(env);
  ok(correos.length === n && episodio() === undefined, "apagado, el cron no hace nada");
  await api({ accion: "config", config: { enabled: true } });
  await pldCron(env);
  ok(episodio() && episodio().alerts === 0, "al encenderlo de nuevo empieza de cero");

  // si todavia no se les habia avisado a los referentes, no se les manda nada
  await preparar();
  dispositivo({ seen: 150, bat: 8, lat: -34.52, lng: -58.4 });
  await pldCron(env);
  ok(episodio() && episodio().alerts === 0, "(preparacion) solo se le pregunto a la persona");
  n = correos.length;
  await api({ accion: "pausa", horas: 12 });
  ok(episodio() === undefined && correos.length === n, "si a los referentes todavia no se les avis\u00f3, no se les manda nada");

  // si la persona ya habia dicho que estaba bien, tampoco
  await conAvisoEnMarcha();
  sqlite.prepare("UPDATE pld_episodios SET state='respondio' WHERE owner_email=?").run(DUENIO);
  n = correos.length;
  await api({ accion: "pausa", horas: 12 });
  ok(episodio() === undefined && correos.length === n, "si ya dijo 'Estoy bien', tampoco se les manda nada");
}

console.log("== Menores: solo ven; el titular arma la proteccion de cada menor");
{
  limpiar();
  sqlite.exec("DELETE FROM family_members");
  const MENOR = "tomi@correo.com", ADULTO = "ana@correo.com", AJENO = "otro@correo.com", BAJA = "viejo@correo.com";
  const fam = sqlite.prepare("INSERT INTO family_members (id,owner_email,member_email,name,owner_name,role,status) VALUES (?,?,?,?,?,?,?)");
  fam.run("fm1", DUENIO, MENOR, "Tomi", "Lucas", "menor", "activo");
  fam.run("fm2", DUENIO, ADULTO, "Ana", "Lucas", "adulto", "activo");
  fam.run("fm3", DUENIO, BAJA, "Viejo", "Lucas", "menor", "baja");
  const apiDe = (persona: string, cuerpo?: unknown) => pldApiDuenio(pedido(ORIGEN + "/api/remote/por-las-dudas?persona=" + encodeURIComponent(persona), cuerpo === undefined ? "GET" : "POST", cuerpo), env);
  const ubic = { latitude: -34.6, longitude: -58.4, address: "Av. Siempre Viva 742" };

  setSesion({ email: DUENIO, method: "passkey" });
  await api({ accion: "pausa", horas: 0 });
  let pn: any = await (await api()).json();
  ok(pn.persona.propia === true && pn.persona.soloLectura === false && pn.personas.length === 1 && pn.personas[0].email === MENOR && pn.personas[0].name === "Tomi", "el titular ve su pagina y la lista de sus menores (solo los activos con rol Menor)");

  let rr: any = await apiDe(MENOR, { accion: "agregar", name: "Mama de Tomi", email: "mama@correo.com" });
  ok(rr.status === 200, "el titular elige un referente para el menor");
  const mailMama = correos.filter((c) => c.to === "mama@correo.com").pop()!;
  ok(/Tomi/.test(mailMama.subject + mailMama.html), "el mail al referente habla de Tomi (el nombre sale de la familia)");
  pn = await (await apiDe(MENOR)).json();
  ok(pn.persona.propia === false && pn.persona.nombre === "Tomi" && pn.referentes.length === 1 && pn.config.displayName === "Tomi", "la pagina de Tomi muestra sus referentes y su nombre");
  pn = await (await api()).json();
  ok(pn.referentes.length === 0, "los referentes de Tomi no se mezclan con los del titular");
  ok((await (await apiDe(MENOR, { accion: "pausa", horas: 8 })).json() as any).config.pausedUntil !== null && (await (await api()).json() as any).config.pausedUntil === null, "el titular puede pausar el Modo Cautela de Tomi sin tocar el suyo");
  ok((await apiDe(MENOR, { accion: "config", config: { farKm: 7 } })).status === 200 && (await pldLeerConfig(env, MENOR)).farKm === 7 && (await pldLeerConfig(env, DUENIO)).farKm !== 7, "y cambiar sus condiciones");

  // el menor ve, pero no edita
  setSesion({ email: MENOR, method: "passkey" });
  pn = await (await api()).json();
  ok(pn.persona.soloLectura === true && pn.persona.propia === true && pn.referentes.length === 1 && pn.personas.length === 0, "el menor ve su protecci\u00f3n armada, en modo solo lectura");
  for (const [nombre, cuerpo] of [["agregar", { accion: "agregar", name: "X", email: "x@y.com" }], ["quitar", { accion: "quitar", id: pn.referentes[0].id }], ["config", { accion: "config", config: { enabled: false } }], ["pausa", { accion: "pausa", horas: 8 }], ["casa", { accion: "casa" }], ["reenviar", { accion: "reenviar", id: pn.referentes[0].id }]] as Array<[string, unknown]>) {
    const rx = await api(cuerpo);
    ok(rx.status === 403 && (await rx.json() as any).error === "solo_administrador", `el menor no puede: ${nombre}`);
  }
  ok((await pldLeerConfig(env, MENOR)).enabled === true && (await pldLeerConfig(env, MENOR)).farKm === 7, "y no se cambio nada");
  ok((await apiDe(DUENIO)).status === 403 && (await apiDe(ADULTO)).status === 403, "el menor tampoco puede mirar ni armar la proteccion de otros");

  // los demas
  setSesion({ email: AJENO, method: "passkey" });
  ok((await apiDe(MENOR)).status === 403 && (await apiDe(MENOR, { accion: "pausa", horas: 8 })).status === 403, "alguien de otra familia no puede ver ni armar la de Tomi");
  pn = await (await api()).json();
  ok(pn.persona.soloLectura === false && pn.personas.length === 0, "y su propia pagina es normal");
  // el padre viaja y el hermano mayor (adulto de la familia) cuida a Tomi
  setSesion({ email: ADULTO, method: "passkey" });
  pn = await (await api()).json();
  ok(pn.persona.soloLectura === false && pn.personas.length === 1 && pn.personas[0].email === MENOR && (await api({ accion: "pausa", horas: 1 })).status === 200, "un adulto de la familia arma la suya y ve a Tomi en el selector");
  pn = await (await apiDe(MENOR)).json();
  ok(pn.persona.propia === false && pn.persona.soloLectura === false && pn.persona.nombre === "Tomi" && pn.referentes.length === 1, "el hermano mayor (adulto de la familia) ve la proteccion de Tomi");
  rr = await apiDe(MENOR, { accion: "agregar", name: "Tia", email: "tia@correo.com" });
  ok(rr.status === 200 && (await (await apiDe(MENOR)).json() as any).referentes.length === 2 && (await (await api()).json() as any).referentes.length === 0, "y puede elegir un referente para Tomi (sin tocar los suyos)");
  rr = await (await apiDe(MENOR, { accion: "pausa", horas: 12 })).json();
  ok(rr.registro.some((x: any) => x.detail === ADULTO + " (administrador de la familia) cambi\u00f3 la pausa."), "el registro de Tomi anota quien hizo el cambio (sin modo oculto)");
  await apiDe(MENOR, { accion: "pausa", horas: 0 });
  // un adulto de OTRA familia, o dado de baja, no
  fam.run("fm4", AJENO, "otra@correo.com", "Otra", "Otro", "adulto", "activo");
  fam.run("fm5", DUENIO, "exadulto@correo.com", "Ex", "Lucas", "adulto", "baja");
  setSesion({ email: "otra@correo.com", method: "passkey" });
  ok((await apiDe(MENOR)).status === 403 && (await (await api()).json() as any).personas.length === 0, "un adulto de otra familia no arma la de Tomi");
  setSesion({ email: "exadulto@correo.com", method: "passkey" });
  ok((await apiDe(MENOR)).status === 403, "un adulto dado de baja de la familia tampoco");
  setSesion({ email: ADULTO, method: "passkey" });
  ok((await apiDe(DUENIO)).status === 403 && (await apiDe("otra@correo.com")).status === 403, "un adulto no arma la de otro adulto (ni la del titular)");
  setSesion({ email: DUENIO, method: "passkey" });
  ok((await apiDe(ADULTO)).status === 403 && (await apiDe(BAJA)).status === 403 && (await apiDe("nadie@correo.com")).status === 403, "el titular no arma la de un adulto, ni de un menor dado de baja, ni de cualquiera");
  setSesion({ email: DUENIO, method: "emergency" });
  ok((await apiDe(MENOR)).status === 403, "con una sesion de emergencia no se entra a ninguna");
  setSesion({ email: DUENIO, method: "passkey" });

  // el SOS del menor avisa a los referentes de Tomi (con el Modo Cautela encendido o apagado)
  sqlite.exec("UPDATE pld_referentes SET status='aceptado' WHERE owner_email='" + MENOR + "'");
  const n = correos.length;
  ok((await pldAvisarSos(env, MENOR, ubic)) === 2 && correos.length === n + 2 && correos.slice(n).map((c) => c.to).sort().join() === "mama@correo.com,tia@correo.com" && /Tomi/.test(correos[n].subject), "si Tomi aprieta el SOS, se les avisa a sus referentes (los que eligio el titular y el hermano mayor)");
  const tp: string = await (pldPaginaDuenio() as any).text();
  ok(/function personaPantalla/.test(tp) && /Esto lo completa el administrador de tu familia/.test(tp) && /Est\u00e1s armando la protecci\u00f3n de/.test(tp) && /\?persona=/.test(tp), "la pagina avisa 'Esto lo completa el administrador de tu familia', arma la de otro y muestra el selector");
  ok(/Mientras est\u00e9 apagado no se manda ning\u00fan aviso autom\u00e1tico a tus referentes\. El SOS sigue avisando/.test(tp) && /Si lo apag\u00e1s no se manda ning\u00fan aviso autom\u00e1tico; el SOS sigue avisando/.test(tp) && !/tampoco el del SOS/.test(tp), "la pagina dice que el SOS sigue avisando aunque este apagado");
  sqlite.exec("DELETE FROM family_members");
}

console.log("== Modo Guardian: el camino");
{
  const gd = async (cuerpo: unknown) => gdApi(pedido(ORIGEN + "/api/guardian", "POST", cuerpo), env);
  const viaje = () => sqlite.prepare("SELECT * FROM gd_viajes WHERE owner_email=? ORDER BY started_at DESC LIMIT 1").get(DUENIO) as any;
  const min = (n: number) => new Date(Date.now() + n * 60_000).toISOString();
  const fijar = (campos: Record<string, unknown>) => { const ks = Object.keys(campos); sqlite.prepare(`UPDATE gd_viajes SET ${ks.map((k) => k + "=?").join(",")} WHERE id=?`).run(...ks.map((k) => campos[k] as any), viaje().id); };
  const nuevoDispositivo = (lat: number, lng: number, plat = "android") => dispositivo({ seen: 1, bat: 80, lat, lng, plat });
  console.log("-- calculo del tiempo");
  ok(gdEstimar(0.1, "caminando") === 3 && gdEstimar(5, "auto") === 14 && gdEstimar(5, "transporte") === 31 && gdEstimar(2, "caminando") === 35 && gdEstimar(5000, "caminando") === 300, "el tiempo se calcula por la distancia y el modo (minimo 3, maximo 300)");

  await preparar();
  sqlite.exec("DELETE FROM gd_viajes; DELETE FROM family_places");
  sqlite.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)").run("pl1", DUENIO, "Casa", -34.57, -58.4, 150, now());
  sqlite.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)").run("pl2", "otro@correo.com", "Casa de otro", -34.5, -58.4, 150, now());
  nuevoDispositivo(-34.6, -58.4);
  setSesion({ email: DUENIO, method: "passkey" });

  console.log("-- empezar");
  setSesion(null);
  ok((await gd({ accion: "estado" })).status === 401, "sin sesion ni enlace no se entra");
  ok((await gd({ t: "gdvxxxx.yyyy", accion: "estado" })).status === 404, "un enlace inventado no sirve");
  setSesion({ email: DUENIO, method: "emergency" });
  ok((await gd({ accion: "estado" })).status === 403, "con una sesion de emergencia tampoco");
  setSesion({ email: DUENIO, method: "passkey" });
  let r2: any = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "auto" })).json();
  ok(r2.minutos >= 8 && r2.minutos <= 12 && r2.km > 2.5 && r2.km < 4, "estimar: de aca a Casa, en auto, unos 10 minutos (" + r2.minutos + " min, " + r2.km + " km)");
  r2 = await (await gd({ accion: "estimar", lugarId: "pl2", modo: "auto" })).json();
  ok(r2.minutos === null, "estimar no mira los lugares de otra persona");
  sqlite.exec("UPDATE pld_referentes SET status='pendiente'");
  let rs = await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" });
  ok(rs.status === 400 && (await rs.json() as any).error === "sin_referentes", "sin ningun referente que haya aceptado no se puede empezar (nadie recibiria el aviso)");
  sqlite.exec("UPDATE pld_referentes SET status='aceptado' WHERE name IN ('Mama','Papa')");
  ok((await gd({ accion: "empezar", lugarId: "pl2", modo: "auto" })).status === 400, "no se puede ir a un lugar de otra persona");
  ok((await gd({ accion: "empezar", lugarId: "pl1", modo: "volando" })).status === 400, "el modo tiene que ser auto, transporte o caminando");
  ok((await gd({ accion: "empezar", texto: "  ", modo: "auto", minutos: 10 })).status === 400, "otro lugar sin nombre no sirve");
  ok((await gd({ accion: "empezar", texto: "Casa de Ana", modo: "auto" })).status === 400, "otro lugar sin minutos no sirve (no hay como calcular)");
  rs = await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" });
  const e1: any = await rs.json();
  ok(rs.status === 200 && e1.viaje.destino === "Casa" && e1.viaje.estado === "en_camino" && e1.viaje.margenMin === 2 && e1.viaje.enlace.includes("/camino?t=gdv"), "empieza el camino a Casa con el tiempo calculado");
  ok(Math.abs((Date.parse(e1.viaje.deadlineAt) - Date.parse(e1.viaje.startedAt)) / 60000 - (e1.viaje.estimadoMin + 2)) < 0.1, "el limite es el tiempo calculado mas 2 minutos de margen");
  ok((await (await api()).json() as any).registro.some((x: any) => /Empezaste un camino a Casa en auto/.test(x.detail)), "queda en el registro");
  rs = await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" });
  ok(rs.status === 409 && (await rs.json() as any).error === "ya_hay_camino", "no se pueden tener dos caminos a la vez");
  const TOKEN = e1.viaje.enlace.split("t=")[1];
  setSesion(null);
  const est: any = await (await gd({ t: TOKEN, accion: "estado" })).json();
  ok(est.viaje.estado === "en_camino" && est.viaje.destino === "Casa" && Date.parse(est.ahora) > 0, "con el enlace personal se ve el camino sin entrar al panel");
  setSesion({ email: DUENIO, method: "passkey" });

  console.log("-- seguimiento (se le pide al telefono una ubicacion nueva)");
  pings.length = 0;
  await gdCron(env);
  ok(pings.length === 1 && viaje().ping_at, "el primer minuto se le pide una ubicacion nueva al telefono (Android)");
  await gdCron(env);
  ok(pings.length === 1, "y no se vuelve a pedir enseguida");
  fijar({ ping_at: new Date(Date.now() - 6 * 60_000).toISOString() });
  await gdCron(env);
  ok(pings.length === 2, "se repite cada 5 minutos");
  nuevoDispositivo(-34.6, -58.4, "ios");
  fijar({ ping_at: new Date(Date.now() - 6 * 60_000).toISOString() });
  await gdCron(env);
  ok(pings.length === 2, "en iPhone no se pide (no despierta la app)");
  nuevoDispositivo(-34.6, -58.4);

  console.log("-- el aviso de dos minutos antes");
  let n = correos.length; avisos.length = 0;
  await gdCron(env);
  ok(correos.length === n && viaje().estado === "en_camino", "con tiempo de sobra no se avisa nada");
  fijar({ deadline_at: min(1.5) });
  await gdCron(env);
  let nuevos = mailsDesde(n);
  ok(viaje().estado === "aviso" && nuevos.length === 1 && nuevos[0].to === DUENIO && /Seguís en camino/.test(nuevos[0].subject) && nuevos[0].html.includes("/camino?t=" + TOKEN), "a dos minutos de vencer se le pregunta a la persona si sigue en camino, con el enlace");
  ok(avisos.length === 1 && avisos[0].data && avisos[0].data.tipo === "guardian" && String(avisos[0].data.url).includes("/camino?t=" + TOKEN), "y se le avisa en el telefono, con el enlace adentro para que la app lo abra");
  await gdCron(env);
  ok(mailsDesde(n).length === 1, "no se repite el aviso");

  console.log("-- extender");
  setSesion(null);
  ok((await gd({ t: TOKEN, accion: "extender", minutos: 15 })).status === 400, "solo se puede extender 10, 20 o 30");
  const antes = Date.parse(viaje().deadline_at);
  let ex: any = await (await gd({ t: TOKEN, accion: "extender", minutos: 10 })).json();
  ok(ex.viaje.estado === "en_camino" && ex.viaje.extensiones === 1 && Math.abs(Date.parse(viaje().deadline_at) - (antes + 10 * 60_000)) < 1000, "extender 10 minutos corre el limite y vuelve a en camino");
  await gd({ t: TOKEN, accion: "extender", minutos: 20 });
  await gd({ t: TOKEN, accion: "extender", minutos: 30 });
  let rx = await gd({ t: TOKEN, accion: "extender", minutos: 10 });
  ok(rx.status === 409 && (await rx.json() as any).error === "demasiadas_extensiones" && viaje().extensiones === 3, "como maximo 3 veces");
  ok((await (await gd({ t: TOKEN, accion: "estado" })).json() as any).viaje.puedeExtender === false, "y la pagina lo sabe (puedeExtender = false)");

  console.log("-- no llego a tiempo");
  setSesion({ email: DUENIO, method: "passkey" });
  n = correos.length; avisos.length = 0;
  fijar({ estado: "en_camino", deadline_at: min(-1), aviso_at: null });
  await gdCron(env);
  nuevos = mailsDesde(n);
  const aRef = nuevos.filter((c) => /no llegó a Casa/.test(c.subject));
  ok(viaje().estado === "alerta" && viaje().alertas === 1 && aRef.length === 2 && aRef.map((c) => c.to).sort().join() === "mama@correo.com,papa@correo.com", "pasado el limite, les avisa a los referentes que aceptaron (no al pendiente)");
  ok(/Av\. Siempre Viva 742/.test(aRef[0].html) && /google\.com\/maps\?q=-34\.6,-58\.4/.test(aRef[0].html) && /referente\?t=/.test(aRef[0].html) && /911/.test(aRef[0].html), "el mail trae el destino, la ultima ubicacion con mapa, su enlace personal y el 911");
  ok(nuevos.some((c) => c.to === DUENIO && /Les avisamos a tus referentes/.test(c.subject)), "y la persona se entera de que se les aviso");
  await gdCron(env);
  ok(mailsDesde(n).length === nuevos.length, "no se repite enseguida");
  let rext = await gd({ t: TOKEN, accion: "extender", minutos: 10 });
  ok(rext.status === 409, "ya avisado, no se puede extender: hay que tocar Llegue");
  for (const esperado of [2, 3]) {
    fijar({ last_alert_at: new Date(Date.now() - 11 * 60_000).toISOString() });
    const m = correos.length;
    await gdCron(env);
    ok(viaje().alertas === esperado && correos.length === m + 2, `a los 10 minutos se repite (aviso ${esperado} de 3)`);
  }
  fijar({ last_alert_at: new Date(Date.now() - 11 * 60_000).toISOString() });
  const mFin = correos.length;
  await gdCron(env);
  ok(viaje().alertas === 3 && correos.length === mFin, "despues del tercero no se avisa mas");
  n = correos.length;
  const rl: any = await (await gd({ t: TOKEN, accion: "llegue" })).json();
  nuevos = mailsDesde(n);
  ok(rl.estado === "llego" && viaje().estado === "llego" && nuevos.length === 2 && nuevos.every((c) => /está bien/.test(c.subject)), "al tocar Llegue se cierra y se les cuenta a los referentes que esta bien");
  ok(nuevos.every((c) => /tocó Llegué a las \d\d:\d\d, \d+ minutos? después del límite/.test(c.html)) && rl.viaje.fin.despuesMin > 0 && /^\d\d:\d\d$/.test(rl.viaje.fin.hora), "el mail dice a que hora toco Llegue y con cuanta demora respecto del limite, y la pagina tambien lo sabe");
  ok(nuevos.every((c) => /dice que está bien, pero su ubicación está a 3,3 km de Casa/.test(c.html) && /comunicate con/.test(c.html)) && viaje().motivo_fin === "llegue_sin_comprobar" && rl.llegada === "sin_comprobar", "como el telefono estaba lejos de Casa, el mail cuenta la distancia y que se comuniquen (no dice que llego bien)");
  ok((await (await api()).json() as any).registro.some((x: any) => /Cerraste el camino a Casa: tocaste Llegué a las \d\d:\d\d, \d+ minutos? después del límite \(\d\d:\d\d\), pero tu ubicación está a 3,3 km de Casa/.test(x.detail)), "y en el registro");
  ok((await gd({ t: TOKEN, accion: "llegue" })).status === 409, "un camino terminado no se puede tocar de nuevo");
  ok((await (await api()).json() as any).registro.some((x: any) => /Cerraste el camino a Casa/.test(x.detail)), "queda en el registro");

  console.log("-- llegar a tiempo, cancelar y pedir ayuda");
  sqlite.exec("DELETE FROM gd_viajes");
  let e2: any = await (await gd({ accion: "empezar", texto: "Casa de Ana", modo: "caminando", minutos: 25 })).json();
  ok(e2.viaje.destino === "Casa de Ana" && e2.viaje.estimadoMin === 25, "otro lugar: la persona pone los minutos");
  const T2 = e2.viaje.enlace.split("t=")[1];
  n = correos.length;
  const rl2: any = await (await gd({ t: T2, accion: "llegue" })).json();
  ok(viaje().estado === "llego" && correos.length === n, "si llega a tiempo no se les manda nada a los referentes");
  ok(rl2.viaje.fin.despuesMin <= -26 && rl2.viaje.fin.despuesMin >= -28 && rl2.viaje.fin.duracionMin === 0 && rl2.viaje.fin.extraMin === 0, "llegando enseguida, la pagina dice que toco Llegue unos 27 minutos antes del limite");
  ok((await (await api()).json() as any).registro.some((x: any) => /tocaste Llegué a las \d\d:\d\d, 2[678] minutos antes del límite/.test(x.detail)), "y el registro lo cuenta");
  e2 = await (await gd({ accion: "empezar", texto: "Cine", modo: "transporte", minutos: 40 })).json();
  const T3 = e2.viaje.enlace.split("t=")[1];
  const rcan: any = await (await gd({ t: T3, accion: "cancelar" })).json();
  nuevos = mailsDesde(n);
  ok(viaje().estado === "cancelado" && rcan.avisados === 2 && nuevos.length === 2 && nuevos.map((c) => c.to).sort().join() === "mama@correo.com,papa@correo.com" && nuevos.every((c) => /canceló el camino a Cine/.test(c.subject)), "cancelar el camino les avisa a los referentes que aceptaron (un chico no puede cancelar sin que se enteren)");
  ok(nuevos.every((c) => /canceló a las \d\d:\d\d el camino a/.test(c.html) && /Desde ahora no se les avisa si no llega/.test(c.html) && /Última ubicación/.test(c.html) && /Av\. Siempre Viva 742/.test(c.html) && /google\.com\/maps\?q=-34\.6,-58\.4/.test(c.html) && /Si no lo esperabas, comunicate con/.test(c.html)), "el mail dice a que hora lo cancelo, trae la ultima ubicacion con el mapa y que se comuniquen si no lo esperaban");
  ok((await (await api()).json() as any).registro.some((x: any) => /Se le avisó a Mama que cancelaste el camino a Cine/.test(x.detail)), "y queda en el registro a quien se le aviso");
  e2 = await (await gd({ accion: "empezar", texto: "Boliche", modo: "auto", minutos: 30 })).json();
  const T4 = e2.viaje.enlace.split("t=")[1];
  n = correos.length;
  const ay: any = await (await gd({ t: T4, accion: "ayuda" })).json();
  nuevos = mailsDesde(n);
  ok(ay.estado === "alerta" && ay.avisados === 2 && nuevos.length === 2 && nuevos.every((c) => /SOS/.test(c.subject)) && /Av\. Siempre Viva 742/.test(nuevos[0].html), "Necesito ayuda avisa enseguida como un SOS, con la ultima ubicacion");
  fijar({ last_alert_at: new Date(Date.now() - 11 * 60_000).toISOString() });
  const m3 = correos.length;
  await gdCron(env);
  ok(correos.length === m3, "despues de pedir ayuda no se repite el aviso de 'no llego'");
  await gd({ t: T4, accion: "cancelar" });
  ok(viaje().estado === "llego" && mailsDesde(m3).length === 2, "si cancela despues de avisar, cuenta como llegue: se les dice que esta bien");

  console.log("-- llegar: se comprueba con la ubicacion");
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.6, -58.4); // el telefono esta a unos 3,3 km de Casa
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  const TL = e2.viaje.enlace.split("t=")[1];
  ok(e2.viaje.destinoExacto === true && e2.viaje.llegada === null, "un camino a un lugar guardado sabe donde queda el destino");
  n = correos.length;
  let rlej = await gd({ t: TL, accion: "llegue" });
  let jlej: any = await rlej.json();
  ok(rlej.status === 409 && jlej.error === "lejos_del_destino" && jlej.detalle.motivo === "lejos" && jlej.detalle.fuente === "telefono" && jlej.detalle.distanciaM > 3200 && jlej.detalle.distanciaM < 3500 && viaje().estado === "en_camino", "tocar Llegue lejos del destino no cierra el camino: dice que esta a unos 3,3 km (con la ubicacion del telefono)");
  ok(correos.length === n && (await (await api()).json() as any).registro.some((x: any) => /Tocaste Llegué, pero tu ubicación está a 3,3 km de Casa: el camino sigue abierto/.test(x.detail)), "no se les avisa a los referentes y queda en el registro");
  rlej = await gd({ t: TL, accion: "llegue", origen: { lat: -34.6, lng: -58.4, precision: 12 } });
  jlej = await rlej.json();
  ok(rlej.status === 409 && jlej.detalle.fuente === "navegador" && jlej.detalle.motivo === "lejos" && viaje().estado === "en_camino", "tambien con la ubicacion del navegador: lejos es lejos");
  const rcer: any = await (await gd({ t: TL, accion: "llegue", origen: { lat: -34.5705, lng: -58.4, precision: 15 } })).json();
  ok(rcer.ok && rcer.estado === "llego" && rcer.llegada === "comprobada" && viaje().estado === "llego" && viaje().motivo_fin === "llegue_comprobada" && rcer.viaje.llegada === "comprobada", "en el destino (con la ubicacion del navegador) se cierra y queda como comprobada");
  ok((await (await api()).json() as any).registro.some((x: any) => /Llegaste bien a Casa: tocaste Llegué a las \d\d:\d\d, .*Tu ubicación lo confirmó \(a \d+ m\)/.test(x.detail)), "el registro dice que la ubicacion lo confirmo");
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.5701, -58.4);
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  const rtel: any = await (await gd({ t: e2.viaje.enlace.split("t=")[1], accion: "llegue", origen: { lat: -34.6, lng: -58.4, precision: 30 } })).json();
  ok(rtel.ok && rtel.llegada === "comprobada", "si el telefono esta en el destino alcanza, aunque la pagina este abierta en otra compu lejos");
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.6, -58.4);
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  const TL3 = e2.viaje.enlace.split("t=")[1];
  let rinc = await gd({ t: TL3, accion: "llegue", origen: { lat: -34.5705, lng: -58.4, precision: 2000 } });
  let jinc: any = await rinc.json();
  ok(rinc.status === 409 && jinc.error === "sin_comprobar" && jinc.detalle.motivo === "incierta" && jinc.detalle.precisionM === 2000 && viaje().estado === "en_camino", "con una ubicacion poco precisa (2 km de error) no se puede asegurar que llego: no cierra");
  rinc = await gd({ t: TL3, accion: "llegue", origen: { lat: -34.62, lng: -58.4, precision: 1000 } });
  jinc = await rinc.json();
  ok(rinc.status === 409 && jinc.error === "lejos_del_destino", "aun con 1 km de error, a unos 5 km se sabe que esta lejos");
  dispositivo({ seen: 40, bat: 80, lat: -34.6, lng: -58.4 }); // la ultima ubicacion del telefono es de hace 40 minutos
  let rsin = await gd({ t: TL3, accion: "llegue" });
  let jsin: any = await rsin.json();
  ok(rsin.status === 409 && jsin.error === "sin_comprobar" && jsin.detalle.motivo === "sin_ubicacion" && jsin.detalle.haceMin >= 39 && viaje().estado === "en_camino", "sin ubicacion del navegador y con la del telefono de hace 40 minutos, no se puede comprobar: no cierra");
  rsin = await gd({ t: TL3, accion: "llegue", origen: { lat: 999, lng: 10 } });
  ok(rsin.status === 409 && (await rsin.json() as any).detalle.motivo === "sin_ubicacion", "una ubicacion inventada (fuera de rango) se ignora");
  n = correos.length;
  const rigu = await gd({ t: TL3, accion: "llegue", forzar: true });
  ok(rigu.status === 409 && (await rigu.json() as any).error === "sin_comprobar" && viaje().estado === "en_camino" && correos.length === n, "no hay forma de cerrar el camino sin estar en el lugar: «forzar» no existe y sigue sin dejar (los chicos dirian que llegaron a lo de un amigo)");
  const rigu2 = await gd({ t: TL3, accion: "llegue", origen: { lat: -34.6, lng: -58.4, precision: 10 }, forzar: true });
  ok(rigu2.status === 409 && (await rigu2.json() as any).error === "lejos_del_destino" && viaje().estado === "en_camino", "tampoco estando lejos");
  console.log("-- llegar: el margen de llegada se elige en la configuracion");
  await gd({ accion: "cancelar" }).catch(() => null);
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.6, -58.4);
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  const TM = e2.viaje.enlace.split("t=")[1];
  const a100 = { lat: -34.5709, lng: -58.4, precision: 10 }; // a unos 100 m de Casa
  let rm: any = await (await gd({ t: TM, accion: "llegue", origen: a100 })).json();
  ok(rm.ok && rm.llegada === "comprobada", "con el margen recomendado (150 m), a 100 metros del destino se da por llegada");
  sqlite.exec("DELETE FROM gd_viajes");
  setSesion({ email: DUENIO, method: "passkey" });
  await gd({ accion: "config", config: { radioLlegadaM: 50 } });
  nuevoDispositivo(-34.6, -58.4);
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  const TM2 = e2.viaje.enlace.split("t=")[1];
  const rm2 = await gd({ t: TM2, accion: "llegue", origen: a100 });
  const jm2: any = await rm2.json();
  ok(rm2.status === 409 && jm2.error === "lejos_del_destino" && jm2.detalle.radioM === 50 && jm2.detalle.distanciaM >= 95 && jm2.detalle.distanciaM <= 110, "con un margen de 50 m, a 100 metros todavia no (y la respuesta dice cual es el margen)");
  rm = await (await gd({ t: TM2, accion: "llegue", origen: { lat: -34.5704, lng: -58.4, precision: 10 } })).json();
  ok(rm.ok && rm.llegada === "comprobada", "y a menos de 50 metros si");
  await gd({ accion: "config", config: { restablecer: true } });
  console.log("-- llegar: con los referentes ya avisados no se discute");
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.57, -58.4);
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  fijar({ estado: "alerta", alertas: 1, last_alert_at: now() });
  n = correos.length;
  const ral: any = await (await gd({ t: e2.viaje.enlace.split("t=")[1], accion: "llegue" })).json();
  nuevos = mailsDesde(n);
  ok(ral.ok && ral.llegada === "comprobada" && nuevos.length === 2 && nuevos.every((c) => /Su ubicación lo confirma/.test(c.html) && /Ya no hace falta que hagas nada/.test(c.html)), "ya avisados los referentes, si esta en el destino se les dice que llego bien y que la ubicacion lo confirma");
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.6, -58.4);
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  fijar({ estado: "alerta", alertas: 1, last_alert_at: now() });
  n = correos.length;
  const ral2: any = await (await gd({ t: e2.viaje.enlace.split("t=")[1], accion: "llegue" })).json();
  nuevos = mailsDesde(n);
  ok(ral2.ok && ral2.llegada === "sin_comprobar" && nuevos.length === 2 && nuevos.every((c) => /dice que está bien, pero su ubicación está a 3,3 km de Casa/.test(c.html) && /comunicate con/.test(c.html) && !/Ya no hace falta/.test(c.html)), "ya avisados, si la ubicacion no coincide igual se cierra (es 'ya estoy bien'), pero se les cuenta la distancia");
  sqlite.exec("DELETE FROM gd_viajes");
  e2 = await (await gd({ accion: "empezar", texto: "Casa de Ana", modo: "caminando", minutos: 25 })).json();
  ok(e2.viaje.destinoExacto === false, "un destino escrito a mano con los minutos no tiene un punto en el mapa");
  const rsd: any = await (await gd({ t: e2.viaje.enlace.split("t=")[1], accion: "llegue" })).json();
  ok(rsd.ok && rsd.llegada === null && viaje().motivo_fin === "llegue", "si no se sabe donde queda el destino no hay nada que comprobar: cierra como siempre");

  console.log("-- cancelar o cambiar el destino: se les avisa a los referentes (se puede apagar)");
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.6, -58.4);
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  const TC = e2.viaje.enlace.split("t=")[1];
  ok(e2.viaje.avisaCambios === true, "la pantalla sabe que se les avisa a los referentes si cambia o cancela");
  n = correos.length;
  const rmod: any = await (await gd({ t: TC, accion: "cambiar", mismo: true, modo: "caminando" })).json();
  ok(rmod.ok && rmod.avisados === 0 && correos.length === n, "cambiar solo como va (mismo destino, otro modo) no les avisa a los referentes");
  const rcl: any = await (await gd({ t: TC, accion: "cancelar" })).json();
  nuevos = mailsDesde(n);
  ok(rcl.avisados === 2 && nuevos.length === 2 && nuevos.every((c) => /a 3,3 km de Casa/.test(c.html)), "al cancelar un camino con el destino en el mapa, el mail dice a cuantos km del destino estaba");
  await gd({ accion: "config", config: { avisarCambios: 0 } });
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  const TD = e2.viaje.enlace.split("t=")[1];
  ok(e2.viaje.avisaCambios === false, "con la opcion apagada en Configuracion la pantalla lo sabe");
  n = correos.length;
  const rcam: any = await (await gd({ t: TD, accion: "cambiar", texto: "Casa de Ana", minutos: 20 })).json();
  ok(rcam.ok && rcam.avisados === 0 && correos.length === n, "con la opcion apagada, cambiar el destino no avisa a nadie");
  await gd({ t: TD, accion: "cancelar" });
  ok(viaje().estado === "cancelado" && correos.length === n, "ni cancelar");
  await gd({ accion: "config", config: { restablecer: true } });
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  sqlite.exec("UPDATE pld_referentes SET status='pendiente'");
  n = correos.length;
  const rsr: any = await (await gd({ t: e2.viaje.enlace.split("t=")[1], accion: "cancelar" })).json();
  ok(rsr.ok && rsr.avisados === 0 && correos.length === n && viaje().estado === "cancelado", "si ya no hay referentes activos, cancelar anda igual (no hay a quien avisarle)");
  sqlite.exec("UPDATE pld_referentes SET status='aceptado' WHERE name IN ('Mama','Papa')");

  console.log("-- mails: si el telefono no mando la direccion, la pone Google (o van las coordenadas), y siempre a cuanto esta del destino");
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.6, -58.4);
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  const TS = e2.viaje.enlace.split("t=")[1];
  sqlite.prepare("UPDATE devices SET last_location_json=?").run(JSON.stringify({ latitude: -34.6, longitude: -58.4 }));
  n = correos.length;
  await gd({ t: TS, accion: "cancelar" });
  nuevos = mailsDesde(n);
  ok(nuevos.length === 2 && nuevos.every((c) => /-34\.60000, -58\.40000, a 3,3 km de Casa/.test(c.html)), "sin direccion y sin clave de Google el mail muestra las coordenadas y a cuanto esta del destino");
  const fetchAntes = globalThis.fetch;
  (env as any).GOOGLE_ROUTES_KEY = "AIza" + "a".repeat(35);
  globalThis.fetch = (async (url: any, init: any) => String(url).includes("/geocode/json") ? new Response(JSON.stringify({ status: "OK", results: [{ formatted_address: "Av. Falsa 123, Buenos Aires" }] })) : fetchAntes(url, init)) as any;
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto", minutos: 20 })).json();
  sqlite.prepare("UPDATE devices SET last_location_json=?").run(JSON.stringify({ latitude: -34.6, longitude: -58.4 }));
  n = correos.length;
  await gd({ t: e2.viaje.enlace.split("t=")[1], accion: "cancelar" });
  nuevos = mailsDesde(n);
  ok(nuevos.length === 2 && nuevos.every((c) => /Av\. Falsa 123, Buenos Aires, a 3,3 km de Casa/.test(c.html)), "con la clave de Google, la direccion que falta la pone Google (Geocoding)");
  globalThis.fetch = (async (url: any) => { throw new Error("sin red"); }) as any;
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto", minutos: 20 })).json();
  sqlite.prepare("UPDATE devices SET last_location_json=?").run(JSON.stringify({ latitude: -34.6, longitude: -58.4 }));
  n = correos.length;
  await gd({ t: e2.viaje.enlace.split("t=")[1], accion: "cancelar" });
  ok(mailsDesde(n).length === 2 && mailsDesde(n).every((c) => /-34\.60000, -58\.40000/.test(c.html)), "si Google no contesta, el mail sale igual con las coordenadas");
  globalThis.fetch = fetchAntes;
  delete (env as any).GOOGLE_ROUTES_KEY;
  nuevoDispositivo(-34.6, -58.4);

  console.log("-- llegada automatica y cierre");
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.6, -58.4);
  e2 = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  n = correos.length;
  await gdCron(env);
  ok(!viaje().llegada_at && mailsDesde(n).length === 0, "lejos del destino no se pregunta nada");
  nuevoDispositivo(-34.57, -58.4);
  await gdCron(env);
  nuevos = mailsDesde(n);
  ok(viaje().llegada_at && nuevos.length === 1 && nuevos[0].to === DUENIO && /Llegaste bien/.test(nuevos[0].subject), "si el telefono esta en el destino se le pregunta si llego bien");
  await gdCron(env);
  ok(mailsDesde(n).length === 1, "y se le pregunta una sola vez");
  fijar({ started_at: new Date(Date.now() - 13 * 3_600_000).toISOString() });
  await gdCron(env);
  ok(viaje().estado === "cerrado" && viaje().motivo_fin === "expiro", "un camino olvidado se cierra solo despues de 12 horas");

  console.log("-- ninguna persona a quien avisar, y los menores");
  sqlite.exec("DELETE FROM gd_viajes");
  nuevoDispositivo(-34.6, -58.4);
  await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" });
  sqlite.exec("UPDATE pld_referentes SET status='baja'");
  fijar({ deadline_at: min(-1) });
  n = correos.length;
  await gdCron(env);
  ok(viaje().estado === "alerta" && mailsDesde(n).every((c) => c.to === DUENIO) && (await (await api()).json() as any).registro.some((x: any) => /no hay ningún referente activo/.test(x.detail)), "si ya no hay referentes activos queda anotado y la persona se entera");
  await preparar();
  sqlite.exec("DELETE FROM gd_viajes; DELETE FROM family_members");
  sqlite.prepare("INSERT INTO family_members (id,owner_email,member_email,name,owner_name,role,status) VALUES (?,?,?,?,?,?,?)").run("fmg", "padre@correo.com", DUENIO, "Lucas", "Padre", "menor", "activo");
  setSesion({ email: DUENIO, method: "passkey" });
  nuevoDispositivo(-34.6, -58.4);
  ok((await gd({ accion: "empezar", texto: "Casa de Ana", modo: "auto", minutos: 20 })).status === 200, "un menor puede empezar su propio camino (lo del Modo Guardian lo activa la persona)");
  sqlite.exec("DELETE FROM family_members; DELETE FROM gd_viajes");

  console.log("-- la pagina del camino");
  const pc: string = await (gdPaginaCamino() as any).text();
  ok(["bSonido", "sonidoTxt", "sonidoCard"].every((i) => pc.includes('id="' + i + '"')) && /function pitido\(/.test(pc) && /ms<=15000/.test(pc) && /wakeLock/.test(pc) && /Tocaste Llegué a las/.test(pc), "la pagina del camino pita cada segundo en los ultimos 15 segundos (se puede apagar), mantiene la pantalla encendida y dice a que hora toco Llegue");
  ok(["reloj", "bLlegue", "bAyuda", "bCancelar", "destino", "estadoTxt", "viaje", "vacio", "acciones"].every((i) => pc.includes('id="' + i + '"')) && /data-m="10"/.test(pc) && /data-m="30"/.test(pc) && /\/api\/guardian/.test(pc), "la pagina del camino tiene el reloj, Llegue, Extender 10 / 20 / 30, Necesito ayuda y Cancelar");
  ok(/<a class="atras" id="atras" href="\/guardian">← Volver a Tu protección<\/a>/.test(pc) && /id="bVolver" href="\/guardian">Volver a Tu protección/.test(pc) && /id="bOtro" href="\/guardian#guardian">Empezar otro camino/.test(pc) && /\$\("despues"\)\.style\.display=activo\?"none":"block"/.test(pc) && /Ir a Tu protección/.test(pc), "la pagina del camino se puede dejar: arriba hay un enlace para volver a Tu proteccion y, cuando el camino terminó o se canceló, los botones Volver y Empezar otro camino");
  ok(/hacer\(\{accion:"cancelar"\},function\(d\)\{return d\.avisados>0\?"Listo: cancelaste el camino\. Se les avisó a tus referentes\.":""\}\)/.test(pc) && /confirm\("¿Cancelar el camino\? "\+\(V&&V\.avisaCambios\?"Se les avisa a tus referentes\.":"No se les avisa a tus referentes\."\)\)/.test(pc) && /id="cmNota"/.test(pc) && /Si cambiás de destino, se les avisa a tus referentes/.test(pc) && /Se les avisó a tus referentes\.":""\)\)/.test(pc), "al cancelar o cambiar el destino la pantalla avisa que se les avisa a los referentes (si esta prendido) y despues cuenta que se les aviso; si no se les aviso, no repite el texto de arriba (la tarjeta ya dice que se cancelo)");
  ok(/id="aInicio" href="\/">Ir al inicio<\/a>/.test(pc) && /id="bInicio" href="\/">Ir al inicio<\/a>/.test(pc) && (pc.match(/Ir al inicio/g) ?? []).length === 3, "la pagina del camino tambien lleva a la pagina de inicio: arriba, en la tarjeta del final y si el enlace no sirve");
  const tpi: string = await (pldPaginaDuenio() as any).text();
  ok(/<div class="arriba"><a class="atras" id="aInicio" href="\/">← Ir al inicio<\/a><a class="atras" id="aHub" href="#" style="display:none">← Tu protección<\/a><\/div>\s*<h1 id="titulo">Tu protección<\/h1>/.test(tpi), "Tu proteccion tiene arriba un enlace para ir a la pagina de inicio y otro (que aparece solo dentro de un modo) para volver a Tu proteccion");
  await preparar();
}

console.log("== Modo Guardian: el tiempo lo calcula Google Mapas");
{
  const gd = async (cuerpo: unknown) => gdApi(pedido(ORIGEN + "/api/guardian", "POST", cuerpo), env);
  const fetchReal = globalThis.fetch;
  const llamadas: Array<{ url: string; cabeceras: any; cuerpo: any }> = [];
  let respuesta: () => Response = () => new Response("{}", { status: 500 });
  const llamadasP: Array<{ url: string; cabeceras: any; cuerpo: any }> = [];
  let respuestaP: () => Response = () => new Response("{}", { status: 500 });
  globalThis.fetch = (async (url: any, init: any) => {
    if (String(url).includes("places.googleapis.com")) { llamadasP.push({ url: String(url), cabeceras: init.headers, cuerpo: JSON.parse(init.body) }); return respuestaP(); }
    if (String(url).includes("routes.googleapis.com")) { llamadas.push({ url: String(url), cabeceras: init.headers, cuerpo: JSON.parse(init.body) }); return respuesta(); }
    return fetchReal(url, init);
  }) as any;
  const ruta = (seg: number, fin = { lat: -34.57, lng: -58.4 }) => () => new Response(JSON.stringify({ routes: [{ duration: seg + "s", distanceMeters: 4200, legs: [{ endLocation: { latLng: { latitude: fin.lat, longitude: fin.lng } } }] }] }), { status: 200 });
  const viaje = () => sqlite.prepare("SELECT * FROM gd_viajes WHERE owner_email=? ORDER BY started_at DESC LIMIT 1").get(DUENIO) as any;

  await preparar();
  sqlite.exec("DELETE FROM gd_viajes; DELETE FROM family_places");
  sqlite.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)").run("pl1", DUENIO, "Casa", -34.57, -58.4, 150, now());
  dispositivo({ seen: 1, bat: 80, lat: -34.6, lng: -58.4 });
  setSesion({ email: DUENIO, method: "passkey" });

  // sin clave: se estima por la distancia (como antes)
  delete (env as any).GOOGLE_ROUTES_KEY;
  let r3: any = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "auto" })).json();
  ok(r3.fuente === "distancia" && r3.editable === true && llamadas.length === 0, "sin clave de Google se estima por la distancia y la persona puede cambiar el tiempo");

  // con clave
  (env as any).GOOGLE_ROUTES_KEY = "clave-de-prueba";
  respuesta = ruta(1230);
  r3 = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "auto" })).json();
  ok(r3.fuente === "mapas" && r3.minutos === 21 && r3.editable === false && r3.km === 4.2, "con la clave, el tiempo sale de Google Mapas (1230 s = 21 min) y no se puede cambiar");
  const l = llamadas[0];
  ok(/computeRoutes/.test(l.url) && l.cabeceras["X-Goog-Api-Key"] === "clave-de-prueba" && /routes\.duration/.test(l.cabeceras["X-Goog-FieldMask"]), "se le pide a Google la ruta con la clave y solo los campos que hacen falta");
  ok(l.cuerpo.travelMode === "DRIVE" && l.cuerpo.routingPreference === "TRAFFIC_AWARE" && l.cuerpo.origin.location.latLng.latitude === -34.6 && l.cuerpo.destination.location.latLng.latitude === -34.57 && l.cuerpo.regionCode === "AR", "en auto va con el transito de ahora, desde donde esta el telefono hasta el Lugar");
  await gd({ accion: "estimar", lugarId: "pl1", modo: "caminando" });
  ok(llamadas[1].cuerpo.travelMode === "WALK" && !("routingPreference" in llamadas[1].cuerpo), "caminando es WALK, sin preferencia de transito");
  await gd({ accion: "estimar", lugarId: "pl1", modo: "transporte" });
  ok(llamadas[2].cuerpo.travelMode === "TRANSIT" && !("routingPreference" in llamadas[2].cuerpo), "transporte publico es TRANSIT");
  await gd({ accion: "estimar", lugarId: "pl1", modo: "auto", origen: { lat: -34.61, lng: -58.45 } });
  ok(llamadas[3].cuerpo.origin.location.latLng.latitude === -34.61 && llamadas[3].cuerpo.origin.location.latLng.longitude === -58.45, "si el celular de la persona da su ubicacion exacta, sale desde ahi");
  await gd({ accion: "estimar", lugarId: "pl1", modo: "auto", origen: { lat: 999, lng: 0 } });
  ok(llamadas[4].cuerpo.origin.location.latLng.latitude === -34.6, "una ubicacion imposible se ignora");

  // otra direccion escrita
  respuesta = ruta(900, { lat: -34.55, lng: -58.45 });
  r3 = await (await gd({ accion: "estimar", texto: "Av. Cabildo 2040, Buenos Aires", modo: "auto" })).json();
  ok(r3.fuente === "mapas" && r3.minutos === 15 && llamadas[5].cuerpo.destination.address === "Av. Cabildo 2040, Buenos Aires", "una direccion escrita tambien la calcula Google");
  respuesta = ruta(20 * 3600);
  r3 = await (await gd({ accion: "estimar", texto: "Kansas", modo: "auto" })).json();
  ok(r3.minutos === null && r3.error === "destino_muy_lejos", "si queda a mas de 5 horas (por ejemplo Kansas, EEUU) se avisa que revise la direccion");
  let re = await gd({ accion: "empezar", texto: "Kansas", modo: "auto", minutos: 10 });
  ok(re.status === 400 && (await re.json() as any).error === "destino_muy_lejos", "y no deja empezar ese camino, ni poniendo minutos a mano");

  // empezar: manda Google, no lo que escriba la persona
  respuesta = ruta(1230);
  re = await gd({ accion: "empezar", lugarId: "pl1", modo: "auto", minutos: 3 });
  const e3: any = await re.json();
  ok(re.status === 200 && e3.viaje.estimadoMin === 21 && viaje().estimado_min === 21, "al empezar vale el tiempo de Google (21 min) aunque la pantalla mande otro numero");
  ok((await (await api()).json() as any).registro.some((x: any) => /21 min \(calculado con mapas y el tránsito de ahora\)/.test(x.detail)), "el registro dice de donde salio el tiempo");
  sqlite.exec("DELETE FROM gd_viajes");
  respuesta = ruta(600, { lat: -34.5, lng: -58.5 });
  re = await gd({ accion: "empezar", texto: "Una direccion", modo: "auto" });
  ok(re.status === 200 && viaje().dest_lat === -34.5 && viaje().dest_lng === -58.5 && viaje().estimado_min === 10, "con una direccion escrita se guardan las coordenadas que devolvio Google (sirven para saber si llego)");
  sqlite.exec("DELETE FROM gd_viajes");

  // si Google falla
  respuesta = () => new Response("error", { status: 500 });
  r3 = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "auto" })).json();
  ok(r3.fuente === "distancia" && r3.minutos >= 8, "si Google no contesta, para un Lugar se estima por la distancia");
  r3 = await (await gd({ accion: "estimar", texto: "Una direccion", modo: "auto" })).json();
  ok(r3.minutos === null && r3.fuente === null, "y para una direccion escrita no hay calculo: la persona pone los minutos");
  re = await gd({ accion: "empezar", texto: "Una direccion", modo: "auto", minutos: 25 });
  ok(re.status === 200 && viaje().estimado_min === 25 && (await (await api()).json() as any).registro.some((x: any) => /tiempo que pusiste vos/.test(x.detail)), "con los minutos que pone la persona se puede empezar (queda anotado)");
  sqlite.exec("DELETE FROM gd_viajes");
  respuesta = () => new Response(JSON.stringify({ routes: [] }), { status: 200 });
  r3 = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "transporte" })).json();
  ok(r3.fuente === "distancia", "si Google no encuentra una ruta (por ejemplo en transporte) se estima por la distancia");

  // por que falla Google (para decirselo a la persona)
  respuesta = () => new Response(JSON.stringify({ error: { code: 403, message: "Routes API has not been used in project 123 before or it is disabled." } }), { status: 403 });
  r3 = await (await gd({ accion: "estimar", texto: "Una direccion", modo: "auto" })).json();
  ok(r3.minutos === null && r3.fallo === "http_403" && /Routes API has not been used/.test(r3.detalle), "si Google rechaza la clave, se lo dice (http_403 y el motivo que da Google) en vez de dejar un numero viejo");
  r3 = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "auto" })).json();
  ok(r3.fuente === "distancia" && r3.fallo === "http_403", "para un Lugar se estima por la distancia y tambien avisa que Google no pudo");

  console.log("-- sugerencias de direcciones (Google Places)");
  respuestaP = () => new Response(JSON.stringify({ suggestions: [
    { placePrediction: { placeId: "ChIJabcdefghij1", distanceMeters: 3240, text: { text: "Av. Cabildo 2359, C1428 Cdad. Autónoma de Buenos Aires" }, structuredFormat: { mainText: { text: "Av. Cabildo 2359" }, secondaryText: { text: "Belgrano, Buenos Aires" } } } },
    { placePrediction: { placeId: "ChIJabcdefghij2", distanceMeters: 281000, text: { text: "Av. Cabildo 2359, Rosario" }, structuredFormat: { mainText: { text: "Av. Cabildo 2359" }, secondaryText: { text: "Rosario, Santa Fe" } } } },
    { placePrediction: { placeId: "ChIJrestaurante1", distanceMeters: 1800, text: { text: "Kansas Cabildo, Av. Cabildo 2501, Buenos Aires" }, structuredFormat: { mainText: { text: "Kansas Cabildo" }, secondaryText: { text: "Av. Cabildo 2501, Belgrano" } } } },
  ] }), { status: 200 });
  let rb: any = await (await gd({ accion: "buscar", texto: "av cab" })).json();
  const lp = llamadasP[0];
  ok(rb.sugerencias.length === 3 && rb.sugerencias[0].placeId === "ChIJabcdefghij1" && rb.sugerencias[0].principal === "Av. Cabildo 2359" && rb.sugerencias[0].secundario === "Belgrano, Buenos Aires", "al escribir devuelve sugerencias con el barrio y la ciudad");
  ok(rb.sugerencias[0].km === 3.2 && rb.sugerencias[1].km === 281, "cada sugerencia dice a cuantos km queda (para distinguir el Cabildo de Rosario)");
  ok(rb.sugerencias[2].principal === "Kansas Cabildo" && rb.sugerencias[2].placeId === "ChIJrestaurante1" && !("includedPrimaryTypes" in lp.cuerpo), "tambien salen nombres de lugares (un restaurante), no solo direcciones: la busqueda no se limita a direcciones");
  ok(lp.cuerpo.origin.latitude === -34.6 && lp.cuerpo.origin.longitude === -58.4 && !("X-Goog-FieldMask" in lp.cabeceras), "y se le pasa el origen a Google para que calcule esas distancias (sin mascara de campos: el autocompletar no la necesita)");
  ok(/places:autocomplete/.test(lp.url) && lp.cabeceras["X-Goog-Api-Key"] === "clave-de-prueba" && lp.cuerpo.input === "av cab" && lp.cuerpo.regionCode === "AR" && lp.cuerpo.languageCode === "es" && lp.cuerpo.locationBias.circle.center.latitude === -34.6, "se le pide a Google con la clave, en espanol, en Argentina y cerca de donde esta el telefono");
  const antesP = llamadasP.length;
  rb = await (await gd({ accion: "buscar", texto: "av" })).json();
  ok(rb.sugerencias.length === 0 && llamadasP.length === antesP, "con menos de 3 letras no se busca");
  respuestaP = () => new Response(JSON.stringify({ error: { message: "Places API (New) has not been used in project 123." } }), { status: 403 });
  rb = await (await gd({ accion: "buscar", texto: "av cabildo" })).json();
  ok(rb.sugerencias.length === 0 && rb.fallo === "http_403" && /Places API \(New\)/.test(rb.detalle), "si Google no deja buscar (Places sin habilitar) se lo dice");
  // si Google rechaza el pedido completo (400), prueba con uno mas simple
  const buenas = JSON.stringify({ suggestions: [{ placePrediction: { placeId: "ChIJrestaurante1", text: { text: "La Panera Rosa, Av. Santa Fe 1234" }, structuredFormat: { mainText: { text: "La Panera Rosa" }, secondaryText: { text: "Av. Santa Fe 1234, Palermo" } } } }] });
  let n400 = 0;
  respuestaP = () => { n400++; return n400 === 1 ? new Response(JSON.stringify({ error: { code: 400, message: "Invalid value at 'origin'", status: "INVALID_ARGUMENT" } }), { status: 400 }) : new Response(buenas, { status: 200 }); };
  const nP = llamadasP.length;
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(rb.sugerencias.length === 1 && rb.sugerencias[0].principal === "La Panera Rosa" && rb.sugerencias[0].km === null && !rb.fallo && llamadasP.length === nP + 2, "si Google rechaza el pedido con ubicacion (400), se reintenta mas simple y salen las sugerencias igual");
  ok(llamadasP[nP].cuerpo.origin && !llamadasP[nP + 1].cuerpo.origin && !llamadasP[nP + 1].cuerpo.locationBias && llamadasP[nP + 1].cuerpo.regionCode === "AR", "el segundo intento va sin ubicacion pero con el pais");
  respuestaP = () => new Response(JSON.stringify({ error: { code: 400, message: "Invalid JSON payload received.", status: "INVALID_ARGUMENT" } }), { status: 400 });
  const nQ = llamadasP.length;
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(rb.sugerencias.length === 0 && rb.fallo === "http_400" && /\[A400 B400 C400\] Invalid JSON payload/.test(rb.detalle) && llamadasP.length === nQ + 3, "si los tres intentos fallan, dice cuales y el motivo exacto de Google");
  respuestaP = () => new Response("", { status: 400 });
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(rb.fallo === "http_400" && /\[A400 B400 C400\]/.test(rb.detalle), "aunque Google conteste 400 sin cuerpo, queda el detalle de los intentos");
  respuestaP = () => new Response(JSON.stringify({ error: { code: 400, message: "API key not valid. Please pass a valid API key.", status: "INVALID_ARGUMENT" } }), { status: 400 });
  const nK = llamadasP.length;
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(rb.fallo === "http_400" && /API key not valid/.test(rb.detalle) && llamadasP.length === nK + 1, "si la clave no es valida no se reintenta (seria repetir el mismo error)");
  respuestaP = () => new Response("<html>Bad Request</html>", { status: 400, headers: { "content-type": "text/html" } });
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(rb.fallo === "http_400" && /Bad Request/.test(rb.detalle), "si Google contesta algo que no es JSON, se muestra el principio de la respuesta");
  respuesta = () => new Response(JSON.stringify({ error: { code: 400, status: "INVALID_ARGUMENT" } }), { status: 400 });
  r3 = await (await gd({ accion: "estimar", texto: "Una direccion", modo: "auto" })).json();
  ok(r3.fallo === "http_400" && /INVALID_ARGUMENT/.test(r3.detalle), "tambien al calcular la ruta: si Google no da mensaje, se muestra su estado");
  // si se corta la conexion con Google ("Network connection lost"), se reintenta
  let cortes = 0;
  respuestaP = () => { cortes++; if (cortes === 1) throw new Error("Network connection lost."); return new Response(buenas, { status: 200 }); };
  const nR1 = llamadasP.length;
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(rb.sugerencias.length === 1 && !rb.fallo && llamadasP.length === nR1 + 2, "si se corta la conexion con Google una vez, se reintenta y salen las sugerencias");
  respuestaP = () => { throw new Error("Network connection lost."); };
  const nR2 = llamadasP.length;
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(rb.sugerencias.length === 0 && rb.fallo === "red" && /\[A:red B:red C:red\] Error: Network connection lost/.test(rb.detalle) && llamadasP.length === nR2 + 6, "si la conexion no vuelve, prueba los tres pedidos (dos veces cada uno) y dice que no hubo conexion con el detalle");
  let cortesR = 0;
  respuesta = () => { cortesR++; if (cortesR === 1) throw new Error("Network connection lost."); return ruta(600)(); };
  r3 = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "auto" })).json();
  ok(r3.fuente === "mapas" && r3.minutos === 10 && cortesR === 2, "tambien al calcular la ruta: si se corta la conexion una vez, se reintenta");
  respuesta = () => { throw new Error("Network connection lost."); };
  r3 = await (await gd({ accion: "estimar", texto: "Una direccion", modo: "auto" })).json();
  ok(r3.minutos === null && r3.fallo === "red" && /Network connection lost/.test(r3.detalle), "si la conexion no vuelve, el motivo que se muestra es la falta de conexion con Google");
  // Google contesta bien pero sin resultados: se prueba mas simple y, si sigue vacio, se dice que no encontro nada
  respuestaP = () => new Response("{}", { status: 200 });
  const nV = llamadasP.length;
  rb = await (await gd({ accion: "buscar", texto: "zzzz" })).json();
  ok(rb.sugerencias.length === 0 && rb.fallo === "sin_resultados" && /\[A200 B200 C200\]/.test(rb.detalle) && llamadasP.length === nV + 3, "si Google no encuentra nada, prueba los tres pedidos y dice que no hubo resultados (no queda en blanco)");
  let vacios = 0;
  respuestaP = () => { vacios++; return vacios === 1 ? new Response("{}", { status: 200 }) : new Response(buenas, { status: 200 }); };
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa caba" })).json();
  ok(rb.sugerencias.length === 1 && !rb.fallo && vacios === 2, "si el pedido con ubicacion no da resultados, el pedido mas simple los encuentra");
  const tp: string = await (pldPaginaDuenio() as any).text();
  ok(/Buscando…/.test(tp) && /Al panel le falta la clave de Google/.test(tp) && /el panel contestó con un error/.test(tp) && /Probá con otro nombre, o con la dirección y la ciudad/.test(tp) && /respuesta_"\+r\.status/.test(tp), "la pantalla siempre dice que paso: buscando, sin clave, error del panel o sin resultados");

  // clave con caracteres invisibles (por ejemplo al pegarla en la consola): se limpia antes de mandarla
  const buena = "AIza" + "b".repeat(35);
  (env as any).GOOGLE_ROUTES_KEY = "\u001b[200~" + buena + "\u001b[201~";
  respuestaP = () => new Response(buenas, { status: 200 });
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(rb.sugerencias.length === 1 && llamadasP[llamadasP.length - 1].cabeceras["X-Goog-Api-Key"] === buena, "si a la clave se le colaron caracteres invisibles, a Google le llega limpia");
  respuesta = ruta(600);
  r3 = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "auto" })).json();
  ok(r3.fuente === "mapas" && llamadas[llamadas.length - 1].cabeceras["X-Goog-Api-Key"] === buena, "tambien en el calculo de la ruta");
  respuestaP = () => new Response("", { status: 400 });
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(/clave de 39 caracteres, empieza con AIza, se quitaron 12 caracteres raros/.test(rb.detalle) && !rb.detalle.includes("bbbbbbbb"), "si igual falla, la pantalla dice cuantos caracteres tenia la clave y cuantos se quitaron, sin mostrarla");
  respuesta = () => new Response("", { status: 400 });
  r3 = await (await gd({ accion: "estimar", texto: "Una direccion", modo: "auto" })).json();
  ok(r3.fallo === "http_400" && /clave de 39 caracteres, empieza con AIza, se quitaron 12 caracteres raros/.test(r3.detalle), "lo mismo al calcular la ruta");
  (env as any).GOOGLE_ROUTES_KEY = "clave-de-prueba";
  respuestaP = () => new Response("", { status: 400 });
  rb = await (await gd({ accion: "buscar", texto: "la panera rosa" })).json();
  ok(/\[A400 B400 C400\]  \(clave de 15 caracteres, empieza con clav\)/.test(rb.detalle) && !/se quitaron/.test(rb.detalle), "con una clave normal y 400 sin mensaje, la pantalla igual da los datos de la clave");
  (env as any).GOOGLE_ROUTES_KEY = "  clave-de-prueba \n";
  respuestaP = () => new Response(buenas, { status: 200 });
  await gd({ accion: "buscar", texto: "la panera rosa" });
  ok(llamadasP[llamadasP.length - 1].cabeceras["X-Goog-Api-Key"] === "clave-de-prueba", "los espacios y saltos de linea de la clave se quitan");
  (env as any).GOOGLE_ROUTES_KEY = "clave-de-prueba";
  delete (env as any).GOOGLE_ROUTES_KEY;
  rb = await (await gd({ accion: "buscar", texto: "av cabildo" })).json();
  ok(rb.sugerencias.length === 0 && rb.fallo === "sin_clave", "sin clave no hay sugerencias");
  (env as any).GOOGLE_ROUTES_KEY = "clave-de-prueba";

  console.log("-- elegir una sugerencia");
  respuesta = ruta(1500, { lat: -34.56, lng: -58.45 });
  const nR = llamadas.length;
  r3 = await (await gd({ accion: "estimar", placeId: "ChIJabcdefghij1", texto: "Av. Cabildo 2359, Belgrano, Buenos Aires", modo: "auto" })).json();
  ok(r3.fuente === "mapas" && r3.minutos === 25 && llamadas[nR].cuerpo.destination.placeId === "ChIJabcdefghij1" && !("address" in llamadas[nR].cuerpo.destination), "con una sugerencia elegida, Google calcula hasta ESE lugar exacto (placeId), no una calle suelta");
  ok((await (await gd({ accion: "estimar", placeId: "x y;z", modo: "auto" })).json() as any).error === "destino_invalido", "un identificador de lugar raro se rechaza");
  const e5: any = await (await gd({ accion: "empezar", placeId: "ChIJabcdefghij1", texto: "Av. Cabildo 2359, Belgrano, Buenos Aires", modo: "auto" })).json();
  ok(e5.viaje.destino === "Av. Cabildo 2359, Belgrano, Buenos Aires" && e5.viaje.estimadoMin === 25 && viaje().dest_lat === -34.56 && viaje().dest_lng === -58.45, "el camino queda con el nombre completo (barrio y ciudad), el tiempo de Google y las coordenadas exactas del destino");
  sqlite.exec("DELETE FROM gd_viajes");

  delete (env as any).GOOGLE_ROUTES_KEY;
  globalThis.fetch = fetchReal;
  const tg: string = await (pldPaginaDuenio() as any).text();
  ok(/id="gdSugerencias"/.test(tg) && /accion:"buscar"/.test(tg) && /GDPLACE/.test(tg) && /Elegí uno de los lugares que te sugerimos/.test(tg) && /Dirección o nombre del lugar/.test(tg) && /Kansas Cabildo/.test(tg), "la tarjeta del Guardian muestra las sugerencias (direcciones y nombres de lugares) con su distancia y no deja empezar sin elegir una");
  ok(/Google rechazó el pedido/.test(tg) && /d\.detalle\.slice\(0,260\)/.test(tg), "si Google rechaza un pedido, la pantalla lo dice y muestra el detalle que dejo el servidor");
  await preparar();
}

console.log("== Modo Guardian: configuracion propia (margen, aviso previo, mas tiempo, avisos)");
{
  const gd = async (cuerpo: unknown) => gdApi(pedido(ORIGEN + "/api/guardian", "POST", cuerpo), env);
  const viaje = () => sqlite.prepare("SELECT * FROM gd_viajes WHERE owner_email=? ORDER BY started_at DESC LIMIT 1").get(DUENIO) as any;
  const min = (n: number) => new Date(Date.now() + n * 60_000).toISOString();
  const fijar = (campos: Record<string, unknown>) => { const ks = Object.keys(campos); sqlite.prepare(`UPDATE gd_viajes SET ${ks.map((k) => k + "=?").join(",")} WHERE id=?`).run(...ks.map((k) => campos[k] as any), viaje().id); };
  await preparar();
  sqlite.exec("DELETE FROM gd_viajes; DELETE FROM family_places; DELETE FROM gd_config");
  sqlite.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)").run("pl1", DUENIO, "Casa", -34.57, -58.4, 150, now());
  dispositivo({ seen: 1, bat: 80, lat: -34.6, lng: -58.4 });
  setSesion({ email: DUENIO, method: "passkey" });

  console.log("-- valores recomendados");
  const c0: any = await (await gd({ accion: "estado" })).json();
  ok(c0.config.margenMin === 2 && c0.config.avisoMin === 2 && c0.config.maxExtensiones === 3 && c0.config.entreAlertasMin === 10 && c0.config.maxAlertas === 3 && c0.config.autoAjusteMin === 60 && c0.config.radioLlegadaM === 150 && c0.config.avisarCambios === 1 && JSON.stringify(c0.config) === JSON.stringify(c0.defaults), "sin haber cambiado nada el Modo Guardian usa los valores recomendados (2 min de margen, preguntar 2 min antes, 3 veces mas tiempo, avisos cada 10 min hasta 3, llegada a menos de 150 m, avisar si cambia el destino o cancela)");

  console.log("-- cambiar y guardar");
  const nuevaCfg = { margenMin: 5, avisoMin: 4, maxExtensiones: 1, entreAlertasMin: 15, maxAlertas: 2, autoAjusteMin: 45, radioLlegadaM: 100, avisarCambios: 0 };
  let cf: any = await (await gd({ accion: "config", config: nuevaCfg })).json();
  ok(cf.ok && JSON.stringify(cf.config) === JSON.stringify(nuevaCfg) && JSON.stringify(cf.defaults) === JSON.stringify(c0.defaults), "se guardan los tiempos y avisos que la persona elige");
  ok(JSON.stringify((await (await gd({ accion: "estado" })).json() as any).config) === JSON.stringify(nuevaCfg), "y quedan guardados");
  cf = await (await gd({ accion: "config", config: { margenMin: 99, avisoMin: 0, maxExtensiones: -3, entreAlertasMin: 1, maxAlertas: 99, autoAjusteMin: 999, radioLlegadaM: 5000, avisarCambios: 7 } })).json();
  ok(cf.config.margenMin === 15 && cf.config.avisoMin === 1 && cf.config.maxExtensiones === 0 && cf.config.entreAlertasMin === 5 && cf.config.maxAlertas === 5 && cf.config.autoAjusteMin === 180 && cf.config.radioLlegadaM === 500 && cf.config.avisarCambios === 1, "los numeros fuera de rango se acomodan a los limites (margen 1 a 15, aviso 1 a 10, mas tiempo 0 a 5, repetir 5 a 60, avisos 1 a 5, tiempo por transito 0 a 180, margen de llegada 50 a 500 m)");
  cf = await (await gd({ accion: "config", config: { radioLlegadaM: 3 } })).json();
  ok(cf.config.radioLlegadaM === 50, "el margen de llegada no baja de 50 metros (menos que eso el GPS no alcanza)");
  cf = await (await gd({ accion: "config", config: { autoAjusteMin: -5 } })).json();
  ok(cf.config.autoAjusteMin === 0, "con 0 no se suma tiempo por transito (queda apagado)");
  cf = await (await gd({ accion: "config", config: { margenMin: "", avisoMin: null } })).json();
  ok(cf.config.margenMin === 15 && cf.config.avisoMin === 1, "un casillero vacio o sin dato deja el valor que estaba (no lo baja al minimo)");
  cf = await (await gd({ accion: "config", config: { margenMin: "abc", avisoMin: 7 } })).json();
  ok(cf.config.margenMin === 15 && cf.config.avisoMin === 7 && cf.config.maxAlertas === 5, "si un valor no es un numero o no viene, queda el que estaba");
  cf = await (await gd({ accion: "config", config: { restablecer: true } })).json();
  ok(JSON.stringify(cf.config) === JSON.stringify(c0.defaults) && JSON.stringify((await (await gd({ accion: "estado" })).json() as any).config) === JSON.stringify(c0.defaults), "'Volver a los valores recomendados' deja todo como vino");
  const reg = (await (await api()).json() as any).registro.map((x: any) => x.detail).join(" | ");
  ok(/Cambiaste los tiempos y avisos del Modo Guardi/.test(reg) && /valores recomendados/.test(reg), "los cambios quedan en el registro");
  setSesion(null);
  ok((await gd({ accion: "config", config: nuevaCfg })).status === 401, "sin entrar al panel no se puede cambiar");
  setSesion({ email: DUENIO, method: "passkey" });
  await gd({ accion: "config", config: nuevaCfg });

  console.log("-- el margen y el limite del camino");
  let rs: any = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  ok(rs.viaje.margenMin === 5 && rs.viaje.extensionesMax === 1 && Math.abs((Date.parse(rs.viaje.deadlineAt) - Date.parse(rs.viaje.startedAt)) / 60000 - (rs.viaje.estimadoMin + 5)) < 0.1, "con margen de 5 minutos, el limite es lo que tarda mas 5");
  ok((await (await api()).json() as any).registro.some((x: any) => /\+ 5 de margen/.test(x.detail)), "y el registro dice 5 de margen");
  const bloq = await gd({ accion: "config", config: { margenMin: 3 } });
  ok(bloq.status === 409 && (await bloq.json() as any).error === "camino_en_marcha" && (await (await gd({ accion: "estado" })).json() as any).config.margenMin === 5, "con un camino en marcha no se cambian los tiempos y avisos (se cambian cuando termine)");
  const TOKEN = rs.viaje.enlace.split("t=")[1];
  ok((await gd({ t: TOKEN, accion: "config", config: { margenMin: 3 } })).status === 400, "y desde el enlace del camino tampoco se puede");
  const estT: any = await (await gd({ t: TOKEN, accion: "estado" })).json();
  ok(!("config" in estT) && !("defaults" in estT), "el enlace del camino no muestra la configuracion");

  console.log("-- preguntar si sigue en camino");
  let n = correos.length;
  fijar({ deadline_at: min(6) });
  await gdCron(env);
  ok(viaje().estado === "en_camino" && mailsDesde(n).length === 0, "faltando 6 minutos todavia no se pregunta (el aviso es a los 4)");
  fijar({ deadline_at: min(3.5) });
  await gdCron(env);
  ok(viaje().estado === "aviso" && mailsDesde(n).some((c) => /Seguís en camino/.test(c.subject)), "faltando 3 minutos y medio ya se pregunta si sigue en camino (con el valor recomendado, de 2 minutos, todavia no)");

  console.log("-- pedir mas tiempo");
  setSesion(null);
  let ex = await gd({ t: TOKEN, accion: "extender", minutos: 10 });
  ok(ex.status === 200 && viaje().extensiones === 1, "con una sola vez permitida, la primera sale");
  ex = await gd({ t: TOKEN, accion: "extender", minutos: 10 });
  const estX: any = await (await gd({ t: TOKEN, accion: "estado" })).json();
  ok(ex.status === 409 && (await ex.json() as any).error === "demasiadas_extensiones" && estX.viaje.puedeExtender === false && estX.viaje.extensionesMax === 1, "y la segunda no (la pagina lo sabe: puedeExtender = false)");

  console.log("-- avisos a los referentes si no llega");
  setSesion({ email: DUENIO, method: "passkey" });
  n = correos.length;
  fijar({ estado: "en_camino", deadline_at: min(-1), aviso_at: null });
  await gdCron(env);
  const aRef = (desde: number) => mailsDesde(desde).filter((c) => /no llegó a Casa/.test(c.subject));
  ok(viaje().alertas === 1 && aRef(n).length === 2 && /aviso 1 de 2 como máximo/.test(aRef(n)[0].html), "el primer aviso dice cuantos avisos como maximo hay (2)");
  n = correos.length;
  fijar({ last_alert_at: new Date(Date.now() - 12 * 60_000).toISOString() });
  await gdCron(env);
  ok(viaje().alertas === 1 && aRef(n).length === 0, "con avisos cada 15 minutos, a los 12 todavia no se repite");
  fijar({ last_alert_at: new Date(Date.now() - 16 * 60_000).toISOString() });
  await gdCron(env);
  ok(viaje().alertas === 2 && aRef(n).length === 2 && /aviso 2 de 2 como máximo/.test(aRef(n)[0].html), "a los 16 sale el segundo");
  n = correos.length;
  fijar({ last_alert_at: new Date(Date.now() - 40 * 60_000).toISOString() });
  await gdCron(env);
  ok(viaje().alertas === 2 && aRef(n).length === 0, "y no hay un tercero: el maximo es 2");
  setSesion(null);
  await gd({ t: TOKEN, accion: "llegue" });
  setSesion({ email: DUENIO, method: "passkey" });

  console.log("-- sin pedir mas tiempo");
  await gd({ accion: "config", config: { maxExtensiones: 0 } });
  rs = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  const T2 = rs.viaje.enlace.split("t=")[1];
  ok(rs.viaje.extensionesMax === 0 && rs.viaje.puedeExtender === false, "con 0 veces de mas tiempo, el camino empieza sin esa opcion");
  setSesion(null);
  const r0 = await gd({ t: T2, accion: "extender", minutos: 10 });
  ok(r0.status === 409 && (await r0.json() as any).error === "sin_extensiones" && viaje().extensiones === 0, "y si se intenta, el servidor dice que en la configuracion no se puede");
  await gd({ t: T2, accion: "cancelar" });

  console.log("-- un menor no lo cambia");
  setSesion({ email: DUENIO, method: "passkey" });
  sqlite.prepare("INSERT INTO family_members (id,owner_email,member_email,name,owner_name,role,status) VALUES (?,?,?,?,?,?,?)").run("fmcfg", "titular@correo.com", DUENIO, "Lucas", "Titular", "menor", "activo");
  const cm = await gd({ accion: "config", config: { margenMin: 9 } });
  ok(cm.status === 403 && (await cm.json() as any).error === "solo_administrador", "una persona menor no cambia los tiempos y avisos (los cambia el administrador de la familia)");
  sqlite.exec("DELETE FROM family_members WHERE id='fmcfg'");
  await gd({ accion: "config", config: { restablecer: true } });
  const pano: any = await (await api()).json();
  ok(JSON.stringify(pano.defaults) === JSON.stringify(PLD_POR_DEFECTO) && pano.defaults.nightFrom === 21, "la pagina de Tu proteccion recibe tambien los valores recomendados del Modo Cautela (para 'Volver a los valores recomendados')");
  console.log("-- la tabla se crea sola (no hace falta tocar la base al instalar)");
  sqlite.exec("DROP TABLE gd_config");
  gdTablaLista = false;
  const sinTabla: any = await (await gd({ accion: "estado" })).json();
  ok(JSON.stringify(sinTabla.config) === JSON.stringify(c0.defaults), "si la tabla todavia no existe, se usan los valores recomendados");
  const creada: any = await (await gd({ accion: "config", config: nuevaCfg })).json();
  ok(creada.ok && JSON.stringify((await (await gd({ accion: "estado" })).json() as any).config) === JSON.stringify(nuevaCfg), "y al guardar por primera vez se crea la tabla y queda guardado");
  await gd({ accion: "config", config: { restablecer: true } });
  sqlite.exec("DELETE FROM gd_viajes");
  await preparar();
}

console.log("== Modo Guardian: recalculo por transito, frenar un rato y cambiar de destino");
{
  const gd = async (cuerpo: unknown) => gdApi(pedido(ORIGEN + "/api/guardian", "POST", cuerpo), env);
  const viaje = () => sqlite.prepare("SELECT * FROM gd_viajes WHERE owner_email=? ORDER BY started_at DESC LIMIT 1").get(DUENIO) as any;
  const min = (n: number) => new Date(Date.now() + n * 60_000).toISOString();
  const fijar = (campos: Record<string, unknown>) => { const ks = Object.keys(campos); sqlite.prepare(`UPDATE gd_viajes SET ${ks.map((k) => k + "=?").join(",")} WHERE id=?`).run(...ks.map((k) => campos[k] as any), viaje().id); };
  const progreso = () => sqlite.prepare("SELECT * FROM gd_progreso WHERE viaje_id=?").get(viaje().id) as any;
  const poner = (campos: Record<string, unknown>) => {
    const ks = Object.keys(campos), id = viaje().id;
    if (!progreso()) sqlite.prepare("INSERT INTO gd_progreso (viaje_id) VALUES (?)").run(id);
    sqlite.prepare(`UPDATE gd_progreso SET ${ks.map((k) => k + "=?").join(",")} WHERE viaje_id=?`).run(...ks.map((k) => campos[k] as any), id);
  };
  const fetchReal = globalThis.fetch;
  const llamadas: any[] = [], llamadasLugares: any[] = [];
  let seg = 1200, estadoRuta = 200;
  globalThis.fetch = (async (url: any, init: any) => {
    if (String(url).includes("routes.googleapis.com")) { llamadas.push(JSON.parse(init.body)); return estadoRuta === 200 ? new Response(JSON.stringify({ routes: [{ duration: seg + "s", distanceMeters: 3000, legs: [{ endLocation: { latLng: { latitude: -34.57, longitude: -58.4 } } }] }] }), { status: 200 }) : new Response("{}", { status: estadoRuta }); }
    if (String(url).includes("places.googleapis.com")) { llamadasLugares.push(JSON.parse(init.body)); return new Response(JSON.stringify({ suggestions: [{ placePrediction: { placeId: "ChIJcambio00001", text: { text: "Kansas, Av. del Libertador" }, structuredFormat: { mainText: { text: "Kansas" }, secondaryText: { text: "Av. del Libertador, CABA" } } } }] }), { status: 200 }); }
    return fetchReal(url, init);
  }) as any;
  (env as any).GOOGLE_ROUTES_KEY = "clave-de-prueba";
  await preparar();
  sqlite.exec("DELETE FROM gd_viajes; DELETE FROM family_places; DELETE FROM gd_config; DELETE FROM gd_progreso");
  sqlite.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)").run("pl1", DUENIO, "Casa", -34.57, -58.4, 150, now());
  sqlite.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)").run("pl2", DUENIO, "Oficina", -34.55, -58.45, 150, now());
  setSesion({ email: DUENIO, method: "passkey" });
  const lejos = () => dispositivo({ seen: 1, bat: 80, lat: -34.6, lng: -58.4 }); // a unos 3,3 km de Casa
  lejos();
  const rs: any = await (await gd({ accion: "empezar", lugarId: "pl1", modo: "auto" })).json();
  let TOKEN = rs.viaje.enlace.split("t=")[1];
  llamadas.length = 0; // la consulta de arriba fue la de empezar el camino
  ok(rs.viaje.estimadoMin === 20 && rs.viaje.ajusteAutoMin === 0 && rs.viaje.puedeCambiar === true && rs.viaje.puedeParar === true && JSON.stringify(rs.viaje.opcionesParada) === "[15,30,60]", "el camino empieza sin tiempo sumado y se puede frenar y cambiar de destino");
  const desvio = (n: number) => { llamadas.length = 0; return n; };

  console.log("-- primera muestra: solo se guarda");
  fijar({ deadline_at: min(9.5) });
  await gdCron(env);
  ok(llamadas.length === 0 && progreso() && Math.abs(progreso().ref_lat - -34.6) < 1e-9 && viaje().estado === "en_camino", "la primera vez solo se guarda donde esta el telefono (para ver despues si avanza); no se le pregunta nada a Google");

  console.log("-- se acerca pero va a tardar mas: se suma solo");
  desvio(0);
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5) });
  seg = 900; // desde aca, 15 minutos
  const limite0 = Date.parse(viaje().deadline_at);
  avisos.length = 0;
  await gdCron(env);
  ok(llamadas.length === 1 && llamadas[0].origin.location.latLng.latitude === -34.6 && llamadas[0].travelMode === "DRIVE" && llamadas[0].routingPreference === "TRAFFIC_AWARE", "como se acerco, se le pregunta a Google cuanto falta desde donde esta, con el transito de ahora");
  const suma1 = Math.round((Date.parse(viaje().deadline_at) - limite0) / 60000);
  ok(suma1 === 8 && viaje().estado === "en_camino" && progreso().auto_min === 8, "Google dice 15 min mas 2 de margen y faltaban 9,5: se suman 8 minutos solos");
  ok(avisos.length === 1 && /Hay más tránsito/.test(avisos[0].title ?? avisos[0].titulo ?? JSON.stringify(avisos[0])) && /8 minutos/.test(JSON.stringify(avisos[0])), "y se le avisa en el telefono");
  ok((await (await api()).json() as any).registro.some((x: any) => /Hay más tránsito: se te sumaron 8 minutos/.test(x.detail)), "queda en el registro");
  const estA: any = await (await gd({ t: TOKEN, accion: "estado" })).json();
  ok(estA.viaje.ajusteAutoMin === 8 && estA.viaje.extensiones === 0, "la pagina del camino sabe cuanto se sumo por transito, y no cuenta como un pedido de mas tiempo");
  llamadas.length = 0;
  await gdCron(env);
  ok(llamadas.length === 0, "no se vuelve a consultar enseguida (como minimo cada 4 minutos)");

  console.log("-- si esta quieto, no se suma");
  fijar({ deadline_at: min(9.5) });
  poner({ ref_lat: -34.6, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5), auto_min: 0 });
  const limiteQ = Date.parse(viaje().deadline_at);
  await gdCron(env);
  ok(llamadas.length === 0 && Math.abs(Date.parse(viaje().deadline_at) - limiteQ) < 1000 && progreso().auto_min === 0, "si el telefono esta en el mismo lugar que hace unos minutos (freno), no se suma nada ni se le pregunta a Google");
  poner({ ref_lat: -34.595, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5) });
  await gdCron(env);
  ok(llamadas.length === 0 && Math.abs(Date.parse(viaje().deadline_at) - limiteQ) < 1000, "avanzar menos de 100 metros en 5 minutos tampoco cuenta (es el ruido del GPS)");
  poner({ ref_lat: -34.59, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5) });
  await gdCron(env);
  ok(llamadas.length === 0 && Math.abs(Date.parse(viaje().deadline_at) - limiteQ) < 1000, "y si se esta alejando, no se suma");

  console.log("-- cuando no corresponde evaluar");
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5) });
  fijar({ deadline_at: min(40) });
  await gdCron(env);
  ok(llamadas.length === 0, "con mas de 20 minutos por delante no se gasta una consulta a Google");
  fijar({ deadline_at: min(9.5) });
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(2), recalc_at: hace(5) });
  await gdCron(env);
  ok(llamadas.length === 0, "si la ubicacion de referencia es de hace menos de 3 minutos, todavia no se compara");
  dispositivo({ seen: 15, bat: 80, lat: -34.6, lng: -58.4 });
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(20), recalc_at: hace(5) });
  await gdCron(env);
  ok(llamadas.length === 0, "con una ubicacion de hace 15 minutos no se decide nada");
  lejos();
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5), auto_min: 60 });
  await gdCron(env);
  ok(llamadas.length === 0, "con el tope de 60 minutos ya usado, no se suma mas");
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5), auto_min: 0 });
  estadoRuta = 500;
  await gdCron(env);
  ok(llamadas.length === 1 && viaje().estado === "en_camino" && progreso().auto_min === 0, "si Google no contesta, no se toca nada");
  estadoRuta = 200; llamadas.length = 0;
  seg = 600; // 10 min + 2 de margen: apenas 2,5 minutos mas de lo que faltaba
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5) });
  await gdCron(env);
  ok(llamadas.length === 1 && progreso().auto_min === 3, "un atraso chico (de 2 minutos o mas) tambien se suma: aca 3 minutos");
  fijar({ deadline_at: min(9.5) }); seg = 560; // 9,3 min -> 10 + 2 = 12... atraso menor a 2
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5), auto_min: 0 });
  seg = 480; llamadas.length = 0;
  const limiteP = Date.parse(viaje().deadline_at);
  await gdCron(env);
  ok(llamadas.length === 1 && Math.abs(Date.parse(viaje().deadline_at) - limiteP) < 1000, "si Google dice que alcanza con el limite que ya hay, no se suma");
  await gd({ accion: "estado" });
  fijar({ dest_lat: null, dest_lng: null });
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5) });
  llamadas.length = 0; seg = 1500;
  await gdCron(env);
  ok(llamadas.length === 0, "si no se conoce el destino exacto, no se recalcula");
  fijar({ dest_lat: -34.57, dest_lng: -58.4 });
  fijar({ estado: "alerta", alertas: 1, last_alert_at: now() });
  poner({ recalc_at: hace(5) });
  await gdCron(env);
  ok(llamadas.length === 0 && viaje().estado === "alerta", "una vez que se les aviso a los referentes, no se suma nada solo");
  fijar({ estado: "aviso", aviso_at: now(), alertas: 0, last_alert_at: null, deadline_at: min(9.5) });
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5), auto_min: 0 });
  seg = 1500;
  await gdCron(env);
  ok(viaje().estado === "en_camino" && viaje().aviso_at === null && progreso().auto_min > 0, "si ya se le habia preguntado si seguia en camino y se acerca, el aviso se retira (vuelve a en camino)");

  console.log("-- tope y apagado en la configuracion");
  await gd({ accion: "config", config: { autoAjusteMin: 10 } }).catch(() => null);
  sqlite.exec("UPDATE gd_viajes SET estado='cancelado'"); // para poder cambiar la configuracion
  await gd({ accion: "config", config: { autoAjusteMin: 10 } });
  fijar({ estado: "en_camino", aviso_at: null, deadline_at: min(9.5) });
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5), auto_min: 7 });
  const limiteT = Date.parse(viaje().deadline_at);
  seg = 1500;
  await gdCron(env);
  ok(Math.round((Date.parse(viaje().deadline_at) - limiteT) / 60000) === 3 && progreso().auto_min === 10, "con un tope de 10 minutos y 7 ya sumados, solo se suman 3");
  sqlite.exec("UPDATE gd_viajes SET estado='cancelado'");
  await gd({ accion: "config", config: { autoAjusteMin: 0 } });
  fijar({ estado: "en_camino", deadline_at: min(9.5) });
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5), auto_min: 0 });
  llamadas.length = 0;
  await gdCron(env);
  ok(llamadas.length === 0, "con 0 minutos de tope el recalculo esta apagado y no se consulta nada");
  await gd({ accion: "config", config: { restablecer: true } });

  console.log("-- voy a frenar un rato: el reloj queda en pausa");
  fijar({ estado: "en_camino", deadline_at: min(5) });
  poner({ paradas: 0, pausa_ini: null, pausa_hasta: null, resta_ms: null, parada_min: 0 });
  let n = correos.length;
  ok((await gd({ t: TOKEN, accion: "parada", minutos: 20 })).status === 400, "solo se puede frenar 15, 30 o 60 minutos");
  const antesP = Date.parse(viaje().deadline_at);
  let rp: any = await (await gd({ t: TOKEN, accion: "parada", minutos: 30 })).json();
  ok(rp.ok && rp.viaje.paradas === 1 && rp.viaje.extensiones === 0 && mailsDesde(n).length === 0, "frenar 30 minutos no cuenta como pedido de mas tiempo y no les avisa a los referentes");
  ok(rp.viaje.pausa && Math.abs(Date.parse(rp.viaje.pausa.hasta) - (Date.now() + 30 * 60_000)) < 2000 && Math.abs(rp.viaje.pausa.restaMs - 5 * 60_000) < 2000, "queda en pausa 30 minutos y se guarda lo que le faltaba (5 minutos): el reloj de la pantalla no baja");
  ok(Math.abs(Date.parse(viaje().deadline_at) - (antesP + 30 * 60_000)) < 2000, "el limite queda en el fin de la pausa mas lo que le faltaba, para que nada salte mientras esta frenado");
  ok((await (await api()).json() as any).registro.some((x: any) => /Vas a frenar un rato: el reloj queda en pausa 30 minutos \(hasta las \d\d:\d\d\) con 5 minutos para llegar a/.test(x.detail)), "queda en el registro");

  console.log("-- durante la pausa el reloj no corre");
  const limiteReal = viaje().deadline_at;
  fijar({ deadline_at: min(1) }); // inconsistente a proposito: mientras dura la pausa manda la pausa
  n = correos.length; avisos.length = 0; llamadas.length = 0;
  poner({ ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6), recalc_at: hace(5) });
  await gdCron(env);
  ok(viaje().estado === "en_camino" && mailsDesde(n).length === 0 && avisos.length === 0 && llamadas.length === 0, "mientras esta frenado no se le pregunta '¿Seguis en camino?', no se avisa a los referentes ni se recalcula por transito");
  fijar({ deadline_at: limiteReal });
  const estadoP: any = await (await gd({ t: TOKEN, accion: "estado" })).json();
  ok(estadoP.viaje.pausa && estadoP.viaje.puedeParar === true && estadoP.viaje.puedeCambiar === true, "mientras esta frenado puede frenar mas, cambiar el destino o tocar Llegue");

  console.log("-- Ya sigo: el reloj retoma lo que le faltaba");
  fijar({ deadline_at: min(35) });
  poner({ pausa_ini: hace(10), pausa_hasta: min(20), resta_ms: 5 * 60_000, paradas: 1, parada_min: 0 }); // pasaron 10 de los 30 minutos
  const rs2: any = await (await gd({ t: TOKEN, accion: "seguir" })).json();
  ok(rs2.ok && rs2.viaje.pausa === null && Math.abs(Date.parse(viaje().deadline_at) - Date.now() - 5 * 60_000) < 2000, "'Ya sigo' retoma el reloj con los 5 minutos que le faltaban, no con el limite de la pausa entera");
  ok(progreso().parada_min === 10 && progreso().pausa_hasta === null && progreso().resta_ms === null && progreso().ref_lat === null, "queda anotado que estuvo frenado 10 minutos, se borra la pausa y se vuelve a tomar la muestra de ubicacion");
  ok((await (await api()).json() as any).registro.some((x: any) => /Seguís en camino a .*: el reloj sigue con 5 minutos/.test(x.detail)), "'Ya sigo' queda en el registro");
  const rs3 = await gd({ t: TOKEN, accion: "seguir" });
  ok(rs3.status === 409 && (await rs3.json() as any).error === "sin_pausa", "si no estaba frenado, 'Ya sigo' no hace nada");

  console.log("-- se termina la pausa sola");
  fijar({ deadline_at: min(19.5) });
  poner({ pausa_ini: hace(30.5), pausa_hasta: hace(0.5), resta_ms: 20 * 60_000, parada_min: 0 }); // la pausa de 30 minutos termino hace medio minuto
  n = correos.length; avisos.length = 0;
  await gdCron(env);
  ok(progreso().pausa_hasta === null && progreso().parada_min === 30 && Math.abs(Date.parse(viaje().deadline_at) - Date.now() - 19.5 * 60_000) < 2000, "al terminar la pausa el reloj sigue solo (el limite ya estaba bien) y se anotan los 30 minutos frenado");
  ok(mailsDesde(n).length === 1 && /Terminó tu parada/.test(mailsDesde(n)[0].subject) && mailsDesde(n)[0].to === DUENIO && avisos.length === 1 && /Terminó tu parada/.test(avisos[0].title), "y se le avisa a la persona (mail y telefono) que termino su parada, sin avisarles a los referentes");
  fijar({ estado: "en_camino", deadline_at: min(1.5), aviso_at: null });
  poner({ pausa_ini: hace(30.5), pausa_hasta: hace(0.5), resta_ms: 2 * 60_000, parada_min: 0 });
  n = correos.length;
  await gdCron(env);
  ok(viaje().estado === "aviso" && mailsDesde(n).length === 1 && /¿Seguís en camino\?/.test(mailsDesde(n)[0].subject), "si al terminar la pausa ya le quedan solo 1 o 2 minutos, se le pregunta si sigue en camino en vez de mandar el aviso de fin de pausa");

  console.log("-- frenar mas tiempo, pedir mas tiempo y llegar frenado");
  fijar({ estado: "en_camino", aviso_at: null, deadline_at: min(5) });
  poner({ paradas: 0, pausa_ini: null, pausa_hasta: null, resta_ms: null, parada_min: 0 });
  await gd({ t: TOKEN, accion: "parada", minutos: 15 });
  const hasta1 = Date.parse(progreso().pausa_hasta);
  const rpm: any = await (await gd({ t: TOKEN, accion: "parada", minutos: 30 })).json();
  ok(rpm.ok && Math.abs(Date.parse(progreso().pausa_hasta) - (hasta1 + 30 * 60_000)) < 1000 && progreso().paradas === 2 && Math.abs(progreso().resta_ms - 5 * 60_000) < 2000, "frenar de nuevo con el reloj en pausa alarga la pausa (45 minutos en total), no toca lo que le faltaba y cuenta como otra parada");
  const rpe: any = await (await gd({ t: TOKEN, accion: "extender", minutos: 10 })).json();
  ok(rpe.ok && Math.abs(progreso().resta_ms - 15 * 60_000) < 2000, "pedir mas tiempo mientras esta frenado se suma a lo que le falta para llegar");
  const rp3 = await gd({ t: TOKEN, accion: "parada", minutos: 15 });
  ok(rp3.status === 409 && (await rp3.json() as any).error === "demasiadas_paradas" && (await (await gd({ t: TOKEN, accion: "estado" })).json() as any).viaje.puedeParar === false, "como maximo 2 paradas por camino");
  poner({ pausa_ini: hace(7) });
  const rll: any = await (await gd({ t: TOKEN, accion: "llegue", origen: { lat: -34.57, lng: -58.4, precision: 15 } })).json();
  ok(rll.ok && viaje().estado === "llego" && progreso().parada_min === 7 && rll.viaje.fin.paradaMin === 7 && rll.viaje.fin.despuesMin < 0 && rll.viaje.fin.extraMin >= 0, "si toca Llegue frenado se cuenta lo que duro la pausa (7 minutos) y el resumen dice 'de parada' aparte; llego antes del limite");
  fijar({ estado: "en_camino", ended_at: null, motivo_fin: null, deadline_at: min(5) });
  poner({ pausa_ini: null, pausa_hasta: null, resta_ms: null, parada_min: 0 });
  fijar({ estado: "alerta", alertas: 1, last_alert_at: now() });
  ok((await gd({ t: TOKEN, accion: "parada", minutos: 15 })).status === 409, "despues de avisarles a los referentes ya no se frena: se toca Llegue");
  fijar({ estado: "en_camino", alertas: 0, last_alert_at: null, deadline_at: min(5) });
  poner({ paradas: 0 });
  await gd({ accion: "config", config: { maxExtensiones: 0 } }).catch(() => null);
  sqlite.exec("UPDATE gd_viajes SET estado='cancelado'");
  await gd({ accion: "config", config: { maxExtensiones: 0 } });
  fijar({ estado: "en_camino" });
  const rp0 = await gd({ t: TOKEN, accion: "parada", minutos: 15 });
  ok(rp0.status === 409 && (await rp0.json() as any).error === "sin_extensiones" && (await (await gd({ t: TOKEN, accion: "estado" })).json() as any).viaje.puedeParar === false, "si en la configuracion no se puede pedir mas tiempo, tampoco se puede frenar");
  sqlite.exec("UPDATE gd_viajes SET estado='cancelado'"); // la configuracion no se cambia con un camino en marcha
  await gd({ accion: "config", config: { restablecer: true } });
  fijar({ estado: "en_camino", ended_at: null, motivo_fin: null, deadline_at: min(5) });

  console.log("-- la tabla de progreso de una instalacion anterior (sin las columnas de la pausa) se completa sola");
  sqlite.exec("DROP TABLE gd_progreso; CREATE TABLE gd_progreso (viaje_id TEXT PRIMARY KEY, ref_lat REAL, ref_lng REAL, ref_at TEXT, recalc_at TEXT, auto_min INTEGER NOT NULL DEFAULT 0, paradas INTEGER NOT NULL DEFAULT 0, updated_at TEXT)");
  gdTablaLista = false;
  fijar({ estado: "en_camino", deadline_at: min(5) });
  const rviejo: any = await (await gd({ t: TOKEN, accion: "parada", minutos: 15 })).json();
  const columnas = (sqlite.prepare("PRAGMA table_info(gd_progreso)").all() as any[]).map((c) => c.name);
  ok(rviejo.ok && rviejo.viaje.pausa && ["pausa_ini", "pausa_hasta", "resta_ms", "parada_min"].every((c) => columnas.includes(c)), "con la tabla de una instalacion anterior, al usarla se le agregan solas las columnas de la pausa y todo anda");
  gdTablaLista = false;
  await gd({ t: TOKEN, accion: "estado" });
  ok(((sqlite.prepare("PRAGMA table_info(gd_progreso)").all() as any[]).filter((c) => c.name === "pausa_hasta")).length === 1, "y si ya las tiene no las vuelve a agregar");
  poner({ paradas: 0, pausa_ini: null, pausa_hasta: null, resta_ms: null, parada_min: 0 });

  console.log("-- cambiar de destino");
  const progAntes = { paradas: 0 };
  poner({ paradas: 1, auto_min: 9, ref_lat: -34.61, ref_lng: -58.4, ref_at: hace(6) });
  fijar({ estado: "aviso", aviso_at: now(), llegada_at: now(), started_at: hace(10), deadline_at: min(1.5) });
  TOKEN = await gdToken(env, { id: viaje().id, startedAt: viaje().started_at }); // el enlace se firma con la hora de inicio
  seg = 720; llamadas.length = 0;
  n = correos.length;
  let rc: any = await (await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl2" })).json();
  ok(rc.ok && llamadas.length === 1 && llamadas[0].origin.location.latLng.latitude === -34.6 && llamadas[0].destination.location.latLng.latitude === -34.55, "cambiar de destino a un lugar guardado: se recalcula desde donde esta el telefono");
  const v1 = viaje();
  ok(v1.destino === "Oficina" && v1.dest_lat === -34.55 && v1.dest_lng === -58.45 && v1.estado === "en_camino" && v1.aviso_at === null && v1.llegada_at === null, "el camino pasa a ir a la Oficina, vuelve a en camino y se borra lo de la llegada anterior");
  ok(Math.abs((Date.parse(v1.deadline_at) - Date.now()) / 60000 - 14) < 0.2 && v1.estimado_min === 22, "el limite es lo que falta (12 min) mas el margen (2) desde ahora; el tiempo estimado total suma lo ya recorrido (10 + 12)");
  ok(progreso().auto_min === 0 && progreso().ref_lat === null && progreso().paradas === 1, "lo sumado por transito y la muestra de referencia empiezan de cero para el nuevo destino; las paradas ya hechas se cuentan igual");
  ok((await (await api()).json() as any).registro.some((x: any) => /Cambiaste el destino a Oficina: 12 min \(calculado con mapas/.test(x.detail)) && mailsDesde(n).length === 2 && mailsDesde(n).every((c) => /cambió el destino: ahora va a Oficina/.test(c.subject) && /antes iba a <strong[^>]*>Casa<\/strong> y ahora va a <strong[^>]*>Oficina<\/strong>/.test(c.html) && /Desde ahora el aviso es por llegar ahí/.test(c.html) && /Si no lo esperabas, comunicate con/.test(c.html)) && rc.avisados === 2, "queda en el registro y se les avisa a los referentes que cambio el destino (antes iba a Casa, ahora a la Oficina)");
  rc = await (await gd({ t: TOKEN, accion: "cambiar", placeId: "ChIJcambio00001", texto: "Kansas, Av. del Libertador, CABA" })).json();
  ok(rc.ok && viaje().destino === "Kansas, Av. del Libertador, CABA" && llamadas[llamadas.length - 1].destination.placeId === "ChIJcambio00001" && viaje().dest_lat === -34.57, "tambien se puede cambiar a una sugerencia (placeId): se guarda el destino exacto que devuelve Google");
  delete (env as any).GOOGLE_ROUTES_KEY;
  const rc2 = await gd({ t: TOKEN, accion: "cambiar", texto: "Casa de Ana" });
  ok(rc2.status === 400 && (await rc2.json() as any).error === "faltan_minutos", "sin Google y sin minutos, no se puede calcular el nuevo destino");
  const rc3 = await gd({ t: TOKEN, accion: "cambiar", texto: "Casa de Ana", minutos: 25 });
  ok(rc3.status === 200 && viaje().destino === "Casa de Ana" && viaje().dest_lat === null && (await (await api()).json() as any).registro.some((x: any) => /Casa de Ana: 25 min \(tiempo que pusiste vos\)/.test(x.detail)), "con los minutos que pone la persona se puede cambiar igual (sin saber el destino exacto, no se recalcula)");
  (env as any).GOOGLE_ROUTES_KEY = "clave-de-prueba";
  seg = 20 * 3600;
  const rc4 = await gd({ t: TOKEN, accion: "cambiar", texto: "Kansas", minutos: 10 });
  ok(rc4.status === 400 && (await rc4.json() as any).error === "destino_muy_lejos", "si el nuevo destino queda a mas de 5 horas, se rechaza");
  seg = 720;
  ok((await gd({ t: TOKEN, accion: "cambiar", lugarId: "no-existe" })).status === 400, "un lugar que no es suyo no sirve");
  fijar({ estado: "alerta", alertas: 1, last_alert_at: now() });
  const rc5 = await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1" });
  ok(rc5.status === 409 && (await rc5.json() as any).error === "ya_se_aviso", "despues de avisarles a los referentes no se cambia el destino: se toca Llegue");

  console.log("-- cambiar de destino: siempre desde donde esta la persona");
  fijar({ estado: "en_camino", alertas: 0, last_alert_at: null, ended_at: null, motivo_fin: null });
  lejos(); // el telefono aviso hace 1 minuto desde (-34.6, -58.4)
  llamadas.length = 0; seg = 600;
  let ro: any = await (await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1", origen: { lat: -34.5, lng: -58.5, precision: 25 } })).json();
  ok(ro.ok && ro.origen.fuente === "navegador" && llamadas[0].origin.location.latLng.latitude === -34.5 && llamadas[0].origin.location.latLng.longitude === -58.5, "usa la ubicacion que manda el navegador de la persona en ese momento (como Google Maps o Waze), no la guardada, y lo dice");
  llamadas.length = 0;
  ro = await (await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1" })).json();
  ok(ro.ok && ro.origen.fuente === "telefono" && ro.origen.haceMin <= 2 && llamadas[0].origin.location.latLng.latitude === -34.6, "si el navegador no la da, usa la del telefono, pero solo porque es de hace 1 minuto");
  llamadas.length = 0;
  ro = await (await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1", origen: { lat: 40, lng: 10, precision: 30000 } })).json();
  ok(ro.ok && ro.origen.fuente === "telefono" && llamadas[0].origin.location.latLng.latitude === -34.6, "una ubicacion del navegador muy imprecisa (por ejemplo la de una computadora) no se usa: vale la del telefono");
  ok((await (await api()).json() as any).registro.some((x: any) => /Calculado desde la última ubicación de tu teléfono \(hace \d+ min\)\./.test(x.detail)) && (await (await api()).json() as any).registro.some((x: any) => /Calculado desde donde estabas\./.test(x.detail)), "el registro cuenta desde donde se calculo");
  dispositivo({ seen: 120, bat: 80, lat: -34.6, lng: -58.4 }); // el telefono no avisa hace 2 horas
  llamadas.length = 0;
  const rv = await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1" });
  const rvj: any = await rv.json();
  ok(rv.status === 400 && rvj.error === "faltan_minutos" && rvj.fallo === "ubicacion_vieja" && llamadas.length === 0, "si la ultima ubicacion del telefono es vieja (2 horas) no se calcula desde ahi: se pide la ubicacion o los minutos");
  const rv2: any = await (await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1", minutos: 25 })).json();
  ok(rv2.ok && rv2.origen === null && rv2.minutos === 25 && viaje().estimado_min >= 25, "con los minutos que pone la persona se puede cambiar igual");
  const est: any = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "auto" })).json();
  ok(est.ok && est.minutos === null && est.fallo === "ubicacion_vieja" && /hace 2 horas/.test(est.detalle), "al estimar con una ubicacion vieja dice por que no puede y de hace cuanto es la ultima");
  const est2: any = await (await gd({ accion: "estimar", lugarId: "pl1", modo: "auto", origen: { lat: -34.58, lng: -58.41, precision: 15 } })).json();
  ok(est2.ok && est2.minutos === 10 && est2.km === 3 && est2.origen.fuente === "navegador", "y con la ubicacion del navegador estima desde ahi (y dice los km para que se pueda juzgar si el tiempo tiene sentido)");
  llamadasLugares.length = 0;
  await gd({ t: TOKEN, accion: "buscar", texto: "kansas" });
  ok(llamadasLugares.length === 1 && llamadasLugares[0].locationBias && !llamadasLugares[0].origin, "si la ubicacion del telefono es vieja, las sugerencias solo se ordenan por cerca de ahi, sin decir a cuantos km quedan");
  llamadasLugares.length = 0;
  await gd({ t: TOKEN, accion: "buscar", texto: "kansas", origen: { lat: -34.58, lng: -58.41, precision: 15 } });
  ok(llamadasLugares.length === 1 && llamadasLugares[0].origin.latitude === -34.58, "con la ubicacion del navegador, si dice a cuantos km quedan");
  lejos();

  console.log("-- cambiar como voy: auto, transporte o caminando");
  fijar({ estado: "en_camino", ended_at: null, motivo_fin: null, destino: "Casa", dest_lat: -34.57, dest_lng: -58.4, modo: "auto" });
  llamadas.length = 0; seg = 1800;
  let rm: any = await (await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1", modo: "caminando" })).json();
  ok(rm.ok && rm.modo === "caminando" && rm.minutos === 30 && rm.km === 3 && viaje().modo === "caminando" && rm.viaje.modoTexto === "caminando" && llamadas[0].travelMode === "WALK", "al cambiar el destino se puede elegir como va: se guarda y el calculo se hace a pie");
  llamadas.length = 0;
  rm = await (await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1", modo: "transporte" })).json();
  ok(rm.ok && viaje().modo === "transporte" && llamadas[0].travelMode === "TRANSIT", "en transporte publico el calculo es de transporte");
  llamadas.length = 0;
  rm = await (await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1" })).json();
  ok(rm.ok && rm.modo === "transporte" && llamadas[0].travelMode === "TRANSIT", "si no elige otro, sigue con el que traia");
  ok((await gd({ t: TOKEN, accion: "cambiar", lugarId: "pl1", modo: "monopatin" })).status === 400, "un modo que no existe no sirve");
  llamadas.length = 0; seg = 900;
  rm = await (await gd({ t: TOKEN, accion: "cambiar", mismo: true, modo: "auto" })).json();
  ok(rm.ok && viaje().destino === "Casa" && viaje().modo === "auto" && llamadas[0].travelMode === "DRIVE" && llamadas[0].routingPreference === "TRAFFIC_AWARE" && llamadas[0].destination.location.latLng.latitude === -34.57, "se puede seguir yendo al mismo lugar y cambiar solo como va: se recalcula hacia el mismo destino exacto, ahora en auto y con el transito de ahora");
  ok((await (await api()).json() as any).registro.some((x: any) => /Cambiaste cómo vas a Casa: ahora en auto: 15 min \(calculado con mapas y el tránsito de ahora, 3 km\)/.test(x.detail)), "queda en el registro con los minutos y los km");
  ok((await (await gd({ t: TOKEN, accion: "estado" })).json() as any).viaje.destinoExacto === true, "la pantalla sabe que el destino es exacto (para ofrecer seguir yendo al mismo lugar)");
  fijar({ dest_lat: null, dest_lng: null });
  ok((await (await gd({ t: TOKEN, accion: "estado" })).json() as any).viaje.destinoExacto === false && (await gd({ t: TOKEN, accion: "cambiar", mismo: true })).status === 400, "si no se conoce el destino exacto no se puede 'seguir yendo al mismo lugar'");
  fijar({ dest_lat: -34.57, dest_lng: -58.4 });

  console.log("-- buscar y lugares con el enlace del camino");
  fijar({ estado: "en_camino", alertas: 0, last_alert_at: null });
  const bt: any = await (await gd({ t: TOKEN, accion: "buscar", texto: "kansas" })).json();
  ok(bt.ok && bt.sugerencias.length === 1 && bt.sugerencias[0].placeId === "ChIJcambio00001" && bt.sugerencias[0].principal === "Kansas", "desde la pagina del camino se buscan lugares (por si cambia de destino)");
  const lt: any = await (await gd({ t: TOKEN, accion: "lugares" })).json();
  ok(lt.ok && lt.lugares.map((x: any) => x.name).join() === "Casa,Oficina", "y se ven sus propios lugares");
  ok((await gd({ t: "gdvxxxx.yyyy", accion: "buscar", texto: "kansas" })).status === 404 && (await gd({ t: "gdvxxxx.yyyy", accion: "lugares" })).status === 404, "con un enlace inventado no se busca ni se ven lugares");
  fijar({ estado: "llego", ended_at: now() });
  const bt2 = await gd({ t: TOKEN, accion: "buscar", texto: "kansas" });
  ok(bt2.status === 409 && (await bt2.json() as any).error === "camino_terminado", "terminado el camino, el enlace ya no sirve para buscar");

  console.log("-- la pagina del camino: frenar un rato y cambiar de destino");
  const pc2: string = await (gdPaginaCamino() as any).text();
  ok(["bFrenar", "bCambiar", "frenarPanel", "frenarAyuda", "cambiarPanel", "cmLugar", "cmOtro", "cmTexto", "cmSugerencias", "cmAyuda", "cmMinBloque", "cmMin", "cmConfirmar"].every((i) => pc2.includes('id="' + i + '"')) && ["15", "30", "60"].every((m) => pc2.includes('data-f="' + m + '"')) && /Voy a frenar un rato/.test(pc2) && /Cambiar destino/.test(pc2) && /No les avisamos a tus referentes/.test(pc2), "la pagina del camino tiene 'Voy a frenar un rato' (15, 30 o 60 minutos, sin avisar a los referentes) y 'Cambiar destino'");
  ok(/accion:"parada",minutos:n/.test(pc2) && /accion:"cambiar"/.test(pc2) && /accion:"buscar",texto:q/.test(pc2) && /accion:"lugares"/.test(pc2) && /e\.codigo==="faltan_minutos"/.test(pc2) && /navigator\.geolocation\.getCurrentPosition/.test(pc2) && /c\.lugarId=\$\("cmLugar"\)\.value/.test(pc2) && /c\.placeId=CMPLACE/.test(pc2), "cambiar de destino: lugares guardados u otro lugar con sugerencias, desde donde esta ahora, y si Google no calcula pide los minutos");
  ok(/V\.puedeParar/.test(pc2) && /Ya frenaste "\+V\.paradasMax/.test(pc2) && /V\.puedeCambiar/.test(pc2) && /V\.paradasMax/.test(pc2) && /demasiadas_paradas/.test(pc2) && /destino_muy_lejos/.test(pc2), "los botones aparecen segun lo que permite el servidor (cantidad de paradas, camino activo)");
  ok(/V\.ajusteAutoMin>0/.test(pc2) && /Sumamos "\+V\.ajusteAutoMin\+" minutos por tr\u00e1nsito/.test(pc2) && /f\.autoMin>0/.test(pc2) && /por tr\u00e1nsito/.test(pc2), "la pagina avisa cuando se sumaron minutos por transito y lo cuenta en el resumen final");
  ok(!/innerHTML/.test(pc2), "la pagina del camino no arma nada con innerHTML (los lugares y las sugerencias se agregan como texto)");
  ok(["lleguePanel", "llegueTxt", "bLlegueDeNuevo"].every((i) => pc2.includes('id="' + i + '"')) && />Volver a comprobar<\/button>/.test(pc2) && !/Llegué igual|bLlegueIgual|forzar/.test(pc2) && /function llegue\(\)/.test(pc2) && /Comprobando tu ubicación/.test(pc2) && /e\.codigo==="lejos_del_destino"\|\|e\.codigo==="sin_comprobar"/.test(pc2) && /e\.detalle=d\.detalle/.test(pc2) && /V\.destinoExacto&&V\.estado!=="alerta"\)/.test(pc2) && /Todavía no estás en/.test(pc2) && /se da por llegada a menos de/.test(pc2) && /V\.llegada==="comprobada"/.test(pc2), "la pantalla del camino pide la ubicacion al tocar Llegue, explica si no esta en el destino (a cuantos km y cual es el margen) y solo deja volver a comprobar: no hay forma de cerrar sin estar en el lugar");
  ok(["bSeguir", "pausaTxt"].every((i) => pc2.includes('id="' + i + '"')) && />Ya sigo<\/button>/.test(pc2) && /function enPausa\(\)/.test(pc2) && /EN PAUSA · termina a las/.test(pc2) && /\$\("reloj"\)\.textContent=reloj\(V\.pausa\.restaMs\)/.test(pc2) && /accion:"seguir"/.test(pc2) && /Frenar más tiempo/.test(pc2) && /pausaVencida/.test(pc2), "la pantalla del camino muestra EN PAUSA con el reloj quieto (lo que le faltaba), hasta cuando dura la pausa, 'Ya sigo' y 'Frenar mas tiempo'; cuando termina la pausa vuelve a preguntar solo");
  ok(/De parada|de parada/.test(pc2) && /f\.paradaMin>0/.test(pc2), "el resumen final cuenta los minutos de parada aparte");
  ok(/id="cmModos"/.test(pc2) && ["auto", "transporte", "caminando"].every((m) => pc2.includes('data-modo="' + m + '"')) && (pc2.match(/<svg viewBox="0 0 24 24"/g) ?? []).length === 3 && /Cómo vas/.test(pc2) && /c\.modo=modosValor\("cmModos"\)|modo:modosValor\("cmModos"\)/.test(pc2) && /"__mismo"/.test(pc2) && /Seguir yendo a /.test(pc2) && /c\.mismo=true/.test(pc2), "'Cambiar destino' tiene los tres modos con icono (auto, transporte, caminando) y la opcion 'Seguir yendo a <el lugar>' para cambiar solo como va");
  ok(/#reloj\.urgente,#reloj\.vencido\{color:var\(--mal\)\}/.test(pc2) && /id=\"anilloProg\"/.test(pc2) && /function anillo\(f\)/.test(pc2) && /function parpadeo\(on\)/.test(pc2) && /parpadeo\(urg\)/.test(pc2) && /Math\.floor\(Date\.now\(\)\/500\)%2===0\?"1":"\.15"/.test(pc2) && !/animation:parpadeo|@keyframes|prefers-reduced-motion/.test(pc2) && ["relojCard", "finalTxt"].every((i) => pc2.includes('id="' + i + '"')) && /var urg=ms>0&&ms<=15000,ven=ms<=0/.test(pc2) && /"urgente":ven\?"vencido":""/.test(pc2) && /tarjeta final/.test(pc2) && /Se termina el tiempo: tocá Llegué"\+\(V\.puedeExtender\?" o pedí más tiempo":""\)/.test(pc2), "en los ultimos 15 segundos el reloj parpadea en rojo (una vez por segundo con un temporizador, no con una animacion de estilos: anda tambien con 'reducir movimiento' o con las animaciones apagadas), la tarjeta se marca y dice que hacer (tocar Llegue o pedir mas tiempo, si se puede); no depende del sonido");
  ok(["bProbar", "sonidoAviso"].every((i) => pc2.includes('id="' + i + '"')) && />Probar sonido<\/button>/.test(pc2) && /g\.gain\.value=largo\?0\.6:0\.5/.test(pc2) && /function vibrar\(/.test(pc2) && /navigator\.audioSession/.test(pc2) && /Bluetooth/.test(pc2) && /SONIDO&&ms>0&&!sonidoListo\(\)/.test(pc2) && !/ms<=60000/.test(pc2) && /Sonido sin activar: tocá la pantalla una vez para que suenen los pitidos/.test(pc2), "la pantalla del camino deja probar el sonido (tres pips, y explica que si hay auriculares, parlante o auto por Bluetooth suena ahi, que hay que subir el volumen y apagar el silencio del iPhone), suena mas fuerte, vibra aunque el navegador no deje sonar y avisa desde que se abre la pantalla (no solo al final) que hay que tocarla una vez si el sonido no esta habilitado");
  ok(/enableHighAccuracy:true/.test(pc2) && /function ubicar\(/.test(pc2) && /Buscando tu ubicación/.test(pc2) && /ubicacion_vieja/.test(pc2) && /desde donde estás ahora/.test(pc2) && !/timeout:4000/.test(pc2), "la pantalla del camino pide la ubicacion actual (con mas tiempo y precision), dice que la esta buscando y cuenta desde donde se calculo; si no se sabe donde esta pide la ubicacion o los minutos");

  globalThis.fetch = fetchReal;
  delete (env as any).GOOGLE_ROUTES_KEY;
  sqlite.exec("DELETE FROM gd_viajes");
  await preparar();
}

console.log("== Tu proteccion: Modo Cautela y Modo Guardian");
{
  const tp: string = await (pldPaginaDuenio() as any).text();
  ok(/Tu protecci\u00f3n/.test(tp) && /Modo Cautela/.test(tp) && /Modo Guardi\u00e1n/.test(tp) && /Empezar camino/.test(tp), "la pagina se llama Tu proteccion y muestra Modo Cautela y el Modo Guardian para empezar un camino");
  const corte = (desde: string, hasta: string) => tp.slice(tp.indexOf(desde), hasta ? tp.indexOf(hasta) : undefined);
  const vInicio = corte('<div id="vInicio">', '<div id="vCautela"'), vCaut = corte('<div id="vCautela"', '<div id="vGuardian"'), vGuar = corte('<div id="vGuardian"', '<div id="vConfig"'), vConf = corte('<div id="vConfig"', '<div id="vCfgRef"');
  const vRef = corte('<div id="vCfgRef"', '<div id="vCfgCaut"'), vCfgC = corte('<div id="vCfgCaut"', '<div id="vCfgGuard"'), vCfgG = corte('<div id="vCfgGuard"', '<div id="vCfgAjustes"'), vAju = corte('<div id="vCfgAjustes"', '<div id="vCfgAcc"'), vAcc = corte('<div id="vCfgAcc"', '<div id="vCfgReg"'), vReg = corte('<div id="vCfgReg"', '<script>\n(function(){');
  ok(/id="tCautela"/.test(vInicio) && /id="swCautelaInicio" role="switch"/.test(vInicio) && /id="tGuardian" href="#guardian"/.test(vInicio) && /id="tConfig" href="#configuracion"/.test(vInicio) && vInicio.indexOf("tCautela") < vInicio.indexOf("tGuardian") && vInicio.indexOf("tGuardian") < vInicio.indexOf("tConfig"), "el inicio de Tu proteccion tiene el Modo Cautela con su interruptor, el Modo Guardian y la Configuracion");
  ok(/id="avisoRef"/.test(vInicio) && /href="#config-referentes">Elegir referentes/.test(vInicio), "si todavia no hay referentes, el inicio avisa y lleva a Configuracion para elegirlos");
  ok(!/Pausar|Condiciones|Empezar camino|id="rAgregar"|id="cGuardar"|id="gdEmpezar"|Registro|<details/.test(vInicio), "y el inicio no trae nada de la configuracion de ningun modo ni el registro");
  ok(/id="cEncender" role="switch"/.test(vCaut) && /id="estadoModo"/.test(vCaut) && /Pausar los avisos/.test(vCaut) && /data-h="8"/.test(vCaut) && /id="pOtro"/.test(vCaut) && /id="refLineaC"/.test(vCaut) && /href="#config-cautela"/.test(vCaut) && !/id="cDesde"|id="cGuardar"|Condiciones<\/h2>|id="gdEmpezar"|id="gdLugar"|id="rAgregar"|id="cNombre"/.test(vCaut), "el Modo Cautela solo tiene lo de todos los dias (el interruptor, el estado y la pausa) y un enlace a sus condiciones: no mezcla el Guardian, los referentes ni las condiciones");
  ok(/id="gdSeccion"/.test(vGuar) && /id="gdEmpezar"/.test(vGuar) && /id="gdLugar"/.test(vGuar) && /id="gdTexto"/.test(vGuar) && /id="gdModo"/.test(vGuar) && /id="gdMin"/.test(vGuar) && /id="refLineaG"/.test(vGuar) && !/Pausar|Condiciones|Estado de tu tel\u00e9fono|id="cEncender"|id="rAgregar"|id="gMargen"/.test(vGuar), "el Modo Guardian tiene lo de todos los dias (a donde vas, como vas, cuanto tardas) y no mezcla el Modo Cautela, los referentes ni sus ajustes");
  ok(["config-referentes", "config-cautela", "config-guardian", "config-ajustes", "config-accesibilidad", "config-registro"].every((h) => vConf.includes('href="#' + h + '"')) && /<b>Referentes<\/b>/.test(vConf) && /<b>Ajustes<\/b>/.test(vConf) && /<b>Accesibilidad<\/b>/.test(vConf) && /<b>Registro<\/b>/.test(vConf) && !/id="rAgregar"|id="cDesde"|id="gMargen"/.test(vConf), "Configuracion es una lista de categorias (Referentes, Modo Cautela, Modo Guardian, Ajustes, Accesibilidad, Registro) y no un solo texto largo");
  ok(/id="rAgregar"/.test(vRef) && /id="referentes"/.test(vRef) && /No lo encuentro/.test(vRef) && !/Pausar|id="cDesde"|id="gdEmpezar"/.test(vRef), "Referentes tiene solo lo de los referentes");
  ok(["cDesde", "cHasta", "cSilNoche", "cSilDia", "cKm", "cBat", "cMin", "cEmer", "cGuardar", "cCasa", "cReset", "hoy"].every((i) => vCfgC.includes('id="' + i + '"')) && /Estado de tu tel\u00e9fono/.test(vCfgC) && !/id="cNombre"|id="gMargen"|id="pOtro"/.test(vCfgC), "las condiciones del Modo Cautela y el estado del telefono estan en su categoria de Configuracion");
  ok(["gMargen", "gAviso", "gExt", "gAuto", "gRadio", "gEntre", "gMaxAv", "gGuardar", "gReset", "gdCfgBloqueo"].every((i) => vCfgG.includes('id="' + i + '"')) && /Margen extra/.test(vCfgG) && /Seguís en camino/.test(vCfgG) && /Avisos a tus referentes/.test(vCfgG) && /Sumar tiempo si hay más tránsito/.test(vCfgG) && /Si estás frenado, no suma nada/.test(vCfgG) && !/id="gdEmpezar"|id="gdLugar"/.test(vCfgG), "el Modo Guardian tiene su categoria de Configuracion: margen extra, cuando preguntar si seguis en camino, veces de mas tiempo, sumar tiempo por transito y avisos a referentes, con valores recomendados");
  ok(/autoAjusteMin:\$\("gAuto"\)\.value/.test(tp) && /\$\("gAuto"\)\.value=c\.autoAjusteMin/.test(tp) && /"gAuto","gRadio","gCambios","gGuardar","gReset"\]\.forEach/.test(tp) && /min m\u00e1s por tr\u00e1nsito/.test(tp), "la pagina guarda, muestra y bloquea con un camino en marcha el tope de minutos por transito");
  ok(/avisarCambios:\$\("gCambios"\)\.value/.test(tp) && /\$\("gCambios"\)\.value=String\(c\.avisarCambios\)/.test(tp) && /id="gCambios"/.test(tp) && /Avisarles también si cambio el destino o cancelo el camino/.test(tp) && /aviso a tus referentes si cambiás el destino o cancelás/.test(tp) && /Si cambiás el destino o cancelás el camino, también se les avisa a tus referentes/.test(tp), "la pagina de Configuracion tiene la opcion de avisarles si cambio el destino o cancelo: la guarda, la muestra, la bloquea con un camino en marcha y la nombra en lo recomendado y en el pie");
  ok(/radioLlegadaM:\$\("gRadio"\)\.value/.test(tp) && /\$\("gRadio"\)\.value=c\.radioLlegadaM/.test(tp) && /id="gRadio"/.test(tp) && /Margen de llegada/.test(tp) && /llegada a menos de "\+GDDEF\.radioLlegadaM\+" m/.test(tp) && /Al tocar Llegué comprobamos que estés a menos de "\+c\.radioLlegadaM/.test(tp), "la pagina de Configuracion tiene el margen de llegada: lo guarda, lo muestra, lo bloquea con un camino en marcha y lo dice en lo recomendado y en el pie");
  ok(/id="cNombre"/.test(vAju) && /id="cNombreGuardar"/.test(vAju) && /Acerca de Tu protecci\u00f3n/.test(vAju) && /en validaci\u00f3n/.test(vAju), "Ajustes tiene como te llaman tus referentes y lo de la validacion");
  ok(["aaNoche", "aaContraste", "aaBotones", "aaSonido", "aaVibra", "aaLuz"].every((i) => vAcc.includes('id="' + i + '" role="switch"')) && /data-t="g"/.test(vAcc) && /data-t="x"/.test(vAcc) && /Tama\u00f1o del texto/.test(vAcc) && /se guardan en este tel\u00e9fono/.test(vAcc), "Accesibilidad: tamano del texto, alto contraste, botones grandes, sonido, vibracion y pantalla encendida (se guardan en el telefono)");
  ok(/id="registro"/.test(vReg) && !/id="rAgregar"/.test(vReg), "el Registro esta en su categoria de Configuracion");
  ok(!/<details/.test(tp), "ya no hay tarjetas plegables: cada cosa tiene su pantalla");
  ok(/location\.hash/.test(tp) && /hashchange/.test(tp) && /"config-referentes":"vCfgRef"/.test(tp) && /h==="gdSeccion"\)h="guardian"/.test(tp) && /h==="tus-referentes"\)h="config-referentes"/.test(tp) && /!PROPIA&&h==="guardian"\)h=""/.test(tp), "la pagina elige que mostrar segun la direccion (#cautela, #guardian, #configuracion y sus categorias), acepta los viejos #gdSeccion y #tus-referentes y no abre el Guardian en la proteccion de otra persona");
  ok(/if\(arriba\)\{aviso\(""\);window\.scrollTo\(0,0\)\}/.test(tp), "al cambiar de pantalla se borra el mensaje de la anterior (por ejemplo 'Cambios guardados.')");
  ok(/RO=!!pe\.soloLectura/.test(tp) && /\.disabled=enMarcha\|\|!PROPIA\|\|RO/.test(tp) && /!\$\("vCfgAcc"\)\.contains\(e\)/.test(tp), "un menor ve los tiempos y avisos del Guardian bloqueados, pero puede usar Accesibilidad (es solo de su telefono)");
  ok(/\$\("refLineaG"\)\.style\.display=nombres\.length\?"block":"none"/.test(tp), "en el Modo Guardian, si no hay referentes no se repite el aviso (ya lo dice la tarjeta de abajo)");
  ok(/<a class="atras" id="aHub"/.test(tp) && /h\.textContent=p==="configuracion"&&!DESDEPANEL\?"← Configuración":"← Tu protección"/.test(tp) && /NOMBREPERSONA/.test(tp), "dentro de cada pantalla aparece el enlace para volver (a Tu proteccion o a Configuracion) y el titulo dice de cual se trata");
  ok(/var DESDEPANEL=vistaActual\(\)==="configuracion"/.test(tp) && /pan=DESDEPANEL&&v==="configuracion"/.test(tp) && /i\.setAttribute\("href",pan\?"\/#config":"\/"\);i\.textContent=pan\?"← Configuración":"← Ir al inicio"/.test(tp) && /DESDEPANEL&&v==="configuracion"\?"Tu protección":TITULOS\[v\]/.test(tp) && (tp.match(/var DESDEPANEL=/g) ?? []).length === 1, "si la pagina se abre directo en Configuracion (como desde la consola del panel), arriba dice Configuracion y vuelve a la Configuracion del panel (/#config), en vez de obligar a ir al inicio; la pantalla se llama Tu proteccion, como la categoria que se toco, y desde adentro vuelve a ella");
  ok(!/Pr\u00f3ximamente/.test(tp) && /id="guardianCard"/.test(tp) && /id="gdEmpezar"/.test(tp) && /id="gdSeccion"/.test(tp), "el Modo Guardian ya no dice Proximamente: tiene su tarjeta para empezar un camino");
  ok(!/Por las dudas est\u00e1 encendido/.test(tp) && /id="cEncender" role="switch" aria-checked="true" aria-label="Modo Cautela"/.test(tp) && /Por las dudas: si dejo de responder/.test(tp) && /function alternarCautela/.test(tp) && /\$\("swCautelaInicio"\)\.onclick=alternarCautela/.test(tp), "el Modo Cautela se prende y se apaga con un interruptor, tanto en el inicio como en su pantalla");
  const ids = ["aviso", "sinSesion", "contenido", "hoy", "referentes", "rNombre", "rCorreo", "rAgregar", "invitacion", "dondeBoton", "cNombre", "cDesde", "cHasta", "cSilNoche", "cSilDia", "cKm", "cBat", "cMin", "cEmer", "cGuardar", "cCasa", "casa", "pausa", "estadoModo", "pHoras", "pOtro", "cEncender", "registro", "titulo", "paraQuien", "persona", "soloLectura", "enNombreDe", "gdSeccion", "guardianCard", "gdCarga", "gdActivo", "gdAbrir", "gdForm", "gdLugar", "gdOtro", "gdTexto", "gdModo", "gdMin", "gdEmpezar", "gdSinRef", "swCautelaInicio", "tCautela", "tGuardian", "tConfig", "avisoRef", "cfRef", "cNombreGuardar", "cReset", "gMargen", "gAviso", "gExt", "gAuto", "gRadio", "gEntre", "gMaxAv", "gGuardar", "gReset", "aaContraste", "aaBotones", "aaSonido", "aaVibra", "aaLuz", "gdPie"];
  ok(ids.every((i) => tp.includes('id="' + i + '"')), "todos los campos que usa la pagina siguen en su lugar");
  ok(/<div class="modos" id="gdModo" role="radiogroup"/.test(vGuar) && ["auto", "transporte", "caminando"].every((m) => vGuar.includes('data-modo="' + m + '"')) && !/<select id="gdModo"/.test(tp) && (vGuar.match(/<svg viewBox="0 0 24 24"/g) ?? []).length === 3 && /function modosValor\(/.test(tp) && /modo:modosValor\("gdModo"\)/.test(tp), "'Empezar camino' elige como va con tres botones con icono (auto, transporte, caminando) en lugar de un desplegable");
  ok(/function gdUbicar\(/.test(tp) && /enableHighAccuracy:true/.test(tp) && /gdUbicar\(\)\.then\(function\(o\)\{if\(mi!==GDSEQ\)return null/.test(tp) && /Buscando tu ubicación/.test(tp) && /ubicacion_vieja/.test(tp) && /desde donde estás ahora/.test(tp) && !/timeout:4000/.test(tp), "al calcular y al empezar el camino se pide la ubicacion actual (tambien para el tiempo que se muestra antes de empezar) y se cuenta desde donde se calculo");
  ok(/d\.viaje\.pausa\?" \(en pausa\)":""/.test(tp), "si el camino esta en pausa, Tu proteccion lo dice");
  ok(['data-h="8"', 'data-h="12"', 'data-h="24"', 'data-h="0"'].every((x) => tp.includes(x)) && />12 horas<\/button>/.test(tp) && />24 horas<\/button>/.test(tp) && /Quitar pausa/.test(tp), "la pagina ofrece pausar por 8, 12 y 24 horas, otro tiempo y quitar la pausa");
  ok(!/C\u00f3mo est\u00e1s hoy/.test(tp) && /Estado de tu tel\u00e9fono/.test(tp), "la tarjeta ya no se llama 'Como estas hoy' (parecia una pregunta de animo): se llama 'Estado de tu telefono'");
  ok(/\.botones\{display:flex;flex-wrap:wrap;gap:10px/.test(tp) && /<div class="botones tres"[^>]*><button class="sec" data-h="8">/.test(tp) && /<div class="botones"><button id="cGuardar">/.test(tp) && /dr\.className="botones"/.test(tp), "los botones tienen espacio entre si (pausas, guardar condiciones y los de cada referente)");
  ok(/Todo tranquilo/.test(tp) && /Con se\u00f1ales de alerta/.test(tp) && /no ver\u00edan nada ahora/.test(tp), "el estado del telefono se explica en palabras simples");
  ok(!tp.includes('id="cActivo"') && !/enabled:\$\("cActivo"\)/.test(tp), "el casillero viejo de 'encendido' se reemplazo por el boton de apagar / encender");
  const n0 = correos.length;
  await pldCorreo(env, "a@b.c", "x", "<p>y</p>");
  ok(/modo cautela/.test(correos[n0].html) && !/por las dudas/.test(correos[n0].html), "el pie de los mails dice modo cautela");
  await api({ accion: "config", config: { enabled: false } });
  dispositivo({ seen: 150, bat: 8, lat: -34.52, lng: -58.4 });
  const ev = await pldEvaluar(env, DUENIO, await pldLeerConfig(env, DUENIO), false);
  ok(/Modo Cautela/.test(ev.motivo), "si esta apagado el mensaje habla del Modo Cautela");
  await api({ accion: "config", config: { enabled: true } });
}

console.log(`\n${total - fallos}/${total} pruebas ok`);
if (fallos) process.exit(1);
