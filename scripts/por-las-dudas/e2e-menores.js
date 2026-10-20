const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:8799';
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await nav.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'es-AR' });
  const pag = await ctx.newPage();
  const errores = [];
  pag.on('pageerror', (e) => errores.push('pageerror: ' + e.message));
  pag.on('dialog', (d) => d.accept());
  const sesion = (email) => fetch(B + '/__sesion', { method: 'POST', body: JSON.stringify({ email, method: 'passkey' }) });
  // --- el titular
  await sesion('lucas@correo.com');
  await pag.goto(B + '/por-las-dudas');
  await pag.waitForFunction(() => document.getElementById('hoy').textContent.length > 0 && document.getElementById('paraQuien').style.display === 'block');
  console.log('titular: selector visible, opciones:', await pag.$$eval('#persona option', (o) => o.map((x) => x.textContent)));
  console.log('titular: titulo:', await pag.textContent('#titulo'), '| banner visible:', await pag.isVisible('#enNombreDe'), '| solo lectura visible:', await pag.isVisible('#soloLectura'));
  await pag.selectOption('#persona', 'tomi@correo.com');
  await pag.waitForFunction(() => document.getElementById('titulo').textContent.includes('Tomi'));
  await pag.waitForFunction(() => document.getElementById('enNombreDe').style.display === 'block');
  console.log('administrando a Tomi: url:', pag.url().replace(B, ''), '| titulo:', await pag.textContent('#titulo'));
  console.log('banner:', await pag.textContent('#enNombreDe'));
  console.log('boton de casa:', await pag.textContent('#cCasa'));
  await pag.fill('#rNombre', 'Mamá de Tomi'); await pag.fill('#rCorreo', 'mama@correo.com'); await pag.click('#rAgregar');
  await pag.waitForFunction(() => document.getElementById('referentes').textContent.includes('Mamá de Tomi'));
  console.log('referentes de Tomi:', (await pag.textContent('#referentes')).replace(/\s+/g, ' ').slice(0, 90));
  await pag.click('button[data-h="8"]');
  await pag.waitForFunction(() => document.getElementById('pausa').textContent.includes('En pausa'));
  console.log('pausa de Tomi:', await pag.textContent('#pausa'));
  await pag.screenshot({ path: 'e2e_admin_menor.png', fullPage: true });
  // --- el titular, su propia pagina: sin los referentes de Tomi
  await pag.goto(B + '/por-las-dudas');
  await pag.waitForFunction(() => document.getElementById('hoy').textContent.length > 0 && document.getElementById('paraQuien').style.display === 'block');
  console.log('propia del titular: referentes:', (await pag.textContent('#referentes')).replace(/\s+/g, ' ').slice(0, 60), '| titulo:', await pag.textContent('#titulo'), '| pausa:', await pag.textContent('#pausa'));
  // --- el menor
  await sesion('tomi@correo.com');
  await pag.goto(B + '/por-las-dudas');
  await pag.waitForFunction(() => document.getElementById('soloLectura').style.display === 'block');
  const habilitados = await pag.$$eval('#contenido input, #contenido select, #contenido button', (e) => e.filter((x) => !x.disabled).length);
  console.log('menor: aviso de solo lectura:', (await pag.textContent('#soloLectura')).trim().slice(0, 80), '| controles habilitados:', habilitados, '| selector visible:', await pag.isVisible('#paraQuien'));
  console.log('menor: ve a su referente:', (await pag.textContent('#referentes')).replace(/\s+/g, ' ').slice(0, 70));
  await pag.click('#detCondiciones summary');
  console.log('menor: puede abrir Condiciones:', await pag.isVisible('#cDesde'), '| campo bloqueado:', await pag.isDisabled('#cDesde'));
  await pag.screenshot({ path: 'e2e_menor_solo_lectura.png', fullPage: true });
  // intento por la API directa
  const r = await fetch(B + '/api/remote/por-las-dudas', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ accion: 'pausa', horas: 8 }) });
  console.log('menor: pausa por la API ->', r.status, JSON.stringify(await r.json()));
  console.log('ERRORES DE PAGINA:', errores.length ? errores : 'ninguno');
  await sesion('lucas@correo.com');
  await nav.close();
})().catch((e) => { console.log('FALLO E2E:', e.message); process.exit(1); });
