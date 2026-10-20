const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:8799';
const poner = (ruta, cuerpo) => fetch(B + ruta, { method: 'POST', body: cuerpo === undefined ? undefined : typeof cuerpo === 'string' ? cuerpo : JSON.stringify(cuerpo) });
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  // el telefono de la persona esta en (-34.505, -58.4): el navegador lo sabe y desde ahi se calcula
  const ctx = await nav.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'es-AR', geolocation: { latitude: -34.505, longitude: -58.4 }, permissions: ['geolocation'] });
  await ctx.route('https://panel.test/**', async (route) => {
    const req = route.request();
    const r = await fetch(req.url().replace('https://panel.test', B), { method: req.method(), headers: { 'content-type': 'application/json' }, body: ['GET', 'HEAD'].includes(req.method()) ? undefined : req.postData() });
    await route.fulfill({ status: r.status, headers: { 'content-type': r.headers.get('content-type') || 'text/plain' }, body: Buffer.from(await r.arrayBuffer()) });
  });
  // un AudioContext de mentira que cuenta los pitidos (1000 Hz: corto, 660 Hz: el largo del final)
  await ctx.addInitScript(() => {
    window.__pitidos = [];
    window.AudioContext = class { constructor() { this.state = 'running'; this.currentTime = 0; this.destination = {}; } resume() { return Promise.resolve(); } createGain() { return { gain: { value: 0 }, connect() {} }; } createOscillator() { const o = { frequency: { value: 0 }, type: '', connect() {}, start() { window.__pitidos.push(o.frequency.value); }, stop() {} }; return o; } };
  });
  const pag = await ctx.newPage();
  const errores = [];
  pag.on('pageerror', (e) => errores.push('pageerror: ' + e.message));
  pag.on('dialog', (d) => d.accept());
  const texto = async (sel) => (await pag.textContent(sel)).replace(/\s+/g, ' ').trim();
  // el reloj muestra mm:ss o "H h MM min": se lo pasa a minutos
  const minReloj = async () => { const t = await texto('#reloj'); const h = /(\d+) h (\d+) min/.exec(t); if (h) return Number(h[1]) * 60 + Number(h[2]); const m = /(\d+):(\d+)/.exec(t); return m ? Number(m[1]) + Number(m[2]) / 60 : NaN; };
  const marcado = () => pag.$eval('#cmModos button[aria-checked="true"]', (b) => b.textContent.trim());

  // --- preparar: un referente que acepta y la clave de Google (el tiempo sale de los mapas: 13 min)
  await poner('/__clave', '1');
  await pag.goto(B + '/guardian#config-referentes');
  await pag.waitForSelector('#vCfgRef', { state: 'visible' });
  await pag.fill('#rNombre', 'Mamá'); await pag.fill('#rCorreo', 'mama@correo.com'); await pag.click('#rAgregar');
  await pag.waitForFunction(() => document.getElementById('referentes').textContent.includes('Mamá'));
  const correos0 = await (await fetch(B + '/__correos')).json();
  const link = /href="([^"]*\/referente\?t=[^"]+)"/.exec(correos0.find((c) => c.to === 'mama@correo.com').html)[1];
  const ref = await ctx.newPage(); await ref.goto(link.replace(/^https?:\/\/[^/]+/, B)); await ref.click('text=Aceptar ser referente'); await ref.close();
  await pag.goto(B + '/guardian#guardian');
  await pag.reload(); // la pagina vuelve a preguntar: ahora ya hay una referente que acepto
  await pag.waitForFunction(() => document.getElementById('gdForm').style.display === 'block');
  await pag.selectOption('#gdLugar', 'pl1');
  await pag.click('#gdModo button[data-modo="auto"]');
  await pag.waitForFunction(() => document.getElementById('gdAyudaMin').textContent.includes('calculado con mapas'));
  console.log('0) empezar: ' + await texto('#gdAyudaMin'));
  await pag.click('#gdEmpezar');
  await pag.waitForURL('**/camino?t=*');
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  console.log('1) camino: ' + await texto('#destino') + ' | ' + await texto('#detalle') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min');
  console.log('   botones a la vista: Voy a frenar:', await pag.isVisible('#bFrenar'), '| Cambiar destino:', await pag.isVisible('#bCambiar'), '| Ya sigo (solo en pausa):', await pag.isVisible('#bSeguir'), '| paneles cerrados:', !(await pag.isVisible('#frenarPanel')) && !(await pag.isVisible('#cambiarPanel')));

  // --- Probar sonido: tres pips, para saber si se escucha (o si salen por unos auriculares Bluetooth)
  await pag.click('#bProbar');
  await pag.waitForFunction(() => document.getElementById('sonidoTxt').textContent.includes('Sonaron tres pips'), null, { timeout: 8000 });
  console.log('1b) Probar sonido: pips cortos:', (await pag.evaluate(() => window.__pitidos)).filter((f) => f === 1000).length, '| ' + (await texto('#sonidoTxt')).slice(0, 150));
  await pag.evaluate(() => { window.__pitidos = []; });

  // --- Cambiar destino: como vas (iconos), a donde vas, y desde donde estas
  await poner('/__ruta', '600'); // Google dice 10 minutos hasta el nuevo destino
  await pag.click('#bCambiar');
  await pag.waitForSelector('#cambiarPanel', { state: 'visible' });
  await pag.waitForFunction(() => document.getElementById('cmLugar').options.length >= 3);
  console.log('2) cambiar destino: como vas:', await pag.$$eval('#cmModos button.modo', (b) => b.map((x) => x.textContent.trim())), '| iconos:', await pag.$$eval('#cmModos svg', (l) => l.length), '| marcado:', await marcado());
  console.log('   a donde vas:', await pag.$$eval('#cmLugar option', (o) => o.map((x) => x.textContent)), '| frenar cerrado:', !(await pag.isVisible('#frenarPanel')));
  await pag.click('#cmModos button[data-modo="caminando"]');
  console.log('   toco Caminando -> marcado:', await marcado());
  await pag.selectOption('#cmLugar', '');
  await pag.waitForSelector('#cmOtro', { state: 'visible' });
  await pag.fill('#cmTexto', 'Kansas cabildo');
  await pag.waitForSelector('#cmSugerencias button');
  console.log('   sugerencias:', await pag.$$eval('#cmSugerencias button', (b) => b.map((x) => x.textContent)));
  await pag.screenshot({ path: 'e2e_camino_cambiar.png', fullPage: true });
  await pag.click('#cmConfirmar');
  console.log('   sin elegir sugerencia: ' + await texto('#aviso'));
  await pag.click('#cmSugerencias button >> nth=0');
  console.log('   eligio: ' + await texto('#cmAyuda'));
  await pag.click('#cmConfirmar');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('cambiamos el destino'));
  console.log('   ' + await texto('#aviso'));
  console.log('   ' + await texto('#destino') + ' | ' + await texto('#detalle') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min | panel cerrado:', !(await pag.isVisible('#cambiarPanel')));
  await pag.screenshot({ path: 'e2e_camino_cambiado.png', fullPage: true });

  // --- seguir yendo al mismo lugar, pero ahora en transporte publico
  await poner('/__ruta', '1200');
  await pag.click('#bCambiar');
  await pag.waitForSelector('#cambiarPanel', { state: 'visible' });
  await pag.waitForFunction(() => document.getElementById('cmLugar').options.length >= 3);
  console.log('3) mismo lugar: modo marcado al abrir:', await marcado(), '| primera opcion:', await pag.$eval('#cmLugar', (s) => s.options[s.selectedIndex].textContent));
  await pag.click('#cmModos button[data-modo="transporte"]');
  await pag.click('#cmConfirmar');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('seguís yendo a'));
  console.log('   ' + await texto('#aviso'));
  console.log('   ' + await texto('#destino') + ' | ' + await texto('#detalle') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min');

  // --- cambiar otra vez, sin clave de Google: pide los minutos
  await poner('/__clave', '0');
  await pag.click('#bCambiar');
  await pag.waitForSelector('#cambiarPanel', { state: 'visible' });
  await pag.selectOption('#cmLugar', '');
  await pag.fill('#cmTexto', 'Plaza del barrio');
  await pag.waitForTimeout(1200);
  await pag.click('#cmConfirmar');
  await pag.waitForSelector('#cmMinBloque', { state: 'visible' });
  console.log('4) sin Google: ' + await texto('#aviso') + ' | pide los minutos:', await pag.isVisible('#cmMin'));
  await pag.fill('#cmMin', '25');
  await pag.click('#cmConfirmar');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('cambiamos el destino'));
  console.log('   ' + await texto('#destino') + ' | ' + await texto('#detalle') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min');
  await poner('/__clave', '1');

  // --- si el navegador no sabe donde esta y el telefono hace rato que no avisa, NO calcula desde un lugar viejo
  await poner('/__ruta', '600');
  await poner('/__gd-ubicacion', { lat: -34.6, lng: -58.4, haceMin: 120 });
  const sinGps = await nav.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'es-AR' }); // sin permiso de ubicacion
  const p2 = await sinGps.newPage();
  p2.on('dialog', (d) => d.accept());
  await p2.goto(B + '/camino' + new URL(pag.url()).search); // el mismo camino, abierto en un navegador que no sabe donde esta
  await p2.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  await p2.click('#bCambiar');
  await p2.waitForFunction(() => document.getElementById('cmLugar').options.length >= 2);
  await p2.selectOption('#cmLugar', 'pl1');
  await p2.click('#cmConfirmar');
  await p2.waitForSelector('#cmMinBloque', { state: 'visible', timeout: 20000 });
  console.log('5) sin ubicacion del navegador y con la del telefono de hace 2 horas: ' + (await p2.textContent('#aviso')).trim() + ' | pide los minutos:', await p2.isVisible('#cmMin'));
  await p2.screenshot({ path: 'e2e_camino_sin_ubicacion.png', fullPage: true });
  await sinGps.close();
  // con el navegador del telefono (que si sabe donde esta) vuelve a la Casa desde ahi
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  await pag.click('#bCambiar');
  await pag.waitForFunction(() => document.getElementById('cmLugar').options.length >= 2);
  await pag.selectOption('#cmLugar', 'pl1');
  await pag.click('#cmModos button[data-modo="auto"]');
  await pag.click('#cmConfirmar');
  await pag.waitForFunction(() => document.getElementById('destino').textContent === 'Vas a Casa');
  console.log('   con el GPS del telefono: ' + await texto('#aviso') + ' | ' + await texto('#detalle'));

  // --- transito: se acerca al destino pero Google calcula que tarda mas -> se suma solo
  await poner('/__gd-minutos', '12'); // faltan 12 minutos (se evalua cuando faltan 20 o menos)
  await poner('/__ruta', '300');
  await poner('/__gd-ubicacion', { lat: -34.52, lng: -58.4 });
  await poner('/__gd-cron');
  const prim = await (await poner('/__gd-progreso', { refMinAtras: 6, recalcMinAtras: 6 })).json();
  console.log('6) transito: muestra de referencia guardada:', prim.filas.length === 1 && prim.filas[0].ref_lat === -34.52, '| autoMin antes:', prim.filas[0].auto_min);
  // el telefono avanzo 1,6 km hacia el destino y Google dice que le quedan 25 minutos
  await poner('/__gd-ubicacion', { lat: -34.505, lng: -58.4 });
  await poner('/__ruta', '1500');
  await poner('/__gd-cron');
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('estadoTxt').textContent.includes('por tránsito'));
  console.log('   ' + await texto('#estadoTxt') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min');
  await pag.screenshot({ path: 'e2e_camino_transito.png', fullPage: true });

  // --- Voy a frenar un rato: el reloj queda en pausa
  await pag.click('#bFrenar');
  await pag.waitForSelector('#frenarPanel', { state: 'visible' });
  console.log('7) frenar: ' + await texto('#frenarAyuda') + ' | opciones:', await pag.$$eval('#frenarPanel button', (b) => b.map((x) => x.textContent.trim())));
  await pag.screenshot({ path: 'e2e_camino_frenar.png', fullPage: true });
  const antes = await minReloj();
  await pag.click('button[data-f="15"]');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('en pausa 15 minutos'));
  const r1 = await texto('#reloj'); await pag.waitForTimeout(2500); const r2 = await texto('#reloj');
  console.log('   ' + await texto('#aviso'));
  console.log('   el reloj estaba en ' + antes.toFixed(1) + ' min y en pausa queda quieto: "' + r1 + '" -> "' + r2 + '" (iguales: ' + (r1 === r2) + ') | ' + await texto('#pausaTxt'));
  console.log('   ' + await texto('#estadoTxt'));
  console.log('   botones: Ya sigo visible:', await pag.isVisible('#bSeguir'), '| "+10 +20 +30" oculto:', !(await pag.isVisible('#extBloque')), '| el boton de frenar dice:', await texto('#bFrenar'), '| panel cerrado:', !(await pag.isVisible('#frenarPanel')));
  await pag.screenshot({ path: 'e2e_camino_pausa.png', fullPage: true });
  await pag.click('#bSeguir');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('seguís en camino'));
  const s1 = await texto('#reloj'); await pag.waitForTimeout(2500); const s2 = await texto('#reloj');
  console.log('   Ya sigo: ' + await texto('#aviso') + ' | el reloj vuelve a bajar: "' + s1 + '" -> "' + s2 + '" (distintos: ' + (s1 !== s2) + ') | retoma con ' + (await minReloj()).toFixed(1) + ' min (lo que le faltaba: ~' + antes.toFixed(0) + ') | pausa oculta:', !(await pag.isVisible('#pausaTxt')), '| Ya sigo oculto:', !(await pag.isVisible('#bSeguir')), '| el boton de frenar dice:', await texto('#bFrenar'));
  // otra parada, de 30 minutos, y se la deja terminar sola
  await pag.click('#bFrenar');
  console.log('   segunda vez: ' + await texto('#frenarAyuda'));
  await pag.click('button[data-f="30"]');
  await pag.waitForFunction(() => document.getElementById('pausaTxt').style.display === 'block');
  console.log('   en pausa otra vez: ' + await texto('#pausaTxt') + ' | el boton de frenar dice:', await texto('#bFrenar'), '(ya usó las 2)');
  const mailsParada = (await (await fetch(B + '/__correos')).json()).filter((c) => c.to === 'mama@correo.com' && /no llegó/.test(c.subject));
  console.log('   avisos a la referente por frenar (debe ser 0):', mailsParada.length);
  await poner('/__gd-pausa', { venceHaceMin: 0.3 }); // la pausa de 30 minutos termino hace 20 segundos
  await poner('/__gd-cron');
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block' && document.getElementById('pausaTxt').style.display === 'none');
  const t1 = await texto('#reloj'); await pag.waitForTimeout(2500); const t2 = await texto('#reloj');
  const mailsFinPausa = (await (await fetch(B + '/__correos')).json()).filter((c) => /Terminó tu parada/.test(c.subject));
  console.log('8) pausa terminada sola: el reloj sigue: "' + t1 + '" -> "' + t2 + '" | ' + await texto('#estadoTxt'));
  console.log('   mail "Terminó tu parada":', mailsFinPausa.map((c) => c.to), '| a la referente (debe ser 0):', mailsFinPausa.filter((c) => c.to === 'mama@correo.com').length);
  const reg = await (await fetch(B + '/api/remote/por-las-dudas')).json();
  console.log('   registro:', (reg.registro || []).filter((x) => /parada|pausa|frenar|Seguís|tránsito|Cambiaste/.test(x.detail)).map((x) => x.detail.slice(0, 120)));

  // --- llegar: se comprueba con la ubicacion. El navegador esta a ~1,7 km de la Casa de prueba: el camino no se cierra y la pantalla explica por que
  await pag.click('#bLlegue');
  await pag.waitForSelector('#lleguePanel', { state: 'visible' });
  console.log('9) llegue lejos del destino: ' + await texto('#llegueTxt'));
  const botonesLlegue = await pag.$$eval('#lleguePanel button', (b) => b.map((x) => x.textContent.trim()));
  if (botonesLlegue.length !== 1 || botonesLlegue[0] !== 'Volver a comprobar') throw new Error('lejos del destino solo se puede volver a comprobar (sin «Llegué igual»)');
  console.log('   botones (solo volver a comprobar):', botonesLlegue, '| el boton Llegué vuelve a decir:', await texto('#bLlegue'), '| el camino sigue abierto:', await pag.isVisible('#acciones'), '|', (await texto('#estadoTxt')).slice(0, 50));
  await pag.screenshot({ path: 'e2e_camino_llegue_lejos.png', fullPage: true });
  // ahora el navegador esta en la puerta de Casa: "Volver a comprobar" cierra el camino como comprobado; el resumen cuenta los minutos por transito y de parada
  await ctx.setGeolocation({ latitude: -34.4902, longitude: -58.4 });
  await pag.click('#bLlegueDeNuevo');
  await pag.waitForFunction(() => document.getElementById('estadoTxt').textContent.includes('Tocaste Llegué'));
  console.log('   en la puerta de Casa: ' + await texto('#aviso') + ' | ' + await texto('#estadoTxt'));
  await pag.screenshot({ path: 'e2e_camino_final.png', fullPage: true });
  const mailsFin = (await (await fetch(B + '/__correos')).json()).filter((c) => c.to === 'mama@correo.com' && /no llegó|está bien/.test(c.subject));
  console.log('   mails a la referente en todo el recorrido (debe ser 0):', mailsFin.length);

  // --- estricto: otro camino a Casa con el navegador lejos; volver a comprobar las veces que sea no lo cierra (los chicos dirian que llegaron a lo de un amigo y se quedarian en otro lado)
  await ctx.setGeolocation({ latitude: -34.505, longitude: -58.4 });
  const otro = await (await fetch(B + '/api/guardian', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ accion: 'empezar', lugarId: 'pl1', modo: 'auto' }) })).json();
  await pag.goto(otro.viaje.enlace.replace(/^https?:\/\/[^/]+/, B));
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  await pag.click('#bLlegue');
  await pag.waitForSelector('#lleguePanel', { state: 'visible' });
  await pag.click('#bLlegueDeNuevo');
  await pag.waitForFunction(() => document.getElementById('bLlegue').textContent === 'Llegué' && document.getElementById('lleguePanel').style.display === 'block');
  const sigue = await pag.isVisible('#acciones');
  console.log('9b) estricto: tras volver a comprobar lejos, el camino sigue abierto:', sigue, '| ' + (await texto('#llegueTxt')).slice(0, 80));
  if (!sigue) throw new Error('no se puede cerrar el camino lejos del destino');
  const reg2 = await (await fetch(B + '/api/remote/por-las-dudas')).json();
  console.log('   registro:', (reg2.registro || []).filter((x) => /Tocaste Llegué, pero|Tu ubicación lo confirmó/.test(x.detail)).map((x) => x.detail.slice(0, 150)));
  await pag.click('#bCancelar'); // se cancela para seguir con lo demas
  await pag.waitForFunction(() => document.getElementById('estadoTxt').textContent.includes('cancelado'));

  // --- el navegador no deja ver la ubicacion (la persona dijo que no) y la ultima del telefono es de hace 2 horas: no se puede comprobar; al dejarla ver, en la puerta de Casa, cierra como comprobado
  await poner('/__gd-ubicacion', { lat: -34.6, lng: -58.4, haceMin: 120 });
  const otro2 = await (await fetch(B + '/api/guardian', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ accion: 'empezar', lugarId: 'pl1', modo: 'auto', origen: { lat: -34.505, lng: -58.4, precision: 20 } }) })).json(); // el camino se arma desde donde esta el navegador (la ubicacion del telefono es vieja)
  await pag.goto(otro2.viaje.enlace.replace(/^https?:\/\/[^/]+/, B));
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  await pag.evaluate(() => { window.__geoReal = navigator.geolocation.getCurrentPosition.bind(navigator.geolocation); navigator.geolocation.getCurrentPosition = (ok, err) => setTimeout(() => err({ code: 1, message: 'User denied Geolocation' }), 50); });
  await pag.click('#bLlegue');
  await pag.waitForSelector('#lleguePanel', { state: 'visible' });
  console.log('9c) sin permiso de ubicacion y con la del telefono de hace 2 horas: ' + await texto('#llegueTxt'));
  await ctx.setGeolocation({ latitude: -34.4902, longitude: -58.4 });
  await pag.evaluate(() => { navigator.geolocation.getCurrentPosition = window.__geoReal; }); // ahora si la deja ver
  await pag.click('#bLlegueDeNuevo');
  await pag.waitForFunction(() => document.getElementById('estadoTxt').textContent.includes('Comprobamos con tu ubicación'));
  console.log('   con permiso y en la puerta de Casa: ' + await texto('#aviso'));

  // --- Configuracion: el tope por transito
  await pag.goto(B + '/guardian#config-guardian');
  await pag.waitForSelector('#vCfgGuard', { state: 'visible' });
  await pag.waitForFunction(() => document.getElementById('gAuto').value !== '');
  console.log('10) Configuracion > Modo Guardian: tope por transito:', await pag.inputValue('#gAuto'), '| margen de llegada:', await pag.inputValue('#gRadio'), 'm | recomendado:', await texto('#gRecomendado'));
  if ((await pag.inputValue('#gRadio')) !== '150') throw new Error('el margen de llegada recomendado es de 150 m');
  await pag.fill('#gAuto', '0');
  await pag.click('#gGuardar');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('Cambios guardados'));
  await pag.reload();
  await pag.waitForSelector('#vCfgGuard', { state: 'visible' });
  await pag.waitForFunction(() => document.getElementById('gAuto').value === '0');
  await pag.goto(B + '/guardian#guardian');
  await pag.waitForFunction(() => document.getElementById('gdForm').style.display === 'block');
  console.log('    con 0, el pie de "Empezar camino" no habla de transito:', !(await texto('#gdPie')).includes('tránsito'), '|', await texto('#gdPie'));
  await pag.goto(B + '/guardian#config-guardian');
  await pag.waitForSelector('#vCfgGuard', { state: 'visible' });
  await pag.fill('#gAuto', '45');
  await pag.fill('#gRadio', '100');
  await pag.click('#gGuardar');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('Cambios guardados'));
  await pag.goto(B + '/guardian#guardian');
  await pag.waitForFunction(() => document.getElementById('gdForm').style.display === 'block');
  console.log('    con 45 y 100 m:', await texto('#gdPie'));
  if (!(await texto('#gdPie')).includes('a menos de 100 m del destino')) throw new Error('el pie de Empezar camino tiene que decir el margen de llegada elegido');
  await pag.goto(B + '/guardian#config-guardian');
  await pag.waitForSelector('#vCfgGuard', { state: 'visible' });
  await pag.screenshot({ path: 'e2e_camino_config.png', fullPage: true });
  await pag.click('#gReset');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('recomendados'));
  console.log('    "Volver a los valores recomendados":', await pag.inputValue('#gAuto'), '| margen de llegada:', await pag.inputValue('#gRadio'), '|', await texto('#gRecomendado'));
  if ((await pag.inputValue('#gRadio')) !== '150') throw new Error('al volver a lo recomendado el margen de llegada tiene que ser 150 m');

  const ancho = await pag.evaluate(() => document.documentElement.scrollWidth);
  console.log('ancho:', ancho, '| errores:', errores.length ? errores : 'ninguno');
  await nav.close();
})().catch((e) => { console.log('FALLO E2E:', e.message); process.exit(1); });
