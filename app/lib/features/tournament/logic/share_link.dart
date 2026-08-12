/// Link chia sẻ 1 giải đấu: URL gốc của app + `?t=<id giải>`.
/// Bỏ fragment và các query khác (VD tham số chống cache) cho link sạch.
/// Khi mở link, app đọc tham số `t` và tự mở trang chi tiết giải.
String tournamentShareLink(Uri base, String tournamentId) => base
    .removeFragment()
    .replace(queryParameters: {'t': tournamentId}).toString();
