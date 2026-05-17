/* ─── MLB Phrase Book — Service Worker ───
   キャッシュ戦略:
   - アプリ本体 (index.html / アイコン) → Cache First（オフライン対応）
   - CDN ライブラリ (React / Babel)     → Cache First（初回のみ取得・以後キャッシュ）
   - 翻訳 / 辞書 API                   → Network Only（オンライン時のみ）
─────────────────────────────────────── */
const CACHE_NAME = "mlb-phrase-v1";

const PRECACHE_URLS = [
  "./index.html",
  "./manifest.json",
  "./icon.svg",
];

const CDN_HOSTS = [
  "unpkg.com",
];

const API_HOSTS = [
  "api.mymemory.translated.net",
  "api.dictionaryapi.dev",
];

/* インストール時: アプリ本体をキャッシュ */
self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
  );
});

/* アクティベート時: 古いキャッシュを削除 */
self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

/* フェッチ */
self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);

  /* 翻訳・辞書 API → ネットワークのみ（失敗してもアプリは壊れない） */
  if (API_HOSTS.some((h) => url.hostname.includes(h))) return;

  /* CDN / アプリ本体 → Cache First */
  e.respondWith(
    caches.match(e.request).then((cached) => {
      if (cached) return cached;
      return fetch(e.request).then((res) => {
        /* 成功したレスポンスはキャッシュに保存 */
        if (res && res.ok) {
          const clone = res.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(e.request, clone));
        }
        return res;
      }).catch(() => {
        /* オフラインかつキャッシュなし → index.html にフォールバック */
        if (e.request.destination === "document") {
          return caches.match("./index.html");
        }
      });
    })
  );
});
