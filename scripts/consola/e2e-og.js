// El boton OG (entrada a Tu proteccion) en pantalla ancha: sin sesion no se ve; con sesion se ve dorado; abierto, el menu se ve entero (sin recortes de la franja de arriba).
// Uso: node e2e-og.js <puerto> (servir.js sirviendo la carpeta nuevo/).
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:' + (process.argv[2] || '8802');
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  let mal = 0;
  for (const [ancho, tema] of [[800, 'claro'], [1200, 'oscuro'], [1440, 'claro'], [1440, 'oscuro'], [1920, 'claro']]) {
    const ctx = await nav.newContext({ viewport: { width: ancho, height: 800 }, locale: 'es-AR' });
    await ctx.route('**/*', (r) => (r.request().url().startsWith('http://localhost') ? r.continue() : r.abort()));
    await ctx.addInitScript((t) => { try { localStorage.setItem('ojo_ms_tema', t); } catch (e) { /* sin almacenamiento */ } }, tema);
    const pag = await ctx.newPage();
    await pag.goto(B + '/');
    await pag.waitForSelector('#access:not(.hidden)');
    const sinSesion = await pag.$eval('.og-guardian', (e) => getComputedStyle(e).display);
    await pag.goto(B + '/?demo=1');
    await pag.waitForSelector('#dashboard:not(.hidden)');
    await pag.click('[data-view="account"]'); // el mapa (pestana de inicio) tapa la franja de arriba en pantallas angostas
    await pag.waitForTimeout(300);
    const boton = await pag.$eval('.og-guardian > summary', (e) => { const c = getComputedStyle(e); return { dorado: c.backgroundColor === 'rgb(217, 178, 76)', sinTriangulo: c.listStyleType === 'none', pastilla: c.borderRadius === '999px' }; });
    await pag.click('.og-guardian > summary');
    await pag.waitForTimeout(250);
    const menu = await pag.evaluate(() => {
      const m = document.querySelector('.og-menu'); const r = m.getBoundingClientRect();
      const abajo = document.elementFromPoint(r.x + r.width / 2, r.y + r.height - 8);
      return { visible: m.offsetParent !== null, ancho: Math.round(r.width), abajoEsMenu: !!(abajo && abajo.closest('.og-menu')) };
    });
    const bien = sinSesion === 'none' && boton.dorado && boton.sinTriangulo && boton.pastilla && menu.visible && menu.abajoEsMenu;
    if (!bien) mal++;
    console.log(bien ? 'OK  ' : 'MAL ', ancho, tema, '| sin sesion:', sinSesion, '| boton:', JSON.stringify(boton), '| menu:', JSON.stringify(menu));
    await ctx.close();
  }
  await nav.close();
  console.log(mal ? 'FALLO: ' + mal : 'todo bien');
  process.exit(mal ? 1 : 0);
})().catch((e) => { console.log('FALLO', e.message); process.exit(1); });
