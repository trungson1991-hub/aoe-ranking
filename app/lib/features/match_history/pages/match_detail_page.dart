import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../leaderboard/models/leaderboard.dart';
import '../data/aoe_constants.dart';
import '../models/match_record.dart';

// Màu 2 đội theo cách gọi của game: đội Đỏ (red_team) và đội Xanh (blue_team).
const _redTeam = Color(0xFFF87171);
const _blueTeam = Color(0xFF60A5FA);

// Một chỉ số so sánh: nhãn + cách lấy giá trị + chiều tốt (thấp hơn = tốt?).
class _Metric {
  const _Metric(this.icon, this.label, this.get,
      {this.lowerBetter = false, this.suffix = '', this.time = false})
      // Thanh tỉ lệ của mốc thời gian chia cho mốc tốt nhất, nên mốc tốt nhất
      // BẮT BUỘC là nhỏ nhất; nếu không tỉ lệ vượt 100 -> Expanded flex âm ->
      // vỡ cả trang. `_metrics` là const nên sai là báo lúc biên dịch.
      : assert(!time || lowerBetter, 'mốc thời gian: sớm hơn = tốt hơn');
  final String icon;
  final String label;
  final int Function(PlayerStat) get;
  final bool lowerBetter;
  final String suffix;

  /// Giá trị là mốc thời gian trong trận (ms): hiện dạng m:ss, và 0 nghĩa là
  /// "chưa đạt" chứ không phải mốc sớm nhất — phải loại khỏi việc so sánh.
  final bool time;
}

/// Mốc đồng hồ trong trận (ms) -> "m:ss".
String _clock(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
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
  _Metric('⏱️', 'Lên đời 2', _age2Time, lowerBetter: true, time: true),
  _Metric('⏱️', 'Lên đời 3', _age3Time, lowerBetter: true, time: true),
  _Metric('⏱️', 'Lên đời 4', _age4Time, lowerBetter: true, time: true),
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
int _age2Time(PlayerStat p) => p.age2Time;
int _age3Time(PlayerStat p) => p.age3Time;
int _age4Time(PlayerStat p) => p.age4Time;

class MatchDetailPage extends StatelessWidget {
  const MatchDetailPage({
    super.key,
    required this.record,
    this.roster = const {},
  });

  final MatchRecord record;

  /// Thành viên team theo uuid — để lấy avatar + đồ trang trí.
  final Map<String, Member> roster;

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
              _ComparisonTable(record: r, roster: roster),
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

  // Chọn lọc từ danh sách chung để nhãn/icon không bị lệch khi sửa một nơi.
  static const _teamMetricLabels = [
    'Giết quân',
    'Phá công trình',
    'Đào vàng',
    'Công nghệ',
    'Dân số',
  ];
  static final List<_Metric> _teamMetrics = [
    for (final label in _teamMetricLabels)
      _metrics.firstWhere((m) => m.label == label),
  ];

  int _sum(List<PlayerStat> side, _Metric m) =>
      side.fold(0, (a, p) => a + m.get(p));

  @override
  Widget build(BuildContext context) {
    // Xét cả đội: người đầu danh sách có thể thiếu dữ liệu thống kê
    // (result = 0) khiến cả đội bị coi là thua và cúp gắn nhầm bên.
    final redWon = record.red.any((p) => p.win);
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
  const _ComparisonTable({required this.record, required this.roster});

  final MatchRecord record;
  final Map<String, Member> roster;

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
          // Wrap thay Row+Spacer: trận đông người trên màn hẹp thì gợi ý
          // "kéo ngang" tự xuống dòng thay vì tràn khỏi thẻ.
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('SO SÁNH TỪNG NGƯỜI',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
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

  /// Avatar của người chơi; người ngoài team (không có trong roster) thì
  /// hiện chữ cái đầu theo tên lấy từ dữ liệu trận.
  /// Ô có chiều cao cố định để cột có khung và cột không khung căn thẳng
  /// hàng với nhau (nếu không, tâm avatar lệch nhau vài pixel).
  Widget _avatarOf(PlayerStat p) {
    final m = roster[p.uuid];
    return SizedBox(
      height: MemberAvatar.maxOuterSize(15),
      child: Center(
        child: MemberAvatar(
          name: m?.name ?? p.label,
          avatarUrl: m?.avatarUrl ?? '',
          radius: 15,
          vipFrameUrl: m?.vipFrameUrl ?? '',
        ),
      ),
    );
  }

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
                // Avatar + khung VIP của người chơi (nếu là thành viên team).
                _avatarOf(p),
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: slotColor(p.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isViewer(p) ? AppColors.gold : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  civName(p.empiresType),
                  textAlign: TextAlign.center,
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
    if (players.isEmpty) return const SizedBox.shrink();
    final values = [for (final p in players) m.get(p)];
    // Với mốc thời gian, 0 = chưa lên tới đời đó. Nếu đem so bình thường thì
    // người không lên đời lại thành người "lên nhanh nhất".
    final ranked = m.time ? [for (final v in values) if (v > 0) v] : values;
    final maxV = ranked.fold(0, (a, b) => a > b ? a : b);
    final minV = ranked.isEmpty ? 0 : ranked.reduce((a, b) => a < b ? a : b);
    final best = m.lowerBetter ? minV : maxV;
    // Bằng nhau hết thì không tô sáng ai. Riêng mốc thời gian: chỉ coi là bằng
    // nhau khi MỌI người đều đạt mốc — lên được đời mà người khác chưa lên tới
    // vẫn đáng tô sáng. Không ai đạt -> cả hàng là "—", không tô ô nào.
    final allEqual = ranked.isEmpty ||
        (maxV == minV && ranked.length == values.length);

    // Thanh tỉ lệ 0..100. Mốc thời gian đảo chiều: lên đời sớm nhất mới là
    // thanh dài nhất, nếu không thanh dài sẽ tôn người lên đời chậm nhất.
    int fraction(int v) {
      if (m.time) return v <= 0 ? 0 : best * 100 ~/ v;
      return maxV == 0 ? 0 : v * 100 ~/ maxV;
    }

    Widget cell(int v) {
      final isBest = !allEqual && v == best;
      final flex = fraction(v);
      final color = isBest ? AppColors.win : Colors.white24;
      return Column(
        children: [
          Text(
            m.time ? (v > 0 ? _clock(v) : '—') : '$v${m.suffix}',
            style: TextStyle(
              color: isBest ? AppColors.win : Colors.white70,
              fontSize: 13,
              fontWeight: isBest ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          // Thanh tỉ lệ so với người tốt nhất trong hàng.
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Row(
                children: [
                  Expanded(flex: flex, child: Container(color: color)),
                  Expanded(
                    flex: flex == 0 ? 1 : 100 - flex,
                    child: const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

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
              child: cell(values[i]),
            ),
        ],
      ),
    );
  }
}
