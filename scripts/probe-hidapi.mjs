import { spawnSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

// This creates a disposable native module, never a published second project.
// No device is enumerated or opened by the native link probe.
const root = fileURLToPath(new URL('../', import.meta.url));
const directory = join(root, '_build/hidapi-link-probe');
await mkdir(directory, { recursive: true });
const windows = process.platform === 'win32';
const include = process.env.HIDAPI_INCLUDE_DIR;
const library = process.env.HIDAPI_LINK_FLAGS ?? (windows ? null : process.platform === 'darwin' ? '-lhidapi' : '-lhidapi-hidraw');
if (!library) throw new Error('Windows: set HIDAPI_INCLUDE_DIR, HIDAPI_LINK_FLAGS (absolute hidapi.lib), and add hidapi.dll directory to PATH.');
const includeFlags = include ? `${windows ? '/I' : '-I'}"${include.replaceAll('\\', '/')}"` : '-I/usr/include/hidapi';
await writeFile(join(directory, 'moon.mod'), 'name = "We1chan/moonhid-link-probe"\nversion = "0.0.0"\npreferred_target = "native"\n');
await writeFile(join(directory, 'moon.pkg'), `pkgtype(kind: "executable")\nsupported_targets = "+native"\noptions("native-stub": ["probe.c"], link: { "native": { "stub-cc-flags": ${JSON.stringify(includeFlags)}, "cc-link-flags": ${JSON.stringify(library.replaceAll('\\', '/'))} } })\n`);
await writeFile(join(directory, 'main.mbt'), '///|\nextern "C" fn probe() -> Int = "moonhid_link_probe"\n///|\nfn main { let result = probe(); if result < 0 { abort("hidapi init failed") }; println(result) }\n');
await writeFile(join(directory, 'probe.c'), `#include <hidapi.h>
int moonhid_link_probe(void) {
  const struct hid_api_version *version;
  /* Force the 0.14+ descriptor symbol to be linked, without opening hardware. */
  int (*volatile descriptor)(hid_device *, unsigned char *, size_t) = hid_get_report_descriptor;
  if (!descriptor || hid_init() != 0) return -1;
  version = hid_version();
  int result = (version->major << 16) | (version->minor << 8) | version->patch;
  hid_exit();
  return result;
}
`);
const args = ['-C', directory, 'run', '.', '--target', 'native', '--release'];
const result = spawnSync(process.env.MOON_BIN ?? 'moon', args, { cwd: root, encoding: 'utf8', timeout: 120000 });
const encoded = Number(result.stdout?.trim().split(/\r?\n/).at(-1));
const ok = result.status === 0 && Number.isInteger(encoded) && encoded >= 0x000e00;
const report = {
  recorded_at: new Date().toISOString(), platform: process.platform,
  scope: 'Native linking, hid_init/hid_exit and 0.14+ descriptor symbol only; no device I/O.',
  status: ok ? 'PASS' : 'FAIL', hidapi_version: ok ? `${encoded >> 16}.${(encoded >> 8) & 255}.${encoded & 255}` : null,
  command: ['moon', '-C', '_build/hidapi-link-probe', 'run', '.', '--target', 'native', '--release'],
  exit_code: result.status, stdout: result.stdout, stderr: result.stderr, error: result.error?.message ?? null,
};
await writeFile(join(root, '_build/hidapi-feasibility.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ status: report.status, platform: report.platform, hidapi_version: report.hidapi_version, evidence: '_build/hidapi-feasibility.json' }));
if (!ok) { console.error(result.stderr || result.error?.message || result.stdout); process.exitCode = 1; }
