import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/leaderboard/pages/leaderboard_page.dart';

class AoeRankingApp extends StatelessWidget {
  const AoeRankingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AoE Ranking',
      debugShowCheckedModeBanner: false,
      // Ẩn thanh cuộn (scrollbar) trên web/desktop.
      scrollBehavior:
          const MaterialScrollBehavior().copyWith(scrollbars: false),
      theme: buildAppTheme(),
      home: const LeaderboardPage(),
    );
  }
}
