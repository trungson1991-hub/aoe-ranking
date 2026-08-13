import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Hộp thoại nhập tỉ số trận chạm [firstTo].
/// Mỗi đội là 1 hàng số 0..firstTo — bấm 1 phát chọn xong số ván thắng.
/// [membersA]/[membersB]: tên thành viên từng đội, hiện dưới tên đội
/// để dễ nhận biết (tên đội thường là tên vui, không nói lên ai đánh).
/// Trả về (scoreA, scoreB) hoặc null nếu huỷ.
/// Không cho lưu tỉ số vô lệ (cả 2 đội cùng đạt firstTo).
Future<(int, int)?> showScoreDialog(
  BuildContext context, {
  required String teamA,
  required String teamB,
  required int firstTo,
  int scoreA = 0,
  int scoreB = 0,
  List<String> membersA = const [],
  List<String> membersB = const [],
}) {
  var a = scoreA;
  var b = scoreB;
  return showDialog<(int, int)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final aWin = a >= firstTo;
        final bWin = b >= firstTo;
        final invalid = aWin && bWin;

        final (String status, Color statusColor) = switch ((aWin, bWin)) {
          (true, true) => ('Chỉ 1 đội được đạt $firstTo ván!', AppColors.loss),
          (true, false) => ('🏆 $teamA thắng', AppColors.win),
          (false, true) => ('🏆 $teamB thắng', AppColors.win),
          _ => ('Chưa kết thúc (chạm $firstTo)', Colors.white38),
        };

        return AlertDialog(
          // scrollable: màn hình thấp (điện thoại xoay ngang) không đủ chỗ cho
          // 2 hàng ô số; không cuộn được thì phần dưới tràn ra ngoài hộp và
          // KHÔNG bấm được — người dùng chỉ nhập được điểm cho đội A.
          scrollable: true,
          title: Row(
            children: [
              const Text('Nhập tỉ số',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              const Spacer(),
              Text('chạm $firstTo',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TeamScoreRow(
                  keyPrefix: 'score-a',
                  name: teamA,
                  members: membersA,
                  value: a,
                  max: firstTo,
                  onChanged: (v) => setLocal(() => a = v),
                ),
                const SizedBox(height: 14),
                _TeamScoreRow(
                  keyPrefix: 'score-b',
                  name: teamB,
                  members: membersB,
                  value: b,
                  max: firstTo,
                  onChanged: (v) => setLocal(() => b = v),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('$a – $b',
                      style: TextStyle(
                          color: invalid
                              ? AppColors.loss
                              : (aWin || bWin)
                                  ? AppColors.win
                                  : Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 2),
                Center(
                  child: Text(status,
                      style: TextStyle(color: statusColor, fontSize: 12)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            TextButton(
              onPressed: invalid ? null : () => Navigator.pop(ctx, (a, b)),
              child: const Text('Lưu',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    ),
  );
}

/// 1 hàng chọn tỉ số: tên đội (+ thành viên) + dãy ô số 0..max (bấm để chọn).
class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({
    required this.keyPrefix,
    required this.name,
    required this.members,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String keyPrefix;
  final String name;
  final List<String> members;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
        if (members.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('👤 ${members.join(', ')}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var v = 0; v <= max; v++)
              GestureDetector(
                key: Key('$keyPrefix-$v'),
                onTap: () => onChanged(v),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? AppColors.gold : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: v == value ? AppColors.gold : Colors.white12),
                  ),
                  child: Text('$v',
                      style: TextStyle(
                          color: v == value ? Colors.black : Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
