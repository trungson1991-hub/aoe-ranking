import '../models/tournament.dart';

/// Áp tỉ số mới cho 1 trận vòng bảng, khớp theo cặp (id, stage).
///
/// KHÔNG được khớp theo id đơn thuần: các giải tạo trước đây có thể chứa
/// id trùng nhau giữa 2 bảng (lỗi sinh id cũ) — khớp id đơn thuần sẽ ghi đè
/// nhầm trận của bảng khác. Trong cùng 1 bảng (stage) id luôn duy nhất.
List<Fixture> groupFixturesAfterEdit(
  Tournament t,
  Fixture f,
  int scoreA,
  int scoreB,
) {
  final list = [...t.groupFixtures];
  final idx = list.indexWhere((x) => x.id == f.id && x.stage == f.stage);
  if (idx < 0) return list;
  list[idx] = list[idx].copyWith(scoreA: scoreA, scoreB: scoreB);
  return list;
}
