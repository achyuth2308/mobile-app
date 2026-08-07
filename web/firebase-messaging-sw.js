importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: 'AIzaSyA_dummy_web_key_replace_me',
  appId: '1:1234567890:web:dummy123456789',
  messagingSenderId: '1234567890',
  projectId: 'fueltracks1',
  authDomain: 'fueltracks1.firebaseapp.com',
  storageBucket: 'fueltracks1.appspot.com',
});

const messaging = firebase.messaging();
