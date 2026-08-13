import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nền tảng chưa đăng ký thì options = null: phải bỏ qua hẳn, vì gọi
  // initializeApp với cấu hình sai làm SDK native ném NSException — crash
  // trước cả khi try/catch dưới đây kịp có tác dụng.
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options != null) {
    try {
      await Firebase.initializeApp(options: options);
    } catch (_) {
      // Firebase lỗi -> bảng xếp hạng vẫn chạy bình thường (chỉ Giải đấu không dùng được).
    }
  }
  runApp(const AoeRankingApp());
}
