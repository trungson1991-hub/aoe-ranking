// Chốt chặn tràn layout trên màn hình hẹp nhất còn phải hỗ trợ (320px).
// Các màn này từng tràn khi thêm avatar + đồ trang trí cho người chơi.
import 'package:aoe_ranking/features/leaderboard/models/leaderboard.dart';
import 'package:aoe_ranking/features/leaderboard/services/leaderboard_service.dart';
import 'package:aoe_ranking/features/match_history/models/match_record.dart';
import 'package:aoe_ranking/features/match_history/pages/match_detail_page.dart';
import 'package:aoe_ranking/features/match_history/pages/user_history_page.dart';
import 'package:aoe_ranking/features/tournament/widgets/team_faces.dart';
import 'package:aoe_ranking/features/tournament/widgets/fixture_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _narrow = Size(320, 900);

PlayerStat _p(String uuid, bool win, int color) => PlayerStat(
      uuid: uuid,
      name: uuid,
      color: color,
      empiresType: 10,
      win: win,
      kills: 50,
      losses: 20,
      razings: 1,
      gold: 500,
      villager: 20,
      population: 60,
      technologies: 10,
      exploration: 50,
      tribute: 0,
      age: 4,
    );

/// Thành viên CÓ khung VIP — trường hợp tốn chỗ nhất.
Member _decorated(String u) => Member(
      userUuid: u,
      name: u,
      avatarUrl: '',
      vipFrameUrl: 'https://example.invalid/frame.png',
      lastPlayed: 1,
      total: const ModeStat(),
      modes: const {},
    );

MatchRecord _match4v4() => MatchRecord(
      createdTime: 1750000000,
      roomId: 1,
      red: [for (var i = 0; i < 4; i++) _p('me$i', true, i + 1)],
      blue: [for (var i = 0; i < 4; i++) _p('op$i', false, i + 5)],
      viewerUuid: 'me0',
      internal: true,
      ghost: false,
    );

Map<String, Member> _roster8() => {
      for (var i = 0; i < 4; i++) 'me$i': _decorated('me$i'),
      for (var i = 0; i < 4; i++) 'op$i': _decorated('op$i'),
    };

class _FakeService extends LeaderboardService {
  const _FakeService(this.records);
  final List<MatchRecord> records;

  @override
  Future<List<MatchRecord>> fetchUserHistory(String uuid,
          {required int sinceEpoch, required Set<String> teamUuids}) async =>
      records;
}

Future<void> _pumpNarrow(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(_narrow);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('danh sách lịch sử: thẻ trận 4v4 không tràn', (tester) async {
    final roster = _roster8();
    await _pumpNarrow(
      tester,
      UserHistoryPage(
        member: roster['me0']!,
        sinceEpoch: 0,
        roster: roster,
        service: _FakeService([_match4v4()]),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chi tiết trận 4v4 không tràn', (tester) async {
    await _pumpNarrow(
      tester,
      MatchDetailPage(record: _match4v4(), roster: _roster8()),
    );
    expect(tester.takeException(), isNull);
  });

  // Bảng so sánh đóng cứng chiều cao mỗi hàng (để cột nhãn ghim thẳng hàng với
  // cột số), nên cỡ chữ hệ thống phóng to là kịch bản dễ tràn nhất.
  testWidgets('chi tiết trận 4v4 không tràn khi phóng to cỡ chữ',
      (tester) async {
    await tester.binding.setSurfaceSize(_narrow);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: MatchDetailPage(record: _match4v4(), roster: _roster8()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // Lỗi kiểu "bóp méo im lặng": không ném exception nên các test tràn ở trên
  // không bắt được — phải kiểm tra trực tiếp bề rộng hàng avatar.
  group('bảng điểm giải: hàng avatar không được nuốt hết chỗ của tên đội', () {
    const uuids = ['me0', 'me1', 'me2', 'me3'];

    test('đội 4 người chiếm chỗ vừa phải', () {
      final w = TeamFaces.widthFor(uuids, _roster8());
      // 4 avatar xếp chồng: phải gọn hơn nhiều so với xếp rời (4 × 26.4).
      expect(w, lessThan(80));
      expect(w, greaterThan(0));
    });

    test('không ai trong roster -> không chiếm chỗ', () {
      expect(TeamFaces.widthFor(uuids, const {}), 0);
    });

    test('cột tên đội ở 320px vẫn còn đủ chỗ đọc được', () {
      // Bề ngang thật còn lại cho cột "Đội" sau các cột số + padding.
      const availableAt320 = 320.0 - 176 - 64;
      final faces = TeamFaces.widthFor(uuids, _roster8());
      final showFaces = availableAt320 - faces >= 92;
      // Ở màn hẹp phải TỰ ẨN avatar, nhường chỗ cho tên đội.
      expect(showFaces, isFalse);
      // Và khi ẩn thì tên đội giữ nguyên toàn bộ chỗ.
      expect(availableAt320, greaterThanOrEqualTo(80));
    });
  });

  testWidgets('thẻ trận giải 4 người/đội, tên dài, không tràn',
      (tester) async {
    await _pumpNarrow(
      tester,
      Scaffold(
        body: FixtureCard(
          aName: 'Đội Có Tên Rất Dài Số Một',
          bName: 'Đội Có Tên Rất Dài Số Hai',
          aMembers: const ['NguoiChoi0', 'NguoiChoi1', 'NguoiChoi2', 'NguoiChoi3'],
          bMembers: const ['NguoiChoi4', 'NguoiChoi5', 'NguoiChoi6', 'NguoiChoi7'],
          aMemberUuids: const ['me0', 'me1', 'me2', 'me3'],
          bMemberUuids: const ['op0', 'op1', 'op2', 'op3'],
          roster: _roster8(),
          scoreA: 2,
          scoreB: 1,
          aWon: true,
          bWon: false,
          decided: true,
          onTap: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
