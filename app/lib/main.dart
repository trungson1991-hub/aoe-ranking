import 'package:flutter/material.dart';

import 'ui/leaderboard_page.dart';

void main() {
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
