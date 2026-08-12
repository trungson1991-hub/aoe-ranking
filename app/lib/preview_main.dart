// ENTRYPOINT TẠM để xem giao diện — không dùng trong bản build thật.
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/tournament/widgets/fixture_card.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: Scaffold(
      appBar: AppBar(title: const Text('Chi tiết giải')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Các trận',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              FixtureCard(
                aName: 'Gà Rán Thần Tốc',
                bName: 'Bò Húc Bất Bại',
                aMembers: const ['Tnos', 'DarkTitan'],
                bMembers: const ['titi_cuti', 'TrumNho'],
                scoreA: 3,
                scoreB: 1,
                aWon: true,
                bWon: false,
                decided: true,
                onTap: () {},
              ),
              FixtureCard(
                aName: 'Đại Bàng Cận Thị',
                bName: 'Tê Giác Lùi Xe',
                aMembers: const ['minh_0909', 'Spainno3'],
                bMembers: const ['EmBe.HY', 'phucyknb'],
                scoreA: 0,
                scoreB: 0,
                aWon: false,
                bWon: false,
                decided: false,
                onTap: () {},
              ),
              FixtureCard(
                aName: 'Gà Rán Thần Tốc',
                bName: '—',
                aMembers: const ['Tnos', 'DarkTitan'],
                scoreA: 0,
                scoreB: 0,
                aWon: true,
                bWon: false,
                decided: true,
              ),
            ],
          ),
        ),
      ),
    ),
  ));
}
