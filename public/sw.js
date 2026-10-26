/* Bump this version when changing the app shell. API calls are never cached. */
const CACHE = "chess-royale-shell-v5";
const SHELL = [
  "/",
  "/index.html",
  "/app.js",
  "/styles.css",
  "/progression.css",
  "/progression-ui.js",
  "/multiplayer-ui.js",
  "/multiplayer.css",
  "/polish.js",
  "/polish.css",
  "/war-room.css",
  "/art/war-room-fortress.jpg",
  "/art/war-room-roles.jpg",
  "/fonts/cinzel-600.ttf",
  "/fonts/inter-400.ttf",
  "/fonts/inter-600.ttf",
  "/translations.js",
  "/art/eldrin.svg",
  "/frame.js",
  "/frame.css",
  "/shared/catalog.js",
  "/art/kingdom.svg",
  "/manifest.webmanifest",
  "/icons/icon-192.png",
  "/icons/icon-512.png",
  "/icons/icon-maskable-512.png",
  "/icons/icon.svg",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      // Optional assets must not prevent an otherwise usable app from installing.
      await Promise.allSettled(
        SHELL.map(async (url) => {
          const response = await fetch(new Request(url, { cache: "reload" }));
          if (response.ok) await cache.put(url, response);
        }),
      );
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter(
            (key) => key.startsWith("chess-royale-shell-") && key !== CACHE,
          )
          .map((key) => caches.delete(key)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("message", (event) => {
  if (event.data?.type === "SKIP_WAITING") self.skipWaiting();
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (
    request.method !== "GET" ||
    url.origin !== self.location.origin ||
    url.pathname === "/api" ||
    url.pathname.startsWith("/api/") ||
    url.pathname === "/sw.js"
  )
    return;
  if (request.mode === "navigate") {
    event.respondWith(
      (async () => {
        const cache = await caches.open(CACHE);
        try {
          const response = await fetch(request);
          if (response.ok) await cache.put("/", response.clone());
          return response;
        } catch {
          return (
            (await cache.match("/")) ||
            (await cache.match("/index.html")) ||
            new Response(
              '<!doctype html><html lang="de"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Chess Royale · Offline</title><body style="font-family:system-ui;background:#121821;color:#e8eddf;padding:48px 24px"><h1>Deine Arena wartet.</h1><p>Du bist gerade offline. Öffne Chess Royale einmal mit Internetverbindung, um die App zu speichern.</p><button onclick="location.reload()" style="padding:14px 22px;border:0;border-radius:8px;background:#d6ec9b">Erneut versuchen</button></body></html>',
              {
                status: 503,
                headers: { "Content-Type": "text/html; charset=utf-8" },
              },
            )
          );
        }
      })(),
    );
    return;
  }
  if (
    !["script", "style", "image", "font", "manifest"].includes(
      request.destination,
    )
  )
    return;
  // Named app files revalidate so a new deployment never waits for a cache bump.
  // Content-hashed assets are immutable and may be served cache-first.
  const immutable = /[.-][a-f0-9]{8,}\./i.test(url.pathname);
  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      const cached = await cache.match(request);
      if (immutable && cached) return cached;
      try {
        const response = await fetch(request);
        if (response.ok && response.type === "basic")
          await cache.put(request, response.clone());
        return response;
      } catch {
        return cached || Response.error();
      }
    })(),
  );
});
