// Thành phần dùng chung cho trang TẠO giải và trang SỬA giải.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Kiểu ô nhập thống nhất của khu vực giải đấu.
InputDecoration tournamentFieldDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.gold)),
    );

const kPrizeLabels = ['🥇 Nhất', '🥈 Nhì', '🥉 Ba'];

/// Ba ô nhập tiền thưởng (nhất / nhì / ba) kèm tiêu đề.
class PrizeFields extends StatelessWidget {
  const PrizeFields({super.key, required this.controllers});

  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tiền thưởng (đ) — để trống nếu không có',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < kPrizeLabels.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controllers[i],
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: tournamentFieldDecoration(kPrizeLabels[i]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
