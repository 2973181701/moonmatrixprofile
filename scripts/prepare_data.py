"""Reproduce the explicitly decimated demo view; full source CSV is retained."""
import csv, hashlib, json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
path = root/'web/data/machine_temperature.csv'
sha = hashlib.sha256(path.read_bytes()).hexdigest()
assert sha == '92bf5b87fc7f9bba8ca0b7ec63ccaac8cb4a1371a258e8c29a10ae9c018d82a4'
with path.open(newline='') as f: rows = list(csv.DictReader(f))
selected = list(range(0, len(rows), 10))
data = {'name': '工业设备温度', 'source': 'Numenta Anomaly Benchmark / realKnownCause',
        'unit': '原始数值', 'stride': 10, 'original_samples': len(rows),
        'source_sha256': sha, 'source_commit': 'ea702d75cc2258d9d7dd35ca8e5e2539d71f3140',
        'timestamps': [rows[i]['timestamp'] for i in selected],
        'original_indices': selected, 'series': [float(rows[i]['value']) for i in selected]}
(root/'web/data/machine_temperature.json').write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
print(f'{len(rows)} original samples -> {len(selected)} displayed samples (every 10th, no averaging)')
