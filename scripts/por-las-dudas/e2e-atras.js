// Recorrido en navegador del boton "Volver" del pie de Tu proteccion: aparece en todas las pantallas menos en el inicio, lleva al mismo lugar que el de arriba
// y, abierta desde la consola (directo en Configuracion), vuelve a la Configuracion del panel. Necesita servidor.ts andando en el puerto 8799.
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:8799';
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await nav.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'es-AR' });
  await ctx.route('https://panel.test/**', async (route) => {
    const req = route.request();
    const r = await fetch(req.url().replace('https://panel.test', B), { method: req.method(), headers: { 'content-type': 'application/json' }, body: ['GET', 'HEAD'].includes(req.method()) ? undefined : req.postData() });
    await route.fulfill({ status: r.status, headers: { 'content-type': r.headers.get('content-type') || 'text/plain' }, body: Buffer.from(await r.arrayBuffer()) });
  });
  let pag = await ctx.newPage();
  const errores = []; pag.on('pageerror', (e) => errores.push(e.message));
  const pie = async () => pag.evaluate(() => { const n = document.getElementById('pieAtras'), a = document.getElementById('aAtrasPie'); return { visible: getComputedStyle(n).display !== 'none', texto: a.textContent.trim(), href: a.getAttribute('href') }; });
  const fallos = [];
  const esperar = (cond, msg) => { if (!cond) { fallos.push(msg); console.log('   FALLA: ' + msg); } };

  // 1) la pagina abierta en el inicio: no hay boton al pie
  await pag.goto(B + '/guardian'); await pag.waitForSelector('#vInicio', { state: 'visible' });
  let p = await pie(); console.log('inicio:', JSON.stringify(p)); esperar(!p.visible, 'el inicio no debe tener Volver al pie');

  // 2) una categoria de Configuracion (abierta desde Tu proteccion): vuelve a Configuracion
  await pag.evaluate(() => { location.hash = 'config-referentes'; }); await pag.waitForSelector('#vCfgRef', { state: 'visible' });
  p = await pie(); console.log('referentes:', JSON.stringify(p)); esperar(p.visible && p.texto === '← Configuración' && p.href === '#configuracion', 'Referentes: Volver lleva a Configuracion');
  await pag.click('#aAtrasPie'); await pag.waitForSelector('#vConfig', { state: 'visible' });
  console.log('   al tocar quedo en:', await pag.evaluate(() => location.hash), '| titulo:', (await pag.textContent('#titulo')).trim());
  esperar(await pag.evaluate(() => location.hash) === '#configuracion', 'tocar Volver deja la vista Configuracion');
  p = await pie(); console.log('configuracion (desde Tu proteccion):', JSON.stringify(p)); esperar(p.visible && p.texto === '← Tu protección' && p.href === '#', 'Configuracion: Volver lleva a Tu proteccion');
  await pag.click('#aAtrasPie'); await pag.waitForSelector('#vInicio', { state: 'visible' });
  esperar(!(await pie()).visible, 'de vuelta en el inicio ya no hay boton');

  // 3) un modo (Cautela): vuelve a Tu proteccion
  await pag.evaluate(() => { location.hash = 'cautela'; }); await pag.waitForSelector('#vCautela', { state: 'visible' });
  p = await pie(); console.log('cautela:', JSON.stringify(p)); esperar(p.visible && p.texto === '← Tu protección' && p.href === '#', 'Modo Cautela: Volver lleva a Tu proteccion');

  // 4) abierta directo en Configuracion (como desde la consola): el pie vuelve a la Configuracion del panel; las categorias vuelven a "Tu proteccion"
  await pag.close(); pag = await ctx.newPage(); pag.on('pageerror', (e) => errores.push(e.message)); // pagina nueva: DESDEPANEL se decide al cargar
  await pag.goto(B + '/guardian#configuracion'); await pag.waitForSelector('#vConfig', { state: 'visible' });
  p = await pie(); console.log('desde la consola, Configuracion:', JSON.stringify(p)); esperar(p.visible && p.texto === '← Configuración' && p.href === '/#config', 'desde la consola: Volver lleva a la Configuracion del panel');
  await pag.evaluate(() => { location.hash = 'config-ajustes'; }); await pag.waitForSelector('#vCfgAjustes', { state: 'visible' });
  p = await pie(); console.log('desde la consola, Ajustes:', JSON.stringify(p)); esperar(p.visible && p.texto === '← Tu protección' && p.href === '#configuracion', 'desde la consola, una categoria vuelve a la pantalla de Configuracion');

  await pag.evaluate(() => { location.hash = 'config-referentes'; }); await pag.waitForSelector('#vCfgRef', { state: 'visible' });
  await pag.screenshot({ path: 'e2e_atras_referentes.png', fullPage: true });
  console.log('errores de pagina:', errores.length ? errores : 'ninguno');
  if (errores.length || fallos.length) { console.log('FALLOS:', fallos.length + errores.length); process.exit(1); }
  console.log('OK: el boton Volver del pie funciona en todas las pantallas');
  await nav.close();
})().catch((e) => { console.log('FALLO', e.message); process.exit(1); });
