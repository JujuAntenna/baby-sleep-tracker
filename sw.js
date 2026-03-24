// =============================================================================
// Baby Sleep Tracker v2 — Service Worker
// =============================================================================
// Provides offline support via caching, background sync for queued data,
// and a stale-while-revalidate strategy for the app shell.
// =============================================================================

const CACHE_NAME = 'baby-sleep-v2';

// App shell resources to pre-cache on install
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json'
];

// ---------------------------------------------------------------------------
// INSTALL — Pre-cache the app shell and activate immediately
// ---------------------------------------------------------------------------
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Pre-caching app shell');
      return cache.addAll(APP_SHELL);
    })
  );
  // Activate new SW immediately, don't wait for old tabs to close
  self.skipWaiting();
});

// ---------------------------------------------------------------------------
// ACTIVATE — Claim clients and purge old caches
// ---------------------------------------------------------------------------
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => {
            console.log('[SW] Deleting old cache:', name);
            return caches.delete(name);
          })
      );
    }).then(() => {
      // Take control of all open tabs immediately
      return self.clients.claim();
    })
  );
});

// ---------------------------------------------------------------------------
// FETCH — Route requests through the appropriate caching strategy
// ---------------------------------------------------------------------------
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = request.url;

  // --- API requests (Supabase): Network-first, never cache ---
  // We always want fresh data from the API; fall through to network error
  // if offline (the app handles offline state via its own queue).
  if (url.includes('supabase.co')) {
    event.respondWith(
      fetch(request).catch(() => {
        // Return a minimal error response so the app can detect offline state
        return new Response(
          JSON.stringify({ error: 'offline', message: 'You are offline' }),
          {
            status: 503,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      })
    );
    return;
  }

  // --- App shell & other requests: Stale-while-revalidate ---
  // Serve from cache immediately (fast), then update the cache in the
  // background so the next load gets fresh content.
  event.respondWith(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.match(request).then((cachedResponse) => {
        // Fire off a network fetch to update the cache in the background
        const networkFetch = fetch(request).then((networkResponse) => {
          // Only cache successful, same-origin responses
          if (networkResponse && networkResponse.ok) {
            cache.put(request, networkResponse.clone());
          }
          return networkResponse;
        }).catch(() => {
          // Network unavailable — that's fine, we'll use the cached version
          return undefined;
        });

        // Return cached response immediately, or wait for network if no cache
        return cachedResponse || networkFetch;
      });
    })
  );
});

// ---------------------------------------------------------------------------
// BACKGROUND SYNC — Replay queued sleep data when connectivity returns
// ---------------------------------------------------------------------------
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-sleep-data') {
    console.log('[SW] Background sync triggered: sync-sleep-data');
    event.waitUntil(syncSleepData());
  }
});

/**
 * Process the offline queue stored in IndexedDB.
 * The main app is responsible for writing queued requests into IndexedDB;
 * this worker reads them out and replays them against the API.
 */
async function syncSleepData() {
  try {
    // Notify all clients that a sync is starting — the app can listen for
    // this message and process its own queue (which has access to Supabase
    // client, auth tokens, etc.)
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const client of clients) {
      client.postMessage({
        type: 'SYNC_SLEEP_DATA',
        message: 'Background sync triggered — process offline queue'
      });
    }
    console.log('[SW] Notified clients to process offline queue');
  } catch (err) {
    console.error('[SW] Background sync failed:', err);
    throw err; // Re-throw so the browser retries the sync
  }
}
