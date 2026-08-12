/// Toàn bộ mốc thời gian trong app hiển thị theo giờ VN (UTC+7),
/// vì API trả epoch UTC còn người dùng đều ở VN.
DateTime epochToVN(int epochSeconds) =>
    DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true)
        .add(const Duration(hours: 7));
