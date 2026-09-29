#!/usr/bin/env node
// Fails when an installed production dependency has a missing or disallowed license.
// Development-only tooling is excluded because it is not distributed in the app.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const ALLOWED = new Set([
  '0BSD',
  'Apache-2.0',
  'BlueOak-1.0.0',
  'BSD-2-Clause',
  'BSD-3-Clause',
  'CC-BY-4.0',
  'CC0-1.0',
  'ISC',
  'MIT',
  'MIT-0',
  // Weak file-level copyleft; used unmodified (lightningcss via Expo's Metro config).
  'MPL-2.0',
  'Python-2.0',
  'Unlicense',
]);

function licenseOf(manifest) {
  if (typeof manifest.license === 'string') return manifest.license;
  if (manifest.license && typeof manifest.license.type === 'string') return manifest.license.type;
  if (Array.isArray(manifest.licenses)) {
    return manifest.licenses.map((entry) => entry.type ?? entry).join(' OR ');
  }
  return null;
}

// SPDX expressions: every AND term must be allowed; an OR expression needs one allowed option.
function isAllowed(expression) {
  const normalized = expression.replace(/[()]/g, '').trim();
  return normalized
    .split(/\s+OR\s+/)
    .some((option) => option.split(/\s+AND\s+/).every((term) => ALLOWED.has(term.trim())));
}

const output = execFileSync('npm', ['ls', '--omit=dev', '--all', '--parseable'], {
  encoding: 'utf8',
  maxBuffer: 64 * 1024 * 1024,
});
const root = process.cwd();
const failures = [];
let checked = 0;

for (const dir of new Set(output.split('\n').filter(Boolean))) {
  if (path.resolve(dir) === root) continue;
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(path.join(dir, 'package.json'), 'utf8'));
  } catch {
    continue;
  }
  checked += 1;
  const license = licenseOf(manifest);
  if (!license || !isAllowed(license)) {
    failures.push(`${manifest.name}@${manifest.version}: ${license ?? 'UNKNOWN'}`);
  }
}

if (failures.length > 0) {
  console.error(`Disallowed or missing licenses in ${failures.length} package(s):`);
  for (const failure of failures.sort()) console.error(`  ${failure}`);
  process.exit(1);
}
console.log(`License check passed for ${checked} production packages.`);
