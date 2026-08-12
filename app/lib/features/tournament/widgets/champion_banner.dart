import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Banner "kết quả chung cuộc" (vô địch + á quân).
class ChampionBanner extends StatelessWidget {
  const ChampionBanner({
    super.key,
    required this.champion,
    required this.runnerUp,
  });

  final String champion;
  final String runnerUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.gold, AppColors.goldDark]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('🏆 KẾT QUẢ CHUNG CUỘC',
              style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const SizedBox(height: 8),
          Text('🥇 Vô địch: $champion',
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          Text('🥈 Á quân: $runnerUp',
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
