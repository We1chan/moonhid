import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { access, readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const read = async path => (await readFile(new URL(path, root), 'utf8')).replace(/\r\n/g, '\n');
const tinyusb = {
  version: '0.21.0',
  commit: 'dae3f9a366bfcddbf9dcf1b48d7500286a849539',
  copyrights: ['Copyright (c) 2019 Ha Thach (tinyusb.org)', 'Copyright (c) 2012-2026, hathach (tinyusb.org)'],
  // SHA-256 of LICENSE at the commit above; the notice must quote it verbatim.
  licenseSha256: 'f878d62e47e693ea64160218edb1b9b4755f4839a3179e5bef4a6b0359399431',
};
// Files whose bytes or item sequences come from the TinyUSB macros (THIRD_PARTY_NOTICES.md section 1).
const derived = [
  'src/examples/templates.mbt', 'src/examples/templates_test.mbt',
  'examples/codec/consumer.hex', 'examples/codec/vendor.hex',
  'examples/declarations/consumer.json', 'examples/declarations/vendor.json',
  'src/cmd/moonhid/main.mbt', 'src/access_test.mbt',
];
const commented = ['src/examples/templates.mbt', 'src/examples/templates_test.mbt'];

const notice = await read('NOTICE');
const thirdParty = await read('THIRD_PARTY_NOTICES.md');
for (const text of [tinyusb.version, tinyusb.commit, ...tinyusb.copyrights, 'MIT License', 'THIRD_PARTY_NOTICES.md']) {
  assert.ok(notice.includes(text), `NOTICE must mention ${text}`);
}
for (const text of [tinyusb.version, tinyusb.commit, ...tinyusb.copyrights]) {
  assert.ok(thirdParty.includes(text), `THIRD_PARTY_NOTICES.md must mention ${text}`);
}
const fences = [...thirdParty.matchAll(/^```text\n([\s\S]*?)^```$/gm)].map(match => match[1]);
const license = fences.find(text => text.startsWith('The MIT License (MIT)\n'));
assert.ok(license, 'THIRD_PARTY_NOTICES.md must quote the TinyUSB MIT License in a text block.');
assert.equal(createHash('sha256').update(license).digest('hex'), tinyusb.licenseSha256,
  'The quoted TinyUSB LICENSE must match the upstream file byte for byte.');

for (const path of derived) {
  await access(new URL(path, root)).catch(() => assert.fail(`Listed TinyUSB-derived file is missing: ${path}`));
  assert.ok(thirdParty.includes('`' + path + '`'), `THIRD_PARTY_NOTICES.md must list ${path}`);
}
for (const path of commented) {
  const text = await read(path);
  for (const expected of [`TinyUSB ${tinyusb.version}`, tinyusb.copyrights[0], 'MIT License', 'THIRD_PARTY_NOTICES.md']) {
    assert.ok(text.includes(expected), `${path} must carry the TinyUSB attribution: ${expected}`);
  }
}
// The expansion recorded in the notice must still be the bytes the repository ships.
const expansion = fences.find(text => text.startsWith('05 0c '))?.trim().split('\n');
assert.deepEqual(expansion, [(await read('examples/codec/consumer.hex')).trim(), (await read('examples/codec/vendor.hex')).trim()],
  'The recorded TinyUSB expansion must equal examples/codec/consumer.hex and vendor.hex.');

// A new source or data file that names TinyUSB has to be registered in the notice too.
const tracked = execFileSync('git', ['ls-files', '-z', '--', 'src', 'examples', 'web', 'scripts'], { cwd: root, encoding: 'utf8' })
  .split('\0').filter(path => path && !path.endsWith('.md') && path !== 'scripts/check-notices.mjs');
for (const path of tracked) {
  if (/tinyusb/i.test(await read(path))) assert.ok(derived.includes(path), `${path} mentions TinyUSB but is not listed in THIRD_PARTY_NOTICES.md`);
}
console.log(`第三方声明检查通过：TinyUSB ${tinyusb.version} 版权、MIT 全文和 ${derived.length} 个派生文件均已登记。`);
