import { readFile, readdir } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export async function unconfirmedDocuments(root) {
  const files = ['README.md', 'src/README.mbt.md',
    ...(await readdir(join(root, 'docs'), { recursive: true }))
      .filter(name => name.endsWith('.md')).map(name => join('docs', name))];
  const hits = [];
  for (const file of files) {
    const lines = (await readFile(join(root, file), 'utf8')).split(/\r?\n/);
    lines.forEach((line, index) => {
      if (line.includes('【待确认】')) hits.push(`${file.replaceAll('\\', '/')}:${index + 1}`);
    });
  }
  return hits;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  const hits = await unconfirmedDocuments(fileURLToPath(new URL('../', import.meta.url)));
  if (hits.length) {
    console.error('验收文档仍有参赛者尚未确认的事实：\n' + hits.join('\n'));
    process.exitCode = 1;
  } else console.log('验收文档事实确认检查通过。');
}
