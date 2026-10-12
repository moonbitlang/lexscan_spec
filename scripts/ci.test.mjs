import assert from 'node:assert/strict';
import { test } from 'node:test';
import { classify, selectTests } from './ci.mjs';

const entry = { signature: 'known failure' };
test('strict FIXME reports failures, unexpected passes, and unrelated errors', () => {
  assert.equal(classify(entry, false, 1, 'known failure'), 'XFAIL');
  assert.equal(classify(entry, true, 0, ''), 'XPASS');
  assert.equal(classify(entry, false, 1, 'different failure'), 'FAIL');
  assert.equal(classify(entry, false, null, 'known failure'), 'FAIL');
  assert.equal(classify(entry, false, 127, 'known failure'), 'FAIL');
  assert.equal(classify(entry, false, 255, 'known failure'), 'XFAIL');
  assert.equal(classify(entry, false, 1, 'Error: [4172] known failure\nError: [4014] unrelated'), 'FAIL');
  assert.equal(classify(undefined, false, 1, 'known failure'), 'FAIL');
  assert.equal(classify(undefined, true, 0, ''), 'PASS');
});

test('isolation preserves helpers, warning attributes, and source line numbers', () => {
  const source = `///|
fn helper() -> Int { 1 }

///|
#warnings("-deprecated_syntax")
test "first" { assert_eq(helper(), 1) }

///|
test "second" { assert_true(false) }

///|
fn trailing_helper() -> Int { 2 }
`;
  const isolated = selectTests(source, name => name === 'first');
  assert.ok(isolated.includes('fn helper()'));
  assert.ok(isolated.includes('fn trailing_helper()'));
  assert.ok(isolated.includes('#warnings("-deprecated_syntax")'));
  assert.ok(isolated.includes('test "first"'));
  assert.ok(!isolated.includes('test "second"'));
  assert.equal(isolated.split('\n').length, source.split('\n').length);
  const ordinary = selectTests(source, name => name !== 'first');
  assert.ok(!ordinary.includes('#warnings'));
  assert.ok(ordinary.includes('test "second"'));
});

import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

test('CI executes isolated FIXMEs and fails on XPASS, unlisted failures, or stale names', () => {
  const root = mkdtempSync(join(tmpdir(), 'lexscan-ci-test-'));
  try {
    for (const dir of ['scripts', 'diagnostics', 'lexmatch', 'lexscan', 'regex_match', 'regex_syntax', 'bin']) {
      mkdirSync(join(root, dir));
    }
    cpSync(new URL('./ci.mjs', import.meta.url), join(root, 'scripts/ci.mjs'));
    writeFileSync(join(root, 'moon.mod'), 'name = "example/test"\n');
    writeFileSync(join(root, 'regex_syntax/cases.mbt'), '///|\ntest "ordinary" { }\n///|\ntest "broken" { }\n');
    writeFileSync(join(root, 'diagnostics/fixtures.tsv'), 'broken_diagnostic\terror\tE4172\t-\t-\n');
    const fixme = { kind: 'test', file: 'regex_syntax/cases.mbt', name: 'broken',
      backends: ['table'], targets: ['js'], modes: ['debug'], signature: 'KNOWN_FAILURE', reason: 'test fixture' };
    writeFileSync(join(root, 'FIXME.json'), JSON.stringify([fixme]));
    writeFileSync(join(root, 'bin/moon'), `#!/usr/bin/env node
const fs = require('node:fs');
const s = fs.readFileSync('regex_syntax/cases.mbt', 'utf8');
fs.appendFileSync(process.env.RUN_LOG, s.includes('test "broken"') ? 'broken\\n' : 'ordinary\\n');
if (s.includes('test "broken"') && !process.env.REPAIRED) { console.log('KNOWN_FAILURE'); process.exit(1); }
if (s.includes('test "ordinary"') && process.env.NEW_FAILURE) { console.log('NEW_FAILURE'); process.exit(1); }
const n = [...s.matchAll(/^test "/gm)].length;
console.log('Total tests: '+n+', passed: '+n+', failed: 0.');
`, { mode: 0o755 });
    const log = join(root, 'runs.log');
    const run = extra => spawnSync(process.execPath, ['scripts/ci.mjs', 'test', 'table', 'js'], {
      cwd: root, encoding: 'utf8', env: { ...process.env, PATH: `${join(root, 'bin')}:${process.env.PATH}`, RUN_LOG: log, ...extra },
    });
    let result = run({});
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /XFAIL/);
    assert.equal(readFileSync(log, 'utf8'), 'ordinary\nbroken\n');
    result = run({ REPAIRED: '1' });
    assert.equal(result.status, 1);
    assert.match(result.stdout, /XPASS/);
    assert.match(result.stderr, /Remove or narrow/);
    assert.equal(run({ NEW_FAILURE: '1' }).status, 1);
    fixme.name = 'renamed';
    writeFileSync(join(root, 'FIXME.json'), JSON.stringify([fixme]));
    result = run({});
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Unknown FIXME/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
