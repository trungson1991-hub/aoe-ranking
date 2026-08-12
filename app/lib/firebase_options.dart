// Cấu hình Firebase (project aoe-ranking). Dùng cho web (leaderboard vẫn đọc JSON tĩnh,
// Firebase chỉ dùng cho tính năng Giải đấu qua Realtime Database).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCQJ4zKr01HHc-kB2rFt5JJWr4feNmWSCw',
    authDomain: 'aoe-ranking.firebaseapp.com',
    databaseURL:
        'https://aoe-ranking-default-rtdb.asia-southeast1.firebasedatabase.app',
    projectId: 'aoe-ranking',
    storageBucket: 'aoe-ranking.firebasestorage.app',
    messagingSenderId: '662666576557',
    appId: '1:662666576557:web:165692b6c6ebb9e536fc24',
    measurementId: 'G-6QXZRK1FGR',
  );
}
