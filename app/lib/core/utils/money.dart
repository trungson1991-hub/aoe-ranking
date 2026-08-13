/// Format số tiền kiểu VN: 500000 -> "500.000đ".
String formatMoney(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '$bđ';
}

/// Đọc số tiền từ chuỗi nhập tay (bỏ mọi ký tự không phải số): "500.000" -> 500000.
int parseMoney(String input) =>
    int.tryParse(input.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
