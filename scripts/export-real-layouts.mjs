import { readFileSync } from 'node:fs';
import { inspect_descriptor } from '../web/moonhid-core.js';

// Read the exact regression bytes instead of maintaining a second fixture copy.
const source = readFileSync(new URL('../real_devices_test.mbt', import.meta.url), 'utf8');
const fixtures = [...source.matchAll(/fn real_device_([a-g])\(\) -> String \{\s*"([^"]+)"/g)].map(([, label, hex]) => {
  const result = JSON.parse(inspect_descriptor(hex));
  if (!result.ok || result.schema_version !== 2) throw new Error(`${label}: ${JSON.stringify(result.error)}`);
  return { label: label.toUpperCase(), hex, layout: result.descriptor.layout };
});
if (fixtures.map(f => f.label).join('') !== 'ABCDEFG') throw new Error('Expected the seven A–G regression fixtures.');
console.log(JSON.stringify(fixtures));
