// Consola (puerto 8801) -> Configuracion > Tu proteccion (la pagina de Tu proteccion la contesta el servidor de prueba del Modo Guardian, puerto 8799) -> "← Configuracion" -> vuelve a la consola, a la lista
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const C = 'http://localhost:8801', F = 'http://localhost:8799';
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await nav.newContext({ viewport: { width: 390, height: 844 }, locale: 'es-AR' });
  await ctx.route('**/*', async (route) => {
    const req = route.request(), u = new URL(req.url());
    if (u.origin !== C) return route.abort();
    if (u.pathname.startsWith('/guardian') || u.pathname.startsWith('/api/remote/por-las-dudas') || u.pathname.startsWith('/api/guardian')) {
      const r = await fetch(F + u.pathname + u.search, { method: req.method(), headers: { 'content-type': 'application/json' }, body: ['GET', 'HEAD'].includes(req.method()) ? undefined : req.postData() });
      return route.fulfill({ status: r.status, headers: { 'content-type': r.headers.get('content-type') || 'text/plain' }, body: Buffer.from(await r.arrayBuffer()) });
    }
    return route.continue();
  });
  const pag = await ctx.newPage();
  const errores = [];
  pag.on('pageerror', (e) => errores.push('pageerror: ' + e.message));
  await pag.goto(C + '/?demo=1');
  await pag.waitForSelector('#dashboard:not(.hidden)');
  await pag.click('[data-view="account"]');
  await pag.waitForSelector('#cfg-lista', { state: 'visible' });
  console.log('1) consola: Configuracion, lista:', await pag.$$eval('#cfg-lista .cfg-item strong', (l) => l.map((x) => x.textContent)));
  await pag.click('#cfg-lista .cfg-item[href="/guardian#configuracion"]');
  await pag.waitForURL('**/guardian#configuracion');
  await pag.waitForSelector('#vConfig', { state: 'visible' });
  const arriba = { titulo: (await pag.textContent('#titulo')).trim(), izq: (await pag.textContent('#aInicio')).trim(), href: await pag.getAttribute('#aInicio', 'href'), hub: await pag.isVisible('#aHub') };
  console.log('2) abierta desde la consola: se llama', JSON.stringify(arriba.titulo), '| arriba dice', JSON.stringify(arriba.izq), '->', arriba.href, '| enlace a Tu proteccion visible:', arriba.hub);
  if (arriba.titulo !== 'Tu protección' || arriba.izq !== '← Configuración' || arriba.href !== '/#config' || arriba.hub) throw new Error('desde la consola, Tu proteccion tiene que volver a la Configuracion');
  await pag.screenshot({ path: 'puente_proteccion.png', fullPage: false });
  await pag.click('#aInicio');
  await pag.waitForURL(C + '/#config');
  await pag.waitForSelector('#cfg-lista', { state: 'attached' });
  console.log('3) tocar "← Configuracion": llega a', pag.url(), '| es la consola:', await pag.evaluate(() => !!document.getElementById('cfg-lista') && !!document.getElementById('dashboard')));
  // con sesion de verdad (aca no hay), apenas se dibuja el panel el #config muestra la lista; en demostracion se prueba el mismo camino con ?demo=1
  await pag.goto(C + '/?demo=1#config');
  await pag.waitForSelector('#cfg-lista', { state: 'visible', timeout: 10000 });
  console.log('   y con el panel dibujado, #config abre la lista:', await pag.isVisible('#cfg-lista'));
  console.log('errores:', errores.length ? errores : 'ninguno');
  await nav.close();
})().catch((e) => { console.log('FALLO E2E:', e.message); process.exit(1); });
