// Model giải đấu (lưu trên Firebase RTDB, mỗi giải = 1 node trong `tournaments`).
// File này CHỈ chứa dữ liệu; logic vòng tròn / bảng điểm / loại trực tiếp
// nằm trong ../logic/.

// Một đội trong giải (chia từ thành viên team).
class TournTeam {
  final String id;
  final String name;
  final List<String> memberUuids;
  final List<String> memberNames;

  const TournTeam({
    required this.id,
    required this.name,
    required this.memberUuids,
    required this.memberNames,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'member_uuids': memberUuids,
        'member_names': memberNames,
      };

  factory TournTeam.fromMap(Map<String, dynamic> m) => TournTeam(
        id: (m['id'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        memberUuids: List<String>.from(m['member_uuids'] ?? const []),
        memberNames: List<String>.from(m['member_names'] ?? const []),
      );
}

// Một cặp đấu (chạm N — first-to-N). scoreA/scoreB = số ván thắng của mỗi đội.
class Fixture {
  final String id;
  final String stage; // '' = vòng tròn 1 bảng; hoặc tên bảng / 'KO'
  final String? aId; // null = chưa xác định (nhánh KO chờ đội)
  final String? bId;
  final int scoreA;
  final int scoreB;

  const Fixture({
    required this.id,
    required this.stage,
    required this.aId,
    required this.bId,
    this.scoreA = 0,
    this.scoreB = 0,
  });

  bool decided(int firstTo) => scoreA >= firstTo || scoreB >= firstTo;

  String? winnerId(int firstTo) {
    if (scoreA >= firstTo) return aId;
    if (scoreB >= firstTo) return bId;
    return null;
  }

  Fixture copyWith({String? aId, String? bId, int? scoreA, int? scoreB}) =>
      Fixture(
        id: id,
        stage: stage,
        aId: aId ?? this.aId,
        bId: bId ?? this.bId,
        scoreA: scoreA ?? this.scoreA,
        scoreB: scoreB ?? this.scoreB,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'stage': stage,
        'a_id': aId,
        'b_id': bId,
        'score_a': scoreA,
        'score_b': scoreB,
      };

  factory Fixture.fromMap(Map<String, dynamic> m) => Fixture(
        id: (m['id'] ?? '') as String,
        stage: (m['stage'] ?? '') as String,
        aId: m['a_id'] as String?,
        bId: m['b_id'] as String?,
        scoreA: (m['score_a'] is num) ? (m['score_a'] as num).toInt() : 0,
        scoreB: (m['score_b'] is num) ? (m['score_b'] as num).toInt() : 0,
      );
}

// Một bảng đấu (vòng tròn).
class GroupDef {
  final String name;
  final List<String> teamIds;
  const GroupDef({required this.name, required this.teamIds});

  Map<String, dynamic> toMap() => {'name': name, 'team_ids': teamIds};
  factory GroupDef.fromMap(Map<String, dynamic> m) => GroupDef(
        name: (m['name'] ?? '') as String,
        teamIds: List<String>.from(m['team_ids'] ?? const []),
      );
}

const kStructureRoundRobin = 'round_robin'; // 1 bảng vòng tròn
const kStructureGroupsKnockout = 'groups_knockout'; // nhiều bảng + loại trực tiếp

// Trạng thái giải. Giải cũ (chưa có field) mặc định là đang diễn ra.
const kStatusActive = 'active'; // đang diễn ra — được nhập/sửa kết quả
const kStatusFinished = 'finished'; // đã kết thúc — chốt kết quả, khoá sửa
const kStatusCancelled = 'cancelled'; // đã huỷ — không tính kết quả, khoá sửa

class Tournament {
  final String id;
  final String name;
  final String pin; // PIN quản trị riêng của giải (người tạo đặt)
  final String format; // '1v1' | '2v2' | '3v3' | '4v4'
  final int firstTo; // chạm N
  final String structure;
  final int advancePerGroup; // số đội đi tiếp mỗi bảng (groups_knockout)
  final int createdAt; // epoch giây
  final String status; // kStatusActive | kStatusFinished | kStatusCancelled
  final List<int> prizes; // tiền thưởng (đ) theo hạng: [nhất, nhì, ba]
  final List<TournTeam> teams;
  final List<GroupDef> groups;
  final List<Fixture> groupFixtures; // vòng bảng / vòng tròn
  final List<Fixture> koFixtures; // loại trực tiếp

  const Tournament({
    required this.id,
    required this.name,
    required this.pin,
    required this.format,
    required this.firstTo,
    required this.structure,
    required this.advancePerGroup,
    required this.createdAt,
    this.status = kStatusActive,
    this.prizes = const [],
    required this.teams,
    required this.groups,
    required this.groupFixtures,
    required this.koFixtures,
  });

  bool get isActive => status == kStatusActive;
  bool get isFinished => status == kStatusFinished;
  bool get isCancelled => status == kStatusCancelled;

  TournTeam? teamById(String? id) {
    if (id == null) return null;
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  Tournament copyWith({
    String? name,
    String? status,
    List<int>? prizes,
    List<TournTeam>? teams,
    List<GroupDef>? groups,
    List<Fixture>? groupFixtures,
    List<Fixture>? koFixtures,
  }) =>
      Tournament(
        id: id,
        name: name ?? this.name,
        pin: pin,
        format: format,
        firstTo: firstTo,
        structure: structure,
        advancePerGroup: advancePerGroup,
        createdAt: createdAt,
        status: status ?? this.status,
        prizes: prizes ?? this.prizes,
        teams: teams ?? this.teams,
        groups: groups ?? this.groups,
        groupFixtures: groupFixtures ?? this.groupFixtures,
        koFixtures: koFixtures ?? this.koFixtures,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'pin': pin,
        'format': format,
        'first_to': firstTo,
        'structure': structure,
        'advance_per_group': advancePerGroup,
        'created_at': createdAt,
        'status': status,
        'prizes': prizes,
        'teams': teams.map((e) => e.toMap()).toList(),
        'groups': groups.map((e) => e.toMap()).toList(),
        'group_fixtures': groupFixtures.map((e) => e.toMap()).toList(),
        'ko_fixtures': koFixtures.map((e) => e.toMap()).toList(),
      };

  factory Tournament.fromDoc(String id, Map<String, dynamic> m) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((m[k] as List?) ?? const [])
            .map((e) => f(Map<String, dynamic>.from(e as Map)))
            .toList();
    return Tournament(
      id: id,
      name: (m['name'] ?? '') as String,
      pin: (m['pin'] ?? '') as String,
      format: (m['format'] ?? '1v1') as String,
      firstTo: (m['first_to'] is num) ? (m['first_to'] as num).toInt() : 1,
      structure: (m['structure'] ?? kStructureRoundRobin) as String,
      advancePerGroup: (m['advance_per_group'] is num)
          ? (m['advance_per_group'] as num).toInt()
          : 1,
      createdAt:
          (m['created_at'] is num) ? (m['created_at'] as num).toInt() : 0,
      status: (m['status'] ?? kStatusActive) as String,
      prizes: ((m['prizes'] as List?) ?? const [])
          .map((e) => (e is num) ? e.toInt() : 0)
          .toList(),
      teams: list('teams', TournTeam.fromMap),
      groups: list('groups', GroupDef.fromMap),
      groupFixtures: list('group_fixtures', Fixture.fromMap),
      koFixtures: list('ko_fixtures', Fixture.fromMap),
    );
  }
}
