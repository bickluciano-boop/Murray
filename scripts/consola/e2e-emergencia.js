// Modo de emergencia y recarga en una pantalla de Configuracion (con el servidor de sesion simulado).
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:' + (process.argv[2] || '8802');
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const errores = [];
  for (const emergencia of [false, true]) {
    const ctx = await nav.newContext({ viewport: { width: 390, height: 844 }, locale: 'es-AR' });
    await ctx.route('**/*', (r) => {
      const u = r.request().url();
      if (!u.startsWith('http://localhost')) return r.abort();
      if (u.includes('/api/remote/session')) return r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ authenticated: true, email: 'titular@ejemplo.com', devices: [], people: [], items: [], evidence: [], watches: [], emergencyMode: emergencia }) });
      return r.continue();
    });
    const pag = await ctx.newPage();
    pag.on('pageerror', (e) => errores.push((emergencia ? 'emergencia: ' : 'normal: ') + e.message));
    await pag.goto(B + '/#config-avisos');
    await pag.waitForSelector('#dashboard:not(.hidden)', { timeout: 10000 });
    await pag.waitForTimeout(1200);
    const estado = await pag.evaluate(() => ({
      pestanaConfig: !!document.querySelector('[data-view="account"]:not(.hidden)') && getComputedStyle(document.querySelector('.bottom-tab[data-view="account"]')).display !== 'none',
      panelAvisos: !document.querySelector('#cfg-avisos').classList.contains('hidden') && document.querySelector('#cfg-avisos').offsetParent !== null,
      lista: document.querySelector('#cfg-lista').offsetParent !== null,
      cuentaVisible: document.querySelector('#account').offsetParent !== null,
      banner: !document.querySelector('#emergency-banner').classList.contains('hidden'),
      equiposVisible: document.querySelector('#devices').offsetParent !== null,
    }));
    console.log(emergencia ? 'EMERGENCIA' : 'NORMAL    ', JSON.stringify(estado));
    await ctx.close();
  }
  await nav.close();
  console.log('errores de pagina:', errores.length ? errores : 'ninguno');
})().catch((e) => { console.log('FALLO', e.message); process.exit(1); });
