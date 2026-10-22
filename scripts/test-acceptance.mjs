import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { runSteps, acceptanceFailed } from './acceptance.mjs';

const scratch = await mkdtemp(join(tmpdir(), 'moonhid 验收 with spaces-'));
try {
  const results = await runSteps([
    { id: 'argv', name: 'Unicode argv', command: process.execPath, args: ['-e', 'process.stdout.write(process.argv[1])', '值 with spaces; $literal'] },
    { id: 'failure', name: 'Process failure', command: process.execPath, args: ['-e', 'console.error("deliberate failure");process.exit(7)'] },
    { id: 'dependent', name: 'Must not run', command: 'missing-executable', needs: ['failure'] },
    { id: 'optional', name: 'Missing optional dependency', required: false, skipReason: 'install dependency' },
    { id: 'missing', name: 'Missing executable', command: join(scratch, 'missing.exe'), required: false },
  ], { cwd: scratch, logDirectory: join(scratch, 'logs') });
  assert.deepEqual(results.map(result => result.status), ['PASS', 'FAIL', 'SKIP', 'SKIP', 'FAIL']);
  assert.equal(await readFile(results[0].log, 'utf8'), '值 with spaces; $literal');
  assert.equal(results[1].exit_code, 7);
  assert.match(results[1].output_tail, /deliberate failure/);
  assert.match(results[2].reason, /failure/);
  assert.equal(acceptanceFailed(results), true);
  assert.equal(acceptanceFailed([results[0], results[3]]), false);
  assert.equal(acceptanceFailed([results[2]]), true, 'Required SKIP must not look successful');
  assert.equal(acceptanceFailed([results[4]]), true, 'An available optional check failing must not look successful');
  console.log('验收脚本：真实进程退出码、Unicode/空格参数、失败后跳过依赖、可选缺依赖和报告判定通过。');
} finally {
  await rm(scratch, { recursive: true, force: true });
}
