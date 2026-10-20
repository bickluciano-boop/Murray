// Servidor de prueba de la consola: sirve los archivos con los nombres que usa la pagina. Uso: node servir.js <carpeta> <puerto>
const http = require('http'), fs = require('fs'), path = require('path');
const dir = process.argv[2] || 'orig', puerto = Number(process.argv[3] || 8801);
const mapa = {
  '/': ['panel-index.html', 'text/html; charset=utf-8'],
  '/styles-v7.css': ['panel-styles.css', 'text/css'],
  '/explanations.css': ['panel-explanations.css', 'text/css'],
  '/theme-gold-v2.css': ['panel-history.css', 'text/css'],
  '/emergency.css': ['emergency.css', 'text/css'],
  '/mobile-fixes.css': ['mobile-fixes.css', 'text/css'],
  '/theme-light-v1.css': ['theme-light.css', 'text/css'],
  '/mapa-v1.css': ['panel-mapa.css', 'text/css'],
  '/app-v9.js': ['panel-app.txt', 'text/javascript; charset=utf-8'],
  '/mapa-v1.js': ['panel-mapa.txt', 'text/javascript; charset=utf-8'],
};
http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  const m = mapa[u.pathname];
  if (m) { res.writeHead(200, { 'content-type': m[1], 'cache-control': 'no-store' }); res.end(fs.readFileSync(path.join(dir, m[0]))); return; }
  if (u.pathname.startsWith('/api/')) { res.writeHead(401, { 'content-type': 'application/json' }); res.end('{"error":"sin_sesion"}'); return; }
  res.writeHead(404); res.end('no');
}).listen(puerto, () => console.log('consola de prueba en ' + puerto));
