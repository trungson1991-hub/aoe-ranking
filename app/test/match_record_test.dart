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

    test('tổng giết + mất quân < 5 -> ghost', () {
      final r = parse(
        red: ['a'],
        blue: ['b'],
        stats: {
          'a': stat(color: 1, kills: 1, losses: 1),
          'b': stat(color: 2, kills: 1, losses: 1, result: 2),
        },
        team: {'a', 'b'},
      );
      expect(r.ghost, isTrue); // kd = 4
    });

    test('đúng ngưỡng 5 -> KHÔNG còn là ghost', () {
      final r = parse(
        red: ['a'],
        blue: ['b'],
        stats: {
          'a': stat(color: 1, kills: 2, losses: 1),
          'b': stat(color: 2, kills: 1, losses: 1, result: 2),
        },
        team: {'a', 'b'},
      );
      expect(r.ghost, isFalse); // kd = 5
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

  group('người xem chung slot không được lọt vào phần hiển thị', () {
    // Dựng theo trận thật (room 810709): đội Đỏ có 2 người cùng
    // empires_color=1 — thực chất là 1v1, người thứ hai chỉ xem chung slot và
    // mang y hệt số liệu của người khác.
    MatchRecord sharedSlot() => parse(
          red: ['dark', 'chim'],
          blue: ['minh'],
          stats: {
            'dark': stat(color: 1, kills: 93, losses: 129, result: 2),
            'chim': stat(color: 1, kills: 128, losses: 93, result: 2),
            'minh': stat(color: 3, kills: 128, losses: 93),
          },
          team: {'dark', 'chim', 'minh'},
          viewer: 'minh',
        );

    test('bảng so sánh chỉ còn người chơi thực', () {
      final r = sharedSlot();
      expect(r.realAll.map((p) => p.uuid), ['dark', 'minh']);
      expect(r.modeLabel, '1v1');
    });

    test('tổng của đội không bị cộng đôi', () {
      final r = sharedSlot();
      // Cộng cả người xem sẽ ra 93+128=221 thay vì 93.
      expect(r.realRed.fold(0, (a, p) => a + p.kills), 93);
      expect(r.realBlue.fold(0, (a, p) => a + p.kills), 128);
    });

    test('cùng màu -> cùng chỉ số, lấy theo người giữ slot', () {
      final r = sharedSlot();
      final chim = r.red.firstWhere((p) => p.uuid == 'chim');
      // API trả cho 'chim' bộ 128/93 (copy nhầm của đối thủ 'minh'); phải bị
      // thay bằng số của 'dark' — người giữ slot màu 1.
      expect(chim.kills, 93);
      expect(chim.losses, 129);
      expect(chim.uuid, 'chim'); // danh tính vẫn giữ nguyên
    });

    test('ghost vẫn tính trên số THÔ để khớp compute.mjs', () {
      // Thô: 3+0 (dark) + 0+0 (chim) + 1+0 (minh) = 4 < 5 -> trận ma.
      // Nếu lỡ tính sau khi đồng bộ slot, 'chim' thành 3 -> kd=7 -> hết ma,
      // và số trận trong app sẽ lệch số trận dùng để tính ELO.
      final r = parse(
        red: ['dark', 'chim'],
        blue: ['minh'],
        stats: {
          'dark': stat(color: 1, kills: 3, losses: 0, result: 2),
          'chim': stat(color: 1, kills: 0, losses: 0, result: 2),
          'minh': stat(color: 3, kills: 1, losses: 0),
        },
        team: {'dark', 'chim', 'minh'},
        viewer: 'minh',
      );
      expect(r.ghost, isTrue);
    });

    test('người chung slot vẫn hiện, gắn vào cột của người cùng màu', () {
      final r = sharedSlot();
      // 'chim' cùng màu với 'dark' -> treo vào cột của 'dark', không tự đứng cột.
      expect(r.slotSharers['dark']!.map((p) => p.uuid), ['chim']);
      expect(r.slotSharers.containsKey('minh'), isFalse);
    });

    test('thiếu màu (color 0) thì KHÔNG gộp, mỗi người một cột', () {
      final r = parse(
        red: ['a', 'a2'],
        blue: ['b'],
        stats: {
          'a': stat(color: 0),
          'a2': stat(color: 0),
          'b': stat(color: 2, result: 2),
        },
        team: {'a', 'a2', 'b'},
      );
      expect(r.slotSharers, isEmpty);
      expect(r.realAll.length, 3);
    });

    test('dòng "vs …" không kể tên người xem', () {
      final r = sharedSlot();
      expect(r.opponentNames, ['dark']);
      expect(r.teammateNames, isEmpty);
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
