import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { analyze } from '../web/core.js';
const root = fileURLToPath(new URL('../', import.meta.url));
const run = request => JSON.parse(analyze(JSON.stringify(request)));
const series = [0, 1, 0, -1, 0, 1, 0, -1, 2, 3, -4, 5];

test('JSON profile uses scalar numbers and nulls, and witnesses obey exclusion', () => {
  const result = run({ series, window: 4 });
  assert.equal(result.ok, true);
  assert.equal(result.profile.distances.length, 9);
  assert.equal(result.profile.indices[0], 4);
  assert.ok(result.profile.distances[0] < 1e-10);
  for (let i = 0; i < result.profile.indices.length; i++) assert.ok(Math.abs(i - result.profile.indices[i]) > result.profile.exclusion);
  assert.deepEqual(run({ series: [1, 2, 3], window: 3 }).profile.distances, [null]);
});
test('missing data and all-excluded are distinguishable', () => {
  const result = run({ series: [null, null, null, null], window: 3 });
  assert.deepEqual(result.profile.valid, [false, false]);
  assert.deepEqual(result.profile.indices, [null, null]);
  assert.equal(result.invalid_windows, 2);
  assert.equal(result.unmatched_windows, 0);
  const excluded = run({ series: [1, 2, 3, 4], window: 3, exclusion: 99 });
  assert.equal(excluded.unmatched_windows, 2);
  assert.equal(excluded.invalid_windows, 0);
});
test('AB join has no trivial-match exclusion and is directional', () => {
  const result = run({ op: 'abjoin', series: [1, 3, 2], target: [4, 1, 3, 2, 9], window: 3 });
  assert.equal(result.ok, true);
  assert.deepEqual(result.profile.indices, [1]);
  assert.ok(result.profile.distances[0] < 1e-10);
  assert.deepEqual(result.motifs, []);
});
test('negative correlation is far apart, positive affine transforms agree', () => {
  const a = run({ op: 'query', series: [3, 2, 1], query: [1, 2, 3] });
  assert.ok(Math.abs(a.distances[0] - Math.sqrt(12)) < 1e-9);
  const b = run({ op: 'query', series: [12, 14, 16], query: [1, 2, 3] });
  assert.ok(b.distances[0] < 1e-9);
});
test('constant and extreme finite ranges remain defined', () => {
  assert.deepEqual(run({ op: 'query', series: [9, 9, 9], query: [2, 2, 2] }).distances, [0]);
  const result = run({ op: 'query', series: [1e308, 0, -1e308], query: [1, 0, -1] });
  assert.equal(result.ok, true);
  assert.ok(result.distances[0] < 1e-9);
});
test('CSV handles escaped quotes, BOM, multiline fields and missing values', () => {
  const result = run({ op: 'parse', column: 'value', csv: '\ufeffvalue,label\r\n1,"two, words"\r\n,"line\nquote""x"\r\n2e1,x\r\n' });
  assert.deepEqual(result.series, [1, null, 20]);
});
for (const [label, request, code] of [
  ['invalid window', { series, window: 2 }, 'E_WINDOW'],
  ['fractional window', { series, window: 3.1 }, 'E_INPUT'],
  ['negative exclusion', { series, window: 3, exclusion: -1 }, 'E_INPUT'],
  ['work budget', { series, window: 3, max_pairs: 2 }, 'E_LIMIT'],
  ['count limit', { series, window: 3, count: 101 }, 'E_LIMIT'],
  ['bad type', { series: [1, '2', 3], window: 3 }, 'E_INPUT'],
  ['missing query', { op: 'query', series, query: [1, null, 3] }, 'E_QUERY'],
  ['unknown op', { op: 'oops', series }, 'E_INPUT'],
  ['duplicate column', { csv: 'x,x\n1,2', column: 'x' }, 'E_CSV'],
  ['bad quote', { csv: 'x\n"1"oops', column: 'x' }, 'E_CSV'],
  ['ragged row', { csv: 'x,y\n1', column: 'x' }, 'E_CSV'],
]) test(`rejects ${label}`, () => { const result = run(request); assert.equal(result.ok, false); assert.equal(result.error.code, code); });
test('query search can suppress the original neighbourhood', () => {
  const result = run({ op: 'query', series, query: series.slice(0, 4), ignore_start: 0, count: 2 });
  assert.equal(result.ok, true);
  assert.equal(result.distances[0], null);
  assert.equal(result.matches[0].index, 4);
});
test('selected motif pairs and discords do not overlap within their result sets', () => {
  const result = run({ series, window: 3, count: 10 });
  for (const list of [result.motifs, result.discords]) {
    for (let i = 0; i < list.length; i++) for (let j = i + 1; j < list.length; j++) assert.ok(Math.abs(list[i].index - list[j].index) >= 3);
  }
});
test('CLI resolves real files, emits JSON, and reports usage/input errors', () => {
  const cli = args => spawnSync('node', ['cli.mjs', ...args], { cwd: root, encoding: 'utf8' });
  const result = cli(['profile', 'examples/tiny.json', '--window', '4', '--json']);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).ok, true);
  assert.equal(cli(['profile', 'examples/tiny.json', '--window', '2']).status, 1);
  assert.equal(cli(['unknown']).status, 2);
  assert.equal(cli(['profile', 'examples/signal sample.csv', '--window', '3', '--column', 'value', '--json']).status, 0);
});
