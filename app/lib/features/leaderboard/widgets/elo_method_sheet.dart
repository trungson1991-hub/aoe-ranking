import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Mở bottom sheet giải thích cách tính ELO.
void showEloMethodSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _MethodSheet(),
  );
}

class _MethodSheet extends StatelessWidget {
  const _MethodSheet();

  @override
  Widget build(BuildContext context) {
    const h = TextStyle(
        color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w800);
    const b = TextStyle(color: Colors.white70, fontSize: 14, height: 1.4);
    Widget bullet(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('•  $s', style: b),
        );

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('CÁCH TÍNH ELO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            const Text('1. Trận được tính', style: h),
            const SizedBox(height: 8),
            bullet('Chỉ lấy trận trong 6 tháng gần nhất.'),
            bullet('Chỉ trận nội bộ: tất cả người chơi của cả 2 đội đều thuộc team.'),
            bullet('Loại "trận ma": ≤1 người, một đội rỗng, hoặc tổng (giết + mất quân) < 5.'),
            bullet('Nhiều người trùng màu (chung 1 slot) là cùng một người chơi: chỉ người có bộ số liệu riêng được tính ELO, người còn lại là viewer (không ảnh hưởng).'),
            const SizedBox(height: 16),
            const Text('2. Điểm phong độ mỗi trận (0–1)', style: h),
            const SizedBox(height: 8),
            const Text(
              'Mỗi chỉ số được so tương đối giữa những người trong cùng trận '
              '(giỏi nhất = 1, kém nhất = 0), rồi nhân trọng số:',
              style: b,
            ),
            const SizedBox(height: 8),
            bullet('Combat 30%: giết quân 15 · ít mất quân 10 · phá công trình 5'),
            bullet('Kinh tế 25%: đào vàng 10 · nông dân đỉnh 10 · tổng dân 5'),
            bullet('Công nghệ & lên đời 25%: công nghệ 10 · lên đời nhanh 10 · đạt đời 4 (5)'),
            bullet('Bản đồ & hỗ trợ 20%: mở bản đồ 12 · bơm đồ 5 · bảo toàn quân 3'),
            const SizedBox(height: 16),
            const Text('3. Cập nhật ELO', style: h),
            const SizedBox(height: 8),
            bullet('Mọi người xuất phát từ 1000 ELO (mốc trung bình), không bao giờ âm.'),
            bullet('Điểm mỗi trận: S = 0.5 × (thắng?1:0) + 0.5 × phong độ.'),
            bullet('Kỳ vọng E tính theo chênh lệch ELO trung bình 2 đội.'),
            bullet('ELO thay đổi: Δ = K × (S − E). 10 trận đầu K = 40 (định hạng nhanh về đúng trình độ), từ trận 11 K = 24 (ổn định).'),
            bullet('Thắng vẫn quan trọng nhất, nhưng chơi hay/tệ ảnh hưởng điểm nhận.'),
            bullet('Trên 1000 = trên trung bình team, dưới 1000 = dưới trung bình.'),
            bullet('Dưới 10 trận: nhãn "ELO tạm" — chưa đủ trận để tin cậy.'),
            bullet('Độ quen tay: cộng nhẹ +√(số trận) điểm (100 trận ≈ +10, 200 trận ≈ +14).'),
            bullet('Giải đấu trên web khi bấm "Kết thúc giải": mỗi thành viên đội vô địch +15, á quân +7 điểm — tính vào bảng Tổng và bảng thể loại của giải. Chỉ tính giải kết thúc trong 1 năm gần nhất.'),
            const SizedBox(height: 16),
            const Text('4. Các bảng', style: h),
            const SizedBox(height: 8),
            bullet('Tính riêng: Tổng và 1v1 / 2v2 / 3v3 / 4v4 (chỉ trận cân người).'),
            bullet('Xếp hạng theo ELO từ cao đến thấp (hạng 1, 2, 3...).'),
            const SizedBox(height: 16),
            const Text(
              'Cập nhật tự động 7:00 / 14:00 / 21:00 hàng ngày (giờ VN).',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
