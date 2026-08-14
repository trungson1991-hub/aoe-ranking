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

// Text các ô tên đội. Nhận diện bằng nhãn thay vì "bỏ N ô đầu": đếm cứng
// theo thứ tự khiến test vỡ mỗi lần form thêm bớt một ô (đã xảy ra khi thêm
// ô Ghi chú), mà lỗi báo ra lại chẳng liên quan gì tới đội.
List<String> teamNameTexts(WidgetTester tester) {
  return [
    for (final f in tester.widgetList<TextField>(find.byType(TextField)))
      if ((f.decoration?.labelText ?? '').startsWith('Tên đội'))
        f.controller!.text,
  ];
}

void main() {
  testWidgets(
      'đội mặc định có tên vui; "Thêm đội" chèn đội mới vào VỊ TRÍ ĐẦU',
      (tester) async {
    // Khung cao để CẢ form được dựng: body là ListView nên ô nào nằm ngoài
    // màn hình sẽ không tồn tại trong cây widget, và test tưởng là mất đội.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
