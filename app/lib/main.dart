import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'ui/leaderboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase lỗi -> bảng xếp hạng vẫn chạy bình thường (chỉ Giải đấu không dùng được).
  }
  runApp(const AoeRankingApp());
}

class AoeRankingApp extends StatelessWidget {
  const AoeRankingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AoE Ranking',
      debugShowCheckedModeBanner: false,
      // Ẩn thanh cuộn (scrollbar) trên web/desktop.
      scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFBBF24),
        brightness: Brightness.dark,
      ),
      home: const LeaderboardPage(),
    );
  }
}
