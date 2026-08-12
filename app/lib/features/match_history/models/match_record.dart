// Một trận (parse trực tiếp từ API GPlay), đủ dữ liệu cho cả danh sách lẫn chi tiết.

import '../../../core/utils/datetime_vn.dart';

int _int(dynamic v) => (v is num) ? v.toInt() : 0;

class PlayerStat {
  final String uuid;
  final String name;
  final int color; // empires_color; 0 = không có dữ liệu thống kê
  final int empiresType; // loại quân
  final bool win;
  final int kills;
  final int losses; // mất quân
  final int razings; // phá công trình
  final int gold; // đào vàng
  final int villager; // nông dân đỉnh
  final int population; // tổng dân số
  final int technologies;
  final int exploration; // mở bản đồ (%)
  final int tribute; // bơm đồ
  final int age; // thời đại đạt được

  const PlayerStat({
    required this.uuid,
    required this.name,
    required this.color,
    required this.empiresType,
    required this.win,
    required this.kills,
    required this.losses,
    required this.razings,
    required this.gold,
    required this.villager,
    required this.population,
    required this.technologies,
    required this.exploration,
    required this.tribute,
    required this.age,
  });

  String get label => name.isNotEmpty
      ? name
      : (uuid.length >= 6 ? uuid.substring(0, 6) : uuid);

  factory PlayerStat.fromApi(
      Map<String, dynamic> member, Map<String, dynamic> stats) {
    final uuid = (member['user_uuid'] ?? '') as String;
    final s = (stats[uuid] is Map)
        ? Map<String, dynamic>.from(stats[uuid] as Map)
        : const <String, dynamic>{};
    return PlayerStat(
      uuid: uuid,
      name: (member['name'] ?? '') as String,
      color: _int(s['empires_color']),
      empiresType: _int(s['empires_type']),
      win: _int(s['result']) == 1,
      kills: _int(s['kills']),
      losses: _int(s['losses']),
      razings: _int(s['razings']),
      gold: _int(s['gold_collected']),
      villager: _int(s['villager_high']),
      population: _int(s['total_population']),
      technologies: _int(s['technologies']),
      exploration: _int(s['exploration']),
      tribute: _int(s['tribute_given']),
      age: _int(s['age']),
    );
  }
}

class MatchRecord {
  final int createdTime;
  final int roomId;
  final List<PlayerStat> red;
  final List<PlayerStat> blue;
  final String viewerUuid;
  final bool internal; // mọi người chơi đều thuộc team
  final bool ghost; // trận "ma" (không tính ELO)

  const MatchRecord({
    required this.createdTime,
    required this.roomId,
    required this.red,
    required this.blue,
    required this.viewerUuid,
    required this.internal,
    required this.ghost,
  });

  List<PlayerStat> get all => [...red, ...blue];

  PlayerStat? get viewer {
    for (final p in all) {
      if (p.uuid == viewerUuid) return p;
    }
    return null;
  }

  bool get win => viewer?.win ?? false;
  bool _viewerInRed() => red.any((p) => p.uuid == viewerUuid);
  List<PlayerStat> get myTeam => _viewerInRed() ? red : blue;
  List<PlayerStat> get oppTeam => _viewerInRed() ? blue : red;

  // Số người thực mỗi đội = số màu khác nhau (trùng màu = viewer/cùng slot).
  // color <= 0 nghĩa là không có dữ liệu màu -> không gộp được, mỗi người tính
  // là 1 slot riêng (khớp luật của scripts/compute.mjs).
  int _distinct(List<PlayerStat> side) {
    final seen = <int>{};
    var n = 0;
    for (final p in side) {
      if (p.color <= 0 || seen.add(p.color)) n++;
    }
    return n;
  }

  int get redCount => _distinct(red);
  int get blueCount => _distinct(blue);
  String get modeLabel => '${redCount}v$blueCount';
  int? get symmetricSize =>
      (redCount == blueCount && redCount >= 1 && redCount <= 4)
          ? redCount
          : null;

  List<String> get opponentNames => _names(oppTeam);

  /// Đồng đội (không tính chính mình).
  List<String> get teammateNames =>
      _names(myTeam.where((p) => p.uuid != viewerUuid));

  List<String> _names(Iterable<PlayerStat> side) {
    final seen = <String>{};
    final out = <String>[];
    for (final p in side) {
      if (seen.add(p.label)) out.add(p.label);
    }
    return out;
  }

  DateTime get dateVN => epochToVN(createdTime);

  factory MatchRecord.fromApi(
    Map<String, dynamic> j,
    String viewerUuid,
    Set<String> teamSet,
  ) {
    List<Map<String, dynamic>> side(String k) => ((j[k] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final redM = side('red_team_members');
    final blueM = side('blue_team_members');
    final stats = (j['statistics'] is Map)
        ? Map<String, dynamic>.from(j['statistics'] as Map)
        : <String, dynamic>{};

    final red = redM.map((m) => PlayerStat.fromApi(m, stats)).toList();
    final blue = blueM.map((m) => PlayerStat.fromApi(m, stats)).toList();
    final all = [...red, ...blue];

    final internal =
        all.isNotEmpty && all.every((p) => teamSet.contains(p.uuid));

    // Ghost: <=1 người / một đội rỗng / tổng kills+losses < 10.
    var kd = 0;
    for (final p in all) {
      kd += p.kills + p.losses;
    }
    final ghost = (red.length + blue.length) <= 1 ||
        red.isEmpty ||
        blue.isEmpty ||
        kd < 10;

    return MatchRecord(
      createdTime: _int(j['created_time']),
      roomId: _int(j['room_id']),
      red: red,
      blue: blue,
      viewerUuid: viewerUuid,
      internal: internal,
      ghost: ghost,
    );
  }
}
