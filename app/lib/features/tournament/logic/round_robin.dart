import '../models/tournament.dart';

// Bộ đếm KHÔNG reset giữa các lần gọi. Trước đây mỗi lời gọi reset đếm về 0
// và dựa vào timestamp để phân biệt — nhưng trên web đồng hồ chỉ có độ phân
// giải mili-giây, nên giải nhiều bảng (gọi liên tiếp cho từng bảng) sinh id
// trùng nhau giữa các bảng, khiến sửa kết quả 1 trận ghi đè nhầm trận bảng khác.
int _fixtureIdCounter = 0;

/// Sinh lịch vòng tròn (mọi cặp gặp nhau đúng 1 lần) theo "circle method":
/// lịch chia thành từng lượt, mỗi lượt mọi đội đá tối đa 1 trận (đội lẻ thì
/// 1 đội nghỉ) — tránh việc 1 đội phải đá dồn nhiều trận liên tiếp.
List<Fixture> generateRoundRobin(List<String> teamIds, {String stage = ''}) {
  if (teamIds.length < 2) return const [];
  final ids = List<String?>.of(teamIds);
  if (ids.length.isOdd) ids.add(null); // slot "nghỉ" cho số đội lẻ
  final n = ids.length;
  final seed = DateTime.now().millisecondsSinceEpoch;
  final out = <Fixture>[];
  for (var round = 0; round < n - 1; round++) {
    for (var i = 0; i < n ~/ 2; i++) {
      final a = ids[i];
      final b = ids[n - 1 - i];
      if (a != null && b != null) {
        out.add(Fixture(
          id: 'f${seed}_${_fixtureIdCounter++}',
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
