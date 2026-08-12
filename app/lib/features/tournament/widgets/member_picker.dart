import 'package:flutter/material.dart';

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
      builder: (ctx, setLocal) => AlertDialog(
        title: Text('Chọn $teamSize thành viên',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final m in roster)
                if (!taken.contains(m.userUuid))
                  CheckboxListTile(
                    value: selected.contains(m.userUuid),
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
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, selected.toList()),
              child: const Text('Xong')),
        ],
      ),
    ),
  );
}
