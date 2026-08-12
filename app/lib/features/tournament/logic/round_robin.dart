import '../models/tournament.dart';

/// Sinh lịch vòng tròn (mọi cặp gặp nhau đúng 1 lần) theo "circle method":
/// lịch chia thành từng lượt, mỗi lượt mọi đội đá tối đa 1 trận (đội lẻ thì
/// 1 đội nghỉ) — tránh việc 1 đội phải đá dồn nhiều trận liên tiếp.
List<Fixture> generateRoundRobin(List<String> teamIds, {String stage = ''}) {
  if (teamIds.length < 2) return const [];
  final ids = List<String?>.of(teamIds);
  if (ids.length.isOdd) ids.add(null); // slot "nghỉ" cho số đội lẻ
  final n = ids.length;
  final seed = DateTime.now().microsecondsSinceEpoch;
  var counter = 0;
  final out = <Fixture>[];
  for (var round = 0; round < n - 1; round++) {
    for (var i = 0; i < n ~/ 2; i++) {
      final a = ids[i];
      final b = ids[n - 1 - i];
      if (a != null && b != null) {
        out.add(Fixture(
          id: 'f${seed}_${counter++}',
          stage: stage,
          aId: a,
          bId: b,
        ));
      }
    }
    // Xoay vòng: giữ nguyên ids[0], phần tử cuối chèn vào vị trí 1.
    ids.insert(1, ids.removeLast());
  }
  return out;
}
