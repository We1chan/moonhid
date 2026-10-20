import assert from 'node:assert/strict';
import { lstat, readFile, readdir, writeFile } from 'node:fs/promises';
import { posix } from 'node:path';

const root = new URL('../', import.meta.url);
const source = 'src/README.mbt.md';
const check = process.argv.includes('--check');
const metadata = await readFile(new URL('moon.mod', root), 'utf8');
assert.equal(metadata.match(/^readme\s*=\s*"([^"]+)"/m)?.[1], 'README.md',
  'moon.mod readme must reference the generated README.md.');
const repository = metadata.match(/^repository\s*=\s*"([^"]+)"/m)?.[1];
assert.ok(repository, 'moon.mod must declare the repository URL.');
const ownMain = repository.replace(/\/$/, '') + '/blob/main/';
const withoutFences = text => {
  let fence;
  return text.split(/\r?\n/).map(line => {
    if (fence) {
      if (new RegExp(`^ {0,3}${fence[0]}{${fence.length},}\\s*$`).test(line)) fence = undefined;
      return '';
    }
    const opening = line.match(/^ {0,3}(`{3,}|~{3,})/);
    if (opening) { fence = opening[1]; return ''; }
    return line;
  }).join('\n');
};
const markdown = (await readFile(new URL(source, root), 'utf8')).replace(/\r\n/g, '\n');
const localLink = target => !/^(?:[a-z][a-z\d+.-]*:|#|\/\/)/i.test(target);
for (const [, target] of withoutFences(markdown).matchAll(/\]\(([^\s)]+)\)/g)) {
  assert.ok(!localLink(target),
    `${source}: cross-file relative link ${target}; use an absolute GitHub URL so Mooncakes does not rewrite its base.`);
}
// GitHub resolves links relative to the displayed README, even for a symlink.
const generated = '<!-- Generated from src/README.mbt.md by node scripts/sync-readme.mjs. -->\n\n' +
  markdown.replace(/(\]\()([^\s)]+)(\))/g, (match, before, target, after) => {
    if (!localLink(target)) return match;
    const [, path, suffix = ''] = target.match(/^([^?#]*)(.*)$/);
    return before + posix.normalize(posix.join(posix.dirname(source), path)) + suffix + after;
  });
const destination = new URL('README.md', root);
assert.ok((await lstat(destination)).isFile(), 'README.md must be a regular file, not a symlink.');
if (check) {
  const actual = (await readFile(destination, 'utf8')).replace(/\r\n/g, '\n');
  assert.equal(actual, generated, 'Run node scripts/sync-readme.mjs after editing src/README.mbt.md.');
} else {
  await writeFile(destination, generated);
}

const files = ['README.md', source, 'ROADMAP.md',
  ...(await readdir(new URL('docs/', root))).filter(name => name.endsWith('.md')).map(name => 'docs/' + name)];
// GitHub heading IDs keep Unicode letters, numbers, hyphens and underscores.
// A used-ID set also handles collisions between repeated and numbered headings.
const headingIds = text => {
  const ids = new Set();
  const lines = withoutFences(text).split(/\r?\n/);
  for (let index = 0; index < lines.length; index++) {
    const atx = lines[index].match(/^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$/);
    const setext = index + 1 < lines.length && /^ {0,3}(?:=+|-+)\s*$/.test(lines[index + 1]);
    if (!atx && (!setext || !lines[index].trim())) continue;
    const heading = (atx ? atx[1] : lines[index].trim())
      .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
      .replace(/<[^>]*>/g, '')
      .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      .replace(/&#(x[\da-f]+|\d+);/gi, (_, value) => String.fromCodePoint(value[0].toLowerCase() === 'x' ? parseInt(value.slice(1), 16) : Number(value)));
    const base = heading.toLowerCase().replace(/[^\p{L}\p{N}\p{M}_\-\s]/gu, '').replace(/\s/g, '-');
    let id = base;
    for (let suffix = 1; ids.has(id); suffix++) id = `${base}-${suffix}`;
    ids.add(id);
    if (!atx) index++;
  }
  return ids;
};
let count = 0;
let anchors = 0;
const headings = new Map();
for (const file of files) {
  const text = await readFile(new URL(file, root), 'utf8');
  for (const [, target] of withoutFences(text).matchAll(/\]\(([^\s)]+)\)/g)) {
    const ownAbsolute = target.startsWith(ownMain);
    if (!ownAbsolute && /^(?:[a-z][a-z\d+.-]*:|\/\/)/i.test(target)) continue;
    const path = decodeURIComponent((ownAbsolute ? target.slice(ownMain.length) : target).split(/[?#]/)[0]);
    const resolved = ownAbsolute ? posix.normalize(path) : path ? posix.normalize(posix.join(posix.dirname(file), path)) : file;
    assert.ok(!resolved.startsWith('../') && !posix.isAbsolute(resolved), `${file}: link escapes repository: ${target}`);
    const info = await lstat(new URL(resolved, root)).catch(() => assert.fail(`${file}: missing link target ${target}`));
    assert.ok(info.isFile(), `${file}: link target must be a regular file: ${target}`);
    const fragment = target.split('#')[1];
    if (fragment && /\.md$/i.test(resolved)) {
      if (!headings.has(resolved)) headings.set(resolved, headingIds(await readFile(new URL(resolved, root), 'utf8')));
      assert.ok(headings.get(resolved).has(decodeURIComponent(fragment)), `${file}: missing Markdown heading ${target}`);
      anchors++;
    }
    count++;
  }
}
console.log(`README ${check ? 'sync verified' : 'generated'}; ${count} local documentation links and ${anchors} heading anchors resolve.`);
