"""Independent differential oracle. Requires requirements-validation.txt only for development."""
import json
import os
import platform
from importlib.metadata import version
import subprocess
from pathlib import Path
os.environ.setdefault('NUMBA_NUM_THREADS', '1')
os.environ.setdefault('NUMBA_DISABLE_JIT', '1')
import numpy as np
import stumpy

ROOT = Path(__file__).resolve().parents[1]
rng = np.random.default_rng(73183)
cases = []
for n in [12, 23, 48, 129, 260]:
    for m in sorted(set([3, 5, n // 3])):
        if m > n: continue
        a = rng.normal(size=n)
        for label, values in [('random', a), ('large-offset', a + 1e12), ('small-scale', a * 1e-100)]:
            cases.append((f'{label}-{n}-{m}', values, None, m))
        b = rng.normal(size=n + 7)
        cases.append((f'ab-{n}-{m}', a, b, m))
for label, a, m in [
    ('constant', np.ones(20), 4),
    ('linear', np.arange(40, dtype=float), 5),
    ('repeat', np.tile([0., 1., 0., -1.], 10), 4),
    ('missing', np.array([1., 4., 2., 8., np.nan, 1., 0., 5., 2., 9., 8., 3.]), 3),
]: cases.append((label, a, None, m))

requests = []
expected = []
def wire(a): return [float(x) if np.isfinite(x) else None for x in a]
for label, a, b, m in cases:
    req = {'op': 'abjoin' if b is not None else 'profile', 'series': wire(a), 'window': m}
    if b is not None: req['target'] = wire(b)
    # STUMPY treats std < 1e-8 as constant. Our documented constant rule is exact;
    # pass explicit constant masks and rescale oracle inputs for parity.
    def condition(x):
        y = x.copy()
        finite = np.isfinite(y)
        if finite.any():
            y[finite] -= y[finite][0]
            scale = np.max(np.abs(y[finite]))
            if scale: y[finite] /= scale
        return y
    aa = condition(a)
    bb = condition(b) if b is not None else None
    def constants(x):
        return np.array([np.isfinite(x[i:i+m]).all() and np.all(x[i:i+m] == x[i]) for i in range(len(x)-m+1)])
    ref = stumpy.stump(aa, m, T_B=bb, ignore_trivial=b is None,
                       T_A_subseq_isconstant=constants(aa),
                       T_B_subseq_isconstant=constants(bb) if bb is not None else None)
    requests.append(req)
    expected.append((label, a, b if b is not None else a, m, ref))
result = subprocess.run(['node', 'cli.mjs', 'batch'], cwd=ROOT,
    input=''.join(json.dumps(r, allow_nan=False)+'\n' for r in requests), text=True,
    capture_output=True, check=True)
actual = [json.loads(line) for line in result.stdout.splitlines()]
assert len(actual) == len(expected)
max_error = 0.
windows = 0
for reply, (label, a, b, m, ref) in zip(actual, expected):
    assert reply['ok'], (label, reply)
    distances = reply['profile']['distances']
    indices = reply['profile']['indices']
    for i, (distance, index) in enumerate(zip(distances, indices)):
        want = float(ref[i, 0])
        if not np.isfinite(want):
            assert distance is None and index is None, (label, i, reply)
            continue
        error = abs(distance - want)
        max_error = max(max_error, error)
        assert error <= 2e-6 * (1 + abs(want)), (label, i, distance, want)
        # Verify the returned witness itself; tie indices may differ.
        x, y = a[i:i+m], b[index:index+m]
        x, y = x-x[0], y-y[0]
        sx, sy = np.std(x), np.std(y)
        if sx == 0 and sy == 0: witness = 0.
        elif sx == 0 or sy == 0: witness = np.sqrt(m)
        else: witness = np.linalg.norm((x-x.mean())/sx-(y-y.mean())/sy)
        assert abs(witness-distance) <= 2e-6*(1+distance), (label, i, 'witness', witness, distance)
        windows += 1
evidence = {'stumpy': version('stumpy'), 'numpy': np.__version__, 'python': platform.python_version(),
            'cases': len(cases), 'checked_windows': windows, 'max_absolute_error': max_error,
            'tolerance': '2e-6 * (1 + expected_distance)', 'seed': 73183,
            'constant_policy': 'exact masks, explicitly conditioned oracle inputs', 'passed': True}
(ROOT/'evidence').mkdir(exist_ok=True)
(ROOT/'evidence'/'stumpy-validation.json').write_text(json.dumps(evidence, indent=2)+'\n')
print(json.dumps(evidence, indent=2))
