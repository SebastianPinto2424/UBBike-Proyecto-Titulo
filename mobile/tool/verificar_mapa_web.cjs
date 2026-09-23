// Comprobación visual local sin dependencias npm. Requiere Node 22+ y Chrome.
// Compilar antes la vista previa en build/vista-previa-mapa (ver documentación).
// Solo opera la vista previa sin API, usando un perfil temporal de Chrome.
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const http = require('node:http');
const demora = ms => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  const raiz = path.resolve('build/vista-previa-mapa');
  if (!fs.existsSync(path.join(raiz, 'index.html'))) throw new Error('Primero compila la vista previa en build/vista-previa-mapa');
  const nginx = fs.readFileSync('nginx.conf', 'utf8');
  const csp = nginx.match(/add_header Content-Security-Policy "([^"]+)"/)[1]
    .replace('__CSP_IMG_SRC__', "'self' data: blob:").replace('__CSP_CONNECT_SRC__', "'self'");
  const tipos = { '.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json',
    '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf' };
  const servidor = http.createServer((req, res) => {
    try {
      const ruta = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
      const archivo = path.resolve(raiz, '.' + (ruta === '/' ? '/index.html' : ruta));
      const relativa = path.relative(raiz, archivo);
      if (relativa.startsWith('..') || path.isAbsolute(relativa)) { res.writeHead(403); res.end(); return; }
      const contenido = fs.readFileSync(archivo);
      res.writeHead(200, { 'Content-Type': tipos[path.extname(archivo)] ?? 'application/octet-stream',
        'Content-Security-Policy': csp, 'Referrer-Policy': 'strict-origin-when-cross-origin' });
      res.end(contenido);
    } catch { res.writeHead(404); res.end(); }
  });
  await new Promise(resolve => servidor.listen(0, '127.0.0.1', resolve));
  const urlBase = `http://127.0.0.1:${servidor.address().port}`;
  const perfil = fs.mkdtempSync(path.join(os.tmpdir(), 'ubbike-mapa-'));
  const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
    '--headless=new', '--no-first-run', '--no-default-browser-check',
    '--remote-debugging-port=0', `--user-data-dir=${perfil}`, 'about:blank'
  ], { windowsHide: true, stdio: 'ignore' });
  let socket;
  let id = 0;
  const pendientes = new Map();
  const eventos = [];
  const tiles = [];
  const ejecutar = (method, params = {}) => new Promise((resolve, reject) => {
    const numero = ++id;
    const timer = setTimeout(() => { pendientes.delete(numero); reject(new Error(`Tiempo agotado: ${method}`)); }, 20000);
    pendientes.set(numero, { resolve, reject, timer });
    socket.send(JSON.stringify({ id: numero, method, params }));
  });
  const evaluar = async expression => {
    const r = await ejecutar('Runtime.evaluate', { expression, returnByValue: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.text);
    return r.result.value;
  };
  const esperar = async expression => {
    for (let i = 0; i < 90; i++) {
      if (await evaluar(expression)) return;
      await demora(500);
    }
    throw new Error(`La vista previa no mostró: ${expression}`);
  };
  const pulsar = async texto => {
    const etiqueta = JSON.stringify(texto);
    const selector = `[...document.querySelectorAll('[role="button"]')].find(e => e.textContent.trim() === ${etiqueta} || e.getAttribute('aria-label') === ${etiqueta})`;
    await esperar(`Boolean(${selector})`);
    await evaluar(`(${selector}).click()`);
    await demora(1200);
  };
  try {
    let pagina;
    for (let i = 0; i < 60; i++) {
      try {
        const puerto = Number(fs.readFileSync(path.join(perfil, 'DevToolsActivePort'), 'utf8').split('\n')[0]);
        const paginas = await (await fetch(`http://127.0.0.1:${puerto}/json/list`)).json();
        pagina = paginas.find(p => p.type === 'page');
        if (pagina) break;
      } catch {}
      await demora(250);
    }
    if (!pagina) throw new Error('No se pudo iniciar Chrome aislado');
    socket = new WebSocket(pagina.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
    socket.addEventListener('message', e => {
      const mensaje = JSON.parse(e.data);
      if (mensaje.id && pendientes.has(mensaje.id)) {
        const tarea = pendientes.get(mensaje.id); pendientes.delete(mensaje.id); clearTimeout(tarea.timer);
        mensaje.error ? tarea.reject(new Error(mensaje.error.message)) : tarea.resolve(mensaje.result);
      }
      if (mensaje.method === 'Runtime.exceptionThrown') eventos.push(mensaje.params.exceptionDetails);
      if (mensaje.method === 'Network.responseReceived' && mensaje.params.response.url.startsWith('https://tile.openstreetmap.org/')) {
        tiles.push(mensaje.params.response.status);
      }
    });
    await ejecutar('Page.enable'); await ejecutar('Runtime.enable'); await ejecutar('Network.enable');
    // Navegador estrecho, no emulación de teclado de teléfono: las métricas
    // móviles sintéticas pueden disparar aserciones de insets del motor Flutter.
    await ejecutar('Emulation.setDeviceMetricsOverride', { width: 390, height: 844,
      screenWidth: 390, screenHeight: 844, deviceScaleFactor: 1, mobile: false });
    await ejecutar('Page.navigate', { url: urlBase });
    await esperar(`Boolean(document.querySelector('flt-semantics-placeholder') || document.querySelector('[role="button"]'))`);
    await evaluar(`document.querySelector('flt-semantics-placeholder')?.click()`);
    await pulsar('Editar ejemplo');
    const salida = path.resolve('build/auditoria-mapa'); fs.mkdirSync(salida, { recursive: true });
    await esperar(`!document.body.textContent.includes('Cargando mapa…')`);
    await demora(1000);
    const capturaFormulario = await ejecutar('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(path.join(salida, 'formulario.png'), Buffer.from(capturaFormulario.data, 'base64'));
    await pulsar('Cambiar ubicación');
    await esperar(`!document.body.textContent.includes('Cargando mapa…')`);
    await demora(1500);
    if (await evaluar(`document.body.textContent.includes('No se pudo cargar el mapa')`)) throw new Error('El proveedor no pudo mostrar el mapa');
    const capturaMapa = await ejecutar('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(path.join(salida, 'selector.png'), Buffer.from(capturaMapa.data, 'base64'));
    console.log(JSON.stringify({ salida, respuestasTiles: tiles, erroresJavaScript: eventos,
      controles: await evaluar(`[...document.querySelectorAll('[role="button"]')].map(e => e.textContent.trim() || e.getAttribute('aria-label'))`) }));
    if (eventos.length || !tiles.includes(200) || tiles.some(status => status >= 400)) process.exitCode = 1;
  } catch (error) {
    let pagina;
    try { pagina = await evaluar(`({ url: location.href, html: document.body.outerHTML.slice(0, 1500) })`); } catch {}
    console.error(JSON.stringify({ error: error.message, erroresJavaScript: eventos, pagina }));
    throw error;
  } finally {
    if (socket?.readyState === WebSocket.OPEN) {
      try { await ejecutar('Browser.close'); } catch {}
      socket.close();
    }
    for (const tarea of pendientes.values()) clearTimeout(tarea.timer);
    chrome.kill();
    servidor.closeAllConnections();
    await new Promise(resolve => servidor.close(resolve));
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
