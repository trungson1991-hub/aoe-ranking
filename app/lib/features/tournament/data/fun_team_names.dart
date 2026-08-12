import 'dart:math';

/// Kho tên đội tiếng Việt vui vẻ — dùng làm tên mặc định khi thêm đội mới
/// trong màn tạo giải (người tạo vẫn sửa được thoải mái).
const List<String> kFunTeamNames = [
  'Gà Rán Thần Tốc',
  'Bò Húc Bất Bại',
  'Voi Điên Phá Nhà',
  'Dân Cày Mất Ngủ',
  'Ngựa Sắt Chém Gió',
  'Cung Thủ Mắt Lác',
  'Đế Chế Ngủ Gật',
  'Sói Đêm Hú Gió',
  'Thợ Săn Vàng Ròng',
  'Búa Gỗ Vô Đối',
  'Khiên Thủng Tự Tin',
  'Bô Lão Chống Lầy',
  'Rồng Lửa Hắt Xì',
  'Cua Càng Kẹp Đau',
  'Mãnh Hổ Sợ Mèo',
  'Chuột Túi Tăng Tốc',
  'Lạc Đà Khát Nước',
  'Đại Bàng Cận Thị',
  'Cá Mập Bơi Ngửa',
  'Khỉ Đột Ăn Chuối',
  'Tê Giác Lùi Xe',
  'Sư Tử Ăn Chay',
  'Bọ Cạp Nhảy Dây',
  'Gấu Trúc Thức Đêm',
];

final _rng = Random();

/// Lấy 1 tên ngẫu nhiên, tránh trùng các tên trong [exclude];
/// nếu đã dùng hết kho thì cho phép trùng.
String randomFunTeamName({Set<String> exclude = const {}}) {
  final pool = kFunTeamNames.where((n) => !exclude.contains(n)).toList();
  final list = pool.isEmpty ? kFunTeamNames : pool;
  return list[_rng.nextInt(list.length)];
}
