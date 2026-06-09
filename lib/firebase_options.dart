// ════════════════════════════════════════════════════════════════════════════
//  firebase_options.dart
//
//  HOW TO GENERATE THIS FILE:
//  1. Install FlutterFire CLI:
//       dart pub global activate flutterfire_cli
//
//  2. Run in your project root:
//       flutterfire configure
//
//  3. Select your Firebase project and platforms (web + android + ios).
//     FlutterFire will overwrite this file with real values automatically.
//
//  Until then, the placeholder values below will throw a clear error on startup
//  reminding you to run flutterfire configure.
// ════════════════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.\n'
          'Run: flutterfire configure',
        );
    }
  }

  // ── WEB ──────────────────────────────────────────────────────────────────
  // Replace with values from: Firebase Console → Project Settings → Your apps → Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyBa-lzzRKUb_OdGAkYikwhoGtANnX-n3sY',
    authDomain:        'shreejiharvesthub.firebaseapp.com',
    projectId:         'shreejiharvesthub',
    storageBucket:     'shreejiharvesthub.firebasestorage.app',
    messagingSenderId: '539785745986',
    appId:             '1:539785745986:web:c5892341c2d3a7368affdb',
  );

  // ── ANDROID ───────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBa-lzzRKUb_OdGAkYikwhoGtANnX-n3sY',
    appId:             '1:539785745986:web:c5892341c2d3a7368affdb',
    messagingSenderId: '539785745986',
    projectId:         'shreejiharvesthub',
    storageBucket:     'shreejiharvesthub.firebasestorage.app',
  );

  // ── iOS ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyBa-lzzRKUb_OdGAkYikwhoGtANnX-n3sY',
    appId:             '1:539785745986:web:c5892341c2d3a7368affdb',
    messagingSenderId: '539785745986',
    projectId:         'shreejiharvesthub',
    storageBucket:     'shreejiharvesthub.firebasestorage.app',
    iosBundleId:       'com.example.farmtrackPro',
  );
}
