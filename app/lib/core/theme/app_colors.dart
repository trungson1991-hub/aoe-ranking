import 'package:flutter/material.dart';

/// Bảng màu chung toàn app (dark theme, tông slate + vàng hổ phách).
abstract final class AppColors {
  static const background = Color(0xFF0F172A); // slate-900
  static const surface = Color(0xFF1E293B); // slate-800
  static const surfaceLight = Color(0xFF334155); // slate-700
  static const gold = Color(0xFFFBBF24); // amber-400 — màu nhấn chính
  static const goldDark = Color(0xFFB45309); // amber-700
  static const silver = Color(0xFFC7D0DD);
  static const bronze = Color(0xFFCD7F32);
  static const win = Color(0xFF86EFAC); // green-300 — chữ "thắng"/ELO dương
  static const loss = Color(0xFFFCA5A5); // red-300 — chữ "thua"/ELO âm
  static const winStrong = Color(0xFF16A34A); // green-600 — banner thắng
  static const lossStrong = Color(0xFFDC2626); // red-600 — banner thua
  static const done = Color(0xFF34D399); // emerald-400 — viền trận đã xong
  static const muted = Color(0xFF64748B); // slate-500 — hạng ngoài top 3
  static const inactive = Color(0xFF475569); // slate-600 — thành viên ngưng chơi
}
