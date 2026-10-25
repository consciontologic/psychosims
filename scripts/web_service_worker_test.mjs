import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { webcrypto } from 'node:crypto';
import vm from 'node:vm';
import test from 'node:test';

const origin = 'https://psychosim.com';
const files = { '/index.html': '<html>Psychosims</html>', '/main.dart.js': 'game', '/assets/font.ttf': 'font' };
const hashes = Object.fromEntries(await Promise.all(Object.entries(files).map(async ([key, value]) => [key,
  Buffer.from(await webcrypto.subtle.digest('SHA-256', new TextEncoder().encode(value))).toString('hex')])));
const source = (await readFile(new URL('../app/web/service_worker.js', import.meta.url), 'utf8'))
  .replace('__BUILD_ID__', 'test-build').replace('__STATIC_RESOURCES__', JSON.stringify(hashes));

function harness({ failPath, corruptPath } = {}) {
  const handlers = new Map();
  const stores = new Map();
  const requested = [];
  const normalize = value => new URL(typeof value === 'string' ? value : value.url, origin).href;
  const caches = {
    open: async name => {
      if (!stores.has(name)) stores.set(name, new Map());
      const data = stores.get(name);
      return {
        put: async (key, response) => data.set(normalize(key), response),
        match: async key => data.get(normalize(key))?.clone(),
        keys: async () => [...data.keys()].map(url => new Request(url)),
      };
    },
    delete: async name => stores.delete(name),
    keys: async () => [...stores.keys()],
  };
  const self = { location: { origin }, registration: { scope: `${origin}/` },
    addEventListener: (kind, callback) => handlers.set(kind, callback),
    clients: { claim: async () => {}, matchAll: async () => [] } };
  vm.runInNewContext(source, { self, caches, URL, Request, Response, Set, Promise, crypto: webcrypto,
    fetch: async request => {
      const url = new URL(typeof request === 'string' ? request : request.url);
      requested.push(request);
      if (url.pathname === failPath) throw new Error('disconnected');
      return new Response(url.pathname === corruptPath ? 'incorrect content' : files[url.pathname], { status: 200 });
    } });
  return { stores, requested, handlers, caches,
    async event(kind, fields = {}) {
      let pending;
      handlers.get(kind)({ ...fields, waitUntil: p => { pending = p; }, respondWith: p => { pending = p; } });
      return pending;
    } };
}

test('installs and verifies the complete inventory before activation', async () => {
  const h = harness(); await h.event('install');
  assert.equal(h.requested.length, Object.keys(files).length);
  assert.equal([...h.stores.values()][0].size, Object.keys(files).length);
  assert.ok(h.requested.every(request => request.credentials === 'omit' && request.cache === 'no-store'));
});
test('partial installs and mismatched asset hashes are rejected and removed', async () => {
  for (const options of [{ failPath: '/main.dart.js' }, { corruptPath: '/main.dart.js' }]) {
    const h = harness(options);
    await assert.rejects(h.event('install'));
    assert.equal(h.stores.size, 0);
  }
});
test('cached root document supports offline hash route reloads', async () => {
  const h = harness(); await h.event('install');
  const request = { url: `${origin}/`, method: 'GET', mode: 'navigate', headers: new Headers() };
  assert.equal(await (await h.event('fetch', { request })).text(), files['/index.html']);
  assert.equal(h.requested.length, 3, 'no network needed after installation');
});
test('API requests, credentials, query strings and unknown paths never enter static cache', async () => {
  const h = harness(); await h.event('install');
  for (const [url, options] of [
    ['https://openrouter.ai/api/v1/chat/completions', { method: 'POST' }],
    [`${origin}/main.dart.js?token=sensitive`, {}],
    [`${origin}/api/state`, {}],
    [`${origin}/main.dart.js`, { headers: { Authorization: 'Bearer example' } }],
    [`${origin}/main.dart.js`, { method: 'POST' }],
  ]) assert.equal(await h.event('fetch', { request: new Request(url, options) }), undefined);
  assert.equal([...h.stores.values()][0].size, 3);
});
test('activation removes only old Psychosims static caches', async () => {
  const h = harness(); await h.event('install');
  await h.caches.open('psychosims-static-previous'); await h.caches.open('other-app-cache');
  await h.event('activate');
  assert.deepEqual(await h.caches.keys(), ['psychosims-static-test-build', 'other-app-cache']);
});
test('ready message reports the fully cached inventory without secrets', async () => {
  const h = harness(); await h.event('install');
  let reply;
  await h.event('message', { data: { type: 'PWA_STATUS' }, ports: [{ postMessage: value => { reply = value; } }] });
  assert.equal(reply.ready, true); assert.equal(reply.resourceCount, 3);
});
test('updates never force activation or interrupt an existing game', () => {
  assert.equal(source.includes('skipWaiting('), false);
});

test('offline returning page checks its active cache even when update fetch fails', async () => {
  const shell = await readFile(new URL('../app/web/pwa.js', import.meta.url), 'utf8');
  const elements = new Map(['#pwa-status', '#pwa-retry', '#pwa-install'].map(id => [id, { addEventListener() {}, textContent: '', hidden: true }]));
  const registration = {
    active: { postMessage: (_message, [port]) => { port.deliver({ ready: true }); } },
    update: async () => { throw new Error('Offline'); }, addEventListener() {},
  };
  const window = { isSecureContext: true, addEventListener() {}, dispatchEvent() {} };
  class Channel {
    constructor() {
      this.port1 = { close() {} };
      this.port2 = { deliver: data => this.port1.onmessage({ data }) };
    }
  }
  vm.runInNewContext(shell, {
    window, document: { querySelector: id => elements.get(id) },
    navigator: { onLine: false, serviceWorker: { getRegistration: async () => registration, register: async () => registration, addEventListener() {} } },
    MessageChannel: Channel, CustomEvent: class {}, setTimeout, clearTimeout,
  });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(window.psychosimsPwa.ready, true);
  assert.equal(window.psychosimsPwa.failed, false);
  assert.match(elements.get('#pwa-status').textContent, /Saved games available/);
});
