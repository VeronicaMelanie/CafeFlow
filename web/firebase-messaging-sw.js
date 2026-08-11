/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: 'AIzaSyCP6rZ9RlR-ENLuhIg1ItMQMbrEv5rQX9k',
  projectId: 'cafeflow-5tg',
  messagingSenderId: '360795635337',
  appId: '1:360795635337:web:e9eafcdaa33b23b9001058',
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const title = payload.notification?.title || 'CafeFlow';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'cafeflow-notification',
  };
  return self.registration.showNotification(title, options);
});
