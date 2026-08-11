// Model khớp với document Firestore `leaderboard/current` do Cloud Function ghi.

class MemberResult {
  final String userUuid;
  final String name;
  final String avatarUrl;
  final int elo;
  final int games;
  final int wins;
  final int losses;
  final int rank; // 1-based
  final String tier;

  const MemberResult({
    required this.userUuid,
    required this.name,
    required this.avatarUrl,
    required this.elo,
    required this.games,
    required this.wins,
    required this.losses,
    required this.rank,
    required this.tier,
  });

  double get winRate => games == 0 ? 0 : wins / games;

  factory MemberResult.fromMap(Map<String, dynamic> m) {
    int asInt(dynamic v) => (v is num) ? v.toInt() : 0;
    return MemberResult(
      userUuid: (m['user_uuid'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      avatarUrl: (m['avatar_url'] ?? '') as String,
      elo: asInt(m['elo']),
      games: asInt(m['games']),
      wins: asInt(m['wins']),
      losses: asInt(m['losses']),
      rank: asInt(m['rank']),
      tier: (m['tier'] ?? '') as String,
    );
  }
}

class Leaderboard {
  final DateTime updatedAt;
  final int startEpoch;
  final int totalMatches;
  final int internalMatches;
  final List<MemberResult> members;

  const Leaderboard({
    required this.updatedAt,
    required this.startEpoch,
    required this.totalMatches,
    required this.internalMatches,
    required this.members,
  });

  // Ngày bắt đầu tính ELO, hiển thị theo giờ VN (UTC+7) để không lệch theo máy người xem.
  DateTime get startDateVN =>
      DateTime.fromMillisecondsSinceEpoch(startEpoch * 1000, isUtc: true)
          .add(const Duration(hours: 7));

  factory Leaderboard.fromMap(Map<String, dynamic> m) {
    int asInt(dynamic v) => (v is num) ? v.toInt() : 0;
    final list = (m['members'] as List<dynamic>? ?? [])
        .map((e) => MemberResult.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Leaderboard(
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(asInt(m['updated_at']) * 1000),
      startEpoch: asInt(m['start_epoch']),
      totalMatches: asInt(m['total_matches']),
      internalMatches: asInt(m['internal_matches']),
      members: list,
    );
  }

  // Gom thành viên theo tier, giữ nguyên thứ tự hạng.
  Map<String, List<MemberResult>> get byTier {
    final map = <String, List<MemberResult>>{};
    for (final mem in members) {
      final key = mem.tier.isEmpty ? 'Khác' : mem.tier;
      map.putIfAbsent(key, () => []).add(mem);
    }
    return map;
  }
}
