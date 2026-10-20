import assert from 'node:assert/strict';
import { lstat, readFile, readdir, writeFile } from 'node:fs/promises';
import { posix } from 'node:path';

const root = new URL('../', import.meta.url);
const source = 'src/README.mbt.md';
const check = process.argv.includes('--check');
const markdown = (await readFile(new URL(source, root), 'utf8')).replace(/\r\n/g, '\n');
const localLink = target => !/^(?:[a-z][a-z\d+.-]*:|#|\/\/)/i.test(target);
// GitHub resolves links relative to the displayed README, even for a symlink.
const generated = '<!-- Generated from src/README.mbt.md by node scripts/sync-readme.mjs. -->\n\n' +
  markdown.replace(/(\]\()([^\s)]+)(\))/g, (match, before, target, after) => {
    if (!localLink(target)) return match;
    const [, path, suffix = ''] = target.match(/^([^?#]*)(.*)$/);
    return before + posix.normalize(posix.join(posix.dirname(source), path)) + suffix + after;
  });
const destination = new URL('README.md', root);
assert.equal((await lstat(destination)).isSymbolicLink(), false, 'README.md must be a regular file.');
if (check) {
  const actual = (await readFile(destination, 'utf8')).replace(/\r\n/g, '\n');
  assert.equal(actual, generated, 'Run node scripts/sync-readme.mjs after editing src/README.mbt.md.');
} else {
  await writeFile(destination, generated);
}

const files = ['README.md', source, 'ROADMAP.md',
  ...(await readdir(new URL('docs/', root))).filter(name => name.endsWith('.md')).map(name => 'docs/' + name)];
let count = 0;
for (const file of files) {
  const text = await readFile(new URL(file, root), 'utf8');
  for (const [, target] of text.matchAll(/\]\(([^\s)]+)\)/g)) {
    if (!localLink(target)) continue;
    const path = decodeURIComponent(target.split(/[?#]/)[0]);
    const resolved = posix.normalize(posix.join(posix.dirname(file), path));
    assert.ok(!resolved.startsWith('../') && !posix.isAbsolute(resolved), `${file}: link escapes repository: ${target}`);
    await lstat(new URL(resolved, root)).catch(() => assert.fail(`${file}: missing link target ${target}`));
    count++;
  }
}
console.log(`README ${check ? 'sync verified' : 'generated'}; ${count} local documentation links resolve.`);
