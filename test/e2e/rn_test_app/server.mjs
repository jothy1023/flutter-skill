/**
 * Node.js test server that simulates the React Native FlutterSkill bridge.
 * Uses the same protocol logic as the RN SDK but with Node.js net/crypto modules.
 * This validates the bridge protocol without requiring a full RN build.
 */
import { createServer } from 'net';
import { createHash } from 'crypto';

const PORT = 18118;
const SDK_VERSION = '1.0.0';

// --- Simulated UI State ---
let counter = 0;
let inputText = '';
let currentPage = 'home';
let logs = [];

function buildElements() {
  if (currentPage === 'detail') {
    return [
      { type: 'text', key: 'detail-title', text: 'Detail Page', bounds: {x:20,y:100,width:300,height:40}, visible: true, enabled: true, clickable: false },
      { type: 'text', key: 'detail-counter', text: `Counter: ${counter}`, bounds: {x:20,y:150,width:200,height:30}, visible: true, enabled: true, clickable: false },
      { type: 'button', key: 'back-btn', text: 'Go Back', bounds: {x:20,y:200,width:100,height:40}, visible: true, enabled: true, clickable: true },
    ];
  }
  const els = [
    { type: 'text', key: 'counter', text: `Count: ${counter}`, bounds: {x:20,y:100,width:200,height:40}, visible: true, enabled: true, clickable: false },
    { type: 'button', key: 'increment-btn', text: 'Increment', bounds: {x:20,y:160,width:120,height:40}, visible: true, enabled: true, clickable: true },
    { type: 'button', key: 'decrement-btn', text: 'Decrement', bounds: {x:150,y:160,width:120,height:40}, visible: true, enabled: true, clickable: true },
    { type: 'text_field', key: 'text-input', text: inputText, bounds: {x:20,y:220,width:250,height:40}, visible: true, enabled: true, clickable: true },
    { type: 'button', key: 'submit-btn', text: 'Submit', bounds: {x:280,y:220,width:80,height:40}, visible: true, enabled: true, clickable: true },
    { type: 'checkbox', key: 'test-checkbox', text: 'Toggle me', bounds: {x:20,y:280,width:150,height:30}, visible: true, enabled: true, clickable: true },
    { type: 'button', key: 'detail-btn', text: 'Go to Detail', bounds: {x:20,y:330,width:150,height:40}, visible: true, enabled: true, clickable: true },
  ];
  for (let i = 0; i < 20; i++) {
    els.push({ type: 'text', key: `item-${i}`, text: `Item ${i+1}`, bounds: {x:20,y:390+i*35,width:300,height:30}, visible: true, enabled: true, clickable: false });
  }
  return els;
}

function findByKey(key) { return buildElements().find(e => e.key === key); }
function findByText(text) { return buildElements().find(e => e.text && e.text.includes(text)); }

// --- JSON-RPC Methods ---
const methods = {
  initialize: () => ({ success: true, framework: 'react-native', sdk_version: SDK_VERSION, platform: 'node-test' }),
  
  inspect: () => ({ elements: buildElements() }),
  
  inspect_interactive: () => {
    const elements = buildElements();
    // Transform elements into interactive format with refs
    const interactiveElements = elements.map((el, index) => ({
      ...el,
      ref: `ref:${el.key}`,
      actions: el.clickable ? ['tap'] : el.type === 'text_field' ? ['tap', 'enter_text'] : [],
      index: index,
      xpath: `//*[@key='${el.key}']`,
      interactable: el.clickable || el.type === 'text_field'
    }));
    return { 
      elements: interactiveElements, 
      interactiveMode: true, 
      refFormat: "key-based",
      totalElements: elements.length 
    };
  },
  
  tap: (p) => {
    let key = p.key || p.selector;
    // Handle ref format: "ref:key" -> "key"
    if (key && key.startsWith('ref:')) {
      key = key.substring(4);
    }
    const el = key ? findByKey(key) : (p.text ? findByText(p.text) : null);
    if (!el) return { success: false, message: 'Element not found' };
    logs.push(`Tapped: ${el.key}`);
    if (el.key === 'increment-btn') { counter++; }
    else if (el.key === 'decrement-btn') { counter--; }
    else if (el.key === 'detail-btn') { currentPage = 'detail'; }
    else if (el.key === 'back-btn') { currentPage = 'home'; }
    return { success: true };
  },
  
  enter_text: (p) => {
    const key = p.key || p.selector;
    const el = key ? findByKey(key) : null;
    if (!el) return { success: false, message: 'Not found' };
    inputText = p.text || '';
    return { success: true };
  },
  
  get_text: (p) => {
    const key = p.key || p.selector;
    const el = key ? findByKey(key) : null;
    return { text: el ? (key === 'text-input' ? inputText : el.text) : null };
  },
  
  find_element: (p) => {
    const key = p.key || p.selector;
    const el = key ? findByKey(key) : (p.text ? findByText(p.text) : null);
    if (el) return { found: true, element: { type: el.type, key: el.key, text: el.text } };
    return { found: false };
  },
  
  wait_for_element: (p) => {
    const key = p.key || p.selector;
    const el = key ? findByKey(key) : (p.text ? findByText(p.text) : null);
    return { found: !!el };
  },
  
  scroll: () => ({ success: true }),
  swipe: () => ({ success: true }),
  
  screenshot: () => {
    // Fake small screenshot
    const png = 'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFklEQVQYV2P8z8BQz0BFwMgwasChAwA3vgX/EPGcywAAAABJRU5ErkJggg==';
    return { success: true, image: png, format: 'png', encoding: 'base64' };
  },
  
  go_back: () => {
    if (currentPage !== 'home') { currentPage = 'home'; return { success: true }; }
    return { success: true };
  },
  
  get_logs: () => ({ logs: logs }),
  clear_logs: () => { logs = []; return { success: true }; },
};

function handleJsonRpc(raw) {
  let req;
  try { req = JSON.parse(raw); } catch { return JSON.stringify({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } }); }
  const fn = methods[req.method];
  if (!fn) return JSON.stringify({ jsonrpc: '2.0', id: req.id, error: { code: -32601, message: `Unknown: ${req.method}` } });
  try {
    const result = fn(req.params || {});
    return JSON.stringify({ jsonrpc: '2.0', id: req.id, result });
  } catch (e) {
    return JSON.stringify({ jsonrpc: '2.0', id: req.id, error: { code: -32000, message: e.message } });
  }
}

// --- WebSocket helpers ---
function decodeFrame(buf) {
  if (buf.length < 2) return null;
  const opcode = buf[0] & 0x0f;
  const masked = (buf[1] & 0x80) !== 0;
  let payloadLen = buf[1] & 0x7f;
  let offset = 2;
  if (payloadLen === 126) { if (buf.length < 4) return null; payloadLen = buf.readUInt16BE(2); offset = 4; }
  else if (payloadLen === 127) { if (buf.length < 10) return null; payloadLen = buf.readUInt32BE(6); offset = 10; }
  let maskKey;
  if (masked) { if (buf.length < offset + 4) return null; maskKey = buf.slice(offset, offset + 4); offset += 4; }
  if (buf.length < offset + payloadLen) return null;
  const payload = Buffer.alloc(payloadLen);
  for (let i = 0; i < payloadLen; i++) payload[i] = masked ? buf[offset + i] ^ maskKey[i % 4] : buf[offset + i];
  return { opcode, payload: payload.toString('utf-8'), totalBytes: offset + payloadLen };
}

function encodeFrame(text) {
  const data = Buffer.from(text, 'utf-8');
  const len = data.length;
  let header;
  if (len < 126) { header = Buffer.alloc(2); header[0] = 0x81; header[1] = len; }
  else if (len < 65536) { header = Buffer.alloc(4); header[0] = 0x81; header[1] = 126; header.writeUInt16BE(len, 2); }
  else { header = Buffer.alloc(10); header[0] = 0x81; header[1] = 127; header.writeUInt32BE(0, 2); header.writeUInt32BE(len, 6); }
  return Buffer.concat([header, data]);
}

// --- TCP Server ---
const server = createServer((socket) => {
  let upgraded = false;
  let wsBuf = Buffer.alloc(0);

  socket.on('data', (data) => {
    if (upgraded) {
      wsBuf = Buffer.concat([wsBuf, data]);
      while (wsBuf.length > 0) {
        const frame = decodeFrame(wsBuf);
        if (!frame) break;
        wsBuf = wsBuf.slice(frame.totalBytes);
        if (frame.opcode === 0x08) { socket.destroy(); return; }
        if (frame.opcode === 0x01) {
          const resp = handleJsonRpc(frame.payload);
          socket.write(encodeFrame(resp));
        }
      }
      return;
    }

    const raw = data.toString('utf-8');
    const lines = raw.split('\r\n');
    const [method, path] = (lines[0] || '').split(' ');
    const headers = {};
    for (let i = 1; i < lines.length; i++) {
      if (lines[i] === '') break;
      const idx = lines[i].indexOf(':');
      if (idx > 0) headers[lines[i].slice(0, idx).trim().toLowerCase()] = lines[i].slice(idx + 1).trim();
    }

    // WebSocket upgrade
    if (headers['upgrade']?.toLowerCase() === 'websocket') {
      const wsKey = headers['sec-websocket-key'];
      const accept = createHash('sha1').update(wsKey + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
      socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
      upgraded = true;
      wsBuf = Buffer.alloc(0);
      return;
    }

    // Health check
    if (method === 'GET' && path === '/.flutter-skill') {
      const body = JSON.stringify({
        framework: 'react-native', app_name: 'RN Test App', platform: 'node-test',
        capabilities: Object.keys(methods), sdk_version: SDK_VERSION
      });
      socket.write(`HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ${Buffer.byteLength(body)}\r\nConnection: close\r\n\r\n${body}`);
      socket.destroy();
      return;
    }

    socket.write('HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n');
    socket.destroy();
  });

  socket.on('error', () => {});
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[flutter-skill-rn] Test bridge on port ${PORT}`);
});
