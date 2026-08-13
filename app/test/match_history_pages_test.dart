import 'package:aoe_ranking/features/leaderboard/models/leaderboard.dart';
import 'package:aoe_ranking/features/leaderboard/services/leaderboard_service.dart';
import 'package:aoe_ranking/features/match_history/models/match_record.dart';
import 'package:aoe_ranking/features/match_history/pages/match_detail_page.dart';
import 'package:aoe_ranking/features/match_history/pages/user_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerStat player(String uuid, String name,
        {required bool win,
        int color = 1,
        int kills = 0,
        int losses = 0,
        int gold = 0}) =>
    PlayerStat(
      uuid: uuid,
      name: name,
      color: color,
      empiresType: 10, // Shang (đánh số từ 0 theo dữ liệu GPlay)
      win: win,
      kills: kills,
      losses: losses,
      razings: 2,
      gold: gold,
      villager: 20,
      population: 60,
      technologies: 14,
      exploration: 45,
      tribute: 0,
      age: 3,
    );

/// Trận 2v2: viewer (v1) + đồng đội m1 thắng đối thủ o1, o2.
MatchRecord record2v2({int createdTime = 1750000000}) => MatchRecord(
      createdTime: createdTime,
      roomId: 123,
      red: [
        player('v1', 'MePlayer', win: true, color: 1, kills: 50, losses: 10, gold: 900),
        player('m1', 'Mate', win: true, color: 2, kills: 30, losses: 20, gold: 700),
      ],
      blue: [
        // Số giết chọn sao cho TỔNG đội (21+12=33) không trùng bất kỳ giá trị
        // nào khác trên màn hình — nếu không, assertion tổng sẽ luôn đúng
        // kể cả khi hàm tính tổng bị hỏng.
        player('o1', 'Rival1', win: false, color: 3, kills: 21, losses: 40, gold: 500),
        player('o2', 'Rival2', win: false, color: 4, kills: 12, losses: 31, gold: 400),
      ],
      viewerUuid: 'v1',
      internal: true,
      ghost: false,
    );

class _FakeService extends LeaderboardService {
  const _FakeService(this.result);
  final List<MatchRecord> result;

  @override
  Future<List<MatchRecord>> fetchUserHistory(String uuid,
          {required int sinceEpoch, required Set<String> teamUuids}) async =>
      result;
}

void main() {
  group('MatchDetailPage', () {
    testWidgets('có banner kết quả, tương quan 2 đội và bảng so sánh',
        (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: MatchDetailPage(record: record2v2())));
      expect(find.text('CHIẾN THẮNG'), findsOneWidget);
      expect(find.text('TƯƠNG QUAN 2 ĐỘI'), findsOneWidget);
      expect(find.text('SO SÁNH TỪNG NGƯỜI'), findsOneWidget);
      // Đủ 4 cột người chơi.
      for (final name in ['MePlayer', 'Mate', 'Rival1', 'Rival2']) {
        expect(find.text(name), findsOneWidget);
      }
      // empires_type 10 phải hiện Shang (bug cũ: map lệch 1 -> hiện Roman).
      expect(find.text('Shang'), findsNWidgets(4));
      expect(find.text('Roman'), findsNothing);
      // Tổng giết quân mỗi đội trong khối tương quan: Đỏ 50+30=80, Xanh 21+12=33.
      expect(find.text('80'), findsOneWidget);
      expect(find.text('33'), findsOneWidget);
    });
  });

  group('UserHistoryPage', () {
    testWidgets('thẻ tổng quan + tile trận hiển thị đúng', (tester) async {
      final matches = [record2v2()];
      await tester.pumpWidget(MaterialApp(
        home: UserHistoryPage(
          member: const Member(
            userUuid: 'v1',
            name: 'MePlayer',
            avatarUrl: '',
            lastPlayed: 1750000000,
            total: ModeStat(elo: 1100, games: 1, wins: 1),
            modes: {},
          ),
          sinceEpoch: 0,
          roster: {
            for (final u in ['v1', 'm1', 'o1', 'o2'])
              u: Member(
                userUuid: u,
                name: u,
                avatarUrl: '',
                lastPlayed: 1,
                total: const ModeStat(),
                modes: const {},
              ),
          },
          service: _FakeService(matches),
        ),
      ));
      await tester.pumpAndSettle();
      // Thẻ tổng quan.
      expect(find.text('PHONG ĐỘ — MỚI NHẤT TRƯỚC'), findsOneWidget);
      expect(find.text('TRUNG BÌNH / TRẬN'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget); // 1 thắng / 1 trận
      // Tile trận: có đối thủ + đồng đội và badge W.
      expect(find.textContaining('Rival1'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      // Mở chi tiết khi bấm tile.
      await tester.tap(find.text('W'));
      await tester.pumpAndSettle();
      expect(find.text('SO SÁNH TỪNG NGƯỜI'), findsOneWidget);
    });
  });
}
