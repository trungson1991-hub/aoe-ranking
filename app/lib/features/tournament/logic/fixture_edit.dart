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

/// Đổi thứ tự trận TRONG 1 bảng ([stage]): chuyển trận ở vị trí [oldIndex]
/// sang [newIndex] (index tính trong danh sách trận của bảng đó).
/// Trận của các bảng khác giữ nguyên vị trí trong danh sách tổng.
List<Fixture> reorderStageFixtures(
  List<Fixture> all,
  String stage,
  int oldIndex,
  int newIndex,
) {
  final stageFx = all.where((f) => f.stage == stage).toList();
  if (oldIndex < 0 || oldIndex >= stageFx.length) return all;
  final item = stageFx.removeAt(oldIndex);
  stageFx.insert(newIndex.clamp(0, stageFx.length), item);
  var i = 0;
  return [for (final f in all) f.stage == stage ? stageFx[i++] : f];
}
