import 'package:aoe_ranking/features/leaderboard/models/leaderboard.dart';
import 'package:aoe_ranking/features/tournament/pages/tournament_create_page.dart';
import 'package:aoe_ranking/features/tournament/services/tournament_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Fake Firebase chỉ đủ để dựng TournamentService trong test
// (trang tạo giải không gọi tới database cho tới khi bấm Lưu).
class _FakeRef implements DatabaseReference {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Không dùng trong test này');
}

class _FakeDb implements FirebaseDatabase {
  @override
  DatabaseReference ref([String? path]) => _FakeRef();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Không dùng trong test này');
}

List<Member> roster() => [
      for (final n in ['Tnos', 'DarkTitan', 'titi_cuti', 'TrumNho'])
        Member(
          userUuid: n,
          name: n,
          avatarUrl: '',
          lastPlayed: 1,
          total: const ModeStat(),
          modes: const {},
        ),
    ];

// Text các ô tên đội (bỏ 5 ô đầu: Tên giải + PIN + 3 ô tiền thưởng).
List<String> teamNameTexts(WidgetTester tester) {
  final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
  return [for (final f in fields.skip(5)) f.controller!.text];
}

void main() {
  testWidgets(
      'đội mặc định có tên vui; "Thêm đội" chèn đội mới vào VỊ TRÍ ĐẦU',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TournamentCreatePage(
        roster: roster(),
        service: TournamentService(db: _FakeDb()),
      ),
    ));
    await tester.pumpAndSettle();

    final before = teamNameTexts(tester);
    expect(before.length, 2);
    expect(before.every((n) => n.trim().isNotEmpty), isTrue,
        reason: 'đội khởi điểm phải có sẵn tên vui');

    await tester.tap(find.text('Thêm đội'));
    await tester.pumpAndSettle(); // chờ animation chèn chạy xong

    final after = teamNameTexts(tester);
    expect(after.length, 3);
    // Đội mới đứng đầu, 2 đội cũ giữ nguyên thứ tự phía sau.
    expect(after.sublist(1), before);
    expect(before.contains(after.first), isFalse,
        reason: 'tên đội mới không trùng đội đã có');
    expect(after.first.trim().isNotEmpty, isTrue);
  });
}
