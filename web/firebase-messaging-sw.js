// Service worker per le notifiche push in background (tab chiusa/minimizzata)
// via Firebase Cloud Messaging sul target Web/PWA. Config pubblica (stessa
// già presente nel bundle compilato, vedi lib/firebase_options.dart) — non
// è una chiave segreta, è protetta dalle Firestore/Functions Rules, non da
// questo valore.
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDU0A5G0DUkPaa-pXk_HzBZtkV0rpuz-sc',
  appId: '1:982110038457:web:a740b3e4cce2c3043aae68',
  messagingSenderId: '982110038457',
  projectId: 'smart-budget-13198',
  authDomain: 'smart-budget-13198.firebaseapp.com',
  storageBucket: 'smart-budget-13198.firebasestorage.app',
});

const messaging = firebase.messaging();
