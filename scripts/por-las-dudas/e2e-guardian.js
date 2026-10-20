const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:8799';
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await nav.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'es-AR' });
  // los enlaces que arma el servidor de prueba apuntan a https://panel.test: se llevan al servidor local
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
  await pag.goto(B + '/por-las-dudas');
  await pag.waitForFunction(() => document.getElementById('gdSinRef').style.display === 'block');
  console.log('sin referentes:', (await pag.textContent('#gdSinRef')).trim().slice(0, 90));
  // un referente que acepta
  await pag.fill('#rNombre', 'Mamá'); await pag.fill('#rCorreo', 'mama@correo.com'); await pag.click('#rAgregar');
  await pag.waitForFunction(() => document.getElementById('referentes').textContent.includes('Mamá'));
  const correos = await (await fetch(B + '/__correos')).json();
  const link = /href="([^"]*\/referente\?t=[^"]+)"/.exec(correos.find((c) => c.to === 'mama@correo.com').html)[1];
  const ref = await ctx.newPage(); await ref.goto(link.replace(/^https?:\/\/[^/]+/, B)); await ref.click('text=Aceptar ser referente'); await ref.close();
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('gdForm').style.display === 'block');
  console.log('opciones de destino:', await pag.$$eval('#gdLugar option', (o) => o.map((x) => x.textContent)));
  await pag.waitForFunction(() => document.getElementById('gdMin').value !== '');
  console.log('minutos calculados:', await pag.inputValue('#gdMin'), '|', await pag.textContent('#gdAyudaMin'));
  await pag.screenshot({ path: 'e2e_guardian_form.png', fullPage: true });
  console.log('sin clave: minutos editables:', !(await pag.$eval('#gdMin', (e) => e.readOnly)));
  // con la clave de Google Rutas: el tiempo sale de los mapas y no se puede cambiar
  await fetch(B + '/__clave', { method: 'POST', body: '1' });
  await pag.selectOption('#gdModo', 'transporte');
  await pag.waitForFunction(() => document.getElementById('gdAyudaMin').textContent.includes('calculado con mapas'));
  console.log('con clave:', await pag.inputValue('#gdMin'), 'min |', await pag.textContent('#gdAyudaMin'), '| solo lectura:', await pag.$eval('#gdMin', (e) => e.readOnly));
  await pag.screenshot({ path: 'e2e_guardian_mapas.png', fullPage: true });
  await pag.selectOption('#gdLugar', '');
  console.log('minutos al cambiar a Otro lugar (no queda el numero viejo):', JSON.stringify(await pag.inputValue('#gdMin')), '|', await pag.textContent('#gdAyudaMin'));
  await pag.fill('#gdTexto', 'Kansas cabildo');
  await pag.waitForSelector('#gdSugerencias button');
  console.log('sugerencias:', await pag.$$eval('#gdSugerencias button', (b) => b.map((x) => x.textContent)));
  await pag.screenshot({ path: 'e2e_guardian_sugerencias.png', fullPage: true });
  await pag.click('#gdEmpezar');
  console.log('sin elegir sugerencia:', (await pag.textContent('#aviso')).trim());
  await pag.click('#gdSugerencias button >> nth=0');
  await pag.waitForFunction(() => document.getElementById('gdAyudaMin').textContent.includes('calculado con mapas'));
  console.log('eligio:', await pag.inputValue('#gdTexto'), '|', await pag.inputValue('#gdMin'), 'min |', await pag.textContent('#gdAyudaMin'));
  await pag.selectOption('#gdLugar', 'pl1');
  await fetch(B + '/__clave', { method: 'POST', body: '0' });
  await pag.selectOption('#gdModo', 'caminando');
  await pag.waitForFunction(() => document.getElementById('gdAyudaMin').textContent.includes('estimado'));
  console.log('caminando:', await pag.inputValue('#gdMin'), 'min');
  await pag.click('#gdEmpezar');
  await pag.waitForURL('**/camino?t=*');
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  console.log('camino:', await pag.textContent('#destino'), '|', (await pag.textContent('#detalle')).trim(), '| reloj:', await pag.textContent('#reloj'));
  console.log('estado:', (await pag.textContent('#estadoTxt')).trim());
  await pag.screenshot({ path: 'e2e_guardian_camino.png', fullPage: true });
  await pag.click('button[data-m="10"]');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('10 minutos más'));
  console.log('tras extender:', await pag.textContent('#aviso'));
  // los ultimos 15 segundos: un pip por segundo, y uno largo al final
  await fetch(B + '/__gd-minutos', { method: 'POST', body: '0.27' });
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  console.log('boton de sonido:', await pag.textContent('#bSonido'), '|', (await pag.textContent('#sonidoTxt')).trim().slice(0, 70));
  await pag.waitForTimeout(19000);
  const pits = await pag.evaluate(() => window.__pitidos);
  console.log('pitidos cortos:', pits.filter((f) => f === 1000).length, '(esperados ~15) | largos:', pits.filter((f) => f === 660).length, '| reloj:', await pag.textContent('#reloj'));
  await pag.click('#bSonido');
  console.log('boton de sonido tras tocarlo:', await pag.textContent('#bSonido'));
  await pag.click('#bSonido');
  // se vence: el reloj corre en el servidor
  await fetch(B + '/__gd-minutos', { method: 'POST', body: '-1' });
  await fetch(B + '/__gd-cron', { method: 'POST' });
  await pag.waitForFunction(() => document.getElementById('estadoTxt').textContent.includes('Ya les avisamos'), null, { timeout: 30000 });
  console.log('tras vencer:', (await pag.textContent('#estadoTxt')).trim(), '| reloj:', await pag.textContent('#reloj'), '| extender habilitado:', await pag.$$eval('button[data-m]', (b) => b.some((x) => !x.disabled)));
  const mails = await (await fetch(B + '/__correos')).json();
  console.log('mails al referente:', mails.filter((c) => c.to === 'mama@correo.com' && /no llegó/.test(c.subject)).map((c) => c.subject));
  await pag.screenshot({ path: 'e2e_guardian_alerta.png', fullPage: true });
  await pag.click('#bLlegue');
  await pag.waitForFunction(() => document.getElementById('estadoTxt').textContent.includes('Tocaste Llegué'));
  console.log('llegue:', (await pag.textContent('#estadoTxt')).trim(), '| acciones visibles:', await pag.isVisible('#acciones'));
  const mails2 = await (await fetch(B + '/__correos')).json();
  console.log('mails de "esta bien":', mails2.filter((c) => c.to === 'mama@correo.com' && /está bien/.test(c.subject)).length);
  // el panel ya no muestra camino en marcha
  await pag.goto(B + '/por-las-dudas');
  await pag.waitForFunction(() => document.getElementById('gdForm').style.display === 'block');
  await pag.click('#detRegistro summary');
  console.log('registro:', (await pag.textContent('#registro')).replace(/\s+/g, ' ').slice(0, 260));
  const ancho = await pag.evaluate(() => document.documentElement.scrollWidth);
  console.log('ancho:', ancho, '| errores:', errores.length ? errores : 'ninguno');
  await nav.close();
})().catch((e) => { console.log('FALLO E2E:', e.message); process.exit(1); });
