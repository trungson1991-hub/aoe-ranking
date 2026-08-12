import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Hộp thoại nhập tỉ số trận chạm [firstTo].
/// Trả về (scoreA, scoreB) hoặc null nếu huỷ.
/// Không cho lưu tỉ số vô lệ (cả 2 đội cùng đạt firstTo).
Future<(int, int)?> showScoreDialog(
  BuildContext context, {
  required String teamA,
  required String teamB,
  required int firstTo,
  int scoreA = 0,
  int scoreB = 0,
}) {
  var a = scoreA;
  var b = scoreB;
  return showDialog<(int, int)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final invalid = a >= firstTo && b >= firstTo;
        return AlertDialog(
          title: Text(
            'Nhập tỉ số (chạm $firstTo)',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TeamScore(
                      name: teamA,
                      value: a,
                      max: firstTo,
                      onChanged: (v) => setLocal(() => a = v),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text('–',
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                  Expanded(
                    child: _TeamScore(
                      name: teamB,
                      value: b,
                      max: firstTo,
                      onChanged: (v) => setLocal(() => b = v),
                    ),
                  ),
                ],
              ),
              if (invalid)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Chỉ 1 đội được đạt số ván chạm.',
                    style: TextStyle(color: AppColors.loss, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            TextButton(
              onPressed: invalid ? null : () => Navigator.pop(ctx, (a, b)),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    ),
  );
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.name,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String name;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.white70),
            ),
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon:
                  const Icon(Icons.add_circle_outline, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }
}
