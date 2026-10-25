// Generated inventory contains public build assets only. Never cache API data.
const CACHE_NAME = 'psychosims-static-__BUILD_ID__';
const RESOURCES = __STATIC_RESOURCES__;
const ROOT = self.location.origin;

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    try {
      // Await every task before deleting a failed partial install.
      const results = await Promise.allSettled(Object.entries(RESOURCES).map(async ([path, hash]) => {
        const request = new Request(new URL(path, ROOT), { cache: 'no-store', credentials: 'omit' });
        const response = await fetch(request);
        if (!response.ok || response.type === 'opaque') throw new Error('Asset unavailable');
        const digest = await crypto.subtle.digest('SHA-256', await response.clone().arrayBuffer());
        const actual = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
        if (actual !== hash) throw new Error('Asset integrity mismatch');
        await cache.put(new URL(path, ROOT).href, response);
      }));
      if (results.some(result => result.status === 'rejected')) throw new Error('Offline download incomplete');
    } catch (error) {
      await caches.delete(CACHE_NAME);
      throw error;
    }
    // An update waits until every existing game tab is closed. No forced reload.
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith('psychosims-static-') && name !== CACHE_NAME) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== ROOT || url.search ||
      request.headers.has('authorization')) return;
  // Hash routes never reach the server. A path URL is deliberately not rewritten.
  const path = request.mode === 'navigate' && url.pathname === '/' ? '/index.html' : url.pathname;
  if (!Object.hasOwn(RESOURCES, path)) return;
  event.respondWith((async () => {
    const cached = await (await caches.open(CACHE_NAME)).match(new URL(path, ROOT).href);
    // Do not add runtime responses: only install-time verified assets are cached.
    return cached ?? fetch(request);
  })());
});

self.addEventListener('message', event => {
  if (event.data?.type !== 'PWA_STATUS' || !event.ports?.[0]) return;
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    const keys = new Set((await cache.keys()).map(request => new URL(request.url).pathname));
    const ready = Object.keys(RESOURCES).every(path => keys.has(path));
    event.ports[0].postMessage({ ready, resourceCount: keys.size });
  })());
});
