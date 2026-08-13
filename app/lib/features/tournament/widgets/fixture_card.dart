import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Thẻ 1 cặp đấu: "Đội A  x - y  Đội B" (kèm tên thành viên mỗi đội nếu có).
/// Dùng cho cả vòng bảng và nhánh KO.
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
    this.aMembers = const [],
    this.bMembers = const [],
    this.onTap,
  });

  final String aName;
  final String bName;
  final int scoreA;
  final int scoreB;
  final bool aWon;
  final bool bWon;
  final bool decided; // đã có kết quả -> viền xanh
  final List<String> aMembers;
  final List<String> bMembers;
  final VoidCallback? onTap; // null = chưa thể nhập (chờ đội / bye)

  Widget _side({
    required String name,
    required List<String> members,
    required bool won,
    required bool alignRight,
  }) {
    final align =
        alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignRight ? TextAlign.right : TextAlign.left;
    return Expanded(
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(name,
              textAlign: textAlign,
              style: TextStyle(
                  color: won ? AppColors.win : Colors.white,
                  fontWeight: FontWeight.w700)),
          if (members.isNotEmpty)
            Text(members.join(', '),
                textAlign: textAlign,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

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
              color: decided
                  ? AppColors.done.withValues(alpha: 0.4)
                  : Colors.white12),
        ),
        child: Row(
          children: [
            _side(
                name: aName,
                members: aMembers,
                won: aWon,
                alignRight: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$scoreA - $scoreB',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ),
            _side(
                name: bName,
                members: bMembers,
                won: bWon,
                alignRight: false),
            const SizedBox(width: 6),
            Icon(onTap != null ? Icons.edit : Icons.hourglass_empty,
                size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
