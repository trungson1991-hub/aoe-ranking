// Logic nhánh loại trực tiếp (knockout): seed, bye, suy đội từ vòng trước.
//
// Quy ước id trận KO: 'ko_r{round}_m{match}' — round 0 là vòng đầu.
// Trận match m của round r nhận đội thắng của 2 trận (2m) và (2m+1) round r-1.
import 'dart:math';

import '../models/tournament.dart';
import 'standings.dart';

bool groupStageDone(Tournament t) =>
    t.groupFixtures.isNotEmpty &&
    t.groupFixtures.every((f) => f.decided(t.firstTo));

/// Thứ tự seed các đội đi tiếp: tất cả hạng 1 (theo thứ tự bảng), rồi hạng 2...
List<String> koSeeds(Tournament t) {
  // Tính bảng điểm 1 lần cho mỗi bảng (không tính lại theo từng hạng).
  final tables = [
    for (final g in t.groups) standingsFor(t, g.teamIds, t.groupFixtures),
  ];
  final seeds = <String>[];
  for (var rank = 0; rank < t.advancePerGroup; rank++) {
    for (final st in tables) {
      if (rank < st.length) seeds.add(st[rank].team.id);
    }
  }
  return seeds;
}

int _nextPow2(int n) {
  var p = 2;
  while (p < n) {
    p *= 2;
  }
  return p;
}

/// Thứ tự slot chuẩn của nhánh đấu [n] đội (n = luỹ thừa 2), trả về chỉ số seed
/// (0-based) theo từng cặp: [0, n-1, ...]. Đảm bảo seed 1 và 2 nằm 2 nửa nhánh
/// khác nhau (chỉ có thể gặp nhau ở chung kết) và bye (slot trống) rơi vào
/// các seed cao nhất.
List<int> bracketOrder(int n) {
  var order = [0];
  while (order.length < n) {
    final size = order.length * 2;
    order = [
      for (final s in order) ...[s, size - 1 - s],
    ];
  }
  return order;
}

/// Sinh toàn bộ nhánh KO: vòng 0 ghép cặp theo thứ tự nhánh chuẩn
/// (seed 1 vs seed cuối, các seed đầu nhận bye nếu lẻ đội);
/// các vòng sau để trống (đội suy ra từ đội thắng vòng trước khi hiển thị).
List<Fixture> buildKnockout(Tournament t) {
  final seeds = koSeeds(t);
  if (seeds.length < 2) return const [];
  final n = _nextPow2(seeds.length);
  final padded = <String?>[
    ...seeds,
    ...List<String?>.filled(n - seeds.length, null),
  ];
  final order = bracketOrder(n);
  final out = <Fixture>[];
  for (var i = 0; i < n ~/ 2; i++) {
    out.add(Fixture(
      id: 'ko_r0_m$i',
      stage: 'KO',
      aId: padded[order[2 * i]],
      bId: padded[order[2 * i + 1]],
    ));
  }
  var prev = n ~/ 2;
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

/// Đội thắng 1 cặp KO (có xét bye: 1 bên trống -> bên kia thắng).
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
  const KoSlot({
    required this.round,
    required this.match,
    required this.aId,
    required this.bId,
    required this.fixture,
    required this.winnerId,
  });

  /// Bye: đã có 1 đội nhưng vĩnh viễn không có đối thủ (chỉ xảy ra ở round 0).
  bool get isBye => round == 0 && (aId == null) != (bId == null);
}

(int, int)? _parseKoId(String id) {
  final m = RegExp(r'^ko_r(\d+)_m(\d+)$').firstMatch(id);
  if (m == null) return null;
  return (int.parse(m.group(1)!), int.parse(m.group(2)!));
}

/// Giải nhánh KO thành danh sách vòng, mỗi vòng là danh sách KoSlot
/// (đội mỗi trận đã được suy ra từ đội thắng vòng trước).
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
      final String? aId;
      final String? bId;
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

/// Áp kết quả sửa 1 trận KO vào danh sách koFixtures.
/// Nếu đội thắng của trận đó THAY ĐỔI thì reset tỉ số các trận phía sau
/// trong cùng nhánh (kết quả cũ thuộc về cặp đấu khác, giữ lại sẽ sai).
List<Fixture> koFixturesAfterEdit(Tournament t, Fixture edited) {
  final list =
      t.koFixtures.map((f) => f.id == edited.id ? edited : f).toList();
  final p = _parseKoId(edited.id);
  if (p == null) return list;

  // Tìm slot cũ để biết cặp đấu (aId/bId suy từ nhánh — sửa tỉ số không đổi cặp).
  KoSlot? slot;
  for (final round in resolveKo(t)) {
    for (final s in round) {
      if (s.fixture.id == edited.id) slot = s;
    }
  }
  if (slot == null) return list;
  final oldWinner = koWinner(slot.fixture, t.firstTo, slot.aId, slot.bId);
  final newWinner = koWinner(edited, t.firstTo, slot.aId, slot.bId);
  if (oldWinner == newWinner) return list;

  var (r, m) = p;
  while (true) {
    r += 1;
    m ~/= 2;
    final idx = list.indexWhere((f) => f.id == 'ko_r${r}_m$m');
    if (idx < 0) break;
    list[idx] = list[idx].copyWith(scoreA: 0, scoreB: 0);
  }
  return list;
}

/// Tên vòng theo số cặp đấu trong vòng.
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

/// Nhà vô địch (đội thắng trận chung kết), null nếu chưa xong.
String? koChampionId(Tournament t) {
  final rounds = resolveKo(t);
  if (rounds.isEmpty) return null;
  final finalRound = rounds.last;
  if (finalRound.length != 1) return null;
  return finalRound.first.winnerId;
}
