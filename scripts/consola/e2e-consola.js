const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const B = 'http://localhost:' + (process.argv[2] || '8802');
const marca = process.argv[3] || 'cfg';
(async () => {
  const nav = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const nuevoCtx = async (vp, tema) => {
    const ctx = await nav.newContext({ viewport: vp, deviceScaleFactor: 1, locale: 'es-AR' });
    await ctx.route('**/*', (r) => (r.request().url().startsWith('http://localhost') ? r.continue() : r.abort()));
    if (tema) await ctx.addInitScript((t) => { try { if (!sessionStorage.getItem('yaPuesto')) { localStorage.setItem('ojo_ms_tema', t); sessionStorage.setItem('yaPuesto', '1'); } } catch (e) {} }, tema);
    return ctx;
  };
  const errores = [];
  const abrir = async (ctx, ruta = '/?demo=1') => {
    const pag = await ctx.newPage();
    pag.on('pageerror', (e) => errores.push('pageerror: ' + e.message));
    pag.on('dialog', (d) => d.accept());
    await pag.goto(B + ruta);
    await pag.waitForSelector('#dashboard:not(.hidden)', { timeout: 10000 });
    return pag;
  };
  const visible = (pag, sel) => pag.isVisible(sel);
  const ctx = await nuevoCtx({ width: 390, height: 844 }, 'claro');
  const pag = await abrir(ctx);

  console.log('1) pestanas:', await pag.$$eval('.bottom-tabs .bottom-tab', (b) => b.map((x) => x.textContent.trim())));
  console.log('   el boton de tema de la barra de arriba (solo en la pantalla de acceso) ya adentro se ve:', await visible(pag, '#theme-toggle'));
  await pag.click('[data-view="account"]');
  await pag.waitForSelector('#cfg-lista', { state: 'visible' });
  console.log('2) lista de Configuracion:', await pag.$$eval('#cfg-lista .cfg-item strong', (l) => l.map((x) => x.textContent)));
  console.log('   tarjetas sueltas de antes visibles en la lista (debe ser 0):', await pag.$$eval('#account .account-card', (l) => l.filter((x) => x.offsetParent !== null).length));
  await pag.screenshot({ path: `${marca}_cel_claro_lista.png`, fullPage: false });

  // cada categoria
  const categorias = {
    cuenta: ['#account-email-copy', '#account-security-state', '#totp-card', '#totp-setup-button', '#qa-card', '#qa-set-form', '#people'],
    avisos: ['#notification-prefs-card', '#notify-email', '#notify-sms', '#notify-silence', '#notify-prefs-save'],
    facial: ['#face-search-card', '#face-search-buy-5', '#face-search-buy-10'],
    familia: ['#cfg-invitar', '#cfg-mapa'],
    equipos: ['#cfg-agregar', '#cfg-equipos-ir', '#cfg-pulseras'],
    apariencia: ['#cfg-tema', '#cfg-acc', '#cfg-contraste', '#cfg-botones'],
  };
  for (const [id, sels] of Object.entries(categorias)) {
    await pag.click(`#cfg-lista [data-cfg="${id}"]`);
    await pag.waitForSelector(`#cfg-${id}`, { state: 'visible' });
    const vis = [];
    for (const s of sels) vis.push(s + ':' + (await visible(pag, s)));
    const otros = await pag.$$eval('.cfg-panel', (l, yo) => l.filter((x) => x.offsetParent !== null && x.id !== 'cfg-' + yo).length, id);
    console.log('3) ' + id + ': hash=' + (await pag.evaluate(() => location.hash)) + ' | titulo: ' + (await pag.textContent(`#cfg-${id} h2`)).trim() + ' | visibles: ' + vis.join(' ') + ' | otras pantallas abiertas (0):', otros, '| lista oculta:', !(await visible(pag, '#cfg-lista')));
    await pag.screenshot({ path: `${marca}_cel_claro_${id}.png`, fullPage: false });
    await pag.click(`#cfg-${id} .cfg-volver`);
    await pag.waitForSelector('#cfg-lista', { state: 'visible' });
  }
  console.log('   Tu proteccion es un enlace a:', await pag.getAttribute('#cfg-lista a.cfg-item', 'href'));

  // el boton Atras del telefono
  await pag.click('#cfg-lista [data-cfg="avisos"]');
  await pag.waitForSelector('#cfg-avisos', { state: 'visible' });
  await pag.goBack();
  await pag.waitForSelector('#cfg-lista', { state: 'visible' });
  console.log('4) con Atras vuelve a la lista:', await visible(pag, '#cfg-lista'), '| hash:', JSON.stringify(await pag.evaluate(() => location.hash)));

  // pestaña de nuevo: siempre la lista
  await pag.click('#cfg-lista [data-cfg="cuenta"]');
  await pag.click('[data-view="devices"]');
  await pag.click('[data-view="account"]');
  console.log('   al volver a tocar la pestana se ve la lista:', await visible(pag, '#cfg-lista'), '| hash:', JSON.stringify(await pag.evaluate(() => location.hash)));

  // tema
  await pag.click('#cfg-lista [data-cfg="apariencia"]');
  const antes = await pag.evaluate(() => document.documentElement.getAttribute('data-theme'));
  const textoAntes = await pag.textContent('#cfg-tema');
  await pag.click('#cfg-tema');
  await pag.waitForTimeout(150);
  const despues = await pag.evaluate(() => document.documentElement.getAttribute('data-theme'));
  console.log('5) tema: antes', antes, '| boton decia:', textoAntes, '| despues', despues, '| ahora dice:', await pag.textContent('#cfg-tema'), '|', await pag.textContent('#cfg-tema-estado'), '| guardado:', await pag.evaluate(() => localStorage.getItem('ojo_ms_tema')));
  await pag.screenshot({ path: `${marca}_cel_oscuro_apariencia.png`, fullPage: false });
  await pag.click('#cfg-tema');
  // accesibilidad
  await pag.click('#cfg-acc [data-t="g"]');
  console.log('6) texto grande: tamano de la pagina', await pag.evaluate(() => document.documentElement.style.fontSize), '| guardado', await pag.evaluate(() => localStorage.getItem('ogAcc')), '| marcado:', await pag.$eval('#cfg-acc [aria-pressed="true"]', (b) => b.textContent.trim()));
  await pag.click('#cfg-acc [data-t="x"]');
  await pag.check('#cfg-contraste'); await pag.check('#cfg-botones');
  console.log('   muy grande + contraste + botones:', await pag.evaluate(() => document.documentElement.style.fontSize + ' | clases: ' + document.documentElement.className + ' | ' + localStorage.getItem('ogAcc')));
  await pag.screenshot({ path: `${marca}_cel_claro_accesibilidad.png`, fullPage: false });
  await pag.reload();
  await pag.waitForSelector('#dashboard:not(.hidden)');
  console.log('   despues de recargar sigue aplicado:', await pag.evaluate(() => document.documentElement.style.fontSize + ' | ' + document.documentElement.className));
  await pag.click('[data-view="account"]'); await pag.click('#cfg-lista [data-cfg="apariencia"]');
  console.log('   y los controles lo muestran:', await pag.$eval('#cfg-acc [aria-pressed="true"]', (b) => b.textContent.trim()), await pag.isChecked('#cfg-contraste'), await pag.isChecked('#cfg-botones'));
  await pag.screenshot({ path: `${marca}_cel_claro_accesibilidad2.png`, fullPage: true });
  await pag.click('#cfg-acc [data-t=""]'); await pag.uncheck('#cfg-contraste'); await pag.uncheck('#cfg-botones');
  console.log('   se vuelve a lo de siempre:', JSON.stringify(await pag.evaluate(() => document.documentElement.style.fontSize + '|' + document.documentElement.className)));

  // atajos
  await pag.click('#cfg-volver, #cfg-apariencia .cfg-volver').catch(() => {});
  await pag.click('#cfg-lista [data-cfg="equipos"]');
  await pag.click('#cfg-agregar');
  await pag.waitForSelector('#add-device-panel', { state: 'visible' });
  console.log('7) Agregar un equipo -> Mis Equipos con el cuadro abierto:', await visible(pag, '#devices'), await visible(pag, '#add-device-panel'));
  await pag.click('[data-view="account"]'); await pag.click('#cfg-lista [data-cfg="equipos"]');
  await pag.click('#cfg-pulseras');
  await pag.waitForSelector('#video-modal', { state: 'visible' });
  console.log('   Ver presentacion de las pulseras abre el video:', await visible(pag, '#video-modal'));
  await pag.click('#video-modal-close');
  await pag.click('[data-view="account"]'); await pag.click('#cfg-lista [data-cfg="familia"]');
  await pag.click('#cfg-invitar');
  await pag.waitForSelector('#og-mapa [data-ogm="dialogo"]:not(.hidden)', { timeout: 8000 });
  console.log('   Invitar a la familia abre el mapa y el cuadro de invitacion:', await visible(pag, '#og-mapa'), await visible(pag, '#og-mapa [data-ogm="dialogo"]'));
  await pag.screenshot({ path: `${marca}_cel_claro_invitar.png`, fullPage: false });
  await pag.click('#og-mapa [data-accion="cerrar-dialogo"]').catch(() => {});
  await pag.click('[data-view="account"]');
  console.log('   desde el mapa, tocar Configuracion vuelve a la lista:', await visible(pag, '#cfg-lista'), '| mapa oculto:', !(await visible(pag, '#og-mapa')));

  // las otras pestañas siguen igual
  await pag.click('[data-view="devices"]');
  console.log('8) Mis Equipos: equipos', await pag.$$eval('#devices-root .device', (l) => l.length), '| pulseras', await pag.$$eval('#watches-root .device', (l) => l.length), '| articulos', await pag.$$eval('#items-root .list-card', (l) => l.length), '| agregar visible', await visible(pag, '#add-device-button'));
  await pag.click('[data-view="history"]');
  console.log('   Evidencias: tarjetas', await pag.$$eval('#evidence-root .evidence-card', (l) => l.length));
  await ctx.close();

  // escritorio, claro y noche
  for (const tema of ['claro', 'oscuro']) {
    const c2 = await nuevoCtx({ width: 1200, height: 900 }, tema);
    const p2 = await abrir(c2);
    await p2.click('[data-view="account"]');
    await p2.screenshot({ path: `${marca}_pc_${tema}_lista.png`, fullPage: false });
    await p2.click('#cfg-lista [data-cfg="cuenta"]');
    await p2.screenshot({ path: `${marca}_pc_${tema}_cuenta.png`, fullPage: true });
    await c2.close();
  }
  // celular en modo noche
  const c3 = await nuevoCtx({ width: 390, height: 844 }, 'oscuro');
  const p3 = await abrir(c3);
  await p3.click('[data-view="account"]');
  await p3.screenshot({ path: `${marca}_cel_oscuro_lista.png`, fullPage: false });
  await p3.click('#cfg-lista [data-cfg="cuenta"]');
  await p3.screenshot({ path: `${marca}_cel_oscuro_cuenta.png`, fullPage: true });
  // pantalla de acceso: el boton de tema sigue ahi
  const c4 = await nuevoCtx({ width: 390, height: 844 }, 'claro');
  const p4 = await c4.newPage();
  await p4.route('**/api/**', (r) => r.fulfill({ status: 401, body: '{"authenticated":false}', contentType: 'application/json' }));
  await p4.goto(B + '/');
  await p4.waitForSelector('#access:not(.hidden)', { timeout: 10000 });
  console.log('9) en la pantalla de acceso el boton de tema se ve:', await p4.isVisible('#theme-toggle'), '| dice:', await p4.textContent('#theme-toggle'));
  await p4.click('#theme-toggle');
  console.log('   y cambia el tema:', await p4.evaluate(() => document.documentElement.getAttribute('data-theme')));
  console.log('errores de pagina:', errores.length ? errores : 'ninguno');
  await nav.close();
})().catch((e) => { console.log('FALLO E2E:', e.message); process.exit(1); });
