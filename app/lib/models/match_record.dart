// Một trận trong lịch sử của 1 user (parse trực tiếp từ API GPlay).

class MatchRecord {
  final int createdTime; // epoch giây
  final int roomId;
  final int redCount;
  final int blueCount;
  final bool win;
  final int kills;
  final int losses;
  final List<String> teammates;
  final List<String> opponents;

  const MatchRecord({
    required this.createdTime,
    required this.roomId,
    required this.redCount,
    required this.blueCount,
    required this.win,
    required this.kills,
    required this.losses,
    required this.teammates,
    required this.opponents,
  });

  // Nhãn thể loại theo số người thực (đã loại trùng màu): "4v4", "3v2"...
  String get modeLabel => '${redCount}v$blueCount';

  // Kích thước nếu là trận cân người 1v1/2v2/3v3/4v4, ngược lại null.
  int? get symmetricSize =>
      (redCount == blueCount && redCount >= 1 && redCount <= 4)
          ? redCount
          : null;

  DateTime get dateVN =>
      DateTime.fromMillisecondsSinceEpoch(createdTime * 1000, isUtc: true)
          .add(const Duration(hours: 7));

  static int _int(dynamic v) => (v is num) ? v.toInt() : 0;

  factory MatchRecord.fromApi(Map<String, dynamic> j, String viewerUuid) {
    List<Map<String, dynamic>> side(String k) =>
        ((j[k] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    final red = side('red_team_members');
    final blue = side('blue_team_members');
    final stats = (j['statistics'] as Map?) ?? const {};

    int colorOf(String uuid) {
      final s = stats[uuid];
      if (s is Map) return _int(s['empires_color']);
      return -1;
    }

    // Đếm người thực mỗi đội = số màu (empires_color) khác nhau; trùng màu = viewer.
    int distinct(List<Map<String, dynamic>> members) {
      final seen = <int>{};
      var n = 0;
      for (final m in members) {
        final c = colorOf((m['user_uuid'] ?? '') as String);
        if (c < 0) {
          n++; // không có màu -> tính riêng
        } else if (seen.add(c)) {
          n++;
        }
      }
      return n;
    }

    // Xác định viewer ở đội nào.
    final inRed = red.any((m) => m['user_uuid'] == viewerUuid);
    final myTeam = inRed ? red : blue;
    final oppTeam = inRed ? blue : red;

    List<String> names(List<Map<String, dynamic>> members, {String? exclude}) {
      final out = <String>[];
      final seen = <String>{};
      for (final m in members) {
        final uuid = (m['user_uuid'] ?? '') as String;
        if (exclude != null && uuid == exclude) continue;
        final name = (m['name'] ?? '') as String;
        final label = name.isNotEmpty
            ? name
            : (uuid.length >= 6 ? uuid.substring(0, 6) : uuid);
        if (seen.add(label)) out.add(label);
      }
      return out;
    }

    final myStat = stats[viewerUuid];
    final result = (myStat is Map) ? _int(myStat['result']) : 0;

    return MatchRecord(
      createdTime: _int(j['created_time']),
      roomId: _int(j['room_id']),
      redCount: distinct(red),
      blueCount: distinct(blue),
      win: result == 1,
      kills: (myStat is Map) ? _int(myStat['kills']) : 0,
      losses: (myStat is Map) ? _int(myStat['losses']) : 0,
      teammates: names(myTeam, exclude: viewerUuid),
      opponents: names(oppTeam),
    );
  }
}
