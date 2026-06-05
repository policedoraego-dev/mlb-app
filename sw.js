// sw.js — キャッシュクリア専用（古いキャッシュを全削除して即アクティブ化）
const CACHE_VERSION = "v3-no-cache";

self.addEventListener("install", () => self.skipWaiting());

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.map(k => {
        console.log("[SW] Deleting cache:", k);
        return caches.delete(k);
      })))
      .then(() => self.clients.claim())
  );
});

// キャッシュしない — 常にネットワーク（ディスク）から取得
self.addEventListener("fetch", e => {
  e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
