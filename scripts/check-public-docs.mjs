import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

// Check the links users actually receive, rather than constructing ideal URLs.
// Usage: node scripts/check-public-docs.mjs [published-version]
const metadata = await readFile(new URL('../moon.mod', import.meta.url), 'utf8');
const setting = name => metadata.match(new RegExp(`^${name}\\s*=\\s*"([^"]+)"`, 'm'))?.[1];
const moduleName = setting('name');
const version = process.argv[2] ?? setting('version');
const repository = setting('repository');
assert.ok(moduleName && repository && /^\d+\.\d+\.\d+(?:[-+][\w.-]+)?$/.test(version),
  'Expected module metadata and an optional published version, for example 0.5.0.');
assert.ok(process.argv.length <= 3, 'Usage: node scripts/check-public-docs.mjs [published-version]');
const repositoryUrl = new URL(repository);
const repositoryPath = repositoryUrl.pathname.replace(/\/$/, '');
const mooncakes = `https://mooncakes.io/docs/${moduleName}@${version}`;
const assetPrefix = `https://assets.mooncakes.io/source/${moduleName}@${version}/`;
const inspector = `https://${repositoryPath.split('/')[1].toLowerCase()}.github.io/${repositoryPath.split('/')[2]}/`;

const get = async url => {
  for (let attempt = 0; ; attempt++) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
      const body = await response.text();
      if (attempt === 0 && (response.status === 429 || response.status >= 500)) continue;
      return { status: response.status, url: response.url, body };
    } catch (error) {
      if (attempt > 0) return { status: error.message, url, body: '' };
    }
  }
};
const hrefs = html => [...html.matchAll(/\bhref\s*=\s*["']([^"']+)["']/gi)]
  .map(match => match[1].replace(/&amp;/g, '&'));
const checks = new Map();
const add = (href, page) => {
  if (href.startsWith('#')) return;
  let url;
  try { url = new URL(href, page); } catch { return; }
  const ownRepository = url.origin === repositoryUrl.origin &&
    (url.pathname === repositoryPath || url.pathname.startsWith(`${repositoryPath}/`));
  // Inspect the original href before URL normalization removes erroneous ../.
  if (!ownRepository && !href.startsWith(assetPrefix)) return;
  url.hash = '';
  const key = `${page}\n${href}`;
  if (!checks.has(key)) checks.set(key, { href, page, url: url.href });
};

const [github, registry] = await Promise.all([get(repository), get(mooncakes)]);
assert.equal(github.status, 200, `GitHub homepage: ${github.status}`);
assert.equal(registry.status, 200, `Mooncakes ${version}: ${registry.status}`);
const article = github.body.match(/<article\b[^>]*class="[^"]*markdown-body[^"]*"[^>]*>([\s\S]*?)<\/article>/i)?.[1];
assert.ok(article, 'GitHub did not render a README article.');
const githubLinks = hrefs(article);
const registryLinks = hrefs(registry.body);
assert.ok(githubLinks.some(href => href.includes(`${repositoryPath}/blob/main/docs/`)),
  'GitHub README has no rendered main-branch documentation links.');
assert.ok(registryLinks.some(href => href.startsWith(assetPrefix)),
  `Mooncakes ${version} has no rendered README asset links for this module version.`);
githubLinks.forEach(href => add(href, repository));
registryLinks.forEach(href => add(href, mooncakes));
checks.set(inspector, { href: inspector, page: repository, url: inspector });

const entries = [...checks.values()];
const failures = [];
console.log(`Read rendered GitHub README and Mooncakes ${version}; checking ${entries.length} links including inspector.`);
for (let index = 0; index < entries.length; index += 4) {
  await Promise.all(entries.slice(index, index + 4).map(async source => {
    const result = await get(source.url);
    if (result.status !== 200) failures.push({ ...source, url: result.url, status: result.status });
  }));
}
for (const failure of failures) {
  console.error(`${failure.status}: ${failure.href}\n  rendered by ${failure.page}\n  requested ${failure.url}`);
}
console.log(`Public documentation ${version}: checked ${entries.length} rendered GitHub/Mooncakes links and inspector; ${failures.length} failed.`);
if (failures.length) process.exitCode = 1;
