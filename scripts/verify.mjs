import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const checks = [
  ['moon', ['version', '--all']],
  ['moon', ['check', '--deny-warn']],
  ['moon', ['fmt', '--check']],
  ...['wasm', 'wasm-gc', 'js'].map(target => ['moon', ['test', '--target', target, '--deny-warn']]),
  ['moon', ['build', '--target', 'wasm-gc', '--deny-warn']],
  ['moon', ['run', 'cmd/main']],
  ['node', ['scripts/build.mjs']],
  ['node', ['--test', 'tests/core.test.mjs']],
];
for (const [command, args] of checks) {
  console.log(`\n> ${command} ${args.join(' ')}`);
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
console.log('\nAll local verification checks passed.');
