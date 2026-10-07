// No MoonBit or Python required: serve the prebuilt bundle on loopback only.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve, relative, extname } from 'node:path';

const base = fileURLToPath(new URL('../web/', import.meta.url));
const port = Number(process.env.MOONHID_PORT ?? 8765);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('MOONHID_PORT must be 1..65535');
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml' };
const server = http.createServer(async (request, response) => {
  try {
    if (!['GET', 'HEAD'].includes(request.method)) { response.writeHead(405); return response.end(); }
    const pathname = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
    const path = resolve(base, '.' + (pathname === '/' ? '/index.html' : pathname));
    const rel = relative(base, path);
    if (rel.startsWith('..') || rel.includes(':') || !mime[extname(path)]) { response.writeHead(404); return response.end(); }
    const bytes = await readFile(path);
    response.writeHead(200, { 'Content-Type': mime[extname(path)], 'Cache-Control': 'no-store' });
    response.end(request.method === 'HEAD' ? undefined : bytes);
  } catch { response.writeHead(404); response.end(); }
});
server.on('error', error => { console.error(`Cannot start inspector: ${error.message}. Set MOONHID_PORT to another port.`); process.exitCode = 1; });
server.listen(port, '127.0.0.1', () => console.log(`MoonHID inspector: http://127.0.0.1:${port}/\nPress Ctrl+C to stop.`));
