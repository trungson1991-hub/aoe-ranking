import 'package:flutter/foundation.dart' show kIsWeb;

import '../../leaderboard/services/leaderboard_service.dart'
    show kDeployedBaseUrl;

/// Link chia sẻ 1 giải đấu: URL gốc của app + `?t=<id giải>`.
/// Bỏ fragment và các query khác (VD tham số chống cache) cho link sạch.
/// Khi mở link, app đọc tham số `t` và tự mở trang chi tiết giải.
String tournamentShareLink(Uri base, String tournamentId) => base
    .removeFragment()
    .replace(queryParameters: {'t': tournamentId}).toString();

/// URL gốc để dựng link chia sẻ, tuỳ nền tảng:
///  - Web: `Uri.base` = origin đang mở (chạy đúng dù deploy ở đâu).
///  - Mobile (iOS/Android): KHÔNG có `Uri.base` kiểu web (thường là `file://`),
///    nên dùng URL site đã deploy — nếu không, link copy ra vô nghĩa, mở lên
///    không ra giải nào.
Uri shareBase() => kIsWeb ? Uri.base : Uri.parse(kDeployedBaseUrl);
