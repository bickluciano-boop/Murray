const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:8799';
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await nav.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'es-AR' });
  await ctx.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: B });
  const pag = await ctx.newPage();
  const vista = async (h) => { await pag.evaluate((x) => { location.hash = x; }, h); await pag.waitForSelector('#' + ({ '': 'vInicio', cautela: 'vCautela', guardian: 'vGuardian', configuracion: 'vConfig', 'config-referentes': 'vCfgRef', 'config-cautela': 'vCfgCaut', 'config-guardian': 'vCfgGuard', 'config-ajustes': 'vCfgAjustes', 'config-accesibilidad': 'vCfgAcc', 'config-registro': 'vCfgReg' })[h], { state: 'visible' }); };
  const errores = []; pag.on('pageerror', (e) => errores.push(e.message)); pag.on('dialog', (d) => d.accept());
  await pag.goto(B + '/por-las-dudas');
  await pag.waitForFunction(() => document.getElementById('hoy').textContent.includes('señales'));
  // 1) el mail sale bien
  await vista('config-referentes');
  await pag.fill('#rNombre', 'Mamá'); await pag.fill('#rCorreo', 'mama@correo.com'); await pag.click('#rAgregar');
  await pag.waitForFunction(() => document.getElementById('invitacion').textContent.includes('Mamá'));
  const t1 = (await pag.textContent('#invitacion')).replace(/\s+/g, ' ');
  const enlace1 = await pag.inputValue('#invitacion input');
  console.log('1) mail ok  ->', t1.slice(0, 110), '| aviso:', JSON.stringify(await pag.textContent('#aviso')));
  console.log('   enlace con forma /referente?t=id.secreto:', /\/referente\?t=[\w-]+\.[\w-]+$/.test(enlace1));
  const correos = await (await fetch(B + '/__correos')).json();
  const delMail = /href="([^"]*\/referente\?t=[^"]+)"/.exec(correos.find((c) => c.to === 'mama@correo.com').html)[1];
  console.log('   el enlace de la pagina es el mismo del mail:', delMail === enlace1);
  await pag.click('text=Copiar enlace');
  console.log('   copiar -> boton dice:', await pag.textContent('#invitacion button:nth-of-type(1)'), '| portapapeles ok:', (await pag.evaluate(() => navigator.clipboard.readText())) === enlace1);
  const [wa] = await Promise.all([ctx.waitForEvent('page'), pag.click('text=Mandar por WhatsApp')]);
  const waUrl = wa.url(); await wa.close().catch(() => {});
  console.log('   WhatsApp abre:', waUrl.slice(0, 40), '| lleva el enlace:', decodeURIComponent(waUrl).includes(enlace1));
  // 2) el mail falla
  await fetch(B + '/__correo-falla', { method: 'POST', body: '1' });
  await pag.fill('#rNombre', 'Papá'); await pag.fill('#rCorreo', 'papa@correo.com'); await pag.click('#rAgregar');
  await pag.waitForFunction(() => document.getElementById('invitacion').textContent.includes('No pudimos'));
  console.log('2) mail falla ->', (await pag.textContent('#invitacion')).replace(/\s+/g, ' ').slice(0, 90), '| aviso:', JSON.stringify(await pag.textContent('#aviso')));
  const enlace2 = await pag.inputValue('#invitacion input');
  console.log('   hay enlace igual:', /\/referente\?t=/.test(enlace2), '| distinto del de Mamá:', enlace2 !== enlace1);
  await pag.screenshot({ path: 'e2e_enlace_falla.png', fullPage: true });
  // 3) "Reenviar" con el mail ya andando vuelve a mostrar el enlace (nuevo)
  await fetch(B + '/__correo-falla', { method: 'POST', body: '0' });
  const botones = await pag.$$eval('#referentes button', (b) => b.map((x) => x.textContent));
  console.log('3) botones en la lista:', botones.join(' | '));
  await pag.locator('#referentes .fila', { hasText: 'Papá' }).locator('button', { hasText: 'Reenviar' }).click();
  await pag.waitForFunction(() => document.getElementById('invitacion').textContent.includes('Le mandamos el mail a Papá'));
  console.log('   reenviar ->', (await pag.textContent('#invitacion')).replace(/\s+/g, ' ').slice(0, 60), '| enlace nuevo:', (await pag.inputValue('#invitacion input')) !== enlace2);
  // 4) el enlace de la pagina sirve: el referente puede aceptar con el
  const ref = await ctx.newPage();
  await ref.goto(await pag.inputValue('#invitacion input'));
  await ref.waitForFunction(() => document.body.textContent.includes('referente'));
  console.log('4) el enlace abre la pagina del referente:', (await ref.textContent('h1')).slice(0, 70));
  console.log('errores de pagina:', errores.length ? errores : 'ninguno');
  await nav.close();
})().catch((e) => { console.log('FALLO', e.message); process.exit(1); });
