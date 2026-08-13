/// Format số tiền kiểu VN: 500000 -> "500.000đ" (số âm -> "-500.000đ").
String formatMoney(int v) {
  final neg = v < 0;
  final s = v.abs().toString();
  final b = StringBuffer(neg ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '$bđ';
}

/// Đọc số tiền từ chuỗi nhập tay (bỏ mọi ký tự không phải số): "500.000" -> 500000.
/// Chặn trên 1 tỉ để tránh số vô lý và lỗi hiển thị với số cực lớn.
int parseMoney(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  final v = int.tryParse(digits) ?? 0;
  return v.clamp(0, 1000000000);
}
