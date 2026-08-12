import '../models/tournament.dart';

/// Một dòng trong bảng điểm vòng tròn.
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

/// Tính bảng xếp hạng cho 1 nhóm đội theo các cặp đã đấu xong.
/// Thứ tự: điểm > hiệu số ván > tổng ván thắng > tên (để ổn định).
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
    final a = rows[f.aId];
    final b = rows[f.bId];
    if (a == null || b == null) continue;
    if (!f.decided(t.firstTo)) continue;
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
    if (y.gameDiff != x.gameDiff) return y.gameDiff - x.gameDiff;
    if (y.gameWon != x.gameWon) return y.gameWon - x.gameWon;
    return x.team.name.compareTo(y.team.name);
  });
  return list;
}
