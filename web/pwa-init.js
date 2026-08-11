/**
 * CafeFlow PWA bootstrap — splash, offline hint, FCM service worker, install detection.
 */
(function () {
  'use strict';

  var SPLASH_ID = 'cafeflow-splash';
  var OFFLINE_BODY_CLASS = 'cafeflow-offline';

  function hideSplash() {
    var splash = document.getElementById(SPLASH_ID);
    if (!splash) return;
    splash.classList.add('cafeflow-splash--hidden');
    setTimeout(function () {
      splash.remove();
    }, 400);
  }

  function updateOfflineState() {
    if (!navigator.onLine) {
      document.body.classList.add(OFFLINE_BODY_CLASS);
    } else {
      document.body.classList.remove(OFFLINE_BODY_CLASS);
    }
  }

  window.addEventListener('online', updateOfflineState);
  window.addEventListener('offline', updateOfflineState);
  updateOfflineState();

  // Expose for Flutter to hide splash after first frame
  window.cafeFlowPwa = {
    hideSplash: hideSplash,
    isStandalone: function () {
      return (
        window.matchMedia('(display-mode: standalone)').matches ||
        window.matchMedia('(display-mode: fullscreen)').matches ||
        window.navigator.standalone === true
      );
    },
    isIos: function () {
      return /iphone|ipad|ipod/i.test(navigator.userAgent);
    },
    shouldShowInstallFlow: function () {
      var params = new URLSearchParams(window.location.search);
      return (
        params.get('install') === '1' ||
        params.get('install') === 'true'
      );
    },
  };

  // FCM uses a dedicated scope — does not conflict with Flutter's service worker (/)
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker
      .register('/firebase-messaging-sw.js', {
        scope: '/firebase-cloud-messaging-push-scope',
      })
      .catch(function () {});
  }

  // Flutter builds register flutter_service_worker.js via flutter_bootstrap.js.
  // register-sw.js handles sw.js for static/non-Flutter previews only.

  // Hide splash when Flutter reports ready (fallback timeout)
  window.addEventListener('flutter-first-frame', hideSplash);
  setTimeout(hideSplash, 12000);

  // Persist ?install=1 for post-login tutorial
  try {
    var qs = new URLSearchParams(window.location.search);
    if (qs.get('install') === '1' || qs.get('install') === 'true') {
      sessionStorage.setItem('cafeflow_show_install', '1');
    }
  } catch (e) {}
})();
