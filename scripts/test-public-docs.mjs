import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { markdownHrefs, extraUrls, parseArguments, requestLink } from './check-public-docs.mjs';

assert.deepEqual(parseArguments(['0.6.0', '--urls', '含空格 links.txt'], '0.5.2'), { version: '0.6.0', urlsFile: '含空格 links.txt' });
assert.deepEqual(parseArguments(['--urls', 'links.txt'], '0.6.0'), { version: '0.6.0', urlsFile: 'links.txt' });
for (const args of [['--urls'], ['--bad'], ['0.6.0', '0.5.2'], ['--urls', 'a', '--urls', 'b']]) assert.throws(() => parseArguments(args, '0.6.0'));
const markdown = [
  '[相对路径](docs/missing.md)', '[标题](https://example.com/title "a title")',
  '<a href="docs/html-link.md">HTML</a>',
  '[带括号](https://example.com/a(b))', '[引用][doc]', '[doc]: https://example.com/reference',
  '<https://example.com/auto>', 'https://example.com/plain.',
  '`https://example.com/code`', '```sh\nhttps://example.com/fenced\n```',
].join('\n');
assert.deepEqual(new Set(markdownHrefs(markdown)), new Set(['docs/missing.md', 'docs/html-link.md', 'https://example.com/title', 'https://example.com/a(b)', 'https://example.com/reference', 'https://example.com/auto', 'https://example.com/plain']));
assert.deepEqual(extraUrls('# comment\nhttps://example.com/a\n\nhttps://example.com/b#section\n'), ['https://example.com/a', 'https://example.com/b#section']);
assert.deepEqual(extraUrls('["https://example.com/a"]'), ['https://example.com/a']);
for (const text of ['relative.md', '["javascript:alert(1)"]', '[1]', '{}']) assert.throws(() => extraUrls(text));
let transient = 0;
const server = createServer((request, response) => {
  if (request.url === '/redirect') { response.writeHead(302, { location: '/ok' }); response.end(); }
  else if (request.url === '/missing') { response.writeHead(404); response.end('not found'); }
  else if (request.url === '/transient' && transient++ === 0) { response.writeHead(503); response.end('retry'); }
  else response.end('verified');
});
await new Promise(done => server.listen(0, '127.0.0.1', done));
try {
  const base = `http://127.0.0.1:${server.address().port}`;
  assert.equal((await requestLink(base + '/missing')).status, 404);
  const redirect = await requestLink(base + '/redirect', { readBody: true });
  assert.deepEqual([redirect.status, redirect.url, redirect.body], [200, base + '/ok', 'verified']);
  assert.equal((await requestLink(base + '/transient')).status, 200);
  assert.equal(transient, 2);
} finally { await new Promise(done => server.close(done)); }
console.log('Public docs checker: Release Markdown/reference/autolinks, URL lists, argv, HTTP 404, redirects and retry passed.');
