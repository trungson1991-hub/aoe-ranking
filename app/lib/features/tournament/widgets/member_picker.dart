import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../leaderboard/models/leaderboard.dart';

/// Dialog chọn [teamSize] thành viên cho 1 đội từ danh sách team.
/// [taken]: các uuid đã thuộc đội khác (ẩn khỏi danh sách chọn).
/// Trả về danh sách uuid đã chọn, hoặc null nếu huỷ.
Future<List<String>?> showMemberPicker(
  BuildContext context, {
  required List<Member> roster,
  required int teamSize,
  required List<String> initial,
  required Set<String> taken,
}) {
  final selected = {...initial};
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final full = selected.length >= teamSize;
        return AlertDialog(
          title: Text('Chọn $teamSize thành viên',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cho biết đã chọn bao nhiêu — trước đây bấm quá số lượng thì
                // ô tick không phản ứng mà không giải thích gì.
                Text(
                  full
                      ? 'Đã đủ $teamSize người — bỏ chọn bớt nếu muốn đổi'
                      : 'Đã chọn ${selected.length}/$teamSize',
                  style: TextStyle(
                    color: full ? AppColors.gold : Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in roster)
                        if (!taken.contains(m.userUuid))
                          CheckboxListTile(
                            value: selected.contains(m.userUuid),
                            // Đủ người thì mờ các ô chưa chọn cho dễ hiểu.
                            enabled:
                                !full || selected.contains(m.userUuid),
                            title: Text(m.name,
                                style: const TextStyle(color: Colors.white)),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  if (selected.length < teamSize) {
                                    selected.add(m.userUuid);
                                  }
                                } else {
                                  selected.remove(m.userUuid);
                                }
                              });
                            },
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, selected.toList()),
                child: const Text('Xong')),
          ],
        );
      },
    ),
  );
}
