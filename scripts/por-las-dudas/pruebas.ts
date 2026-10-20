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
  ok((await pldAvisarSosCancelado(env, DUENIO, now())) === 0 && correos.length === n, "una cancelacion sin aviso previo no manda nada");
  // sin ubicacion
  n = correos.length;
  await pldAvisarSos(env, DUENIO, null);
  nuevos = mailsDesde(n);
  ok(nuevos.length === 2 && !/google\.com\/maps/.test(nuevos[0].html), "sin ubicacion igual avisa (sin el mapa)");
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
  ok(/Mientras est\u00e1 apagado no se manda ning\u00fan aviso autom\u00e1tico a tus referentes\. El SOS sigue avisando/.test(tp) && !/tampoco el del SOS/.test(tp), "la pagina dice que el SOS sigue avisando aunque este apagado");
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
  ok((await (await api()).json() as any).registro.some((x: any) => /Llegaste bien a Casa: tocaste Llegué a las \d\d:\d\d, \d+ minutos? después del límite/.test(x.detail)), "y en el registro");
  ok((await gd({ t: TOKEN, accion: "llegue" })).status === 409, "un camino terminado no se puede tocar de nuevo");
  ok((await (await api()).json() as any).registro.some((x: any) => /Llegaste bien a Casa/.test(x.detail)), "queda en el registro");

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
  await gd({ t: T3, accion: "cancelar" });
  ok(viaje().estado === "cancelado" && correos.length === n, "cancelar antes de que venza no avisa a nadie");
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
  ok(!/hacer\(\{accion:"cancelar"\},/.test(pc), "al cancelar no se repite el texto arriba (la tarjeta ya dice que se canceló)");
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

console.log("== Tu proteccion: Modo Cautela y Modo Guardian");
{
  const tp: string = await (pldPaginaDuenio() as any).text();
  ok(/Tu protecci\u00f3n/.test(tp) && /Modo Cautela/.test(tp) && /Modo Guardi\u00e1n/.test(tp) && /Empezar camino/.test(tp), "la pagina se llama Tu proteccion y muestra Modo Cautela y el Modo Guardian para empezar un camino");
  const pos = (x: string) => tp.indexOf(x);
  const corte = (desde: string, hasta: string) => tp.slice(tp.indexOf(desde), hasta ? tp.indexOf(hasta) : undefined);
  const vInicio = corte('<div id="vInicio">', '<div id="vReferentes"'), vRef = corte('<div id="vReferentes"', '<div id="vCautela"'), vCaut = corte('<div id="vCautela"', '<div id="vGuardian"'), vGuar = corte('<div id="vGuardian"', '<script>');
  ok(/id="tReferentes" href="#tus-referentes"/.test(vInicio) && /id="tCautela" href="#cautela"/.test(vInicio) && /id="tGuardian" href="#guardian"/.test(vInicio) && vInicio.indexOf("tReferentes") < vInicio.indexOf("tCautela") && vInicio.indexOf("tCautela") < vInicio.indexOf("tGuardian") && vInicio.indexOf("tGuardian") < vInicio.indexOf("<h2>Registro</h2>"), "la pantalla de inicio de Tu proteccion muestra tres tarjetas (referentes, Modo Cautela, Modo Guardian) y el registro");
  ok(!/Pausar o apagar|Condiciones|Empezar camino|id="rAgregar"|id="cGuardar"|id="gdEmpezar"/.test(vInicio), "y la pantalla de inicio no trae nada de la configuracion de ningun modo");
  ok(/id="rAgregar"/.test(vRef) && /id="referentes"/.test(vRef) && /No lo encuentro/.test(vRef) && !/Pausar o apagar|Condiciones|Empezar camino/.test(vRef), "Tus referentes tiene solo lo de los referentes");
  ok(vCaut.indexOf("Pausar o apagar") > 0 && vCaut.indexOf("Pausar o apagar") < vCaut.indexOf("Estado de tu tel\u00e9fono") && vCaut.indexOf("Estado de tu tel\u00e9fono") < vCaut.indexOf("<h2>Condiciones</h2>") && /id="cEncender"/.test(vCaut) && /id="refLineaC"/.test(vCaut) && !/Empezar camino|id="gdEmpezar"|id="gdLugar"|id="rAgregar"|Tus referentes<\/h2>/.test(vCaut), "el Modo Cautela muestra solo lo suyo (pausar o apagar, estado del telefono, condiciones) y no mezcla el Guardian ni los referentes");
  ok(/id="gdSeccion"/.test(vGuar) && /id="gdEmpezar"/.test(vGuar) && /id="gdLugar"/.test(vGuar) && /id="refLineaG"/.test(vGuar) && !/Pausar o apagar|Condiciones|Estado de tu tel\u00e9fono|id="cEncender"|id="rAgregar"/.test(vGuar), "el Modo Guardian muestra solo lo suyo (a donde vas, como vas, cuanto tardas) y no mezcla el Modo Cautela ni los referentes");
  ok(/location\.hash/.test(tp) && /hashchange/.test(tp) && /"tus-referentes":"vReferentes"/.test(tp) && /h==="gdSeccion"\)h="guardian"/.test(tp) && /!PROPIA\)h=""/.test(tp), "la pagina elige que mostrar segun la direccion (#cautela, #guardian, #tus-referentes), acepta el viejo #gdSeccion y no abre el Guardian en la proteccion de otra persona");
  ok(/\$\("refLineaG"\)\.style\.display=nombres\.length\?"block":"none"/.test(tp), "en el Modo Guardian, si no hay referentes no se repite el aviso (ya lo dice la tarjeta de abajo)");
  ok(/<a class="atras" id="aHub"/.test(tp) && /\$\("aHub"\)\.style\.display=v\?"inline-block":"none"/.test(tp) && /NOMBREPERSONA/.test(tp), "dentro de un modo aparece el enlace para volver a Tu proteccion y el titulo dice de cual se trata");
  ok(['detHoy', 'detCondiciones', 'detRegistro'].every((i) => new RegExp('<details class="tarjeta" id="' + i + '"').test(tp)) && !/<details[^>]*\sopen/.test(tp), "como estas hoy, condiciones y registro estan plegados");
  ok(/id="detCondiciones">.*?id="cGuardar".*?<\/details>/s.test(tp) && /id="detRegistro">.*?id="registro".*?<\/details>/s.test(tp) && /id="detHoy">.*?id="hoy".*?<\/details>/s.test(tp), "los campos estan dentro de su tarjeta plegable");
  ok(!/Pr\u00f3ximamente/.test(tp) && /id="guardianCard"/.test(tp) && /id="gdEmpezar"/.test(tp) && /id="gdSeccion"/.test(tp), "el Modo Guardian ya no dice Proximamente: tiene su tarjeta para empezar un camino");
  ok(!/Por las dudas est\u00e1 encendido/.test(tp) && /Encender Modo Cautela|Apagar Modo Cautela/.test(tp) && /Por las dudas: si dejo de responder/.test(tp), "el interruptor y el subtitulo usan el nombre nuevo");
  const ids = ["aviso", "sinSesion", "contenido", "hoy", "referentes", "rNombre", "rCorreo", "rAgregar", "invitacion", "dondeBoton", "cNombre", "cDesde", "cHasta", "cSilNoche", "cSilDia", "cKm", "cBat", "cMin", "cEmer", "cGuardar", "cCasa", "casa", "pausa", "estadoModo", "pHoras", "pOtro", "cEncender", "registro", "titulo", "paraQuien", "persona", "soloLectura", "enNombreDe", "gdSeccion", "guardianCard", "gdCarga", "gdActivo", "gdAbrir", "gdForm", "gdLugar", "gdOtro", "gdTexto", "gdModo", "gdMin", "gdEmpezar", "gdSinRef"];
  ok(ids.every((i) => tp.includes('id="' + i + '"')), "todos los campos que usa la pagina siguen en su lugar");
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
