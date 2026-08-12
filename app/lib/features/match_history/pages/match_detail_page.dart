import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../models/match_record.dart';

// Màu 2 đội theo cách gọi của game: đội Đỏ (red_team) và đội Xanh (blue_team).
const _redTeam = Color(0xFFF87171);
const _blueTeam = Color(0xFF60A5FA);

// Màu quân theo empires_color (AoE).
const Map<int, Color> _slotColors = {
  1: Color(0xFF3B82F6), // xanh dương
  2: Color(0xFFEF4444), // đỏ
  3: Color(0xFF22C55E), // xanh lá
  4: Color(0xFFEAB308), // vàng
  5: Color(0xFF06B6D4), // xanh ngọc
  6: Color(0xFFEC4899), // hồng
  7: Color(0xFF9CA3AF), // xám
  8: Color(0xFFF97316), // cam
};

// Tên quân (Đế chế / AoE Rise of Rome) theo empires_type.
const Map<int, String> _civNames = {
  1: 'Assyrian', 2: 'Babylonian', 3: 'Choson', 4: 'Egyptian',
  5: 'Greek', 6: 'Hittite', 7: 'Minoan', 8: 'Persian',
  9: 'Phoenician', 10: 'Roman', 11: 'Shang', 12: 'Sumerian',
  13: 'Yamato', 14: 'Carthaginian', 15: 'Macedonian', 16: 'Palmyran',
};

// Một chỉ số so sánh: nhãn + cách lấy giá trị + chiều tốt (thấp hơn = tốt?).
class _Metric {
  const _Metric(this.icon, this.label, this.get,
      {this.lowerBetter = false, this.suffix = ''});
  final String icon;
  final String label;
  final int Function(PlayerStat) get;
  final bool lowerBetter;
  final String suffix;
}

const List<_Metric> _metrics = [
  _Metric('⚔️', 'Giết quân', _kills),
  _Metric('💀', 'Mất quân', _losses, lowerBetter: true),
  _Metric('🏰', 'Phá công trình', _razings),
  _Metric('🪙', 'Đào vàng', _gold),
  _Metric('👨‍🌾', 'Dân đỉnh', _villager),
  _Metric('👥', 'Dân số', _population),
  _Metric('🔬', 'Công nghệ', _tech),
  _Metric('🗺️', 'Mở bản đồ', _explore, suffix: '%'),
  _Metric('🤝', 'Bơm đồ', _tribute),
  _Metric('⏫', 'Đời đạt', _age),
];

int _kills(PlayerStat p) => p.kills;
int _losses(PlayerStat p) => p.losses;
int _razings(PlayerStat p) => p.razings;
int _gold(PlayerStat p) => p.gold;
int _villager(PlayerStat p) => p.villager;
int _population(PlayerStat p) => p.population;
int _tech(PlayerStat p) => p.technologies;
int _explore(PlayerStat p) => p.exploration;
int _tribute(PlayerStat p) => p.tribute;
int _age(PlayerStat p) => p.age;

class MatchDetailPage extends StatelessWidget {
  const MatchDetailPage({super.key, required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final win = r.win;
    final banner = win ? AppColors.winStrong : AppColors.lossStrong;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết trận',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          // Rộng hơn các trang khác để bảng so sánh có chỗ thở.
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Banner kết quả.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [banner, banner.withValues(alpha: 0.55)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(win ? 'CHIẾN THẮNG' : 'THẤT BẠI',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      '${r.modeLabel}  ·  ${DateFormat('dd/MM/yyyy HH:mm').format(r.dateVN)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    Text('Phòng ${r.roomId}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _TeamBars(record: r),
              const SizedBox(height: 14),
              _ComparisonTable(record: r),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tương quan sức mạnh 2 đội: bar đối đầu cho các chỉ số tổng.
class _TeamBars extends StatelessWidget {
  const _TeamBars({required this.record});

  final MatchRecord record;

  static const List<_Metric> _teamMetrics = [
    _Metric('⚔️', 'Giết quân', _kills),
    _Metric('🏰', 'Phá công trình', _razings),
    _Metric('🪙', 'Đào vàng', _gold),
    _Metric('🔬', 'Công nghệ', _tech),
    _Metric('👥', 'Dân số', _population),
  ];

  int _sum(List<PlayerStat> side, _Metric m) =>
      side.fold(0, (a, p) => a + m.get(p));

  @override
  Widget build(BuildContext context) {
    final redWon = record.red.isNotEmpty && record.red.first.win;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text('TƯƠNG QUAN 2 ĐỘI',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend('Đội Đỏ', _redTeam, redWon),
              const SizedBox(width: 18),
              _legend('Đội Xanh', _blueTeam, !redWon),
            ],
          ),
          const SizedBox(height: 12),
          for (final m in _teamMetrics) ...[
            _barRow(m),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _legend(String name, Color color, bool won) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(name,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        if (won)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('🏆', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _barRow(_Metric m) {
    final red = _sum(record.red, m);
    final blue = _sum(record.blue, m);
    final total = red + blue;
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 64,
              child: Text('$red',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      color: red >= blue ? _redTeam : Colors.white54,
                      fontSize: 13,
                      fontWeight:
                          red >= blue ? FontWeight.w800 : FontWeight.w500)),
            ),
            Expanded(
              child: Text('${m.icon} ${m.label}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            SizedBox(
              width: 64,
              child: Text('$blue',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: blue >= red ? _blueTeam : Colors.white54,
                      fontSize: 13,
                      fontWeight:
                          blue >= red ? FontWeight.w800 : FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 7,
            child: total == 0
                ? Container(color: Colors.white12)
                : Row(
                    children: [
                      Expanded(
                          flex: red, child: Container(color: _redTeam)),
                      if (red > 0 && blue > 0) const SizedBox(width: 2),
                      Expanded(
                          flex: blue, child: Container(color: _blueTeam)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Bảng so sánh mọi người chơi: cột = người, hàng = chỉ số.
/// Ô tốt nhất mỗi hàng được tô sáng; có thanh tỉ lệ để so bằng mắt.
class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.record});

  final MatchRecord record;

  static const double _labelW = 118;
  static const double _colW = 86;

  @override
  Widget build(BuildContext context) {
    final players = record.all;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('SO SÁNH TỪNG NGƯỜI',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              const Spacer(),
              if (players.length > 4)
                const Text('kéo ngang để xem thêm →',
                    style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerRow(players),
                const SizedBox(height: 6),
                for (var i = 0; i < _metrics.length; i++)
                  _metricRow(_metrics[i], players, striped: i.isEven),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isViewer(PlayerStat p) => p.uuid == record.viewerUuid;
  bool _inRed(PlayerStat p) => record.red.any((x) => x.uuid == p.uuid);

  Widget _headerRow(List<PlayerStat> players) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: _labelW),
        for (final p in players)
          Container(
            width: _colW,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: _isViewer(p)
                  ? AppColors.gold.withValues(alpha: 0.10)
                  : null,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _slotColors[p.color] ?? AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isViewer(p) ? AppColors.gold : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _civNames[p.empiresType] ?? 'Quân #${p.empiresType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 4),
                // Gạch màu đội (Đỏ/Xanh) dưới tên.
                Container(
                  height: 3,
                  width: 40,
                  decoration: BoxDecoration(
                    color: _inRed(p) ? _redTeam : _blueTeam,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _metricRow(_Metric m, List<PlayerStat> players,
      {required bool striped}) {
    final values = [for (final p in players) m.get(p)];
    final maxV = values.fold(0, (a, b) => a > b ? a : b);
    final minV = values.fold(values.first, (a, b) => a < b ? a : b);
    final best = m.lowerBetter ? minV : maxV;
    final allEqual = maxV == minV;

    return Container(
      decoration: BoxDecoration(
        color: striped ? Colors.white.withValues(alpha: 0.025) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: _labelW,
            child: Text('${m.icon} ${m.label}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          for (var i = 0; i < players.length; i++)
            Container(
              width: _colW,
              color: _isViewer(players[i])
                  ? AppColors.gold.withValues(alpha: 0.06)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  Text(
                    '${values[i]}${m.suffix}',
                    style: TextStyle(
                      color: !allEqual && values[i] == best
                          ? AppColors.win
                          : Colors.white70,
                      fontSize: 13,
                      fontWeight: !allEqual && values[i] == best
                          ? FontWeight.w900
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Thanh tỉ lệ so với giá trị lớn nhất trong hàng.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 3,
                      child: Row(
                        children: [
                          Expanded(
                            flex: maxV == 0 ? 0 : (values[i] * 100 ~/ maxV),
                            child: Container(
                              color: !allEqual && values[i] == best
                                  ? AppColors.win
                                  : Colors.white24,
                            ),
                          ),
                          Expanded(
                            flex: maxV == 0
                                ? 1
                                : 100 - (values[i] * 100 ~/ maxV),
                            child: const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
