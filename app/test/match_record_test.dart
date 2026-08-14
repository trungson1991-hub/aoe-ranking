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
  int position = 0,
}) =>
    {
      'empires_color': color,
      'empires_type': 10,
      'result': result,
      'kills': kills,
      'losses': losses,
      'position': position,
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
    // 'me' chung màu với 'other'. Thứ tự trong mảng CỐ TÌNH luôn đặt 'me'
    // đứng trước, để chứng minh thứ tự không còn quyết định gì — thứ quyết
    // định là ai mang số liệu riêng, ai mang bản sao của người khác.
    MatchRecord withViewer({required bool meMangBanSao}) => parse(
          red: ['me', 'other'],
          blue: ['b'],
          stats: {
            // Bản sao = trùng khít số liệu của 'b' ở đội đối diện.
            'me': meMangBanSao
                ? stat(color: 1, kills: 44, losses: 11, result: 2, position: 1)
                : stat(color: 1, kills: 30, losses: 20, result: 2, position: 0),
            'other': meMangBanSao
                ? stat(color: 1, kills: 30, losses: 20, result: 2, position: 0)
                : stat(color: 1, kills: 44, losses: 11, result: 2, position: 1),
            'b': stat(color: 2, kills: 44, losses: 11, position: 4),
          },
          team: {'me', 'other', 'b'},
          viewer: 'me',
        );

    test('người xem mang bản sao số liệu -> không phải người chơi thực', () {
      expect(withViewer(meMangBanSao: true).viewerIsRealPlayer, isFalse);
    });

    test('người xem có số liệu riêng -> là người chơi thực', () {
      expect(withViewer(meMangBanSao: false).viewerIsRealPlayer, isTrue);
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

    // Thứ tự API trả về KHÔNG ổn định: cùng một cặp người, trận này 'dark'
    // đứng trước, trận sau 'chim' đứng trước. Lấy người đầu mảng là lấy bừa.
    // Người giữ slot phải là người có số liệu RIÊNG ('dark'), còn 'chim' mang
    // bản sao số liệu của 'minh' ở đội đối diện.
    MatchRecord sharedSlotCopyFirst() => parse(
          red: ['chim', 'dark'], // bản sao đứng TRƯỚC người thật
          blue: ['minh'],
          stats: {
            'chim': stat(color: 1, kills: 60, losses: 41, result: 2),
            'dark': stat(color: 1, kills: 41, losses: 82, result: 2),
            'minh': stat(color: 3, kills: 60, losses: 41),
          },
          team: {'dark', 'chim', 'minh'},
          viewer: 'minh',
        );

    test('người giữ slot là người có số liệu riêng, không phải người đầu mảng',
        () {
      final r = sharedSlotCopyFirst();
      expect(r.realAll.map((p) => p.uuid), ['dark', 'minh']);
      expect(r.slotSharers['dark']!.map((p) => p.uuid), ['chim']);
      // Cột chung slot phải mang số của 'dark', không phải bản sao của 'minh'.
      expect(r.realRed.single.kills, 41);
      expect(r.red.firstWhere((p) => p.uuid == 'chim').kills, 41);
    });

    // Số liệu không phân biệt được ai giữ slot -> phải chốt theo ghế, KHÔNG
    // theo thứ tự mảng. Thứ tự mảng API trả về đổi giữa các trận, để nó quyết
    // thì ELO nhảy qua nhảy lại giữa hai người mỗi lần tính lại.
    MatchRecord tie({required bool ghePhaiDungTruoc}) => parse(
          red: ghePhaiDungTruoc ? ['ghe0', 'ghe1'] : ['ghe1', 'ghe0'],
          blue: ['minh'],
          stats: {
            'ghe0': stat(color: 1, kills: 30, losses: 20, result: 2, position: 0),
            'ghe1': stat(color: 1, kills: 30, losses: 20, result: 2, position: 1),
            'minh': stat(color: 3, kills: 44, losses: 11),
          },
          team: {'ghe0', 'ghe1', 'minh'},
          viewer: 'minh',
        );

    test('2 người cùng màu VÀ số liệu giống hệt -> chốt theo ghế nhỏ hơn', () {
      for (final ghe0DungTruoc in [true, false]) {
        final r = tie(ghePhaiDungTruoc: ghe0DungTruoc);
        expect(r.realAll.map((p) => p.uuid), ['ghe0', 'minh'],
            reason: 'đổi thứ tự mảng không được đổi người giữ slot');
        expect(r.slotSharers['ghe0']!.single.uuid, 'ghe1');
      }
    });

    test('người giữ slot mới là người được tính vào lịch sử/ELO', () {
      final r = sharedSlotCopyFirst();
      expect(r.realPlayerUuids, containsAll(['dark', 'minh']));
      expect(r.realPlayerUuids.contains('chim'), isFalse);
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
