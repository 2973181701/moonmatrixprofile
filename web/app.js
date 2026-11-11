const $ = id => document.getElementById(id);
let worker, nextId = 0, pending = null;
let values = [], metadata = {}, profileResult = null, queryResult = null;
let activeTab = 'discords', selected = null, elapsed = 0, busy = false;
const accent = '#bf603e', ink = '#3b4745', gray = '#8a988b';
function resetWorker() {
  worker?.terminate();
  worker = new Worker('./worker.js', { type: 'module' });
  worker.onmessage = ({ data }) => {
    if (!pending || pending.id !== data.id) return;
    clearTimeout(pending.timer);
    const { resolve, reject } = pending;
    pending = null;
    if (data.result.ok) resolve(data);
    else reject(new Error(`${data.result.error.code} · ${data.result.error.message}`));
  };
  worker.onerror = event => {
    event.preventDefault();
    if (pending) { clearTimeout(pending.timer); pending.reject(new Error('计算核心未能加载。请先运行 npm run build。')); pending = null; }
  };
}
function engine(request) {
  return new Promise((resolve, reject) => {
    const id = ++nextId;
    const timer = setTimeout(() => {
      pending = null; resetWorker(); reject(new Error('计算超过 45 秒，请缩短输入或窗口。'));
    }, 45000);
    pending = { id, resolve, reject, timer };
    $('cancel').hidden = false;
    worker.postMessage({ id, request });
  });
}
function setBusy(value, message = '') {
  busy = value;
  document.body.classList.toggle('busy', value);
  for (const id of ['analyze', 'dataset', 'file', 'column', 'window', 'query', 'export']) $(id).disabled = value;
  $('cancel').hidden = !(value && pending);
  if (message) $('status').textContent = message;
}
function showError(error) { $('error').hidden = false; $('error').textContent = error.message; $('status').textContent = '本次操作未完成，请检查输入。'; }
function clearError() { $('error').hidden = true; $('error').textContent = ''; }
function clearAnalysis() {
  profileResult = null; queryResult = null; selected = null; elapsed = 0;
  $('tab-query').hidden = true; activeTab = 'discords'; render();
}
function synthetic() {
  let state = 73183;
  const random = () => { state = (1664525 * state + 1013904223) >>> 0; return state / 4294967296; };
  const series = Array.from({ length: 768 }, (_, i) => 8 + Math.sin(i / 7.4) + .35 * Math.sin(i / 2.7) + (random() - .5) * .1);
  const motif = Array.from({ length: 48 }, (_, i) => 8 + Math.sin(i * .23) * (1 + .3 * Math.cos(i * .7)));
  for (const start of [96, 336]) series.splice(start, 48, ...motif);
  for (let i = 550; i < 586; i++) series[i] = 8 + (i % 2 ? 1 : -1) * (1 + (i - 550) / 12);
  return { series, name: '有标签合成信号', source: '本项目确定性生成 · seed 73183', stride: 1,
    note: '768 点合成信号；96 / 336 含相同片段，550–585 注入交替扰动。用于解释行为，不代表真实检测精度。' };
}
function setData(data, windowLength = Number($('window').value)) {
  if (!Array.isArray(data.series) || data.series.length < 3 || data.series.length > 5000) throw new Error('交互视图接受 3–5,000 个样本。更长的数据请使用命令行。');
  if (data.series.some(x => x !== null && (typeof x !== 'number' || !Number.isFinite(x)))) throw new Error('数据必须是有限数值或 null。');
  values = data.series; metadata = data;
  $('series-title').textContent = data.name;
  $('source-note').textContent = data.note || data.source || '本地导入数据';
  $('window').max = Math.min(256, Math.max(3, Math.floor(values.length / 3)));
  $('window').min = 3;
  $('window').value = Math.min(windowLength, Number($('window').max));
  $('window-value').textContent = `${$('window').value} 个样本`;
  $('axis-note').textContent = data.stride > 1 ? `每 ${data.stride} 个原始样本取 1 点，共 ${data.original_samples.toLocaleString()} 个原始点；未作平均` : '横轴为从 0 开始的样本位置；点击曲线选择片段';
  clearAnalysis();
}
async function loadPreset() {
  let loaded = false;
  clearError(); setBusy(true, '正在加载数据…');
  try {
    if ($('dataset').value === 'synthetic') setData(synthetic(), 48);
    else {
      const response = await fetch('./data/machine_temperature.json');
      if (!response.ok) throw new Error('真实数据文件加载失败');
      const data = await response.json();
      data.note = 'NAB 工业设备温度 · 原始 22,695 点，每 10 点取 1 点。该视图用于离线探索，不是完整 NAB 基准成绩。';
      setData(data, 48);
    }
    loaded = true;
  } catch (error) { showError(error); }
  finally { setBusy(false); }
  if (loaded) await runAnalysis();
}
async function runAnalysis() {
  clearError(); setBusy(true, '正在比较波形片段… 可随时取消');
  try {
    const { result, milliseconds } = await engine({ series: values, window: Number($('window').value), count: 4 });
    profileResult = result; queryResult = null; elapsed = milliseconds; activeTab = 'discords';
    $('tab-query').hidden = true;
    selected = result.discords[0] || result.motifs[0] || null;
    render();
    $('status').textContent = `分析完成 · ${result.invalid_windows} 个无效窗口 · ${result.unmatched_windows} 个窗口无邻居`;
  } catch (error) { showError(error); }
  finally { setBusy(false); }
}
function hits() {
  if (activeTab === 'query') return queryResult?.matches.map(hit => ({ ...hit, neighbor: queryResult.start })) || [];
  return profileResult?.[activeTab] || [];
}
function renderFindings() {
  for (const tab of ['discords', 'motifs', 'query']) $(`tab-${tab}`).setAttribute('aria-selected', String(activeTab === tab));
  const list = $('findings-list'); list.replaceChildren();
  const candidates = hits();
  if (!candidates.length) {
    const message = document.createElement('p'); message.className = 'empty';
    message.textContent = profileResult ? '当前设置下没有满足条件的片段。可以调整窗口长度后重新分析。' : '运行分析后，这里会列出可查看的片段。';
    list.append(message); return;
  }
  candidates.forEach((hit, i) => {
    const button = document.createElement('button'); button.className = 'hit';
    button.classList.toggle('selected', selected?.index === hit.index && selected?.neighbor === hit.neighbor);
    const rank = document.createElement('span'); rank.className = 'rank'; rank.textContent = String(i + 1).padStart(2, '0');
    const place = document.createElement('span'); place.className = 'place'; place.textContent = `片段 ${hit.index} — ${hit.index + Number($('window').value) - 1}`;
    const small = document.createElement('small'); small.textContent = metadata.timestamps?.[hit.index] || `对比片段起点 ${hit.neighbor}`; place.append(small);
    const score = document.createElement('span'); score.className = 'score'; score.textContent = hit.distance.toFixed(3);
    button.append(rank, place, score);
    button.onclick = () => { selected = hit; render(); };
    list.append(button);
  });
}
function surface(id, height) {
  const canvas = $(id), width = Math.max(200, canvas.getBoundingClientRect().width), dpr = window.devicePixelRatio || 1;
  canvas.style.height = `${height}px`; canvas.width = Math.round(width * dpr); canvas.height = Math.round(height * dpr);
  const ctx = canvas.getContext('2d'); ctx.scale(dpr, dpr);
  return { canvas, ctx, width, height };
}
function draw(id, data, { height, color = ink, highlights = [], other = null, showX = true } = {}) {
  const { ctx, width, height: h } = surface(id, height);
  const left = 43, top = 15, right = 10, bottom = showX ? 27 : 12;
  const all = data.concat(other || []).filter(x => x !== null && Number.isFinite(x));
  let lo = all.length ? Math.min(...all) : 0, hi = all.length ? Math.max(...all) : 1;
  if (hi - lo < 1e-12) { lo -= 1; hi += 1; }
  const padding = (hi - lo) * .1; lo -= padding; hi += padding;
  const x = i => left + (width - left - right) * i / Math.max(1, data.length - 1);
  const y = v => top + (h - top - bottom) * (1 - (v - lo) / (hi - lo));
  ctx.font = '10px Consolas, monospace'; ctx.fillStyle = '#89918b'; ctx.textAlign = 'right';
  for (let i = 0; i < 4; i++) {
    const v = lo + (hi - lo) * i / 3, py = y(v);
    ctx.strokeStyle = '#edf0e9'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(left, py); ctx.lineTo(width - right, py); ctx.stroke();
    ctx.fillText(Math.abs(v) < 1000 ? v.toFixed(1) : v.toExponential(1), left - 9, py + 3);
  }
  if (showX) {
    ctx.textAlign = 'center';
    for (let i = 0; i < 5; i++) { const index = Math.round((data.length - 1) * i / 4); ctx.fillText(String(index), x(index), h - 6); }
  }
  for (const mark of highlights) {
    ctx.fillStyle = mark.color === accent ? 'rgba(191,96,62,.11)' : 'rgba(109,132,111,.10)';
    ctx.fillRect(x(mark.start), top, Math.max(2, x(Math.min(data.length - 1, mark.start + mark.length)) - x(mark.start)), h - top - bottom);
  }
  function line(series, stroke, dashed = false, range = null) {
    ctx.strokeStyle = stroke; ctx.lineWidth = 1.5; ctx.setLineDash(dashed ? [4, 3] : []); ctx.beginPath(); let active = false;
    for (let i = 0; i < series.length; i++) {
      if (range && (i < range.start || i >= range.start + range.length)) { active = false; continue; }
      const value = series[i];
      if (value === null || !Number.isFinite(value)) { active = false; continue; }
      if (!active) { ctx.moveTo(x(i), y(value)); active = true; } else ctx.lineTo(x(i), y(value));
    }
    ctx.stroke(); ctx.setLineDash([]);
  }
  line(data, color);
  for (const mark of highlights) line(data, mark.color, mark.color === gray, mark);
  if (other) line(other, gray, true);
}
function normalize(series) {
  if (series.some(x => x === null)) return series.map(() => null);
  const shifted = series.map(x => x - series[0]), mean = shifted.reduce((a, b) => a + b, 0) / series.length;
  const sigma = Math.sqrt(shifted.reduce((a, b) => a + (b - mean) ** 2, 0) / series.length);
  return shifted.map(x => sigma ? (x - mean) / sigma : 0);
}
function renderCharts() {
  const m = Number($('window').value);
  const highlights = selected ? [{ start: selected.index, length: m, color: accent }, ...(selected.neighbor !== null ? [{ start: selected.neighbor, length: m, color: gray }] : [])] : [];
  draw('signal', values, { height: 238, highlights });
  draw('profile', profileResult?.profile.distances || [], { height: 148, color: accent, highlights: selected ? [{ start: selected.index, length: 1, color: accent }] : [] });
  if (selected?.neighbor !== null && selected?.neighbor !== undefined) {
    draw('comparison', normalize(values.slice(selected.index, selected.index + m)), { height: 154, color: accent, other: normalize(values.slice(selected.neighbor, selected.neighbor + m)) });
    $('comparison-note').textContent = `片段 ${selected.index} 与 ${selected.neighbor} · 标准化距离 ${selected.distance.toFixed(6)}。实线为当前片段，虚线为对比片段。`;
  } else { draw('comparison', [], { height: 154 }); $('comparison-note').textContent = '运行分析后，点击结果查看对比；含缺失值的片段无法比较。'; }
}
function render() {
  $('metric-samples').textContent = values.length ? values.length.toLocaleString() : '—';
  $('metric-window').textContent = profileResult ? profileResult.profile.window : '—';
  $('metric-valid').textContent = profileResult ? profileResult.profile.distances.filter(x => x !== null).length.toLocaleString() : '—';
  $('metric-time').textContent = profileResult ? `${elapsed.toFixed(0)} ms` : '—';
  renderFindings(); renderCharts();
}
$('analyze').onclick = runAnalysis;
$('dataset').onchange = loadPreset;
$('window').oninput = () => { $('window-value').textContent = `${$('window').value} 个样本`; clearAnalysis(); $('status').textContent = '参数已更改，请重新分析。'; };
for (const tab of ['discords', 'motifs', 'query']) $(`tab-${tab}`).onclick = () => { activeTab = tab; selected = hits()[0] || null; render(); };
$('cancel').onclick = () => {
  if (pending) { clearTimeout(pending.timer); pending.reject(new Error('计算已取消')); pending = null; }
  resetWorker(); setBusy(false, '计算已取消。');
};
$('signal').onclick = event => {
  if (!profileResult || busy) return;
  const rect = $('signal').getBoundingClientRect(), m = Number($('window').value);
  const index = Math.max(0, Math.min(values.length - m, Math.round((event.clientX - rect.left - 43) / (rect.width - 53) * (values.length - 1))));
  selected = { index, neighbor: profileResult.profile.indices[index], distance: profileResult.profile.distances[index] };
  render();
};
$('query').onclick = async () => {
  if (!profileResult) { $('status').textContent = '请先运行分析。'; return; }
  const start = selected?.index ?? 0, m = Number($('window').value);
  clearError(); setBusy(true, '正在检索相似波形…');
  try {
    const { result } = await engine({ op: 'query', series: values, query: values.slice(start, start + m), ignore_start: start, count: 4 });
    queryResult = { ...result, start }; activeTab = 'query'; $('tab-query').hidden = false; selected = hits()[0] || null;
    render(); $('status').textContent = `检索完成 · 查询片段起点 ${start}`;
  } catch (error) { showError(error); }
  finally { setBusy(false); }
};
$('file').onchange = async () => {
  const file = $('file').files[0]; if (!file) return;
  clearError(); setBusy(true, '正在读取本地文件…');
  try {
    if (file.size > 8_000_000) throw new Error('文件超过 8 MB');
    const text = await file.text(); let series;
    if (file.name.toLowerCase().endsWith('.json')) series = JSON.parse(text);
    else { const { result } = await engine({ op: 'parse', csv: text, column: $('column').value }); series = result.series; }
    setData({ series, name: file.name, stride: 1, source: '本地导入 · 未上传至服务器' });
    $('status').textContent = '导入完成，请运行分析。';
  } catch (error) { showError(error); }
  finally { setBusy(false); $('file').value = ''; }
};
$('export').onclick = () => {
  if (!profileResult) { $('status').textContent = '请先运行分析。'; return; }
  const { series, ...provenance } = metadata;
  const blob = new Blob([JSON.stringify({ engine: '2973181701/moonmatrixprofile@0.1.0', provenance, result: profileResult, query: queryResult }, null, 2)], { type: 'application/json' });
  const link = document.createElement('a'), url = URL.createObjectURL(blob); link.href = url; link.download = 'moonmatrixprofile-analysis.json'; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
};
new ResizeObserver(() => renderCharts()).observe(document.querySelector('.analysis'));
resetWorker(); loadPreset();
