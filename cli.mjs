#!/usr/bin/env node
import { readFileSync, statSync } from 'node:fs';
import { createInterface } from 'node:readline';
import { analyze } from './web/core.js';

const help = `MoonMatrixProfile 0.1.0
Usage:
  node cli.mjs profile FILE --window N [--column NAME] [--count N] [--json]
  node cli.mjs abjoin SOURCE.json TARGET.json --window N [--json]
  node cli.mjs query FILE QUERY.json [--column NAME] [--json]
  node cli.mjs request REQUEST.json
  node cli.mjs batch                  # one JSON request per stdin line

FILE: a JSON numeric array (null = missing), or CSV with --column.
Indices are zero-based sample offsets; windows use sample counts.
Optional: --exclusion N, --max-pairs N. Diagnostics go to stderr.
Exit codes: 0 success, 1 input/analysis error, 2 usage error.
`;
const args = process.argv.slice(2);
if (!args.length || args.includes('--help') || args[0] === 'help') { console.log(help); process.exit(0); }
if (args[0] === '--version') { console.log('0.1.0'); process.exit(0); }
if (args[0] === 'batch') {
  for await (const line of createInterface({ input: process.stdin, crlfDelay: Infinity })) {
    if (line.trim()) console.log(analyze(line));
  }
  process.exit(0);
}
function read(path) {
  if (statSync(path).size > 8_000_000) throw new Error('Input file exceeds 8 MB');
  return readFileSync(path, 'utf8');
}
function array(path) {
  const value = JSON.parse(read(path));
  if (!Array.isArray(value)) throw new Error('JSON file must contain a numeric array');
  return value;
}
try {
  const [command, ...rest] = args;
  if (!['profile', 'abjoin', 'query', 'request'].includes(command)) {
    console.error(help); process.exit(2);
  }
  const files = [], options = {};
  for (let i = 0; i < rest.length; i++) {
    const item = rest[i];
    if (!item.startsWith('--')) { files.push(item); continue; }
    if (item === '--json') { options.json = true; continue; }
    const key = { '--window': 'window', '--column': 'column', '--count': 'count', '--exclusion': 'exclusion', '--max-pairs': 'max_pairs' }[item];
    if (!key || i + 1 >= rest.length) throw new Error(`Unknown or incomplete option: ${item}`);
    const raw = rest[++i];
    if (key === 'column') options[key] = raw;
    else {
      if (!/^\d+$/.test(raw) || !Number.isSafeInteger(Number(raw))) throw new Error(`${item} requires a nonnegative integer`);
      options[key] = Number(raw);
    }
  }
  const needed = ['abjoin', 'query'].includes(command) ? 2 : 1;
  if (files.length !== needed) throw new Error(`${command} requires ${needed} file(s)`);
  let request;
  if (command === 'request') request = JSON.parse(read(files[0]));
  else {
    request = { op: command, ...options };
    delete request.json;
    if (options.column !== undefined) request.csv = read(files[0]);
    else request.series = array(files[0]);
    if (command === 'abjoin') request.target = array(files[1]);
    if (command === 'query') request.query = array(files[1]);
  }
  const result = JSON.parse(analyze(JSON.stringify(request)));
  if (!result.ok) { console.error(`${result.error.code}: ${result.error.message}`); process.exit(1); }
  if (options.json || command === 'request') console.log(JSON.stringify(result));
  else if (result.kind === 'query') {
    console.log(`Query window: ${result.window} samples`);
    for (const hit of result.matches) console.log(`  match @ ${hit.index}  distance=${hit.distance.toFixed(8)}`);
  } else {
    console.log(`MoonMatrixProfile | ${result.samples} samples | window ${result.profile.window}`);
    console.log(`Invalid windows: ${result.invalid_windows} | Valid without neighbour: ${result.unmatched_windows}`);
    for (const kind of ['motifs', 'discords']) {
      console.log(kind.toUpperCase());
      for (const hit of result[kind]) console.log(`  ${hit.index} ↔ ${hit.neighbor}  distance=${hit.distance.toFixed(8)}`);
    }
  }
} catch (error) { console.error(error.message); process.exit(1); }
