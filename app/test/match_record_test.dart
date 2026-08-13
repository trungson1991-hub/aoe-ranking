// Luật lọc/đếm trong MatchRecord phải KHỚP scripts/compute.mjs — nếu lệch,
// số trận trên trang lịch sử sẽ khác số trận dùng để tính ELO.
import 'package:aoe_ranking/features/match_history/models/match_record.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> player(String uuid, {String name = ''}) =>
    {'user_uuid': uuid, 'name': name};

Map<String, dynamic> stat({
  required int color,
  int kills = 20,
  int losses = 20,
  int result = 1,
}) =>
    {
      'empires_color': color,
      'empires_type': 10,
      'result': result,
      'kills': kills,
      'losses': losses,
    };

MatchRecord parse({
  required List<String> red,
  required List<String> blue,
  required Map<String, dynamic> stats,
  required Set<String> team,
  String viewer = 'a',
}) =>
    MatchRecord.fromApi({
      'created_time': 1750000000,
      'room_id': 1,
      'red_team_members': [for (final u in red) player(u)],
      'blue_team_members': [for (final u in blue) player(u)],
      'statistics': stats,
    }, viewer, team);

void main() {
  group('internal — chỉ trận toàn người trong team', () {
    test('có người ngoài team -> không nội bộ', () {
      final r = parse(
        red: ['a'],
        blue: ['x'],
        stats: {'a': stat(color: 1), 'x': stat(color: 2, result: 2)},
        team: {'a', 'b'},
      );
      expect(r.internal, isFalse);
    });

    test('tất cả trong team -> nội bộ', () {
      final r = parse(
        red: ['a'],
        blue: ['b'],
        stats: {'a': stat(color: 1), 'b': stat(color: 2, result: 2)},
        team: {'a', 'b'},
      );
      expect(r.internal, isTrue);
    });
  });

  group('ghost — loại trận không có giao tranh thật', () {
    test('một đội rỗng -> ghost', () {
      final r = parse(
        red: ['a'],
        blue: [],
        stats: {'a': stat(color: 1)},
        team: {'a'},
      );
      expect(r.ghost, isTrue);
    });

    test('tổng giết + mất quân < 10 -> ghost', () {
      final r = parse(
        red: ['a'],
        blue: ['b'],
        stats: {
          'a': stat(color: 1, kills: 2, losses: 1),
          'b': stat(color: 2, kills: 1, losses: 2, result: 2),
        },
        team: {'a', 'b'},
      );
      expect(r.ghost, isTrue);
    });

    test('đủ giao tranh -> không ghost', () {
      final r = parse(
        red: ['a'],
        blue: ['b'],
        stats: {'a': stat(color: 1), 'b': stat(color: 2, result: 2)},
        team: {'a', 'b'},
      );
      expect(r.ghost, isFalse);
    });
  });

  group('đếm người thực — người trùng màu là viewer, không tính', () {
    test('2 người cùng màu trong 1 đội -> đếm là 1', () {
      final r = parse(
        red: ['a', 'a2'],
        blue: ['b'],
        stats: {
          'a': stat(color: 1),
          'a2': stat(color: 1), // cùng slot -> viewer
          'b': stat(color: 2, result: 2),
        },
        team: {'a', 'a2', 'b'},
      );
      expect(r.redCount, 1);
      expect(r.blueCount, 1);
      expect(r.modeLabel, '1v1');
      expect(r.symmetricSize, 1);
    });

    test('màu 0 = thiếu dữ liệu -> KHÔNG gộp (khớp compute.mjs)', () {
      final r = parse(
        red: ['a', 'a2'],
        blue: ['b', 'b2'],
        stats: {
          'a': stat(color: 0),
          'a2': stat(color: 0),
          'b': stat(color: 0, result: 2),
          'b2': stat(color: 0, result: 2),
        },
        team: {'a', 'a2', 'b', 'b2'},
      );
      expect(r.redCount, 2);
      expect(r.blueCount, 2);
      expect(r.symmetricSize, 2);
    });

    test('trận lệch người -> không thuộc bảng thể loại nào', () {
      final r = parse(
        red: ['a', 'a2'],
        blue: ['b'],
        stats: {
          'a': stat(color: 1),
          'a2': stat(color: 3),
          'b': stat(color: 2, result: 2),
        },
        team: {'a', 'a2', 'b'},
      );
      expect(r.modeLabel, '2v1');
      expect(r.symmetricSize, isNull);
    });
  });

  group('viewerIsRealPlayer — trận mà người xem chỉ là viewer thì không tính',
      () {
    test('người xem đứng SAU người cùng màu -> không phải người chơi thực', () {
      final r = parse(
        red: ['first', 'me'],
        blue: ['b'],
        stats: {
          'first': stat(color: 1),
          'me': stat(color: 1), // trùng slot với 'first'
          'b': stat(color: 2, result: 2),
        },
        team: {'first', 'me', 'b'},
        viewer: 'me',
      );
      expect(r.viewerIsRealPlayer, isFalse);
    });

    test('người xem đứng TRƯỚC -> vẫn là người chơi thực', () {
      final r = parse(
        red: ['me', 'later'],
        blue: ['b'],
        stats: {
          'me': stat(color: 1),
          'later': stat(color: 1),
          'b': stat(color: 2, result: 2),
        },
        team: {'me', 'later', 'b'},
        viewer: 'me',
      );
      expect(r.viewerIsRealPlayer, isTrue);
    });
  });

  group('đối thủ / đồng đội', () {
    test('phân biệt đúng phía của người xem', () {
      final r = parse(
        red: ['a', 'mate'],
        blue: ['x', 'y'],
        stats: {
          'a': stat(color: 1),
          'mate': stat(color: 2),
          'x': stat(color: 3, result: 2),
          'y': stat(color: 4, result: 2),
        },
        team: {'a', 'mate', 'x', 'y'},
      );
      expect(r.win, isTrue);
      expect(r.teammateNames.length, 1);
      expect(r.opponentNames.length, 2);
    });
  });
}
