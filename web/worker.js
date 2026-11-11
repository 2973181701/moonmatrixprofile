import { analyze } from './core.js';
self.onmessage = ({ data: { id, request } }) => {
  const start = performance.now();
  try {
    const result = JSON.parse(analyze(JSON.stringify(request)));
    self.postMessage({ id, result, milliseconds: performance.now() - start });
  } catch (error) {
    self.postMessage({ id, result: { ok: false, error: { code: 'E_HOST', message: error.message } } });
  }
};
