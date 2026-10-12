#!/usr/bin/env node
import { cpSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const backends = ['table', 'block', 'runtime'];
const targets = ['wasm', 'wasm-gc', 'js', 'native'];
const modes = ['debug', 'release'];

// MoonBit's formatter separates top-level declarations with ///|. Keep all
// helper declarations, and select test declarations by their complete names.
export function selectTests(source, keep) {
  return source.split(/(?=^\/\/\/\|[ \t]*$)/m).map(block => {
    const match = block.match(/^test "([^"\n]+)"\s*\{/m);
    return match && !keep(match[1]) ? block.replace(/[^\n]/g, ' ') : block;
  }).join('');
}

export function classify(entry, success, status, output) {
  if (!entry) return success ? 'PASS' : 'FAIL';
  if (success) return 'XPASS';
  // Tool launch failures, signals, and unrelated compiler/runtime failures
  // must never be accepted merely because the test is listed in FIXME.
  const compilerErrors = output.split(/(?=Error: \[\d+\])/).slice(1);
  return status !== null && status > 0 && ![126, 127].includes(status) &&
    output.includes(entry.signature) &&
    compilerErrors.every(error => error.includes(entry.signature)) ? 'XFAIL' : 'FAIL';
}

function inventory() {
  const tests = new Map();
  for (const dir of ['lexmatch', 'lexscan', 'regex_match', 'regex_syntax']) {
    for (const file of readdirSync(join(root, dir)).filter(f => f.endsWith('.mbt'))) {
      const path = `${dir}/${file}`;
      const source = readFileSync(join(root, path), 'utf8');
      for (const match of source.matchAll(/^test "([^"\n]+)"\s*\{/gm)) {
        const key = `${path}\t${match[1]}`;
        if (tests.has(key)) throw new Error(`Duplicate test: ${key}`);
        tests.set(key, { file: path, name: match[1] });
      }
    }
  }
  return tests;
}

function loadFixmes(tests) {
  const entries = JSON.parse(readFileSync(join(root, 'FIXME.json'), 'utf8'));
  if (!Array.isArray(entries)) throw new Error('FIXME.json must contain an array');
  const diagnostics = new Set(readFileSync(join(root, 'diagnostics/fixtures.tsv'), 'utf8')
    .split('\n').filter(line => line && !line.startsWith('#')).map(line => line.split('\t')[0]));
  const seen = new Set();
  for (const entry of entries) {
    const key = entry.kind === 'test' ? `${entry.file}\t${entry.name}` : entry.name;
    if (!['test', 'diagnostic'].includes(entry.kind) ||
        !(entry.kind === 'test' ? tests.has(key) : diagnostics.has(key))) {
      throw new Error(`Unknown FIXME case: ${key}`);
    }
    if (seen.has(`${entry.kind}\t${key}`)) throw new Error(`Duplicate FIXME case: ${key}`);
    seen.add(`${entry.kind}\t${key}`);
    if (typeof entry.reason !== 'string' || !entry.reason.trim() ||
        typeof entry.signature !== 'string' || !entry.signature.trim()) {
      throw new Error(`FIXME needs a reason and a failure signature: ${key}`);
    }
    if (entry.kind === 'test') {
      for (const [field, allowed] of [['backends', backends], ['targets', targets], ['modes', modes]]) {
        if (!Array.isArray(entry[field]) || !entry[field].length ||
            new Set(entry[field]).size !== entry[field].length ||
            entry[field].some(value => !allowed.includes(value))) {
          throw new Error(`Invalid FIXME ${field}: ${key}`);
        }
      }
    }
  }
  return entries;
}

function project(parent, label, tests, keep) {
  const dest = join(parent, label);
  cpSync(root, dest, { recursive: true, filter: path => {
    const relative = path.slice(root.length + 1);
    return !relative.split('/').some(part => part === '.git' || part === '_build');
  } });
  for (const file of new Set([...tests.values()].map(test => test.file))) {
    const path = join(dest, file);
    writeFileSync(path, selectTests(readFileSync(path, 'utf8'), name => keep(`${file}\t${name}`)));
  }
  return dest;
}

function moon(cwd, args, backend) {
  console.log(`> regex_backend=${backend} moon ${args.join(' ')}`);
  const result = spawnSync('moon', args, {
    cwd, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024,
    env: { ...process.env, MOONC_INTERNAL_PARAMS: `regex_backend=${backend}|` },
  });
  const output = (result.stdout ?? '') + (result.stderr ?? '');
  process.stdout.write(output);
  if (result.error) console.error(result.error.message);
  return { ...result, output };
}

function complete(result, count) {
  const summaries = [...result.output.matchAll(/Total tests: (\d+), passed: (\d+), failed: (\d+)\./g)];
  return result.status === 0 && summaries.length === 1 &&
    Number(summaries[0][1]) === count && Number(summaries[0][2]) === count &&
    Number(summaries[0][3]) === 0;
}

function report(verdict, name, reason = '') {
  console.log(`${verdict} ${name}${reason ? `: ${reason}` : ''}`);
  if (verdict === 'XPASS') console.error(`Remove or narrow this entry in FIXME.json: ${name}`);
  return verdict === 'FAIL' || verdict === 'XPASS' ? 1 : 0;
}

function main(args) {
  const tests = inventory();
  const entries = loadFixmes(tests);
  const [command, backend = 'table', target, mode = 'debug'] = args;
  if (command === 'validate' && args.length === 1) {
    console.log(`Validated ${entries.length} FIXME entries and ${tests.size} test identities.`);
    return 0;
  }
  if (command === 'diagnostic-result' && args.length === 5) {
    const [, name, ok, status, path] = args;
    const entry = entries.find(e => e.kind === 'diagnostic' && e.name === name);
    const output = readFileSync(path, 'utf8');
    const verdict = classify(entry, ok === '1', Number(status), output);
    if (verdict === 'FAIL') process.stdout.write(output);
    return report(verdict, name, entry?.reason);
  }
  if (!(command === 'check' && args.length === 1) &&
      !(command === 'test' && args.length >= 3 && args.length <= 4 &&
        backends.includes(backend) && targets.includes(target) && modes.includes(mode))) {
    throw new Error('Usage: node scripts/ci.mjs validate | check | test <table|block|runtime> <wasm|wasm-gc|js|native> [debug|release]');
  }
  const applicable = entries.filter(e => e.kind === 'test' && e.backends.includes(backend) &&
    (command === 'check' || (e.targets.includes(target) && e.modes.includes(mode))));
  const excluded = new Set(applicable.map(e => `${e.file}\t${e.name}`));
  const temp = mkdtempSync(join(tmpdir(), 'lexscan-ci-'));
  let failed = 0;
  try {
    const normal = project(temp, 'ordinary', tests, key => !excluded.has(key));
    const buildDir = resolve(root, '_build', `regex-${backend}`);
    if (command === 'check') {
      failed |= report(moon(normal, ['check', '--target', 'all', '--deny-warn', '--target-dir', buildDir], backend).status === 0 ? 'PASS' : 'FAIL', 'ordinary type checks');
    } else {
      const testArgs = ['test', '--target', target, '--deny-warn'];
      if (mode === 'release') testArgs.push('--release');
      const ordinary = moon(normal, [...testArgs, '--target-dir', buildDir], backend);
      failed |= report(complete(ordinary, tests.size - excluded.size) ? 'PASS' : 'FAIL', 'ordinary tests');
      for (const [index, entry] of applicable.entries()) {
        const key = `${entry.file}\t${entry.name}`;
        const isolated = project(temp, `fixme-${index}`, tests, candidate => candidate === key);
        // Isolation makes shared helpers/imports unused; keep every other warning fatal.
        const result = moon(isolated, [...testArgs, '--warn-list', '-1-2-29', entry.file, '--target-dir', `${buildDir}-fixme-${index}`], backend);
        failed |= report(classify(entry, complete(result, 1), result.status, result.output), key, entry.reason);
      }
    }
  } finally {
    rmSync(temp, { recursive: true, force: true });
  }
  return failed;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { process.exitCode = main(process.argv.slice(2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
