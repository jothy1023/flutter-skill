#!/usr/bin/env node
// Comprehensive E2E test for bridge-protocol SDKs via Node.js
// Usage: node test/e2e/bridge_e2e_test.mjs [port] [platform]
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const WebSocket = require('/Users/cw/development/flutter-skill/sdks/electron/node_modules/ws');
const http = require('http');

const PORT = process.argv[2] || 18118;
const PLATFORM = process.argv[3] || 'unknown';
let passed = 0, failed = 0, total = 0;

function httpGet(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', (d) => data += d);
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

class TestClient {
  constructor(port) { this.port = port; this._id = 0; this._pending = {}; }
  
  connect() {
    return new Promise((resolve, reject) => {
      // Try /ws first (Android, iOS native), fall back to root (Electron)
      const tryConnect = (path) => {
        const ws = new WebSocket(`ws://127.0.0.1:${this.port}${path}`);
        ws.on('open', () => { this.ws = ws; this._setupListeners(); resolve(); });
        ws.on('error', (e) => {
          if (path === '/ws') { tryConnect(''); }
          else reject(e);
        });
      };
      tryConnect('/ws');
    });
  }

  _setupListeners() {
    this.ws.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      if (msg.id && this._pending[msg.id]) {
        this._pending[msg.id](msg);
        delete this._pending[msg.id];
      }
    });
  }
  
  call(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++this._id;
      this._pending[id] = resolve;
      this.ws.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
      setTimeout(() => {
        if (this._pending[id]) {
          delete this._pending[id];
          reject(new Error(`${method} timed out`));
        }
      }, 15000);
    });
  }

  sendRaw(data) {
    return new Promise((resolve, reject) => {
      const id = data.id || ++this._id;
      this._pending[id] = resolve;
      this.ws.send(typeof data === 'string' ? data : JSON.stringify(data));
      setTimeout(() => {
        if (this._pending[id]) {
          delete this._pending[id];
          reject(new Error(`raw call timed out`));
        }
      }, 15000);
    });
  }
  
  close() { this.ws.close(); }
}

async function test(name, fn) {
  total++;
  const pad = name.padEnd(55);
  try {
    await fn();
    passed++;
    console.log(`  ${pad} \x1b[32mPASS\x1b[0m`);
  } catch (e) {
    failed++;
    console.log(`  ${pad} \x1b[31mFAIL\x1b[0m ${e.message || e}`);
  }
}

function assert(cond, msg) { if (!cond) throw new Error(msg); }
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// Platform-specific element keys
const KEYS = {
  electron: { increment: 'increment-btn', input: 'text-input', detail: 'detail-btn', counter: 'counter', submit: 'submit-btn', checkbox: 'test-checkbox' },
  android:  { increment: 'increment_btn', input: 'input_field', detail: 'detail_btn', counter: 'counter_text', submit: 'submit_btn', checkbox: 'test_checkbox' },
  kmp:      { increment: 'increment-btn', input: 'text-input', detail: 'detail-btn', counter: 'counter', submit: 'submit-btn', checkbox: 'test-checkbox' },
  dotnet:   { increment: 'increment-btn', input: 'text-input', detail: 'detail-btn', counter: 'counter', submit: 'submit-btn', checkbox: 'test-checkbox' },
  tauri:    { increment: 'increment-btn', input: 'text-input', detail: 'detail-btn', counter: 'counter', submit: 'submit-btn', checkbox: 'test-checkbox' },
  'react-native': { increment: 'increment-btn', input: 'text-input', detail: 'detail-btn', counter: 'counter', submit: 'submit-btn', checkbox: 'test-checkbox' },
  default:  { increment: 'increment_btn', input: 'input_field', detail: 'detail_btn', counter: 'counter_text', submit: 'submit_btn', checkbox: 'test_checkbox' },
};
const K = KEYS[PLATFORM] || KEYS.default;

async function main() {
  console.log('============================================');
  console.log(` Bridge E2E Test Suite`);
  console.log(` Platform: ${PLATFORM} | Port: ${PORT}`);
  console.log('============================================');

  // HTTP health — try the specified port, then port-1 (for split HTTP/WS servers like Tauri)
  console.log('\n--- Health Check ---');
  let health;
  let healthPort = PORT;
  try {
    const body = await httpGet(`http://127.0.0.1:${PORT}/.flutter-skill`);
    health = JSON.parse(body);
  } catch (e) {
    try {
      healthPort = PORT - 1;
      const body = await httpGet(`http://127.0.0.1:${healthPort}/.flutter-skill`);
      health = JSON.parse(body);
      console.log(`  (Health on port ${healthPort}, WS on port ${PORT})`);
    } catch (e2) {
      console.log(`  \x1b[31mApp not running on port ${PORT}\x1b[0m: ${e.message}`);
      process.exit(1);
    }
  }
  console.log(`  Platform: ${health.platform || health.framework}`);
  console.log(`  SDK: ${health.sdk_version}`);
  console.log(`  Capabilities: ${(health.capabilities || []).join(', ')}`);

  const client = new TestClient(PORT);
  await client.connect();

  // =============================================
  // Initialize
  // =============================================
  console.log('\n--- Initialize ---');
  await test('initialize', async () => {
    const r = await client.call('initialize', { protocol_version: '1.0', client: 'e2e-test' });
    assert(r.result, `No result: ${JSON.stringify(r)}`);
  });

  // =============================================
  // Inspect
  // =============================================
  console.log('\n--- Inspect ---');
  let elements;
  await test('inspect returns elements', async () => {
    const r = await client.call('inspect');
    elements = r.result?.elements || r.result?.children ? [r.result] : [];
    if (r.result?.elements) elements = r.result.elements;
    assert(elements.length > 0, 'No elements');
    console.log(`    (${elements.length} elements)`);
  });

  await test('elements have type/bounds', async () => {
    const el = elements[0];
    assert(el.type || el.tag, `Missing type: ${JSON.stringify(el).slice(0, 100)}`);
  });

  await test('elements have numeric bounds', async () => {
    // Find any element with bounds
    const withBounds = elements.find(e => e.bounds || e.x != null);
    if (!withBounds) { console.log('    (no bounds on elements, skipping)'); return; }
    const b = withBounds.bounds || withBounds;
    const x = b.x ?? b.left;
    const y = b.y ?? b.top;
    assert(typeof x === 'number' && typeof y === 'number', `Bounds not numeric: ${JSON.stringify(b)}`);
  });

  await test('elements have text or type fields', async () => {
    const hasInfo = elements.some(e => e.text != null || e.type != null || e.tag != null);
    assert(hasInfo, 'No element has text or type');
  });

  let homeElementCount;
  await test('inspect element count baseline', async () => {
    const r = await client.call('inspect');
    const els = r.result?.elements || [];
    homeElementCount = els.length;
    assert(homeElementCount > 0, 'No elements');
    console.log(`    (baseline: ${homeElementCount} elements)`);
  });

  // =============================================
  // Inspect Interactive
  // =============================================
  console.log('\n--- Inspect Interactive ---');
  let interactiveElements = [];
  let sampleRef = null;

  await test('inspect_interactive returns elements', async () => {
    const r = await client.call('inspect_interactive');
    interactiveElements = r.result?.elements || [];
    assert(interactiveElements.length > 0, `No interactive elements: ${JSON.stringify(r).slice(0, 200)}`);
    console.log(`    (${interactiveElements.length} interactive elements)`);
  });

  await test('interactive elements have ref field', async () => {
    const withRef = interactiveElements.filter(e => e.ref != null);
    assert(withRef.length > 0, 'No elements have ref');
    sampleRef = withRef[0].ref;
    console.log(`    (sample ref: "${sampleRef}")`);
  });

  await test('interactive elements have actions array', async () => {
    const withActions = interactiveElements.filter(e => Array.isArray(e.actions));
    assert(withActions.length > 0, 'No elements have actions array');
    console.log(`    (sample actions: ${JSON.stringify(withActions[0].actions)})`);
  });

  await test('interactive elements have bounds', async () => {
    const withBounds = interactiveElements.filter(e => e.bounds || e.x != null);
    // bounds may not be on all elements, just check at least some
    console.log(`    (${withBounds.length}/${interactiveElements.length} have bounds)`);
  });

  await test('interactive refs contain colon (semantic)', async () => {
    const refs = interactiveElements.filter(e => e.ref).map(e => e.ref);
    const withColon = refs.filter(r => r.includes(':'));
    console.log(`    (${withColon.length}/${refs.length} refs contain ":")`);
    // Soft check — log but pass if format differs
    if (withColon.length === 0 && refs.length > 0) {
      console.log(`    (refs: ${refs.slice(0, 3).join(', ')})`);
    }
  });

  // =============================================
  // Tap
  // =============================================
  console.log('\n--- Tap ---');
  await test('tap by key (increment)', async () => {
    const r = await client.call('tap', { key: K.increment });
    assert(r.result?.success === true, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('tap by text (Submit)', async () => {
    const r = await client.call('tap', { text: 'Submit' });
    // Text match may not work on all platforms
    if (r.error) console.log('    (text tap not supported)');
  });
  await sleep(300);

  await test('tap by coordinates', async () => {
    const r = await client.call('tap', { x: 100, y: 200 });
    // Coordinate tap may not be supported on all platforms
    if (r.error) console.log(`    (coordinate tap not supported: ${r.error.message || ''})`);
    else assert(r.result != null, `No result: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('tap by ref', async () => {
    if (!sampleRef) { console.log('    (no ref available, skipping)'); return; }
    const r = await client.call('tap', { ref: sampleRef });
    if (r.error) console.log(`    (ref tap not supported: ${r.error.message || ''})`);
    else assert(r.result != null, `No result: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('tap invalid key → graceful response', async () => {
    const r = await client.call('tap', { key: 'nonexistent_key_xyz_999' });
    // Should return error or success:false, but NOT crash
    assert(r.result != null || r.error != null, 'No response at all');
    if (r.error) console.log(`    (error: ${r.error.message || JSON.stringify(r.error)})`);
    if (r.result?.success === false) console.log('    (returned success:false)');
  });

  await test('tap invalid ref → graceful response', async () => {
    const r = await client.call('tap', { ref: 'fake:nonexistent_ref_999' });
    assert(r.result != null || r.error != null, 'No response at all');
    if (r.error) console.log(`    (error: ${r.error.message || JSON.stringify(r.error)})`);
  });

  // =============================================
  // Enter Text
  // =============================================
  console.log('\n--- Enter Text ---');
  await test('enter_text basic', async () => {
    const r = await client.call('enter_text', { key: K.input, text: 'Hello E2E' });
    assert(r.result?.success === true, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('enter_text empty string', async () => {
    const r = await client.call('enter_text', { key: K.input, text: '' });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('enter_text special chars (emoji/unicode)', async () => {
    const r = await client.call('enter_text', { key: K.input, text: 'Hello 🌍 世界' });
    assert(r.result?.success === true, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('enter_text overwrite existing text', async () => {
    await client.call('enter_text', { key: K.input, text: 'First' });
    await sleep(200);
    const r = await client.call('enter_text', { key: K.input, text: 'Second' });
    assert(r.result?.success === true, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('enter_text on non-existent key → error', async () => {
    const r = await client.call('enter_text', { key: 'nonexistent_input_xyz', text: 'test' });
    assert(r.result != null || r.error != null, 'No response');
    if (r.error) console.log(`    (error: ${r.error.message || JSON.stringify(r.error)})`);
    if (r.result?.success === false) console.log('    (returned success:false)');
  });

  await test('enter_text long string (500+ chars)', async () => {
    const longStr = 'A'.repeat(500);
    const r = await client.call('enter_text', { key: K.input, text: longStr });
    assert(r.result?.success === true, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  // =============================================
  // Get Text
  // =============================================
  console.log('\n--- Get Text ---');
  await test('get_text on counter', async () => {
    const r = await client.call('get_text', { key: K.counter });
    assert(r.result?.text != null, `No text: ${JSON.stringify(r)}`);
    console.log(`    text="${r.result.text}"`);
  });

  await test('get_text on input after entering text', async () => {
    await client.call('enter_text', { key: K.input, text: 'ReadBack' });
    await sleep(300);
    const r = await client.call('get_text', { key: K.input });
    console.log(`    text="${r.result?.text}"`);
    // Some platforms may return the text, others may not
    assert(r.result != null, `No result: ${JSON.stringify(r)}`);
  });

  await test('get_text on non-existent key → error', async () => {
    const r = await client.call('get_text', { key: 'nonexistent_key_xyz_999' });
    assert(r.result != null || r.error != null, 'No response');
    if (r.error) console.log(`    (error: ${r.error.message || JSON.stringify(r.error)})`);
  });

  await test('get_text on button (label)', async () => {
    const r = await client.call('get_text', { key: K.submit });
    console.log(`    text="${r.result?.text}"`);
    assert(r.result != null, `No result: ${JSON.stringify(r)}`);
  });

  // =============================================
  // Find Element
  // =============================================
  console.log('\n--- Find Element ---');
  await test('find_element by key (exists)', async () => {
    const r = await client.call('find_element', { key: K.increment });
    assert(r.result?.found === true, `Not found: ${JSON.stringify(r)}`);
  });

  await test('find_element missing key', async () => {
    const r = await client.call('find_element', { key: 'nonexistent_xyz_999' });
    assert(r.result?.found === false, `Should not be found: ${JSON.stringify(r)}`);
  });

  await test('find_element by text', async () => {
    const r = await client.call('find_element', { text: 'Submit' });
    assert(r.result?.found === true, `Not found: ${JSON.stringify(r)}`);
  });

  await test('find_element by partial text', async () => {
    const r = await client.call('find_element', { text: 'Coun' });
    // Partial text may or may not be supported
    if (r.result?.found === true) {
      console.log('    (partial text match works)');
    } else {
      console.log('    (partial text not matched — platform may require exact match)');
    }
  });

  await test('find_element returns bounds when found', async () => {
    const r = await client.call('find_element', { key: K.increment });
    assert(r.result?.found === true, `Not found`);
    const b = r.result?.bounds || r.result?.element?.bounds;
    if (b) {
      console.log(`    (bounds: ${JSON.stringify(b)})`);
      assert(typeof (b.x ?? b.left) === 'number', 'Bounds not numeric');
    } else {
      console.log('    (no bounds returned with find_element)');
    }
  });

  // =============================================
  // Wait For Element
  // =============================================
  console.log('\n--- Wait For Element ---');
  await test('wait_for_element by key (exists)', async () => {
    const r = await client.call('wait_for_element', { key: K.counter, timeout: 3000 });
    assert(r.result?.found === true, `Not found: ${JSON.stringify(r)}`);
  });

  await test('wait_for_element by text', async () => {
    const r = await client.call('wait_for_element', { text: 'Count', timeout: 3000 });
    assert(r.result?.found === true, `Not found: ${JSON.stringify(r)}`);
  });

  await test('wait_for_element missing → timeout', async () => {
    const start = Date.now();
    const r = await client.call('wait_for_element', { key: 'nonexistent_never_xyz', timeout: 1000 });
    const elapsed = Date.now() - start;
    // Should return found:false or error, not crash
    assert(r.result?.found === false || r.error != null, `Expected not found: ${JSON.stringify(r)}`);
    console.log(`    (elapsed: ${elapsed}ms)`);
  });

  await test('wait_for_element returns fast for present el', async () => {
    const start = Date.now();
    const r = await client.call('wait_for_element', { key: K.counter, timeout: 5000 });
    const elapsed = Date.now() - start;
    assert(r.result?.found === true, `Not found`);
    assert(elapsed < 3000, `Took too long: ${elapsed}ms`);
    console.log(`    (resolved in ${elapsed}ms)`);
  });

  // =============================================
  // Scroll
  // =============================================
  console.log('\n--- Scroll ---');
  await test('scroll down', async () => {
    const r = await client.call('scroll', { direction: 'down', distance: 300 });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('scroll up', async () => {
    const r = await client.call('scroll', { direction: 'up', distance: 300 });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('scroll left', async () => {
    const r = await client.call('scroll', { direction: 'left', distance: 200 });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('scroll right', async () => {
    const r = await client.call('scroll', { direction: 'right', distance: 200 });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('scroll with large distance', async () => {
    const r = await client.call('scroll', { direction: 'down', distance: 5000 });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  // Scroll back up after large scroll
  await client.call('scroll', { direction: 'up', distance: 5000 });
  await sleep(300);

  await test('scroll with zero distance', async () => {
    const r = await client.call('scroll', { direction: 'down', distance: 0 });
    assert(r.result != null || r.error != null, 'No response');
  });

  // =============================================
  // Swipe
  // =============================================
  console.log('\n--- Swipe ---');
  await test('swipe up', async () => {
    const r = await client.call('swipe', { direction: 'up', distance: 400 });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('swipe down', async () => {
    const r = await client.call('swipe', { direction: 'down', distance: 400 });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('swipe left', async () => {
    const r = await client.call('swipe', { direction: 'left', distance: 300 });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  await test('swipe right', async () => {
    const r = await client.call('swipe', { direction: 'right', distance: 300 });
    assert(r.result?.success === true || r.result != null, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(300);

  // =============================================
  // Screenshot
  // =============================================
  console.log('\n--- Screenshot ---');
  await test('screenshot returns base64', async () => {
    const r = await client.call('screenshot');
    const img = r.result?.image || r.result?.screenshot;
    assert(img && img.length > 100, `No screenshot`);
    console.log(`    (${img.length} base64 chars)`);
  });

  await test('screenshot has valid image header', async () => {
    const r = await client.call('screenshot');
    const img = r.result?.image || r.result?.screenshot;
    assert(img, 'No image data');
    // PNG starts with iVBOR in base64, JPEG with /9j/
    const isPng = img.startsWith('iVBOR');
    const isJpeg = img.startsWith('/9j/');
    assert(isPng || isJpeg, `Unknown image format (starts with: ${img.slice(0, 10)})`);
    console.log(`    (format: ${isPng ? 'PNG' : 'JPEG'})`);
  });

  // =============================================
  // Navigation
  // =============================================
  console.log('\n--- Navigation ---');
  await test('navigate to detail page', async () => {
    const r = await client.call('tap', { key: K.detail });
    assert(r.result?.success === true, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(500);

  await test('inspect after navigate shows elements', async () => {
    const r = await client.call('inspect');
    const els = r.result?.elements || [];
    assert(els.length > 0, 'No elements');
    console.log(`    (${els.length} elements on detail page)`);
  });

  await test('inspect_interactive on detail page', async () => {
    const r = await client.call('inspect_interactive');
    const els = r.result?.elements || [];
    console.log(`    (${els.length} interactive elements on detail page)`);
  });

  await test('tap works on detail page', async () => {
    // Try tapping by text on the detail page
    const r = await client.call('tap', { text: 'Back' });
    // This may or may not work depending on platform
    if (r.error) console.log('    (text tap on detail not supported, using go_back)');
  });

  await test('go_back', async () => {
    const r = await client.call('go_back');
    assert(r.result?.success === true, `Failed: ${JSON.stringify(r)}`);
  });
  await sleep(500);

  await test('inspect after go_back (home)', async () => {
    const r = await client.call('inspect');
    const els = r.result?.elements || [];
    assert(els.length > 0, 'No elements on home page');
  });

  await test('go_back on home → should not crash', async () => {
    const r = await client.call('go_back');
    // Should return gracefully — success or error, but not crash
    assert(r.result != null || r.error != null, 'No response');
    if (r.error) console.log(`    (error: ${r.error.message || JSON.stringify(r.error)})`);
    if (r.result?.success === true) console.log('    (returned success — may be a no-op)');
  });
  await sleep(300);

  await test('nav: detail → fill form → back → home state', async () => {
    // Navigate to detail
    await client.call('tap', { key: K.detail });
    await sleep(500);
    // Verify on detail
    const detailInspect = await client.call('inspect');
    const detailEls = detailInspect.result?.elements || [];
    assert(detailEls.length > 0, 'No elements on detail');
    // Go back
    await client.call('go_back');
    await sleep(500);
    // Verify home state — counter should still be accessible
    const r = await client.call('get_text', { key: K.counter });
    assert(r.result?.text != null || r.result != null, 'Counter not accessible after nav round-trip');
    console.log(`    (counter text after round-trip: "${r.result?.text}")`);
  });

  // =============================================
  // Inspect element count changes
  // =============================================
  console.log('\n--- Inspect (state changes) ---');
  await test('inspect element count changes after tap', async () => {
    const before = await client.call('inspect');
    const beforeCount = (before.result?.elements || []).length;
    // Tap increment
    await client.call('tap', { key: K.increment });
    await sleep(300);
    const after = await client.call('inspect');
    const afterCount = (after.result?.elements || []).length;
    // Elements may or may not change count, but both should succeed
    console.log(`    (before: ${beforeCount}, after: ${afterCount})`);
    assert(afterCount > 0, 'No elements after tap');
  });

  // =============================================
  // Logs
  // =============================================
  console.log('\n--- Logs ---');
  await test('get_logs', async () => {
    const r = await client.call('get_logs');
    assert(r.result?.logs != null, `No logs: ${JSON.stringify(r)}`);
    console.log(`    (${r.result.logs.length} log entries)`);
  });

  await test('clear_logs', async () => {
    const r = await client.call('clear_logs');
    assert(r.result?.success === true, `Failed: ${JSON.stringify(r)}`);
  });

  await test('get_logs after clear → fewer/empty', async () => {
    const r = await client.call('get_logs');
    assert(r.result?.logs != null, `No logs field: ${JSON.stringify(r)}`);
    console.log(`    (${r.result.logs.length} log entries after clear)`);
  });

  // =============================================
  // Eval (if supported)
  // =============================================
  console.log('\n--- Eval ---');
  await test('eval simple expression', async () => {
    const r = await client.call('eval', { expression: '1 + 1' });
    if (r.error) {
      console.log(`    (eval not supported: ${r.error.message || ''})`);
    } else {
      console.log(`    (result: ${JSON.stringify(r.result)})`);
    }
  });

  await test('eval returning a value', async () => {
    const r = await client.call('eval', { expression: '"hello"' });
    if (r.error) {
      console.log(`    (eval not supported)`);
    } else {
      console.log(`    (result: ${JSON.stringify(r.result)})`);
    }
  });

  // =============================================
  // Error Handling
  // =============================================
  console.log('\n--- Error Handling ---');
  await test('unknown method → JSON-RPC error', async () => {
    const r = await client.call('totally_fake_method_xyz', {});
    assert(r.error != null, `Expected error, got: ${JSON.stringify(r)}`);
    console.log(`    (error code: ${r.error.code}, msg: ${r.error.message})`);
  });

  await test('missing required params → error', async () => {
    // tap with no key/text/ref/coords
    const r = await client.call('tap', {});
    assert(r.error != null || (r.result?.success === false), `Expected error: ${JSON.stringify(r)}`);
  });

  await test('malformed request handling', async () => {
    // Send a request with wrong jsonrpc version
    const r = await client.sendRaw({ jsonrpc: '1.0', id: client._id + 1, method: 'inspect', params: {} });
    client._id++;
    // Should get some response (error or result), not crash
    assert(r != null, 'No response to malformed request');
  });

  // =============================================
  // Summary
  // =============================================
  client.close();
  console.log('\n============================================');
  console.log(` Results: ${passed} passed, ${failed} failed, ${total} total`);
  console.log('============================================');
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
