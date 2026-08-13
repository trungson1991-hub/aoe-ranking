// Một trận (parse trực tiếp từ API GPlay), đủ dữ liệu cho cả danh sách lẫn chi tiết.

import '../../../core/utils/datetime_vn.dart';

int _int(dynamic v) => (v is num) ? v.toInt() : 0;

// Thời gian nghiên cứu lên đời (ms). API chỉ trả mốc lên đời XONG, nhưng cái
// người chơi muốn so là mốc BẤM lên đời — nên lùi lại đúng bằng các hằng này.
const int _age2ResearchMs = 120 * 1000; // đời 1 -> 2: 2 phút
const int _age3ResearchMs = 140 * 1000; // đời 2 -> 3: 2 phút 20
const int _age4ResearchMs = 160 * 1000; // đời 3 -> 4: 2 phút 40

/// Lùi mốc "lên đời xong" về mốc "bấm lên đời".
/// 0 phải giữ nguyên 0 (chưa lên tới đời đó) chứ không được thành số âm.
int _clickTime(int doneMs, int researchMs) =>
    doneMs <= 0 ? 0 : doneMs - researchMs;

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

  // Mốc BẤM lên đời theo đồng hồ TRONG trận (ms), 0 = chưa lên tới đời đó.
  // Đây KHÔNG phải số thô của API: API trả mốc lên đời xong, `fromApi` đã trừ
  // thời gian nghiên cứu để ra mốc bấm.
  // API đặt tên trường theo tên đời đích chứ không theo số: stone = đời 2,
  // bronze = đời 3, steel = đời 4 (khớp với `age`: age 3 luôn có đúng 2 mốc).
  final int age2Time;
  final int age3Time;
  final int age4Time;

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
    this.age2Time = 0,
    this.age3Time = 0,
    this.age4Time = 0,
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
      age2Time: _clickTime(_int(s['stone_age_upgraded_time']), _age2ResearchMs),
      age3Time: _clickTime(_int(s['bronze_age_upgraded_time']), _age3ResearchMs),
      age4Time: _clickTime(_int(s['steel_age_upgraded_time']), _age4ResearchMs),
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

  // Không const: các trường dẫn xuất bên dưới dùng `late final` để nhớ kết quả.
  MatchRecord({
    required this.createdTime,
    required this.roomId,
    required this.red,
    required this.blue,
    required this.viewerUuid,
    required this.internal,
    required this.ghost,
  });

  // Các giá trị dẫn xuất được tính 1 lần rồi nhớ lại: mỗi thẻ trận đọc
  // chúng nhiều lần trong lúc vẽ, tính lại mỗi lần sẽ cấp phát list/Set thừa.
  late final List<PlayerStat> all = [...red, ...blue];

  late final PlayerStat? viewer = () {
    for (final p in all) {
      if (p.uuid == viewerUuid) return p;
    }
    return null;
  }();

  late final bool win = viewer?.win ?? false;
  late final bool _viewerInRed = red.any((p) => p.uuid == viewerUuid);
  List<PlayerStat> get myTeam => _viewerInRed ? red : blue;
  List<PlayerStat> get oppTeam => _viewerInRed ? blue : red;

  /// Uuid của những người chơi THỰC (khớp `realPlayers` trong compute.mjs):
  /// nếu nhiều người cùng `empires_color` (chung một slot) thì chỉ người xuất
  /// hiện đầu tiên được tính, những người sau là "viewer". color <= 0 nghĩa là
  /// thiếu dữ liệu màu -> không gộp được, mỗi người là 1 slot riêng.
  late final Set<String> realPlayerUuids = () {
    final seenColor = <int>{};
    final out = <String>{};
    for (final p in all) {
      if (p.color <= 0 || seenColor.add(p.color)) out.add(p.uuid);
    }
    return out;
  }();

  /// Người đang xem có thực sự chơi trận này không (hay chỉ là viewer chung
  /// slot). Trận mà người xem là viewer KHÔNG được tính vào ELO của họ, nên
  /// cũng không nên đếm vào lịch sử — nếu không, tổng số trận ở trang lịch sử
  /// sẽ lệch với số trận trên bảng xếp hạng.
  bool get viewerIsRealPlayer => realPlayerUuids.contains(viewerUuid);

  int _countReal(List<PlayerStat> side) =>
      side.where((p) => realPlayerUuids.contains(p.uuid)).length;

  late final int redCount = _countReal(red);
  late final int blueCount = _countReal(blue);
  late final String modeLabel = '${redCount}v$blueCount';
  late final int? symmetricSize =
      (redCount == blueCount && redCount >= 1 && redCount <= 4)
          ? redCount
          : null;

  late final List<String> opponentNames = _names(oppTeam);

  /// Đồng đội (không tính chính mình).
  late final List<String> teammateNames =
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

    // Ghost: một đội rỗng (không có đối thủ) / tổng kills+losses < 10.
    var kd = 0;
    for (final p in all) {
      kd += p.kills + p.losses;
    }
    final ghost = red.isEmpty || blue.isEmpty || kd < 10;

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
