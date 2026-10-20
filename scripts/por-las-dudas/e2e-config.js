// Recorrido en navegador de Configuracion: interruptor del Modo Cautela, categorias, guardar y volver a los valores recomendados,
// tiempos y avisos del Modo Guardian, y Accesibilidad (se guarda en el telefono y vale en el camino). Necesita servidor.ts andando en el puerto 8799.
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:8799';
const MAPA = { '': 'vInicio', cautela: 'vCautela', guardian: 'vGuardian', configuracion: 'vConfig', 'config-referentes': 'vCfgRef', 'config-cautela': 'vCfgCaut', 'config-guardian': 'vCfgGuard', 'config-ajustes': 'vCfgAjustes', 'config-accesibilidad': 'vCfgAcc', 'config-registro': 'vCfgReg' };
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await nav.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'es-AR' });
  await ctx.route('https://panel.test/**', async (route) => {
    const req = route.request();
    const r = await fetch(req.url().replace('https://panel.test', B), { method: req.method(), headers: { 'content-type': 'application/json' }, body: ['GET', 'HEAD'].includes(req.method()) ? undefined : req.postData() });
    await route.fulfill({ status: r.status, headers: { 'content-type': r.headers.get('content-type') || 'text/plain' }, body: Buffer.from(await r.arrayBuffer()) });
  });
  // pitidos, vibraciones y pedidos de pantalla encendida de mentira, para contarlos
  await ctx.addInitScript(() => {
    window.__pitidos = []; window.__vibra = 0; window.__luz = 0;
    window.AudioContext = class { constructor() { this.state = 'running'; this.currentTime = 0; this.destination = {}; } resume() { return Promise.resolve(); } createGain() { return { gain: { value: 0 }, connect() {} }; } createOscillator() { const o = { frequency: { value: 0 }, type: '', connect() {}, start() { window.__pitidos.push(o.frequency.value); }, stop() {} }; return o; } };
    navigator.vibrate = () => { window.__vibra++; return true; };
    Object.defineProperty(navigator, 'wakeLock', { value: { request: () => { window.__luz++; return Promise.resolve({ addEventListener() {}, release() {} }); } }, configurable: true });
  });
  const pag = await ctx.newPage();
  const errores = [];
  pag.on('pageerror', (e) => errores.push('pageerror: ' + e.message));
  const dialogos = [];
  pag.on('dialog', (d) => { dialogos.push(d.message()); d.accept(); });
  const vista = async (h) => { await pag.evaluate((x) => { location.hash = x; }, h); await pag.waitForSelector('#' + MAPA[h], { state: 'visible' }); };
  const visibles = () => pag.evaluate((ids) => ids.filter((i) => getComputedStyle(document.getElementById(i)).display !== 'none'), Object.values(MAPA));
  const aviso = async () => (await pag.textContent('#aviso')).trim();
  const esperarAviso = (t) => pag.waitForFunction((x) => document.getElementById('aviso').textContent.includes(x), t);

  await pag.goto(B + '/guardian');
  await pag.waitForFunction(() => document.getElementById('gdSinRef').style.display === 'block');

  // ---- interruptor del Modo Cautela, desde el inicio
  console.log('1) inicio: interruptor:', await pag.getAttribute('#swCautelaInicio', 'aria-checked'), '| estado:', (await pag.textContent('#tCautelaEstado')).trim());
  await pag.click('#swCautelaInicio');
  await esperarAviso('apagado');
  console.log('   tocar el interruptor pregunta y apaga ->', dialogos[dialogos.length - 1].slice(0, 40), '| interruptor:', await pag.getAttribute('#swCautelaInicio', 'aria-checked'), '| estado:', (await pag.textContent('#tCautelaEstado')).trim(), '| aviso:', await aviso());
  await pag.click('#swCautelaInicio');
  await esperarAviso('encendido');
  console.log('   y al prenderlo no pregunta ->', 'dialogos:', dialogos.length, '| interruptor:', await pag.getAttribute('#swCautelaInicio', 'aria-checked'), '| estado:', (await pag.textContent('#tCautelaEstado')).trim());
  await pag.click('#tCautela .modo-txt');
  await pag.waitForSelector('#vCautela', { state: 'visible' });
  await pag.click('#cEncender');
  await esperarAviso('apagado');
  console.log('   en la pantalla del Modo Cautela, el otro interruptor queda igual ->', await pag.getAttribute('#cEncender', 'aria-checked'), '/', await pag.getAttribute('#swCautelaInicio', 'aria-checked'), '| estado:', (await pag.textContent('#estadoModo')).trim());
  await pag.click('#cEncender');
  await esperarAviso('encendido');

  // ---- categorias de Configuracion y volver
  await vista('configuracion');
  const filas = await pag.$$eval('#vConfig .item', (l) => l.map((x) => x.querySelector('b').textContent + ' -> ' + x.getAttribute('href')));
  console.log('2) Configuracion:', filas.join(' | '));
  for (const [href, vistaId, titulo] of [['config-referentes', 'vCfgRef', 'Referentes'], ['config-cautela', 'vCfgCaut', 'Modo Cautela'], ['config-guardian', 'vCfgGuard', 'Modo Guardián'], ['config-ajustes', 'vCfgAjustes', 'Ajustes'], ['config-accesibilidad', 'vCfgAcc', 'Accesibilidad'], ['config-registro', 'vCfgReg', 'Registro']]) {
    await pag.click('#vConfig .item[href="#' + href + '"]');
    await pag.waitForSelector('#' + vistaId, { state: 'visible' });
    const v = await visibles();
    const t = (await pag.textContent('#titulo')).trim(), volver = (await pag.textContent('#aHub')).trim();
    await pag.click('#aHub');
    await pag.waitForSelector('#vConfig', { state: 'visible' });
    console.log('   ' + href + ': abre solo', JSON.stringify(v), '| titulo:', t, t === titulo ? '(ok)' : '(ESPERADO ' + titulo + ')', '| volver:', volver);
  }

  // ---- condiciones del Modo Cautela
  await vista('config-cautela');
  await pag.fill('#cKm', '8'); await pag.fill('#cBat', '30'); await pag.fill('#cSilNoche', '120');
  await pag.click('#cGuardar');
  await esperarAviso('Condiciones guardadas');
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('cKm').value !== '');
  console.log('3) condiciones guardadas y vueltas a leer: km', await pag.inputValue('#cKm'), '| bateria', await pag.inputValue('#cBat'), '| sin senal de noche', await pag.inputValue('#cSilNoche'), '| recomendado:', (await pag.textContent('#cRecomendado')).trim().slice(0, 90));
  await pag.click('#cReset');
  await esperarAviso('restablecidas');
  console.log('   volver a los valores recomendados: km', await pag.inputValue('#cKm'), '| bateria', await pag.inputValue('#cBat'), '| sin senal de noche', await pag.inputValue('#cSilNoche'), '| pregunto:', dialogos[dialogos.length - 1].slice(0, 50));

  // ---- Ajustes: como te llaman
  await vista('config-ajustes');
  await pag.fill('#cNombre', 'Lucho');
  await pag.click('#cNombreGuardar');
  await esperarAviso('Nombre guardado');
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('cNombre').value !== '');
  console.log('4) Ajustes: el nombre quedo guardado:', await pag.inputValue('#cNombre'), '| condiciones intactas: km', await pag.inputValue('#cKm'));

  // ---- referente para poder empezar un camino
  await vista('config-referentes');
  await pag.fill('#rNombre', 'Mamá'); await pag.fill('#rCorreo', 'mama@correo.com'); await pag.click('#rAgregar');
  await pag.waitForFunction(() => document.getElementById('referentes').textContent.includes('Mamá'));
  const correos = await (await fetch(B + '/__correos')).json();
  const link = /href="([^"]*\/referente\?t=[^"]+)"/.exec(correos.find((c) => c.to === 'mama@correo.com').html)[1];
  const ref = await ctx.newPage(); await ref.goto(link.replace(/^https?:\/\/[^/]+/, B)); await ref.click('text=Aceptar ser referente'); await ref.close();
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('avisoRef').style.display === 'none');
  await vista('');
  console.log('5) con un referente aceptado: aviso de falta de referentes visible:', await pag.isVisible('#avisoRef'), '| estado del Guardian:', (await pag.textContent('#tGuardianEstado')).trim());

  // ---- tiempos y avisos del Modo Guardian
  await vista('config-guardian');
  await pag.fill('#gMargen', '5'); await pag.fill('#gAviso', '4'); await pag.fill('#gExt', '2'); await pag.fill('#gEntre', '15'); await pag.fill('#gMaxAv', '2');
  await pag.click('#gGuardar');
  await esperarAviso('Cambios guardados');
  await pag.reload();
  await pag.waitForFunction(() => document.getElementById('gMargen').value === '5');
  console.log('6) Guardian: guardado y vuelto a leer:', await pag.$$eval('#gMargen,#gAviso,#gExt,#gEntre,#gMaxAv', (l) => l.map((x) => x.value)));
  await vista('guardian');
  await pag.waitForFunction(() => document.getElementById('gdForm').style.display === 'block');
  console.log('   el pie de "Empezar camino" ya habla de la configuracion:', (await pag.textContent('#gdPie')).trim());
  await pag.selectOption('#gdLugar', 'pl1');
  await pag.waitForFunction(() => document.getElementById('gdMin').value !== '');
  await pag.click('#gdEmpezar');
  await pag.waitForURL('**/camino?t=*');
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  console.log('   camino con esa configuracion:', (await pag.textContent('#detalle')).trim(), '| botones de mas tiempo visibles:', await pag.isVisible('#extBloque'));
  await pag.screenshot({ path: 'e2e_config_camino.png', fullPage: true });
  await pag.click('#atras');
  await pag.waitForURL('**/guardian');
  await vista('config-guardian');
  await pag.waitForFunction(() => document.getElementById('gdCfgBloqueo').style.display === 'block');
  console.log('   con un camino en marcha, los tiempos y avisos se ven bloqueados: aviso visible:', await pag.isVisible('#gdCfgBloqueo'), '| campo bloqueado:', await pag.isDisabled('#gMargen'), '| boton Guardar bloqueado:', await pag.isDisabled('#gGuardar'));
  await pag.screenshot({ path: 'e2e_config_guardian_bloqueado.png', fullPage: true });
  // terminar el camino y volver a los valores recomendados
  await vista('guardian');
  await pag.click('#gdAbrir');
  await pag.waitForURL('**/camino?t=*');
  await pag.click('#bCancelar');
  await pag.waitForFunction(() => document.getElementById('estadoTxt').textContent.includes('Camino cancelado'));
  await pag.goto(B + '/guardian#config-guardian');
  await pag.waitForSelector('#vCfgGuard', { state: 'visible' });
  await pag.waitForFunction(() => document.getElementById('gdCfgBloqueo').style.display === 'none' && !document.getElementById('gMargen').disabled);
  await pag.click('#gReset');
  await esperarAviso('recomendados');
  console.log('   terminado el camino se puede cambiar; "Volver a los valores recomendados":', await pag.$$eval('#gMargen,#gAviso,#gExt,#gEntre,#gMaxAv', (l) => l.map((x) => x.value)));
  await vista('guardian');
  await pag.waitForFunction(() => document.getElementById('gdPie').textContent.includes('2 minutos de margen'));
  console.log('   y el pie vuelve a hablar de los valores recomendados:', (await pag.textContent('#gdPie')).trim());

  // ---- Accesibilidad
  await vista('config-accesibilidad');
  const acc = async () => pag.evaluate(() => ({ texto: document.documentElement.style.fontSize, contraste: document.documentElement.classList.contains('ac'), grandes: document.documentElement.classList.contains('ab'), ls: localStorage.getItem('ogAcc') }));
  console.log('7) Accesibilidad al empezar:', JSON.stringify(await acc()), '| interruptores:', await pag.$$eval('#aaContraste,#aaBotones,#aaSonido,#aaVibra,#aaLuz', (l) => l.map((x) => x.id + '=' + x.getAttribute('aria-checked'))).then((x) => x.join(' ')));
  await pag.click('button[data-t="x"]');
  await pag.click('#aaContraste');
  await pag.click('#aaBotones');
  console.log('   texto muy grande + alto contraste + botones grandes:', JSON.stringify(await acc()));
  await pag.screenshot({ path: 'e2e_config_accesibilidad.png', fullPage: true });
  await pag.reload();
  await pag.waitForSelector('#vCfgAcc', { state: 'visible' });
  console.log('   despues de recargar siguen puestos:', JSON.stringify(await acc()), '| boton de tamano elegido:', await pag.$$eval('button[data-t]', (l) => l.filter((x) => x.className === '').map((x) => x.textContent)));
  await pag.goto(B + '/camino?t=invalido');
  await pag.waitForSelector('#vacio', { state: 'visible' });
  console.log('   en otra pantalla de Ojo Guard (el camino) tambien aplica:', JSON.stringify(await acc()));
  await pag.goto(B + '/guardian#config-accesibilidad');
  await pag.waitForSelector('#vCfgAcc', { state: 'visible' });
  await pag.click('button[data-t=""]');
  await pag.click('#aaContraste');
  await pag.click('#aaBotones');
  console.log('   volver a normal:', JSON.stringify(await acc()));

  // ---- sonido, vibracion y pantalla encendida en el camino
  await vista('guardian');
  await pag.selectOption('#gdLugar', 'pl1');
  await pag.waitForFunction(() => document.getElementById('gdMin').value !== '');
  await pag.click('#gdEmpezar');
  await pag.waitForURL('**/camino?t=*');
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  // el servidor de prueba arma enlaces de https://panel.test: se abre el mismo camino en el servidor local para que comparta lo guardado en Accesibilidad
  const urlCamino = B + '/camino?t=' + new URL(pag.url()).searchParams.get('t');
  await fetch(B + '/__gd-minutos', { method: 'POST', body: '0.12' });
  await pag.goto(urlCamino);
  await pag.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
  await pag.click('#bSonido'); await pag.click('#bSonido'); // un toque habilita el audio (regla del navegador)
  await pag.waitForTimeout(9000);
  const conTodo = await pag.evaluate(() => ({ pitidos: window.__pitidos.length, vibraciones: window.__vibra, pantalla: window.__luz }));
  console.log('8) camino con todo activado: pitidos', conTodo.pitidos, '| vibraciones', conTodo.vibraciones, '| pedidos de pantalla encendida', conTodo.pantalla);
  await vista2(urlCamino);
  async function vista2(u) {
    // la misma persona, en otra pestana, con sonido, vibracion y pantalla apagados desde Accesibilidad
    const p2 = await ctx.newPage();
    await p2.goto(B + '/guardian#config-accesibilidad');
    await p2.waitForSelector('#vCfgAcc', { state: 'visible' });
    for (const id of ['aaSonido', 'aaVibra', 'aaLuz']) await p2.click('#' + id);
    console.log('   apagados en Accesibilidad:', (await p2.$$eval('#aaSonido,#aaVibra,#aaLuz', (l) => l.map((x) => x.id + '=' + x.getAttribute('aria-checked')))).join(' '), '| localStorage:', await p2.evaluate(() => ['gdSonido', 'gdVibra', 'gdLuz'].map((k) => k + '=' + localStorage.getItem(k)).join(' ')));
    await fetch(B + '/__gd-minutos', { method: 'POST', body: '0.12' });
    await p2.goto(u);
    await p2.waitForFunction(() => document.getElementById('viaje').style.display === 'block');
    await p2.mouse.click(10, 10);
    await p2.waitForTimeout(9000);
    const sinTodo = await p2.evaluate(() => ({ pitidos: window.__pitidos.length, vibraciones: window.__vibra, pantalla: window.__luz, boton: document.getElementById('bSonido').textContent }));
    console.log('   camino con todo apagado: pitidos', sinTodo.pitidos, '| vibraciones', sinTodo.vibraciones, '| pedidos de pantalla encendida', sinTodo.pantalla, '| boton de sonido del camino:', sinTodo.boton);
    await p2.close();
  }
  const ancho = await pag.evaluate(() => document.documentElement.scrollWidth);
  console.log('ancho:', ancho, '| errores:', errores.length ? errores : 'ninguno');
  await nav.close();
})().catch((e) => { console.log('FALLO E2E:', e.message); process.exit(1); });
