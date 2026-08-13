// Test chốt cho các lỗi đã từng xảy ra ở phần giải đấu.
import 'package:aoe_ranking/core/utils/money.dart';
import 'package:aoe_ranking/features/leaderboard/models/leaderboard.dart';
import 'package:aoe_ranking/features/tournament/widgets/member_picker.dart';
import 'package:aoe_ranking/features/tournament/widgets/pin_dialog.dart';
import 'package:aoe_ranking/features/tournament/widgets/score_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Member member(String uuid, String name) => Member(
      userUuid: uuid,
      name: name,
      avatarUrl: '',
      lastPlayed: 1,
      total: const ModeStat(),
      modes: const {},
    );

/// Dựng 1 nút mở dialog, trả về hàm mở. Cho phép đặt kích thước màn hình.
Future<Future<T?> Function()> mount<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext) open, {
  Size? surface,
}) async {
  if (surface != null) {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  late Future<T?> Function() run;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(builder: (context) {
        run = () => open(context);
        return const SizedBox.expand();
      }),
    ),
  ));
  return run;
}

void main() {
  group('score_dialog — màn hình thấp (điện thoại xoay ngang)', () {
    testWidgets('vẫn nhập được tỉ số cho CẢ HAI đội', (tester) async {
      final open = await mount<(int, int)>(
        tester,
        (ctx) => showScoreDialog(ctx,
            teamA: 'Đội A', teamB: 'Đội B', firstTo: 3),
        surface: const Size(800, 360), // ngang, thấp
      );
      final result = open();
      await tester.pumpAndSettle();

      // Đội A: cuộn tới rồi bấm.
      await tester.ensureVisible(find.byKey(const Key('score-a-3')));
      await tester.tap(find.byKey(const Key('score-a-3')));
      await tester.pump();

      // Đội B nằm ở nửa dưới — trước đây tràn khỏi hộp nên bấm không ăn.
      await tester.ensureVisible(find.byKey(const Key('score-b-1')));
      await tester.tap(find.byKey(const Key('score-b-1')));
      await tester.pump();

      await tester.ensureVisible(find.text('Lưu'));
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(await result, (3, 1), reason: 'phải ghi nhận điểm của đội B');
    });
  });

  group('pin_dialog', () {
    testWidgets('PIN đúng -> true, không lỗi vòng đời controller',
        (tester) async {
      final open = await mount<bool>(tester, (ctx) => askPin(ctx, '1234'));
      final result = open();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PIN rỗng trong dữ liệu -> KHÔNG mở khoá bằng ô trống',
        (tester) async {
      final open = await mount<bool>(tester, (ctx) => askPin(ctx, ''));
      final result = open();
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // để trống
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });
  });

  group('member_picker', () {
    testWidgets('thành viên đã rời team vẫn bỏ chọn được (không bị kẹt)',
        (tester) async {
      final open = await mount<List<String>>(
        tester,
        (ctx) => showMemberPicker(
          ctx,
          roster: [member('u1', 'Người 1'), member('u2', 'Người 2')],
          teamSize: 2,
          initial: const ['ghost-uuid', 'u1'], // ghost không còn trong team
          taken: const {},
        ),
      );
      final result = open();
      await tester.pumpAndSettle();

      // Dòng "đã rời team" phải hiện ra để bỏ chọn.
      expect(find.textContaining('đã rời team'), findsOneWidget);
      await tester.tap(find.textContaining('đã rời team'));
      await tester.pump();

      // Bỏ xong thì chọn được người khác.
      await tester.tap(find.text('Người 2'));
      await tester.pump();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      final picked = await result;
      expect(picked, isNotNull);
      expect(picked, isNot(contains('ghost-uuid')));
      expect(picked!.toSet(), {'u1', 'u2'});
    });
  });

  group('money', () {
    test('số âm và số quá lớn được xử lý an toàn', () {
      expect(formatMoney(-500000), '-500.000đ');
      expect(parseMoney('999999999999'), 1000000000); // chặn trần
      expect(parseMoney('5tr'), 5); // chỉ giữ chữ số
    });
  });
}
