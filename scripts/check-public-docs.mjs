import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const usage = 'Usage: node scripts/check-public-docs.mjs [published-version] [--urls <file>]';
export function parseArguments(args, defaultVersion) {
  let version, urlsFile;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--urls') {
      assert.ok(!urlsFile && args[i + 1] && !args[i + 1].startsWith('--'), usage);
      urlsFile = args[++i];
    } else {
      assert.ok(!version && !args[i].startsWith('-'), usage);
      version = args[i];
    }
  }
  version ??= defaultVersion;
  assert.match(version ?? '', /^\d+\.\d+\.\d+(?:[-+][\w.-]+)?$/, usage);
  return { version, urlsFile };
}

// Release bodies use inline/reference Markdown, autolinks and plain HTTPS URLs.
// Code examples are not rendered hyperlinks and are deliberately excluded.
export function markdownHrefs(markdown) {
  const visible = markdown.replace(/```[^\n]*\n[\s\S]*?```|~~~[^\n]*\n[\s\S]*?~~~/g, '').replace(/`[^`\n]*`/g, '');
  const result = new Set();
  const definitions = new Map();
  for (const match of visible.matchAll(/\bhref\s*=\s*["']([^"']+)["']/gi)) result.add(match[1].replaceAll('&amp;', '&'));
  for (const match of visible.matchAll(/^\s*\[([^\]]+)\]:\s*(?:<([^>]+)>|(\S+))/gm)) definitions.set(match[1].toLowerCase(), match[2] ?? match[3]);
  for (const match of visible.matchAll(/!?\[[^\]]*\]\(\s*(<[^>]+>|(?:\\.|[^()\s]|\([^()\n]*\))+)(?:\s+["'][^\n]*?["'])?\s*\)/g)) result.add(match[1].replace(/^<|>$/g, '').replace(/\\([()])/g, '$1'));
  for (const match of visible.matchAll(/!?\[([^\]]+)\](?:\[([^\]]*)\])?/g)) {
    const href = definitions.get((match[2] || match[1]).toLowerCase());
    if (href) result.add(href);
  }
  for (const match of visible.matchAll(/<((?:https?:\/\/)[^>\s]+)>/g)) result.add(match[1]);
  for (const match of visible.matchAll(/https?:\/\/[^\s<>"'`\[\]()]+(?:\([^\s<>]*?\)[^\s<>"'`\[\]()]*)*/g)) result.add(match[0].replace(/[.,;:!?，。；：！？」』]+$/g, ''));
  return [...result];
}

export function extraUrls(text) {
  const entries = text.trimStart().startsWith('[') ? JSON.parse(text) : text.split(/\r?\n/).map(line => line.trim()).filter(line => line && !line.startsWith('#'));
  assert.ok(Array.isArray(entries), 'URL file must be a JSON array or one absolute HTTP(S) URL per line.');
  for (const entry of entries) {
    assert.ok(typeof entry === 'string' && /^https?:\/\//i.test(entry), `Expected an absolute HTTP(S) URL: ${entry}`);
    new URL(entry);
  }
  return entries;
}

export async function requestLink(url, { readBody = false } = {}) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
      if ((response.status === 429 || response.status >= 500) && attempt < 2) {
        await response.body?.cancel();
        await new Promise(done => setTimeout(done, 500 * (attempt + 1)));
        continue;
      }
      const body = readBody ? await response.text() : '';
      if (!readBody) await response.body?.cancel();
      return { status: response.status, url: response.url, body };
    } catch (error) {
      if (attempt === 2) return { status: error.message, url, body: '' };
    }
  }
}

async function main() {
  if (process.argv.includes('--help')) { console.log(usage); return; }
  const metadata = await readFile(new URL('../moon.mod', import.meta.url), 'utf8');
  const setting = name => metadata.match(new RegExp(`^${name}\\s*=\\s*"([^"]+)"`, 'm'))?.[1];
  const { version, urlsFile } = parseArguments(process.argv.slice(2), setting('version'));
  const moduleName = setting('name'), repository = setting('repository');
  assert.ok(moduleName && repository, 'Expected module name and repository metadata.');
  const repositoryUrl = new URL(repository);
  const repositoryPath = repositoryUrl.pathname.replace(/\/$/, '');
  const mooncakes = `https://mooncakes.io/docs/${moduleName}@${version}`;
  const assetPrefix = `https://assets.mooncakes.io/source/${moduleName}@${version}/`;
  const inspector = `https://${repositoryPath.split('/')[1].toLowerCase()}.github.io/${repositoryPath.split('/')[2]}/`;
  const hrefs = html => [...html.matchAll(/\bhref\s*=\s*["']([^"']+)["']/gi)].map(match => match[1].replace(/&amp;/g, '&'));
  const checks = new Map();
  const add = (href, page, all = false) => {
    if (href.startsWith('#')) return;
    const url = /^https?:\/\//i.test(href) ? new URL(href) : new URL(href, page);
    if (!['http:', 'https:'].includes(url.protocol)) return;
    const own = url.origin === repositoryUrl.origin && (url.pathname === repositoryPath || url.pathname.startsWith(`${repositoryPath}/`));
    const registryAsset = url.hostname === 'assets.mooncakes.io';
    if (!all && !own && !registryAsset && !href.startsWith('../')) return;
    url.hash = '';
    const key = `${page}\n${href}`;
    if (!checks.has(key)) checks.set(key, { href, page, url: url.href });
  };
  const [github, registry] = await Promise.all([requestLink(repository, { readBody: true }), requestLink(mooncakes, { readBody: true })]);
  assert.equal(github.status, 200, `GitHub homepage: ${github.status}`);
  assert.equal(registry.status, 200, `Mooncakes ${version}: ${registry.status}`);
  const article = github.body.match(/<article\b[^>]*class="[^"]*markdown-body[^"]*"[^>]*>([\s\S]*?)<\/article>/i)?.[1];
  assert.ok(article, 'GitHub did not render a README article.');
  const githubLinks = hrefs(article), registryLinks = hrefs(registry.body);
  assert.ok(githubLinks.some(href => href.includes(`${repositoryPath}/blob/main/docs/`)), 'GitHub README has no main-branch documentation links.');
  githubLinks.forEach(href => add(href, repository));
  registryLinks.forEach(href => add(href, mooncakes));
  add(inspector, repository, true);
  // Use authenticated gh rather than printing or forwarding credentials.
  const gh = spawnSync('gh', ['api', '--paginate', '--slurp', `repos${repositoryPath}/releases?per_page=100`], { encoding: 'utf8', timeout: 60000, windowsHide: true, maxBuffer: 16 * 1024 * 1024 });
  assert.equal(gh.status, 0, `Cannot inspect all Release bodies with gh api: ${gh.stderr || gh.error?.message}`);
  const releases = JSON.parse(gh.stdout).flat();
  for (const release of releases) markdownHrefs(release.body ?? '').forEach(href => add(href, release.html_url, true));
  const extras = urlsFile ? extraUrls(await readFile(urlsFile, 'utf8')) : [];
  extras.forEach(href => add(href, `URL file: ${urlsFile}`, true));
  const entries = [...checks.values()], failures = [], verified = new Set();
  const uniqueUrls = [...new Set(entries.map(entry => entry.url))];
  const responses = new Map();
  console.log(`Read GitHub/Mooncakes ${version}, all ${releases.length} Release bodies and ${extras.length} extra URLs; checking ${entries.length} link sources (${uniqueUrls.length} unique URLs).`);
  for (let index = 0; index < uniqueUrls.length; index += 4) await Promise.all(uniqueUrls.slice(index, index + 4).map(async url => responses.set(url, await requestLink(url))));
  for (const source of entries) {
    const result = responses.get(source.url);
    if (result.status !== 200) failures.push({ ...source, url: result.url, status: result.status });
    else verified.add(`${source.page}\n${source.href}`);
  }
  for (const failure of failures) console.error(`${failure.status}: ${failure.href}\n  rendered by ${failure.page}\n  requested ${failure.url}`);
  const missing = ['hid-compatibility.md', 'report-cases.md'].filter(file => !registryLinks.some(href => {
    if (!/^https?:\/\//i.test(href) || !verified.has(`${mooncakes}\n${href}`)) return false;
    const url = new URL(href);
    return (url.origin === repositoryUrl.origin && url.pathname.startsWith(`${repositoryPath}/blob/`) && url.pathname.endsWith(`/docs/${file}`)) ||
      (href.startsWith(assetPrefix) && url.pathname === `${new URL(assetPrefix).pathname}docs/${file}`);
  }));
  for (const file of missing) console.error(`Mooncakes ${version}: no verified absolute link to docs/${file}.`);
  const report = { version, recorded_at: new Date().toISOString(), releases_checked: releases.map(release => release.tag_name), extra_urls: extras,
    link_sources: entries.length, unique_urls: uniqueUrls.length, failures, required_registry_links_missing: missing,
    results: uniqueUrls.map(url => ({ requested_url: url, ...responses.get(url), body: undefined })) };
  await mkdir(new URL('../_build/', import.meta.url), { recursive: true });
  await writeFile(new URL('../_build/public-docs-report.json', import.meta.url), JSON.stringify(report, null, 2) + '\n');
  console.log(`Public documentation ${version}: ${entries.length} links, ${releases.length} Releases, ${failures.length} failed, ${missing.length} required registry links missing. Report: _build/public-docs-report.json`);
  if (failures.length || missing.length) process.exitCode = 1;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  await main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
