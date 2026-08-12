import 'package:aoe_ranking/features/tournament/data/fun_team_names.dart';
import 'package:aoe_ranking/features/tournament/logic/fixture_edit.dart';
import 'package:aoe_ranking/features/tournament/logic/group_assign.dart';
import 'package:aoe_ranking/features/tournament/logic/knockout.dart';
import 'package:aoe_ranking/features/tournament/logic/round_robin.dart';
import 'package:aoe_ranking/features/tournament/logic/share_link.dart';
import 'package:aoe_ranking/features/tournament/logic/standings.dart';
import 'package:aoe_ranking/features/tournament/logic/tournament_edit.dart';
import 'package:aoe_ranking/features/tournament/models/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- Helpers dựng dữ liệu test ----

TournTeam team(String id) => TournTeam(
    id: id, name: 'Đội $id', memberUuids: const [], memberNames: const []);

Fixture fx(String id, String stage, String? a, String? b,
        {int sa = 0, int sb = 0}) =>
    Fixture(id: id, stage: stage, aId: a, bId: b, scoreA: sa, scoreB: sb);

Tournament tourn({
  required List<String> teamIds,
  required List<GroupDef> groups,
  required List<Fixture> groupFixtures,
  List<Fixture> koFixtures = const [],
  int firstTo = 1,
  int advance = 1,
}) =>
    Tournament(
      id: 'x',
      name: 'Test',
      pin: '1',
      format: '1v1',
      firstTo: firstTo,
      structure: kStructureGroupsKnockout,
      advancePerGroup: advance,
      createdAt: 0,
      teams: teamIds.map(team).toList(),
      groups: groups,
      groupFixtures: groupFixtures,
      koFixtures: koFixtures,
    );

void main() {
  group('bracketOrder', () {
    test('seed 1 và 2 nằm khác nửa nhánh (chỉ gặp ở chung kết)', () {
      for (final n in [2, 4, 8, 16]) {
        final order = bracketOrder(n);
        expect(order.toSet(), Set.of(List.generate(n, (i) => i)));
        if (n >= 4) {
          final firstHalf = order.sublist(0, n ~/ 2);
          // Seed 0 nửa trên, seed 1 nửa dưới.
          expect(firstHalf.contains(0), isTrue);
          expect(firstHalf.contains(1), isFalse);
        }
      }
    });
  });

  group('buildKnockout', () {
    test('6 đội: bye rơi vào 2 seed cao nhất', () {
      // 3 bảng × 2 đi tiếp: seeds = [A1,B1,C1,A2,B2,C2].
      final t = tourn(
        teamIds: ['a1', 'b1', 'c1', 'a2', 'b2', 'c2'],
        advance: 2,
        groups: [
          const GroupDef(name: 'A', teamIds: ['a1', 'a2']),
          const GroupDef(name: 'B', teamIds: ['b1', 'b2']),
          const GroupDef(name: 'C', teamIds: ['c1', 'c2']),
        ],
        groupFixtures: [
          fx('g1', 'A', 'a1', 'a2', sa: 1),
          fx('g2', 'B', 'b1', 'b2', sa: 1),
          fx('g3', 'C', 'c1', 'c2', sa: 1),
        ],
      );
      final ko = buildKnockout(t);
      final round0 = ko.where((f) => f.id.startsWith('ko_r0')).toList();
      expect(round0.length, 4);
      // Bye = trận vòng 0 thiếu 1 đội. Seed 1 (a1) và seed 2 (b1) được bye.
      final byes = round0
          .where((f) => (f.aId == null) != (f.bId == null))
          .map((f) => f.aId ?? f.bId)
          .toSet();
      expect(byes, {'a1', 'b1'});
      // Đủ số vòng tới chung kết: 4 + 2 + 1.
      expect(ko.length, 7);
    });

    test('4 đội 2 bảng: A1 gặp B2, B1 gặp A2', () {
      final t = tourn(
        teamIds: ['a1', 'b1', 'a2', 'b2'],
        advance: 2,
        groups: [
          const GroupDef(name: 'A', teamIds: ['a1', 'a2']),
          const GroupDef(name: 'B', teamIds: ['b1', 'b2']),
        ],
        groupFixtures: [
          fx('g1', 'A', 'a1', 'a2', sa: 1),
          fx('g2', 'B', 'b1', 'b2', sa: 1),
        ],
      );
      final round0 =
          buildKnockout(t).where((f) => f.id.startsWith('ko_r0')).toList();
      final pairs = round0.map((f) => {f.aId, f.bId}).toList();
      expect(pairs, containsAll([{'a1', 'b2'}, {'b1', 'a2'}]));
    });
  });

  group('resolveKo', () {
    test('bye tự đi tiếp, vô địch suy từ chuỗi thắng', () {
      final t = tourn(
        teamIds: ['s1', 's2', 's3'],
        groups: [const GroupDef(name: 'A', teamIds: ['s1', 's2', 's3'])],
        groupFixtures: [fx('g', 'A', 's1', 's2', sa: 1)],
        koFixtures: [
          fx('ko_r0_m0', 'KO', 's1', null), // bye cho s1
          fx('ko_r0_m1', 'KO', 's3', 's2', sa: 1),
          fx('ko_r1_m0', 'KO', null, null, sa: 0, sb: 1),
        ],
      );
      final rounds = resolveKo(t);
      expect(rounds[0][0].winnerId, 's1'); // bye
      expect(rounds[0][0].isBye, isTrue);
      expect(rounds[0][1].winnerId, 's3');
      // Chung kết: s1 vs s3, s3 thắng 0-1.
      expect(rounds[1][0].aId, 's1');
      expect(rounds[1][0].bId, 's3');
      expect(koChampionId(t), 's3');
    });
  });

  group('koFixturesAfterEdit', () {
    test('đổi đội thắng vòng trước -> reset tỉ số vòng sau', () {
      final t = tourn(
        teamIds: ['s1', 's2', 's3', 's4'],
        groups: [
          const GroupDef(name: 'A', teamIds: ['s1', 's2', 's3', 's4'])
        ],
        groupFixtures: [fx('g', 'A', 's1', 's2', sa: 1)],
        koFixtures: [
          fx('ko_r0_m0', 'KO', 's1', 's4', sa: 1),
          fx('ko_r0_m1', 'KO', 's2', 's3', sa: 1),
          fx('ko_r1_m0', 'KO', null, null, sa: 1, sb: 0), // s1 đã thắng CK
        ],
      );
      // Sửa bán kết m0: s4 thắng thay vì s1.
      final edited = fx('ko_r0_m0', 'KO', 's1', 's4', sa: 0, sb: 1);
      final updated = koFixturesAfterEdit(t, edited);
      final finalMatch = updated.firstWhere((f) => f.id == 'ko_r1_m0');
      expect(finalMatch.scoreA, 0); // tỉ số chung kết cũ bị reset
      expect(finalMatch.scoreB, 0);
    });

    test('đội thắng không đổi -> giữ nguyên vòng sau', () {
      final t = tourn(
        teamIds: ['s1', 's2', 's3', 's4'],
        firstTo: 3,
        groups: [
          const GroupDef(name: 'A', teamIds: ['s1', 's2', 's3', 's4'])
        ],
        groupFixtures: [fx('g', 'A', 's1', 's2', sa: 3)],
        koFixtures: [
          fx('ko_r0_m0', 'KO', 's1', 's4', sa: 3, sb: 0),
          fx('ko_r0_m1', 'KO', 's2', 's3', sa: 3, sb: 1),
          fx('ko_r1_m0', 'KO', null, null, sa: 3, sb: 2),
        ],
      );
      // Chỉ chỉnh tỉ số 3-0 thành 3-1, s1 vẫn thắng.
      final edited = fx('ko_r0_m0', 'KO', 's1', 's4', sa: 3, sb: 1);
      final updated = koFixturesAfterEdit(t, edited);
      final finalMatch = updated.firstWhere((f) => f.id == 'ko_r1_m0');
      expect(finalMatch.scoreA, 3);
      expect(finalMatch.scoreB, 2);
    });
  });

  group('generateRoundRobin', () {
    test('mọi cặp gặp nhau đúng 1 lần, mỗi lượt mỗi đội đá tối đa 1 trận', () {
      for (final n in [2, 3, 4, 5, 6]) {
        final ids = List.generate(n, (i) => 't$i');
        final fixtures = generateRoundRobin(ids);
        expect(fixtures.length, n * (n - 1) ~/ 2);
        final pairs = fixtures.map((f) => {f.aId, f.bId}).toList();
        // Không cặp nào lặp lại.
        for (var i = 0; i < pairs.length; i++) {
          for (var j = i + 1; j < pairs.length; j++) {
            expect(pairs[i], isNot(equals(pairs[j])));
          }
        }
        // Theo lượt (mỗi lượt = floor(n/2) trận liên tiếp): không đội nào đá 2 trận cùng lượt.
        final perRound = n ~/ 2;
        for (var start = 0; start < fixtures.length; start += perRound) {
          final round = fixtures.skip(start).take(perRound);
          final seen = <String>{};
          for (final f in round) {
            expect(seen.add(f.aId!), isTrue);
            expect(seen.add(f.bId!), isTrue);
          }
        }
      }
    });
  });

  group('generateRoundRobin — id duy nhất', () {
    test('2 bảng tạo liên tiếp không trùng id (lỗi cũ trên web)', () {
      // Trên web timestamp chỉ có độ phân giải ms nên 2 lời gọi liên tiếp
      // gần như chắc chắn cùng timestamp — id phải vẫn duy nhất.
      final a = generateRoundRobin(['a', 'b', 'c', 'd'], stage: 'Bảng A');
      final b = generateRoundRobin(['e', 'f', 'g', 'h'], stage: 'Bảng B');
      final ids = {...a.map((f) => f.id), ...b.map((f) => f.id)};
      expect(ids.length, a.length + b.length);
    });
  });

  group('groupFixturesAfterEdit', () {
    test('dữ liệu cũ trùng id giữa 2 bảng: chỉ sửa trận đúng bảng', () {
      // Mô phỏng giải cũ bị lỗi sinh id: 2 bảng có cùng id 'f1_0'.
      final t = tourn(
        teamIds: ['a1', 'a2', 'b1', 'b2'],
        groups: [
          const GroupDef(name: 'Bảng A', teamIds: ['a1', 'a2']),
          const GroupDef(name: 'Bảng B', teamIds: ['b1', 'b2']),
        ],
        groupFixtures: [
          fx('f1_0', 'Bảng A', 'a1', 'a2'),
          fx('f1_0', 'Bảng B', 'b1', 'b2'), // id trùng, khác bảng
        ],
      );
      final edited = groupFixturesAfterEdit(
          t, t.groupFixtures.first, 1, 0); // sửa trận Bảng A: 1-0
      final bangA = edited.firstWhere((f) => f.stage == 'Bảng A');
      final bangB = edited.firstWhere((f) => f.stage == 'Bảng B');
      expect(bangA.scoreA, 1);
      // Trận Bảng B không bị ghi đè: giữ nguyên đội và tỉ số.
      expect(bangB.aId, 'b1');
      expect(bangB.scoreA, 0);
      expect(bangB.scoreB, 0);
    });
  });

  group('distributeTeams', () {
    test('đội chọn bảng giữ nguyên, đội tự chia cân bằng vào bảng ít nhất',
        () {
      // 6 đội, 2 bảng: đội 0,1 chọn bảng 0; đội 2 chọn bảng 1; còn lại tự chia.
      final buckets = distributeTeams([0, 0, 1, null, null, null], 2);
      expect(buckets[0], containsAll([0, 1]));
      expect(buckets[1], contains(2));
      // Cân bằng: mỗi bảng 3 đội.
      expect(buckets[0].length, 3);
      expect(buckets[1].length, 3);
    });

    test('không ai chọn -> chia đều', () {
      final buckets = distributeTeams([null, null, null, null, null], 2);
      expect(buckets[0].length + buckets[1].length, 5);
      expect((buckets[0].length - buckets[1].length).abs(), 1);
    });
  });

  group('reorderStageFixtures', () {
    test('đổi thứ tự trong bảng, bảng khác giữ nguyên vị trí', () {
      final all = [
        fx('a0', 'A', 'x', 'y'),
        fx('b0', 'B', 'p', 'q'),
        fx('a1', 'A', 'x', 'z'),
        fx('b1', 'B', 'p', 'r'),
        fx('a2', 'A', 'y', 'z'),
      ];
      // Bảng A: [a0, a1, a2] -> chuyển a0 xuống cuối.
      final out = reorderStageFixtures(all, 'A', 0, 2);
      expect(out.map((f) => f.id).toList(), ['a1', 'b0', 'a2', 'b1', 'a0']);
    });
  });

  group('applyTeamEdits', () {
    Tournament threeGroups() => tourn(
          teamIds: ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'],
          groups: [
            const GroupDef(name: 'Bảng A', teamIds: ['a1', 'a2']),
            const GroupDef(name: 'Bảng B', teamIds: ['b1', 'b2']),
            const GroupDef(name: 'Bảng C', teamIds: ['c1', 'c2']),
          ],
          groupFixtures: [
            fx('gA', 'Bảng A', 'a1', 'a2', sa: 1),
            fx('gB', 'Bảng B', 'b1', 'b2', sa: 1),
            fx('gC', 'Bảng C', 'c1', 'c2', sa: 1),
          ],
          koFixtures: [fx('ko_r0_m0', 'KO', 'a1', 'b1')],
        );

    test('chỉ đổi tên/thành viên: lịch, kết quả và KO giữ nguyên', () {
      final t = threeGroups();
      final newTeams = [
        for (final team in t.teams)
          TournTeam(
              id: team.id,
              name: 'Mới ${team.id}',
              memberUuids: const ['u9'],
              memberNames: const ['NgườiMới']),
      ];
      final out = applyTeamEdits(t, teams: newTeams, groups: t.groups);
      expect(out.groupFixtures, same(t.groupFixtures));
      expect(out.koFixtures, same(t.koFixtures));
      expect(out.teamById('a1')!.name, 'Mới a1');
    });

    test('chuyển đội sang bảng khác: tạo lại lịch 2 bảng liên quan, '
        'bảng còn lại giữ kết quả, KO bị xoá', () {
      final t = threeGroups();
      // Chuyển b1 sang Bảng A.
      final newGroups = [
        const GroupDef(name: 'Bảng A', teamIds: ['a1', 'a2', 'b1']),
        const GroupDef(name: 'Bảng B', teamIds: ['b2']),
        const GroupDef(name: 'Bảng C', teamIds: ['c1', 'c2']),
      ];
      expect(changedGroupStages(t, newGroups), {'Bảng A', 'Bảng B'});

      final out = applyTeamEdits(t, teams: t.teams, groups: newGroups);
      // Bảng C nguyên vẹn (giữ cả kết quả 1-0).
      final gC = out.groupFixtures.where((f) => f.stage == 'Bảng C').toList();
      expect(gC.single.id, 'gC');
      expect(gC.single.scoreA, 1);
      // Bảng A tạo lại: 3 đội -> 3 trận, tỉ số 0-0.
      final gA = out.groupFixtures.where((f) => f.stage == 'Bảng A').toList();
      expect(gA.length, 3);
      expect(gA.every((f) => f.scoreA == 0 && f.scoreB == 0), isTrue);
      // Bảng B còn 1 đội -> không có trận.
      expect(out.groupFixtures.where((f) => f.stage == 'Bảng B'), isEmpty);
      // KO bị xoá vì seed không còn đúng.
      expect(out.koFixtures, isEmpty);
    });
  });

  group('Tournament status', () {
    test('giải cũ chưa có field status -> mặc định đang diễn ra', () {
      final t = Tournament.fromDoc('x', {'name': 'Giải cũ'});
      expect(t.isActive, isTrue);
      expect(t.isFinished, isFalse);
      expect(t.isCancelled, isFalse);
    });

    test('copyWith đổi trạng thái và round-trip qua toMap/fromDoc', () {
      final t = tourn(
        teamIds: ['a', 'b'],
        groups: [const GroupDef(name: 'A', teamIds: ['a', 'b'])],
        groupFixtures: [fx('g', 'A', 'a', 'b', sa: 1)],
      ).copyWith(status: kStatusFinished);
      expect(t.isFinished, isTrue);
      final parsed = Tournament.fromDoc('x', t.toMap());
      expect(parsed.isFinished, isTrue);
      // Mở lại giải.
      expect(parsed.copyWith(status: kStatusActive).isActive, isTrue);
    });
  });

  group('tournamentShareLink', () {
    test('giữ origin + path, bỏ fragment và query khác, thêm ?t=', () {
      final link = tournamentShareLink(
          Uri.parse('https://user.github.io/aoe-ranking/?_=123#/x'), 'abc-1');
      expect(link, 'https://user.github.io/aoe-ranking/?t=abc-1');
    });
  });

  group('randomFunTeamName', () {
    test('không rỗng và tránh tên đã dùng', () {
      final used = kFunTeamNames.take(kFunTeamNames.length - 1).toSet();
      // Chỉ còn đúng 1 tên chưa dùng -> phải trả về tên đó.
      final name = randomFunTeamName(exclude: used);
      expect(name, kFunTeamNames.last);
      // Hết kho -> vẫn trả về 1 tên hợp lệ (cho phép trùng).
      final any = randomFunTeamName(exclude: kFunTeamNames.toSet());
      expect(kFunTeamNames.contains(any), isTrue);
    });
  });

  group('standingsFor', () {
    test('điểm > hiệu số ván > tổng ván thắng', () {
      final t = tourn(
        teamIds: ['x', 'y', 'z'],
        firstTo: 2,
        groups: [const GroupDef(name: 'A', teamIds: ['x', 'y', 'z'])],
        groupFixtures: [
          fx('g1', 'A', 'x', 'y', sa: 2, sb: 1), // x thắng
          fx('g2', 'A', 'y', 'z', sa: 2, sb: 0), // y thắng
          fx('g3', 'A', 'z', 'x', sa: 2, sb: 1), // z thắng
        ],
      );
      // Cùng 3 điểm: x HS 3-3=0, y HS 3-2=+1... tính lại:
      // x: thắng y 2-1, thua z 1-2 => ván 3-3, HS 0
      // y: thua x 1-2, thắng z 2-0 => ván 3-2, HS +1
      // z: thắng x 2-1, thua y 0-2 => ván 2-3, HS -1
      final rows = standingsFor(t, ['x', 'y', 'z'], t.groupFixtures);
      expect(rows.map((r) => r.team.id).toList(), ['y', 'x', 'z']);
    });
  });
}
