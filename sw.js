// Haalt alles altijd vers op; bewaart geen voorraadgegevens op het toestel.
self.addEventListener("install", function () { self.skipWaiting(); });
self.addEventListener("activate", function (e) { e.waitUntil(self.clients.claim()); });
self.addEventListener("fetch", function (e) {
  if (e.request.mode !== "navigate") return;
  e.respondWith(fetch(e.request).catch(function () {
    return new Response(
      '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<body style="font:16px system-ui;padding:40px 20px;text-align:center;color:#1b1f24">' +
      '<h2>Geen internet</h2><p>Stocktelling heeft een internetverbinding nodig. Probeer het opnieuw zodra je verbonden bent.</p></body>',
      { headers: { "Content-Type": "text/html; charset=utf-8" } }
    );
  }));
});
