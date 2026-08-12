import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Thẻ 1 cặp đấu: "Đội A  x - y  Đội B". Dùng cho cả vòng bảng và nhánh KO.
class FixtureCard extends StatelessWidget {
  const FixtureCard({
    super.key,
    required this.aName,
    required this.bName,
    required this.scoreA,
    required this.scoreB,
    required this.aWon,
    required this.bWon,
    required this.decided,
    this.onTap,
  });

  final String aName;
  final String bName;
  final int scoreA;
  final int scoreB;
  final bool aWon;
  final bool bWon;
  final bool decided; // đã có kết quả -> viền xanh
  final VoidCallback? onTap; // null = chưa thể nhập (chờ đội / bye)

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  decided ? AppColors.done.withValues(alpha: 0.4) : Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(aName,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: aWon ? AppColors.win : Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$scoreA - $scoreB',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: Text(bName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: bWon ? AppColors.win : Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            Icon(onTap != null ? Icons.edit : Icons.hourglass_empty,
                size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
