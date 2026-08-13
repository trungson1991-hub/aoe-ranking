// Cấu hình Firebase (project aoe-ranking). Dùng cho web (leaderboard vẫn đọc JSON tĩnh,
// Firebase chỉ dùng cho tính năng Giải đấu qua Realtime Database).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  /// `null` = nền tảng này chưa đăng ký trong Firebase console -> main.dart bỏ
  /// qua initializeApp. Bảng xếp hạng vẫn chạy (đọc JSON tĩnh), chỉ Giải đấu
  /// hiện "không kết nối được máy chủ".
  ///
  /// TUYỆT ĐỐI không mượn tạm cấu hình `web` cho iOS/Android: SDK native kiểm
  /// định dạng `appId` rồi ném NSException, mà try/catch của Dart KHÔNG bắt
  /// được -> app crash ngay khi mở. Muốn bật Giải đấu trên iOS: đăng ký app
  /// iOS (bundle com.jvbcorp.aoeRanking) trong Firebase console, thêm
  /// `static const FirebaseOptions ios = ...` rồi trả nó ở đây.
  static FirebaseOptions? get currentPlatform => kIsWeb ? web : null;

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
