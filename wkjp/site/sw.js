// wkjp's service worker: lets the app install and open without a network.
//
// The app's own files are network-first, so a deploy shows up on the next
// load, with the last copy as the fallback when offline. The web fonts are
// cached once fetched. Nothing else is touched: WaniKani, Claude, speech,
// recordings and the per-browser files on the server (stats, notebook,
// course, pictures, Anki) always go straight to the network, never a cache.
const CACHE = "wkjp-v1", FONTS = "wkjp-fonts-v1";
const SHELL = ["./", "index.html", "course.json", "bunpro.json", "emoji.json", "manifest.webmanifest",
  "favicon.svg", "favicon-32.png", "apple-touch-icon.png", "icon-192.png", "icon-512.png", "icon-maskable-512.png"];
const shellPaths = new Set(SHELL.map(p => new URL(p, self.registration.scope).pathname));

self.addEventListener("install", e => {
  // each file on its own, so one missing file doesn't stop the install
  e.waitUntil(caches.open(CACHE).then(c => Promise.all(SHELL.map(p => c.add(p).catch(() => {})))));
  self.skipWaiting();
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE && k !== FONTS).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.hostname === "fonts.googleapis.com" || url.hostname === "fonts.gstatic.com") {
    e.respondWith(caches.open(FONTS).then(c => c.match(req).then(hit => hit || fetch(req).then(res => {
      if (res.ok || res.type === "opaque") c.put(req, res.clone());
      return res;
    }))));
    return;
  }
  if (url.origin !== location.origin) return;
  const nav = req.mode === "navigate";
  if (!nav && !shellPaths.has(url.pathname)) return;
  // the page is stored under "./" whatever query it was opened with
  const key = nav ? new URL("./", self.registration.scope).href : req;
  e.respondWith(fetch(req).then(res => {
    if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(key, copy)); }
    return res;
  }).catch(() => caches.match(key, { ignoreSearch: true }).then(hit => hit || caches.match("index.html"))
    .then(hit => hit || new Response("wkjp is offline and hasn't been saved on this device yet.", { status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" } }))));
});
