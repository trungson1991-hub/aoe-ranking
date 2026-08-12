import 'package:aoe_ranking/features/tournament/widgets/score_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Future<(int, int)?> Function()> _openDialog(WidgetTester tester,
    {int firstTo = 3}) async {
  late Future<(int, int)?> Function() open;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(builder: (context) {
        open = () => showScoreDialog(context,
            teamA: 'Gà Rán Thần Tốc',
            teamB: 'Bò Húc Bất Bại',
            membersA: const ['Tnos', 'DarkTitan'],
            membersB: const ['titi_cuti', 'TrumNho'],
            firstTo: firstTo);
        return const SizedBox();
      }),
    ),
  ));
  return open;
}

void main() {
  testWidgets('chọn tỉ số bằng ô số, xem trước đội thắng, lưu đúng',
      (tester) async {
    final open = await _openDialog(tester);
    final result = open();
    await tester.pumpAndSettle();

    // Mỗi đội có dãy ô 0..3.
    expect(find.byKey(const Key('score-a-3')), findsOneWidget);
    expect(find.byKey(const Key('score-b-3')), findsOneWidget);

    // Tên thành viên hiện dưới tên đội.
    expect(find.textContaining('Tnos, DarkTitan'), findsOneWidget);
    expect(find.textContaining('titi_cuti, TrumNho'), findsOneWidget);

    await tester.tap(find.byKey(const Key('score-a-3')));
    await tester.pump();
    expect(find.textContaining('Gà Rán Thần Tốc thắng'), findsOneWidget);

    await tester.tap(find.byKey(const Key('score-b-1')));
    await tester.pump();
    expect(find.text('3 – 1'), findsOneWidget);

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(await result, (3, 1));
  });

  testWidgets('cả 2 đội cùng đạt chạm -> báo lỗi và không cho lưu',
      (tester) async {
    final open = await _openDialog(tester);
    open();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('score-a-3')));
    await tester.tap(find.byKey(const Key('score-b-3')));
    await tester.pump();

    expect(find.textContaining('Chỉ 1 đội'), findsOneWidget);
    final save = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Lưu'));
    expect(save.onPressed, isNull);
  });
}
