import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Thanh tỉ lệ thắng: phần xanh là tỉ lệ thắng, phần còn lại là nền.
class WinRateBar extends StatelessWidget {
  const WinRateBar({
    super.key,
    required this.winRate, // 0..1
    this.width,
    this.height = 4,
    this.lossColor = Colors.white12,
  });

  final double winRate;
  final double? width;
  final double height;
  final Color lossColor;

  @override
  Widget build(BuildContext context) {
    final win = (winRate * 100).round().clamp(0, 100);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        width: width,
        child: Row(
          children: [
            Expanded(
              flex: win,
              child: Container(color: AppColors.win.withValues(alpha: 0.8)),
            ),
            Expanded(
              flex: 100 - win,
              child: Container(color: lossColor),
            ),
          ],
        ),
      ),
    );
  }
}
