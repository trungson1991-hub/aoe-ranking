// Cấu hình Firebase (project aoe-ranking). Dùng cho web (leaderboard vẫn đọc JSON tĩnh,
// Firebase chỉ dùng cho tính năng Giải đấu qua Realtime Database).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// `null` = nền tảng này chưa đăng ký trong Firebase console -> main.dart bỏ
  /// qua initializeApp. Bảng xếp hạng vẫn chạy (đọc JSON tĩnh), chỉ Giải đấu
  /// hiện "không kết nối được máy chủ".
  ///
  /// TUYỆT ĐỐI không mượn cấu hình của nền tảng khác cho nền tảng chưa đăng ký:
  /// SDK native kiểm định dạng `appId` rồi ném NSException, mà try/catch của
  /// Dart KHÔNG bắt được -> app crash ngay khi mở. Thêm nền tảng mới thì đăng
  /// ký app trong Firebase console rồi khai thêm một hằng như `ios` bên dưới.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }

  // Lấy từ GoogleService-Info.plist của app iOS (bundle com.jvbcorp.aoeRanking).
  // apiKey của Firebase là khoá client, vốn nằm công khai trong mọi bản app —
  // chặn truy cập là việc của rules Realtime Database, không phải của khoá này.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB2SCKsjMAumYsrsiRE5XAXfmsElXXZd88',
    appId: '1:662666576557:ios:51f8c94d1d24c17c36fc24',
    messagingSenderId: '662666576557',
    projectId: 'aoe-ranking',
    databaseURL:
        'https://aoe-ranking-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'aoe-ranking.firebasestorage.app',
    iosBundleId: 'com.jvbcorp.aoeRanking',
  );

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
