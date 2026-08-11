/**
 * Minimal service worker registration.
 * Skips registration when Flutter bootstraps (flutter_service_worker.js owns "/").
 */
(function () {
  'use strict';

  if (!('serviceWorker' in navigator)) return;

  var isFlutterHost =
    document.querySelector('script[src*="flutter_bootstrap"]') != null;

  if (isFlutterHost) {
    return;
  }

  window.addEventListener('load', function () {
    navigator.serviceWorker
      .register('/sw.js', { scope: '/' })
      .catch(function (err) {
        console.warn('[CafeFlow] sw.js registration failed:', err);
      });
  });
})();
