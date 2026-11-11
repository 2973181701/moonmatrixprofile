import { analyze } from '../web/core.js';
import { performance } from 'node:perf_hooks';
import { cpus, platform, arch } from 'node:os';
import { writeFileSync, mkdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
let seed = 73183;
const random = () => { seed = (1664525 * seed + 1013904223) >>> 0; return seed / 4294967296; };
const workloads = [512, 1024, 2048, 4096].map(n => ({ name: `random-${n}`, window: 48, series: Array.from({ length: n }, () => random() * 2 - 1) }));
workloads.push({ name: 'repeated-linear-512', window: 48, series: Array.from({ length: 512 }, (_, i) => i) });
const measurements = [];
for (const workload of workloads) {
  const input = JSON.stringify({ series: workload.series, window: workload.window, count: 3 });
  analyze(input);
  const trials = [];
  for (let i = 0; i < 3; i++) {
    const start = performance.now();
    const output = JSON.parse(analyze(input));
    trials.push(performance.now() - start);
    if (!output.ok) throw new Error(JSON.stringify(output));
  }
  const sorted = [...trials].sort((a, b) => a - b);
  measurements.push({ name: workload.name, samples: workload.series.length, window: workload.window, median_ms: sorted[1], trials_ms: trials });
}
const report = { date: new Date().toISOString(), node: process.version, platform: platform(), arch: arch(), cpu: cpus()[0]?.model,
  toolchain: execFileSync('moon', ['version', '--all'], { encoding: 'utf8' }).trim(),
  includes: 'JSON parse, MoonBit-compiled JS core, candidate selection, JSON stringify, host parse',
  excludes: 'build and initial warm-up; not a cross-language speed comparison', seed: 73183, measurements };
mkdirSync(new URL('../evidence/', import.meta.url), { recursive: true });
writeFileSync(new URL('../evidence/benchmark.json', import.meta.url), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
