// Model giải đấu (lưu trên Firebase RTDB, mỗi giải = 1 node trong `tournaments`).
import 'dart:math';

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

// ---- Loại trực tiếp (knockout) ----

bool groupStageDone(Tournament t) =>
    t.groupFixtures.isNotEmpty &&
    t.groupFixtures.every((f) => f.decided(t.firstTo));

// Thứ tự seed các đội đi tiếp: tất cả hạng 1 (theo thứ tự bảng), rồi hạng 2...
List<String> koSeeds(Tournament t) {
  final seeds = <String>[];
  for (var rank = 0; rank < t.advancePerGroup; rank++) {
    for (final g in t.groups) {
      final st = standingsFor(t, g.teamIds, t.groupFixtures);
      if (rank < st.length) seeds.add(st[rank].team.id);
    }
  }
  return seeds;
}

int _nextPow2(int n) {
  var p = 1;
  while (p < n) {
    p *= 2;
  }
  return p < 2 ? 2 : p;
}

// Sinh toàn bộ nhánh KO: vòng 0 seed theo cặp (i vs n-1-i, bye ở cuối);
// các vòng sau để trống (đội suy ra từ đội thắng vòng trước khi hiển thị).
List<Fixture> buildKnockout(Tournament t) {
  final seeds = koSeeds(t);
  if (seeds.length < 2) return const [];
  final n = _nextPow2(seeds.length);
  final padded = <String?>[...seeds, ...List<String?>.filled(n - seeds.length, null)];
  final out = <Fixture>[];
  final r0 = n ~/ 2;
  for (var i = 0; i < r0; i++) {
    out.add(Fixture(
      id: 'ko_r0_m$i',
      stage: 'KO',
      aId: padded[i],
      bId: padded[n - 1 - i],
    ));
  }
  var prev = r0;
  var r = 1;
  while (prev > 1) {
    final cnt = prev ~/ 2;
    for (var j = 0; j < cnt; j++) {
      out.add(Fixture(id: 'ko_r${r}_m$j', stage: 'KO', aId: null, bId: null));
    }
    prev = cnt;
    r++;
  }
  return out;
}

// Đội thắng 1 cặp KO (có xét bye: 1 bên trống -> bên kia thắng).
String? koWinner(Fixture f, int firstTo, String? aId, String? bId) {
  if (aId != null && bId == null) return aId;
  if (bId != null && aId == null) return bId;
  if (aId == null || bId == null) return null;
  if (f.scoreA >= firstTo) return aId;
  if (f.scoreB >= firstTo) return bId;
  return null;
}

class KoSlot {
  final int round;
  final int match;
  final String? aId;
  final String? bId;
  final Fixture fixture;
  final String? winnerId;
  KoSlot(
      {required this.round,
      required this.match,
      required this.aId,
      required this.bId,
      required this.fixture,
      required this.winnerId});
}

(int, int)? _parseKoId(String id) {
  final m = RegExp(r'^ko_r(\d+)_m(\d+)$').firstMatch(id);
  if (m == null) return null;
  return (int.parse(m.group(1)!), int.parse(m.group(2)!));
}

// Giải nhánh KO thành danh sách vòng, mỗi vòng là danh sách KoSlot (đã suy ra đội).
List<List<KoSlot>> resolveKo(Tournament t) {
  if (t.koFixtures.isEmpty) return const [];
  final byId = {for (final f in t.koFixtures) f.id: f};
  final roundSize = <int, int>{};
  for (final f in t.koFixtures) {
    final p = _parseKoId(f.id);
    if (p != null) {
      roundSize[p.$1] = max(roundSize[p.$1] ?? 0, p.$2 + 1);
    }
  }
  if (roundSize.isEmpty) return const [];
  final maxRound = roundSize.keys.reduce(max);
  final winners = <int, Map<int, String?>>{};
  final out = <List<KoSlot>>[];
  for (var r = 0; r <= maxRound; r++) {
    final cnt = roundSize[r] ?? 0;
    final slots = <KoSlot>[];
    for (var m = 0; m < cnt; m++) {
      final f = byId['ko_r${r}_m$m'];
      if (f == null) continue;
      String? aId;
      String? bId;
      if (r == 0) {
        aId = f.aId;
        bId = f.bId;
      } else {
        aId = winners[r - 1]?[2 * m];
        bId = winners[r - 1]?[2 * m + 1];
      }
      final w = koWinner(f, t.firstTo, aId, bId);
      winners.putIfAbsent(r, () => {})[m] = w;
      slots.add(KoSlot(
          round: r, match: m, aId: aId, bId: bId, fixture: f, winnerId: w));
    }
    out.add(slots);
  }
  return out;
}

// Tên vòng theo số cặp đấu trong vòng.
String koRoundName(int matchesInRound) {
  switch (matchesInRound) {
    case 1:
      return 'Chung kết';
    case 2:
      return 'Bán kết';
    case 4:
      return 'Tứ kết';
    case 8:
      return 'Vòng 1/8';
    default:
      return 'Vòng ${matchesInRound * 2} đội';
  }
}

// Nhà vô địch (đội thắng trận chung kết), null nếu chưa xong.
String? koChampionId(Tournament t) {
  final rounds = resolveKo(t);
  if (rounds.isEmpty) return null;
  final finalRound = rounds.last;
  if (finalRound.length != 1) return null;
  return finalRound.first.winnerId;
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
