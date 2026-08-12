/// Chia đội vào bảng khi tạo giải nhiều bảng.
///
/// [choices]: lựa chọn bảng của từng đội (theo index đội) — số bảng (0-based)
/// hoặc null = "tự chia". Đội đã chọn bảng giữ nguyên bảng đó; đội tự chia
/// lần lượt vào bảng đang ít đội nhất (cân bằng số đội).
/// Trả về danh sách index đội của từng bảng.
List<List<int>> distributeTeams(List<int?> choices, int numGroups) {
  final buckets = List.generate(numGroups, (_) => <int>[]);
  bool valid(int? c) => c != null && c >= 0 && c < numGroups;

  for (var i = 0; i < choices.length; i++) {
    if (valid(choices[i])) buckets[choices[i]!].add(i);
  }
  for (var i = 0; i < choices.length; i++) {
    if (!valid(choices[i])) {
      var minIdx = 0;
      for (var g = 1; g < numGroups; g++) {
        if (buckets[g].length < buckets[minIdx].length) minIdx = g;
      }
      buckets[minIdx].add(i);
    }
  }
  return buckets;
}
