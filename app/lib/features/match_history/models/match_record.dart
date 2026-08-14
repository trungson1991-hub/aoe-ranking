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

  /// Ghế trong phòng (0-3 đội Đỏ, 4-7 đội Xanh). Chỉ dùng để phân xử khi hai
  /// người cùng màu mà số liệu không phân biệt được ai giữ slot.
  final int position;

  // Mốc BẤM lên đời theo đồng hồ TRONG trận (ms), 0 = chưa lên tới đời đó.
  // Đây KHÔNG phải số thô của API: API trả mốc lên đời xong, `fromApi` đã trừ
  // thời gian nghiên cứu để ra mốc bấm.
  // API đặt tên trường theo tên đời đích chứ không theo số: stone = đời 2,
  // bronze = đời 3, steel = đời 4 (khớp với `age`: age 3 luôn có đúng 2 mốc).
  final int age2Time;
  final int age3Time;
  final int age4Time;

  /// Uuid người GIỮ SLOT của mình; rỗng = tự giữ slot. Khác rỗng nghĩa là mình
  /// ngồi chung slot với người đó và số liệu ở đây là số của họ.
  ///
  /// Quyết định này do `MatchRecord.fromApi` chốt MỘT LẦN trên số liệu thô rồi
  /// ghi lại vào đây. Không được suy diễn lại về sau: sau khi đồng bộ số liệu,
  /// bản sao và bản gốc giống hệt nhau nên dấu hiệu để phân biệt đã mất.
  final String slotOwnerUuid;

  bool get isSlotOwner => slotOwnerUuid.isEmpty || slotOwnerUuid == uuid;

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
    this.position = 99,
    this.age2Time = 0,
    this.age3Time = 0,
    this.age4Time = 0,
    this.slotOwnerUuid = '',
  });

  String get label => name.isNotEmpty
      ? name
      : (uuid.length >= 6 ? uuid.substring(0, 6) : uuid);

  /// Giữ danh tính (uuid + tên) nhưng lấy TOÀN BỘ chỉ số của [owner].
  ///
  /// Dùng cho người ngồi chung slot: cùng `empires_color` là cùng một slot
  /// trong game nên phải cùng chỉ số. API vẫn trả cho họ một khối thống kê
  /// riêng, nhưng khối đó SAI — đối chiếu dữ liệu thật thì nó trùng khít từng
  /// chỉ số với một người chơi khác trong trận, kể cả người ở đội đối diện.
  PlayerStat withStatsOf(PlayerStat owner) => PlayerStat(
        uuid: uuid,
        name: name,
        color: owner.color,
        empiresType: owner.empiresType,
        win: owner.win,
        kills: owner.kills,
        losses: owner.losses,
        razings: owner.razings,
        gold: owner.gold,
        villager: owner.villager,
        population: owner.population,
        technologies: owner.technologies,
        exploration: owner.exploration,
        tribute: owner.tribute,
        age: owner.age,
        // position là chỗ ngồi của CHÍNH mình, thuộc danh tính chứ không phải
        // số liệu lối chơi, nên giữ nguyên như uuid/tên.
        position: position,
        age2Time: owner.age2Time,
        age3Time: owner.age3Time,
        age4Time: owner.age4Time,
        slotOwnerUuid: owner.uuid,
      );

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
      // Thiếu position -> 99 để KHÔNG vô tình thắng ở bước phân xử theo ghế.
      position: (s['position'] is num) ? (s['position'] as num).toInt() : 99,
      age2Time: _clickTime(_int(s['stone_age_upgraded_time']), _age2ResearchMs),
      age3Time: _clickTime(_int(s['bronze_age_upgraded_time']), _age3ResearchMs),
      age4Time: _clickTime(_int(s['steel_age_upgraded_time']), _age4ResearchMs),
    );
  }
}

/// Luật gốc về "slot": nhiều người cùng `empires_color` là CÙNG MỘT người chơi
/// (1 màu = 1 slot trong AoE). color <= 0 = thiếu dữ liệu màu -> không gộp
/// được, mỗi người một slot. Khớp `realPlayers()` trong scripts/compute.mjs.
///
/// Người GIỮ SLOT là người có bộ số liệu RIÊNG — vân tay không trùng với người
/// chơi màu khác nào trong trận. KHÔNG được lấy người đầu tiên trong mảng: thứ
/// tự API trả về KHÔNG ổn định (cùng một cặp người, trận này người này đứng
/// trước, trận sau người kia), còn GPlay thì hay trả cho người còn lại một bản
/// sao số liệu của người khác, kể cả người ở đội đối diện.
///
/// Trả về từng người kèm người giữ slot của họ (`identical` = chính họ giữ).
/// Cả lúc parse lẫn lúc dẫn xuất danh sách đều gọi hàm này.
Iterable<(PlayerStat player, PlayerStat owner)> _bySlot(
    Iterable<PlayerStat> ordered) sync* {
  final players = ordered.toList();

  // Vân tay số liệu lối chơi. Không lấy mốc lên đời (đã trừ thời gian nghiên
  // cứu nên "chưa đạt" lẫn với mốc thật) và không lấy kết quả thắng/thua (bản
  // sao vẫn bị gán theo đội của người nhận).
  String fp(PlayerStat p) => '${p.kills}|${p.losses}|${p.razings}|${p.gold}|'
      '${p.villager}|${p.population}|${p.technologies}|${p.exploration}|'
      '${p.tribute}|${p.age}';

  // Cùng một vân tay xuất hiện ở HAI màu khác nhau = có bản sao. Trùng khít
  // 10 chỉ số giữa hai người thì không thể là ngẫu nhiên.
  final colorsOf = <String, Set<int>>{};
  for (final p in players) {
    (colorsOf[fp(p)] ??= <int>{}).add(p.color);
  }
  bool isCopy(PlayerStat p) => (colorsOf[fp(p)]?.length ?? 1) > 1;

  // Ưu tiên người có số liệu riêng. Hoà thì lấy ghế nhỏ hơn: mỗi khi vân tay
  // quyết được, người nó chọn LUÔN là người ghế nhỏ nhất (3/3 trên dữ liệu
  // thật). Hoà nữa thì so uuid — cốt để kết quả KHÔNG phụ thuộc thứ tự mảng
  // API trả về, vì thứ tự đó đổi giữa các trận và sẽ làm ELO nhảy qua nhảy lại
  // giữa hai người mỗi lần tính lại.
  bool better(PlayerStat a, PlayerStat b) {
    if (isCopy(a) != isCopy(b)) return !isCopy(a);
    if (a.position != b.position) return a.position < b.position;
    return a.uuid.compareTo(b.uuid) < 0;
  }

  final owner = <int, PlayerStat>{};
  for (final p in players) {
    if (p.color <= 0) continue;
    final cur = owner[p.color];
    if (cur == null || better(p, cur)) owner[p.color] = p;
  }

  for (final p in players) {
    yield p.color <= 0 ? (p, p) : (p, owner[p.color]!);
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

  /// Đội nhà / đội đối thủ — CHỈ người chơi thực, xem `realRed`.
  List<PlayerStat> get myTeam => _viewerInRed ? realRed : realBlue;
  List<PlayerStat> get oppTeam => _viewerInRed ? realBlue : realRed;

  /// Chỉ mục slot: chỉ ĐỌC LẠI quyết định mà `fromApi` đã chốt trên số liệu
  /// thô (xem `PlayerStat.slotOwnerUuid`). Không được suy diễn lại từ `all`:
  /// số liệu ở đây đã đồng bộ nên bản sao và bản gốc giống hệt nhau, dấu hiệu
  /// phân biệt đã mất và sẽ chọn nhầm người giữ slot.
  ///
  /// MatchRecord dựng thẳng (không qua `fromApi`) thì mọi người đều tự giữ slot.
  late final ({Set<String> owners, Map<String, List<PlayerStat>> sharers})
      _slotIndex = () {
    final owners = <String>{};
    final sharers = <String, List<PlayerStat>>{};
    for (final p in all) {
      if (p.isSlotOwner) {
        owners.add(p.uuid);
      } else {
        (sharers[p.slotOwnerUuid] ??= <PlayerStat>[]).add(p);
      }
    }
    return (owners: owners, sharers: sharers);
  }();

  /// Uuid của những người chơi THỰC — mỗi slot đúng một người (xem `_bySlot`).
  Set<String> get realPlayerUuids => _slotIndex.owners;

  /// Người đang xem có thực sự chơi trận này không (hay chỉ là viewer chung
  /// slot). Trận mà người xem là viewer KHÔNG được tính vào ELO của họ, nên
  /// cũng không nên đếm vào lịch sử — nếu không, tổng số trận ở trang lịch sử
  /// sẽ lệch với số trận trên bảng xếp hạng.
  bool get viewerIsRealPlayer => realPlayerUuids.contains(viewerUuid);

  /// Danh sách người chơi đã bỏ người xem chung slot. MỌI chỗ hiển thị số liệu
  /// phải dùng các danh sách này chứ không phải `red`/`blue`/`all`: giữ người
  /// xem lại sẽ đẻ ra một cột ma trùng y hệt số liệu người khác trong bảng so
  /// sánh, và cộng đôi tổng của cả đội ở khối tương quan.
  late final List<PlayerStat> realRed = _onlyReal(red);
  late final List<PlayerStat> realBlue = _onlyReal(blue);
  late final List<PlayerStat> realAll = [...realRed, ...realBlue];

  List<PlayerStat> _onlyReal(List<PlayerStat> side) =>
      [for (final p in side) if (realPlayerUuids.contains(p.uuid)) p];

  /// Những người ngồi CHUNG slot với một người chơi thực, tra theo uuid của
  /// người thực đó. Bảng so sánh hiện tên/avatar của họ trên cùng một cột.
  ///
  /// Chỉ số của họ đã được `fromApi` đồng bộ theo người giữ slot (xem
  /// `PlayerStat.withStatsOf`), nên vẫn phải gộp cột: để riêng thì tổng của đội
  /// bị cộng đôi và mọi hàng đều thành "hoà nhau".
  Map<String, List<PlayerStat>> get slotSharers => _slotIndex.sharers;

  late final int redCount = realRed.length;
  late final int blueCount = realBlue.length;
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

    final rawRed = redM.map((m) => PlayerStat.fromApi(m, stats)).toList();
    final rawBlue = blueM.map((m) => PlayerStat.fromApi(m, stats)).toList();
    final rawAll = [...rawRed, ...rawBlue];

    final internal =
        rawAll.isNotEmpty && rawAll.every((p) => teamSet.contains(p.uuid));

    // Ghost: một đội rỗng (không có đối thủ) / tổng kills+losses < 5.
    // Ngưỡng phải KHỚP isGhost() trong scripts/compute.mjs.
    // Tính trên số THÔ, trước khi đồng bộ slot: isGhost() trong compute.mjs
    // cộng thẳng m.statistics, lệch một trận là số trận ở đây khác số trận
    // dùng để tính ELO.
    var kd = 0;
    for (final p in rawAll) {
      kd += p.kills + p.losses;
    }
    final ghost = rawRed.isEmpty || rawBlue.isEmpty || kd < 5;

    // Cùng empires_color = cùng một slot trong game -> phải cùng chỉ số.
    // Duyệt cả trận một lượt theo thứ tự red rồi blue (đúng thứ tự `_bySlot`)
    // rồi mới cắt lại hai bên, để "người giữ slot" nhất quán với phần dẫn xuất.
    final synced = [
      for (final (p, owner) in _bySlot(rawAll))
        identical(p, owner) ? p : p.withStatsOf(owner),
    ];
    final red = synced.sublist(0, rawRed.length);
    final blue = synced.sublist(rawRed.length);

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
