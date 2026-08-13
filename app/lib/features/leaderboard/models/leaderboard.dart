// Model khớp document JSON do scripts/compute.mjs sinh ra.
// Mỗi thành viên có thống kê Tổng + theo từng thể loại (1v1/2v2/3v3/4v4).
// Việc xếp hạng tính ở client theo chế độ đang chọn.

import '../../../core/utils/datetime_vn.dart';

const List<String> kModeKeys = ['1v1', '2v2', '3v3', '4v4'];
const String kTotalKey = 'total';

/// Mốc ELO xuất phát (mọi người bắt đầu từ đây, không bao giờ âm).
const int kEloBase = 1000;

/// Dưới ngưỡng này (số trận trong bảng) ELO còn "tạm xếp" — chưa đủ tin cậy.
const int kPlacementGames = 10;

int _asInt(dynamic v) => (v is num) ? v.toInt() : 0;

class ModeStat {
  final int elo;
  final int games;
  final int wins;
  final int losses;

  const ModeStat({this.elo = 0, this.games = 0, this.wins = 0, this.losses = 0});

  double get winRate => games == 0 ? 0 : wins / games;

  /// Đã có trận trong bảng này (chưa có thì không xếp hạng).
  bool get isRated => games > 0;

  /// Còn trong giai đoạn định hạng (ELO chưa ổn định).
  bool get isProvisional => games > 0 && games < kPlacementGames;

  factory ModeStat.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ModeStat();
    return ModeStat(
      elo: _asInt(m['elo']),
      games: _asInt(m['games']),
      wins: _asInt(m['wins']),
      losses: _asInt(m['losses']),
    );
  }
}

class Member {
  final String userUuid;
  final String name;
  final String avatarUrl;
  final int lastPlayed; // epoch giây, 0 nếu không có
  final ModeStat total;
  final Map<String, ModeStat> modes;

  // Đồ trang trí mua trong game (rỗng nếu người chơi không có).
  // Ảnh thực tế là GIF động dù đuôi .png.
  final String vipFrameUrl; // khung tròn quanh avatar
  final String backgroundUrl; // ảnh nền ngang cho thẻ
  final String effectUrl; // vòng sáng quanh avatar

  const Member({
    required this.userUuid,
    required this.name,
    required this.avatarUrl,
    required this.lastPlayed,
    required this.total,
    required this.modes,
    this.vipFrameUrl = '',
    this.backgroundUrl = '',
    this.effectUrl = '',
  });

  bool get hasDecoration =>
      vipFrameUrl.isNotEmpty || backgroundUrl.isNotEmpty || effectUrl.isNotEmpty;

  // view = 'total' | '1v1' | '2v2' | '3v3' | '4v4'
  ModeStat statFor(String view) =>
      view == kTotalKey ? total : (modes[view] ?? const ModeStat());

  DateTime? get lastPlayedVN => lastPlayed <= 0 ? null : epochToVN(lastPlayed);

  factory Member.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic>? sub(dynamic v) =>
        v == null ? null : Map<String, dynamic>.from(v as Map);
    final rawModes = (m['modes'] as Map?) ?? {};
    final modes = <String, ModeStat>{
      for (final k in kModeKeys) k: ModeStat.fromMap(sub(rawModes[k])),
    };
    return Member(
      userUuid: (m['user_uuid'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      avatarUrl: (m['avatar_url'] ?? '') as String,
      vipFrameUrl: (m['vip_frame_url'] ?? '') as String,
      backgroundUrl: (m['background_url'] ?? '') as String,
      effectUrl: (m['effect_url'] ?? '') as String,
      lastPlayed: _asInt(m['last_played']),
      total: ModeStat.fromMap(sub(m['total'])),
      modes: modes,
    );
  }
}

class Leaderboard {
  final int updatedEpoch;
  final int startEpoch;
  final int internalMatches;
  final List<Member> members;

  const Leaderboard({
    required this.updatedEpoch,
    required this.startEpoch,
    required this.internalMatches,
    required this.members,
  });

  DateTime get updatedAtVN => epochToVN(updatedEpoch);
  DateTime get startDateVN => epochToVN(startEpoch);

  factory Leaderboard.fromMap(Map<String, dynamic> m) {
    final members = (m['members'] as List<dynamic>? ?? [])
        .map((e) => Member.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Leaderboard(
      updatedEpoch: _asInt(m['updated_at']),
      startEpoch: _asInt(m['start_epoch']),
      internalMatches: _asInt(m['internal_matches']),
      members: members,
    );
  }
}
