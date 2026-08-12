import 'package:aoe_ranking/features/leaderboard/models/leaderboard.dart';
import 'package:aoe_ranking/features/leaderboard/widgets/member_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Member member() => const Member(
      userUuid: 'u1',
      name: 'Test',
      avatarUrl: '', // rỗng -> không tải ảnh mạng trong test
      lastPlayed: 1700000000,
      total: ModeStat(),
      modes: {},
    );

Widget wrap(ModeStat stat) => MaterialApp(
      home: Scaffold(
        body: MemberCard(
          member: member(),
          rank: 4,
          stat: stat,
          accent: Colors.grey,
          sinceEpoch: 0,
          teamUuids: const {'u1'},
        ),
      ),
    );

void main() {
  testWidgets('đủ trận: hiện số ELO với nhãn "ELO"', (tester) async {
    await tester.pumpWidget(
        wrap(const ModeStat(elo: 1100, games: 20, wins: 12, losses: 8)));
    expect(find.text('1100'), findsOneWidget);
    expect(find.text('ELO'), findsOneWidget);
    expect(find.text('ELO tạm'), findsNothing);
  });

  testWidgets('dưới 10 trận: nhãn "ELO tạm"', (tester) async {
    await tester.pumpWidget(
        wrap(const ModeStat(elo: 1040, games: 5, wins: 3, losses: 2)));
    expect(find.text('1040'), findsOneWidget);
    expect(find.text('ELO tạm'), findsOneWidget);
  });

  testWidgets('chưa có trận: hiện "—" thay vì ELO xuất phát', (tester) async {
    await tester.pumpWidget(wrap(const ModeStat(elo: 1000, games: 0)));
    expect(find.text('—'), findsOneWidget);
    expect(find.text('1000'), findsNothing);
    expect(find.text('chưa có trận'), findsOneWidget);
  });
}
