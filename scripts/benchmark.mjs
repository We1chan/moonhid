// End-to-end JS bridge measurements, including JSON serialization/parsing.
// Timings are observations, not CI pass/fail thresholds or core-only timings.
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { performance } from 'node:perf_hooks';
import { inspect_descriptor, decode_wire } from '../web/moonhid-core.js';

const source = readFileSync(new URL('../src/real_devices_test.mbt', import.meta.url), 'utf8');
const fixtures = [...source.matchAll(/fn real_device_([a-g])\(\) -> String \{\s*"([^"]+)"/g)];
const results = [];
function measure(name, operation, iterations) {
  for (let i = 0; i < 2; i++) JSON.parse(operation());
  global.gc?.();
  const before = process.memoryUsage().heapUsed;
  const samples = [];
  for (let i = 0; i < iterations; i++) {
    const start = performance.now();
    const result = JSON.parse(operation());
    if (!result.ok) throw new Error(`${name}: ${JSON.stringify(result.error)}`);
    samples.push(performance.now() - start);
  }
  global.gc?.();
  const after = process.memoryUsage().heapUsed;
  samples.sort((a, b) => a - b);
  results.push({ name, iterations, min_ms: samples[0], median_ms: samples[Math.floor(samples.length / 2)], max_ms: samples.at(-1),
    heap_delta_bytes: global.gc ? after - before : null });
}
for (const [, name, hex] of fixtures) measure(`inspect-real-${name.toUpperCase()}`, () => inspect_descriptor(hex), 30);
const manyFields = '05 01 09 05 a1 01 15 00 25 01 75 08 95 01 ' + '09 30 81 02 '.repeat(4096) + 'c0';
measure('inspect-4096-fields', () => inspect_descriptor(manyFields), 5);
const largeReport = '05 01 09 05 a1 01 15 00 25 01 75 01 97 00 00 01 00 09 30 81 02 c0';
const wire = '00 '.repeat(8192).trim();
measure('decode-65536-one-bit-values', () => decode_wire(largeReport, 'input', wire), 5);
console.log(JSON.stringify({ created_at: new Date().toISOString(), commit: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
  working_tree_modified: Boolean(execFileSync('git', ['status', '--porcelain'], { encoding: 'utf8' }).trim()),
  environment: { node: process.version, platform: process.platform, arch: process.arch },
  scope: 'JS bridge + JSON serialize/parse; warmup=2; heap delta after GC is retained heap, not peak memory or total allocation', results }, null, 2));
