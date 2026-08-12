import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Màu quân theo empires_color (AoE, slot 1-8).
const Map<int, Color> kSlotColors = {
  1: Color(0xFF3B82F6), // xanh dương
  2: Color(0xFFEF4444), // đỏ
  3: Color(0xFF22C55E), // xanh lá
  4: Color(0xFFEAB308), // vàng
  5: Color(0xFF06B6D4), // xanh ngọc
  6: Color(0xFFEC4899), // hồng
  7: Color(0xFF9CA3AF), // xám
  8: Color(0xFFF97316), // cam
};

Color slotColor(int empiresColor) => kSlotColors[empiresColor] ?? AppColors.muted;

/// Tên quân (AoE / Rise of Rome) theo empires_type — game đánh số TỪ 0
/// theo thứ tự ABC (bản gốc trước, 4 quân Rise of Rome nối sau).
/// Đối chiếu dữ liệu thật: 9 = Roman, 10 = Shang (map cũ đánh số từ 1
/// nên Shang bị hiện nhầm thành Roman).
const Map<int, String> kCivNames = {
  0: 'Assyrian', 1: 'Babylonian', 2: 'Choson', 3: 'Egyptian',
  4: 'Greek', 5: 'Hittite', 6: 'Minoan', 7: 'Persian',
  8: 'Phoenician', 9: 'Roman', 10: 'Shang', 11: 'Sumerian',
  12: 'Yamato', 13: 'Carthaginian', 14: 'Macedonian', 15: 'Palmyran',
};

String civName(int empiresType) =>
    kCivNames[empiresType] ?? 'Quân #$empiresType';
