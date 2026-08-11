// Model khớp document JSON do scripts/compute.mjs sinh ra.
// Mỗi thành viên có thống kê Tổng + theo từng thể loại (1v1/2v2/3v3/4v4).
// Việc xếp hạng & chia tier tính ở client theo chế độ đang chọn.

const List<String> kModeKeys = ['1v1', '2v2', '3v3', '4v4'];
const String kTotalKey = 'total';

class ModeStat {
  final int elo;
  final int games;
  final int wins;
  final int losses;

  const ModeStat({this.elo = 0, this.games = 0, this.wins = 0, this.losses = 0});

  double get winRate => games == 0 ? 0 : wins / games;

  factory ModeStat.fromMap(Map<String, dynamic>? m) {
    int asInt(dynamic v) => (v is num) ? v.toInt() : 0;
    if (m == null) return const ModeStat();
    return ModeStat(
      elo: asInt(m['elo']),
      games: asInt(m['games']),
      wins: asInt(m['wins']),
      losses: asInt(m['losses']),
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

  const Member({
    required this.userUuid,
    required this.name,
    required this.avatarUrl,
    required this.lastPlayed,
    required this.total,
    required this.modes,
  });

  // view = 'total' | '1v1' | '2v2' | '3v3' | '4v4'
  ModeStat statFor(String view) =>
      view == kTotalKey ? total : (modes[view] ?? const ModeStat());

  // Ngày chơi gần nhất theo giờ VN (UTC+7); null nếu chưa có.
  DateTime? get lastPlayedVN => lastPlayed <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastPlayed * 1000, isUtc: true)
          .add(const Duration(hours: 7));

  factory Member.fromMap(Map<String, dynamic> m) {
    int asInt(dynamic v) => (v is num) ? v.toInt() : 0;
    Map<String, dynamic>? sub(dynamic v) =>
        v == null ? null : Map<String, dynamic>.from(v as Map);
    final rawModes = (m['modes'] as Map?) ?? {};
    final modes = <String, ModeStat>{};
    for (final k in kModeKeys) {
      modes[k] = ModeStat.fromMap(sub(rawModes[k]));
    }
    return Member(
      userUuid: (m['user_uuid'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      avatarUrl: (m['avatar_url'] ?? '') as String,
      lastPlayed: asInt(m['last_played']),
      total: ModeStat.fromMap(sub(m['total'])),
      modes: modes,
    );
  }
}

class TierDef {
  final String label;
  final int size;
  const TierDef(this.label, this.size);
}

class RankedMember {
  final Member member;
  final int rank; // 1-based
  final String tier;
  final ModeStat stat;
  const RankedMember({
    required this.member,
    required this.rank,
    required this.tier,
    required this.stat,
  });
}

class Leaderboard {
  final DateTime updatedAt;
  final int startEpoch;
  final int totalMatches;
  final int internalMatches;
  final List<Member> members;
  final List<TierDef> tiers;

  const Leaderboard({
    required this.updatedAt,
    required this.startEpoch,
    required this.totalMatches,
    required this.internalMatches,
    required this.members,
    required this.tiers,
  });

  // Ngày bắt đầu tính ELO, hiển thị theo giờ VN (UTC+7).
  DateTime get startDateVN =>
      DateTime.fromMillisecondsSinceEpoch(startEpoch * 1000, isUtc: true)
          .add(const Duration(hours: 7));

  factory Leaderboard.fromMap(Map<String, dynamic> m) {
    int asInt(dynamic v) => (v is num) ? v.toInt() : 0;
    final members = (m['members'] as List<dynamic>? ?? [])
        .map((e) => Member.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final tiers = (m['tiers'] as List<dynamic>? ?? [])
        .map((e) {
          final t = Map<String, dynamic>.from(e as Map);
          return TierDef((t['label'] ?? '') as String, asInt(t['size']));
        })
        .toList();
    return Leaderboard(
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(asInt(m['updated_at']) * 1000),
      startEpoch: asInt(m['start_epoch']),
      totalMatches: asInt(m['total_matches']),
      internalMatches: asInt(m['internal_matches']),
      members: members,
      tiers: tiers.isNotEmpty
          ? tiers
          : const [
              TierDef('Top 1', 3),
              TierDef('Top 2', 2),
              TierDef('Top 3', 2),
              TierDef('Top 4', 3),
            ],
    );
  }
}
