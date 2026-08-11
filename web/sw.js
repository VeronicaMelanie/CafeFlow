/**
 * CafeFlow static PWA service worker (shell + offline fallback).
 *
 * Flutter production builds use flutter_service_worker.js (generated at build time).
 * This worker is registered only when Flutter is not bootstrapping — see register-sw.js.
 *
 * Strategy:
 * - install: precache shell assets
 * - fetch: navigation → network-first with offline.html fallback
 * - fetch: same-origin static → cache-first, then network
 */
'use strict';

const CACHE_VERSION = 'cafeflow-shell-v1';
const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/offline.html',
  '/manifest.json',
  '/pwa-styles.css',
  '/pwa-init.js',
  '/register-sw.js',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/apple-touch-icon-180.png',
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_VERSION).then(function (cache) {
      return cache.addAll(PRECACHE_URLS);
    }).then(function () {
      return self.skipWaiting();
    })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(
        keys
          .filter(function (key) { return key !== CACHE_VERSION; })
          .map(function (key) { return caches.delete(key); })
      );
    }).then(function () {
      return self.clients.claim();
    })
  );
});

function isNavigationRequest(request) {
  return request.mode === 'navigate' ||
    (request.method === 'GET' && request.headers.get('accept') && request.headers.get('accept').includes('text/html'));
}

self.addEventListener('fetch', function (event) {
  var request = event.request;
  if (request.method !== 'GET') return;

  var url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (isNavigationRequest(request)) {
    event.respondWith(
      fetch(request)
        .then(function (response) {
          if (response && response.ok) {
            var copy = response.clone();
            caches.open(CACHE_VERSION).then(function (cache) {
              cache.put(request, copy);
            });
          }
          return response;
        })
        .catch(function () {
          return caches.match(request).then(function (cached) {
            return cached || caches.match('/offline.html');
          });
        })
    );
    return;
  }

  event.respondWith(
    caches.match(request).then(function (cached) {
      if (cached) return cached;
      return fetch(request).then(function (response) {
        if (!response || response.status !== 200 || response.type === 'opaque') {
          return response;
        }
        var copy = response.clone();
        caches.open(CACHE_VERSION).then(function (cache) {
          cache.put(request, copy);
        });
        return response;
      });
    })
  );
});
