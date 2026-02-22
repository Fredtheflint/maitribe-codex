const CACHE_VERSION = 3;
const CACHE_NAME = "maitribe-cache-v" + CACHE_VERSION;
const OFFLINE_FALLBACK = "/offline.html";

const CORE_ASSETS = [
  "/",
  "/index.html",
  "/offline.html",
  "/manifest.json",
  "/manifest.webmanifest",
  "/icon.svg",
  "/icons/icon-192x192.svg",
  "/icons/icon-512x512.svg",
  "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.1",
  "https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,300;0,400;0,500;1,400&family=DM+Sans:wght@400;500;700&display=swap"
];

// Static asset extensions for cache-first strategy
const STATIC_EXTENSIONS = /\.(html|css|js|svg|png|jpg|jpeg|webp|woff2?|ico|json|webmanifest)$/i;

// --- Install: pre-cache core assets ---
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(CORE_ASSETS))
      .then(() => self.skipWaiting())
  );
});

// --- Activate: purge old caches, claim clients ---
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

// --- Fetch: cache-first for static, network-first for API ---
self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);

  // Skip SW bypass param
  if (url.searchParams.has("no_sw") && url.searchParams.get("no_sw") === "1") return;

  // Network-first for API calls (Supabase, Gemini, etc.)
  if (url.hostname.includes("supabase") || url.hostname.includes("googleapis.com")) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const cloned = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, cloned)).catch(() => {});
          return response;
        })
        .catch(() => caches.match(request))
    );
    return;
  }

  // Cache-first for static assets (local files + CDN scripts)
  if (STATIC_EXTENSIONS.test(url.pathname) || url.hostname === "cdn.jsdelivr.net") {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached;
        return fetch(request).then((response) => {
          const cloned = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, cloned)).catch(() => {});
          return response;
        });
      }).catch(() => caches.match(OFFLINE_FALLBACK))
    );
    return;
  }

  // Default: network-first with offline fallback
  event.respondWith(
    fetch(request)
      .then((response) => {
        const cloned = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(request, cloned)).catch(() => {});
        return response;
      })
      .catch(() => caches.match(request).then((cached) => cached || caches.match(OFFLINE_FALLBACK)))
  );
});

// --- Push Notifications ---
self.addEventListener("push", (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = {};
  }

  const options = {
    body: data.body || "I am here when you are ready.",
    icon: data.icon || "/icon.svg",
    badge: data.badge || "/icon.svg",
    tag: data.tag || "maitribe",
    data: { url: data.url || "/" },
    silent: data.type === "mindful_reminder"
  };

  event.waitUntil(self.registration.showNotification(data.title || "Mai", options));
});

// --- Notification Click: focus or open app ---
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const targetUrl = event.notification && event.notification.data && event.notification.data.url
    ? event.notification.data.url
    : "/";

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      const existing = windowClients.find((client) => client.url.includes(self.location.origin));
      if (existing) {
        existing.focus();
        existing.navigate(targetUrl);
        return;
      }
      return clients.openWindow(targetUrl);
    })
  );
});
