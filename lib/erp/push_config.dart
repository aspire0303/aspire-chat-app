import 'package:firebase_core/firebase_core.dart';

// Firebase client settings for push notifications. They identify the app to Firebase and are
// not passwords (the same values ship inside every installed APK).
const aspireFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyC0lEwt1KARrFvh551OP5VPXYFfyVjjg9s',
  appId: '1:238703803499:android:0b2f9be7db82918e59c52e',
  messagingSenderId: '238703803499',
  projectId: 'aspire-messenger',
  storageBucket: 'aspire-messenger.firebasestorage.app',
);
