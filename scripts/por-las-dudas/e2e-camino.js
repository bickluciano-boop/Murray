const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:8799';
const poner = (ruta, cuerpo) => fetch(B + ruta, { method: 'POST', body: cuerpo === undefined ? undefined : typeof cuerpo === 'string' ? cuerpo : JSON.stringify(cuerpo) });
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  // el telefono de la persona esta en (-34.505, -58.4): desde ahi se recalcula al cambiar de destino
  const ctx = await nav.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'es-AR', geolocation: { latitude: -34.505, longitude: -58.4 }, permissions: ['geolocation'] });
  await ctx.route('https://panel.test/**', async (route) => {
    const req = route.request();
    const r = await fetch(req.url().replace('https://panel.test', B), { method: req.method(), headers: { 'content-type': 'application/json' }, body: ['GET', 'HEAD'].includes(req.method()) ? undefined : req.postData() });
    await route.fulfill({ status: r.status, headers: { 'content-type': r.headers.get('content-type') || 'text/plain' }, body: Buffer.from(await r.arrayBuffer()) });
  });
  const pag = await ctx.newPage();
  const errores = [];
  pag.on('pageerror', (e) => errores.push('pageerror: ' + e.message));
  pag.on('dialog', (d) => d.accept());
  const texto = async (sel) => (await pag.textContent(sel)).replace(/\s+/g, ' ').trim();
  // el reloj muestra mm:ss o "H h MM min": se lo pasa a minutos
  const minReloj = async () => { const t = await texto('#reloj'); const h = /(\d+) h (\d+) min/.exec(t); if (h) return Number(h[1]) * 60 + Number(h[2]); const m = /(\d+):(\d+)/.exec(t); return m ? Number(m[1]) + Number(m[2]) / 60 : NaN; };

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
  await pag.selectOption('#gdModo', 'auto');
  await pag.waitForFunction(() => document.getElementById('gdAyudaMin').textContent.includes('calculado con mapas'));
  await pag.click('#gdEmpezar');
  await pag.waitForURL('**/camino?t=*');
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  console.log('1) camino: ' + await texto('#destino') + ' | ' + await texto('#detalle') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min');
  console.log('   botones a la vista: Voy a frenar:', await pag.isVisible('#bFrenar'), '| Cambiar destino:', await pag.isVisible('#bCambiar'), '| paneles cerrados:', !(await pag.isVisible('#frenarPanel')) && !(await pag.isVisible('#cambiarPanel')));

  // --- Voy a frenar un rato
  await pag.click('#bFrenar');
  await pag.waitForSelector('#frenarPanel', { state: 'visible' });
  console.log('2) frenar: ' + await texto('#frenarAyuda') + ' | opciones:', await pag.$$eval('#frenarPanel button', (b) => b.map((x) => x.textContent.trim())));
  await pag.screenshot({ path: 'e2e_camino_frenar.png', fullPage: true });
  const antes = await minReloj();
  await pag.click('button[data-f="15"]');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('frenás 15 minutos'));
  console.log('   ' + await texto('#aviso') + ' | el reloj paso de ' + antes.toFixed(1) + ' a ' + (await minReloj()).toFixed(1) + ' min | panel cerrado:', !(await pag.isVisible('#frenarPanel')));
  await pag.click('#bFrenar');
  console.log('   segunda vez: ' + await texto('#frenarAyuda'));
  await pag.click('button[data-f="30"]');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('frenás 30 minutos'));
  console.log('   ' + await texto('#aviso') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min | "Voy a frenar" deshabilitado (ya frenó 2 veces):', await pag.isDisabled('#bFrenar'), '| dice:', await texto('#bFrenar'));
  const mailsParada = (await (await fetch(B + '/__correos')).json()).filter((c) => c.to === 'mama@correo.com' && /no llegó/.test(c.subject));
  console.log('   avisos a la referente por frenar (debe ser 0):', mailsParada.length);

  // --- Cambiar destino (otro lugar, con sugerencias; el tiempo se recalcula desde donde esta el telefono)
  await poner('/__ruta', '600'); // Google dice 10 minutos hasta el nuevo destino
  await pag.click('#bCambiar');
  await pag.waitForSelector('#cambiarPanel', { state: 'visible' });
  await pag.waitForFunction(() => document.getElementById('cmLugar').options.length >= 2);
  console.log('3) cambiar destino: opciones:', await pag.$$eval('#cmLugar option', (o) => o.map((x) => x.textContent)), '| frenar cerrado:', !(await pag.isVisible('#frenarPanel')));
  await pag.selectOption('#cmLugar', '');
  await pag.waitForSelector('#cmOtro', { state: 'visible' });
  await pag.fill('#cmTexto', 'Kansas cabildo');
  await pag.waitForSelector('#cmSugerencias button');
  console.log('   sugerencias:', await pag.$$eval('#cmSugerencias button', (b) => b.map((x) => x.textContent)));
  await pag.screenshot({ path: 'e2e_camino_cambiar.png', fullPage: true });
  await pag.click('#cmConfirmar');
  await texto('#aviso');
  console.log('   sin elegir sugerencia: ' + await texto('#aviso'));
  await pag.click('#cmSugerencias button >> nth=0');
  console.log('   eligio: ' + await texto('#cmAyuda'));
  await pag.click('#cmConfirmar');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('cambiamos el destino'));
  console.log('   ' + await texto('#aviso') + ' | ' + await texto('#destino') + ' | ' + await texto('#detalle') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min | panel cerrado:', !(await pag.isVisible('#cambiarPanel')));
  console.log('   "Voy a frenar" sigue deshabilitado (las paradas no se reinician):', await pag.isDisabled('#bFrenar'));
  await pag.screenshot({ path: 'e2e_camino_cambiado.png', fullPage: true });

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

  // --- cambiar a un lugar guardado (la Casa): se conoce el punto exacto, asi que despues se puede seguir si se acerca
  await poner('/__ruta', '600');
  await pag.click('#bCambiar');
  await pag.waitForSelector('#cambiarPanel', { state: 'visible' });
  await pag.selectOption('#cmLugar', 'pl1');
  console.log('   con un lugar guardado no se pide direccion:', !(await pag.isVisible('#cmOtro')));
  await pag.click('#cmConfirmar');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('cambiamos el destino') && document.getElementById('destino').textContent === 'Vas a Casa');
  console.log('   ' + await texto('#destino') + ' | ' + await texto('#detalle') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min');

  // --- tránsito: se acerca al destino pero Google calcula que tarda mas -> se suma solo
  await poner('/__gd-minutos', '12'); // faltan 12 minutos (se evalua cuando faltan 20 o menos)
  await poner('/__ruta', '300');
  await poner('/__gd-ubicacion', { lat: -34.52, lng: -58.4 });
  await poner('/__gd-cron');
  const prim = await (await poner('/__gd-progreso', { refMinAtras: 6, recalcMinAtras: 6 })).json();
  console.log('5) transito: muestra de referencia guardada:', prim.filas.length === 1 && prim.filas[0].ref_lat === -34.52, '| autoMin antes:', prim.filas[0].auto_min);
  // el telefono avanzo 1,6 km hacia el destino y Google dice que le quedan 25 minutos
  await poner('/__gd-ubicacion', { lat: -34.505, lng: -58.4 });
  await poner('/__ruta', '1500');
  await poner('/__gd-cron');
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('estadoTxt').textContent.includes('por tránsito'));
  console.log('   ' + await texto('#estadoTxt') + ' | reloj: ' + (await minReloj()).toFixed(1) + ' min');
  await pag.screenshot({ path: 'e2e_camino_transito.png', fullPage: true });
  const reg = await (await fetch(B + '/api/remote/por-las-dudas')).json();
  console.log('   registro:', (reg.registro || []).filter((x) => /tránsito/.test(x.detail)).map((x) => x.detail));

  // --- llegar: el resumen cuenta los minutos por transito
  await pag.click('#bLlegue');
  await pag.waitForFunction(() => document.getElementById('estadoTxt').textContent.includes('Tocaste Llegué'));
  console.log('6) llegue: ' + await texto('#estadoTxt'));
  await pag.screenshot({ path: 'e2e_camino_final.png', fullPage: true });
  const mailsFin = (await (await fetch(B + '/__correos')).json()).filter((c) => c.to === 'mama@correo.com' && /no llegó|está bien/.test(c.subject));
  console.log('   mails a la referente en todo el recorrido (debe ser 0):', mailsFin.length);

  // --- Configuracion: el tope por transito
  await pag.goto(B + '/guardian#config-guardian');
  await pag.waitForSelector('#vCfgGuard', { state: 'visible' });
  await pag.waitForFunction(() => document.getElementById('gAuto').value !== '');
  console.log('7) Configuracion > Modo Guardian: tope por transito:', await pag.inputValue('#gAuto'), '| recomendado:', await texto('#gRecomendado'));
  await pag.fill('#gAuto', '0');
  await pag.click('#gGuardar');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('Cambios guardados'));
  await pag.reload();
  await pag.waitForSelector('#vCfgGuard', { state: 'visible' });
  await pag.waitForFunction(() => document.getElementById('gAuto').value === '0');
  await pag.goto(B + '/guardian#guardian');
  await pag.waitForFunction(() => document.getElementById('gdForm').style.display === 'block');
  console.log('   con 0, el pie de "Empezar camino" no habla de transito:', !(await texto('#gdPie')).includes('tránsito'), '|', await texto('#gdPie'));
  await pag.goto(B + '/guardian#config-guardian');
  await pag.waitForSelector('#vCfgGuard', { state: 'visible' });
  await pag.fill('#gAuto', '45');
  await pag.click('#gGuardar');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('Cambios guardados'));
  await pag.goto(B + '/guardian#guardian');
  await pag.waitForFunction(() => document.getElementById('gdForm').style.display === 'block');
  console.log('   con 45:', await texto('#gdPie'));
  await pag.goto(B + '/guardian#config-guardian');
  await pag.waitForSelector('#vCfgGuard', { state: 'visible' });
  await pag.screenshot({ path: 'e2e_camino_config.png', fullPage: true });
  await pag.click('#gReset');
  await pag.waitForFunction(() => document.getElementById('aviso').textContent.includes('recomendados'));
  console.log('   "Volver a los valores recomendados":', await pag.inputValue('#gAuto'), '|', await texto('#gRecomendado'));

  const ancho = await pag.evaluate(() => document.documentElement.scrollWidth);
  console.log('ancho:', ancho, '| errores:', errores.length ? errores : 'ninguno');
  await nav.close();
})().catch((e) => { console.log('FALLO E2E:', e.message); process.exit(1); });
