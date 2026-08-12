// Model giải đấu (lưu trên Firestore, mỗi giải = 1 document trong collection `tournaments`).

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
  final String stage; // '' = vòng tròn 1 bảng; hoặc tên bảng / tên vòng KO
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

class Tournament {
  final String id;
  final String name;
  final String pin; // PIN quản trị riêng của giải (người tạo đặt)
  final String format; // '1v1' | '2v2' | '3v3' | '4v4'
  final int firstTo; // chạm N
  final String structure;
  final int advancePerGroup; // số đội đi tiếp mỗi bảng (groups_knockout)
  final int createdAt; // epoch giây
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
    required this.teams,
    required this.groups,
    required this.groupFixtures,
    required this.koFixtures,
  });

  TournTeam? teamById(String? id) {
    if (id == null) return null;
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  Tournament copyWith({
    String? name,
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
        teams: teams,
        groups: groups,
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
      advancePerGroup:
          (m['advance_per_group'] is num) ? (m['advance_per_group'] as num).toInt() : 1,
      createdAt: (m['created_at'] is num) ? (m['created_at'] as num).toInt() : 0,
      teams: list('teams', TournTeam.fromMap),
      groups: list('groups', GroupDef.fromMap),
      groupFixtures: list('group_fixtures', Fixture.fromMap),
      koFixtures: list('ko_fixtures', Fixture.fromMap),
    );
  }
}

// Sinh lịch vòng tròn (mọi cặp gặp nhau 1 lần) cho 1 nhóm đội.
List<Fixture> generateRoundRobin(List<String> teamIds, {String stage = ''}) {
  final out = <Fixture>[];
  var n = 0;
  for (var i = 0; i < teamIds.length; i++) {
    for (var j = i + 1; j < teamIds.length; j++) {
      out.add(Fixture(
        id: 'f${DateTime.now().microsecondsSinceEpoch}_${n++}',
        stage: stage,
        aId: teamIds[i],
        bId: teamIds[j],
      ));
    }
  }
  return out;
}

// ---- Bảng xếp hạng vòng tròn ----

class StandingRow {
  final TournTeam team;
  int played = 0;
  int wins = 0;
  int losses = 0;
  int gameWon = 0; // tổng ván thắng
  int gameLost = 0;
  StandingRow(this.team);

  int get points => wins * 3; // thắng 3đ, thua 0 (AoE không hòa)
  int get gameDiff => gameWon - gameLost;
}

// Tính bảng xếp hạng cho 1 nhóm đội theo các cặp đã đấu xong.
List<StandingRow> standingsFor(
  Tournament t,
  List<String> teamIds,
  List<Fixture> fixtures,
) {
  final rows = <String, StandingRow>{};
  for (final id in teamIds) {
    final team = t.teamById(id);
    if (team != null) rows[id] = StandingRow(team);
  }
  for (final f in fixtures) {
    if (f.aId == null || f.bId == null) continue;
    if (!rows.containsKey(f.aId) || !rows.containsKey(f.bId)) continue;
    if (!f.decided(t.firstTo)) continue;
    final a = rows[f.aId]!;
    final b = rows[f.bId]!;
    a.played++;
    b.played++;
    a.gameWon += f.scoreA;
    a.gameLost += f.scoreB;
    b.gameWon += f.scoreB;
    b.gameLost += f.scoreA;
    if (f.winnerId(t.firstTo) == f.aId) {
      a.wins++;
      b.losses++;
    } else {
      b.wins++;
      a.losses++;
    }
  }
  final list = rows.values.toList();
  list.sort((x, y) {
    if (y.points != x.points) return y.points - x.points;
    if (y.wins != x.wins) return y.wins - x.wins;
    return y.gameDiff - x.gameDiff;
  });
  return list;
}
