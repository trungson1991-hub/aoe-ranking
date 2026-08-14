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
    // (result = 0) khiến cả đội bị coi là thua và cúp gắn nhầm bên. Người
    // thiếu màu vẫn được tính là người chơi thực nên cách này còn nguyên tác
    // dụng dự phòng.
    final redWon = record.realRed.any((p) => p.win);
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
          // Wrap chứ không Row: cỡ chữ hệ thống phóng to là hai chú thích
          // tràn khỏi thẻ; cho phép xuống dòng thay vì vỡ layout.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 4,
            children: [
              _legend('Đội Đỏ', _redTeam, redWon),
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
    final red = _sum(record.realRed, m);
    final blue = _sum(record.realBlue, m);
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
                      Expanded(flex: red, child: Container(color: _redTeam)),
                      if (red > 0 && blue > 0) const SizedBox(width: 2),
                      Expanded(flex: blue, child: Container(color: _blueTeam)),
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
class _ComparisonTable extends StatefulWidget {
  const _ComparisonTable({required this.record, required this.roster});

  final MatchRecord record;
  final Map<String, Member> roster;

  @override
  State<_ComparisonTable> createState() => _ComparisonTableState();
}

class _ComparisonTableState extends State<_ComparisonTable> {
  static const double _labelW = 118; // cột nhãn lúc đầy đủ
  static const double _labelIconW = 30; // cột nhãn khi đã cuộn (còn mỗi icon)
  // Quãng cuộn để cột nhãn thu hết cỡ. Đặt rộng hơn 88px bề ngang mất đi:
  // cột co bao nhiêu thì mép trái vùng cuộn dịch bấy nhiêu, cộng với chính
  // quãng cuộn nên nội dung chạy nhanh hơn ngón tay — quãng càng dài thì phần
  // chạy dư càng khó nhận ra.
  static const double _collapseOver = 140;
  static const double _colW = 86;
  // Chiều cao 1 hàng chỉ số, DÙNG CHUNG cho cột nhãn ghim và hàng số trong
  // vùng cuộn — lệch một chút là hai bên so le nhau.
  // 36 = chữ 13pt (~19) + khoảng 3 + thanh tỉ lệ 3 + đệm trên dưới 10, chừa 1.
  static const double _rowH = 36;

  MatchRecord get record => widget.record;
  Map<String, Member> get roster => widget.roster;

  final _hCtrl = ScrollController();

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  /// Mức thu gọn của cột nhãn, 0 = đầy đủ, 1 = chỉ còn icon.
  ///
  /// Bám THẲNG vào vị trí cuộn chứ không bật/tắt theo ngưỡng: bật/tắt làm kéo
  /// nhẹ 5px cũng khiến cột co ngay 88px và nội dung giật một cái, lại phải
  /// cuộn hẳn về mép trái mới lấy lại được nhãn. Bám theo vị trí thì kéo tới
  /// đâu nhãn lùi tới đó, buông ở đâu giữ nguyên ở đó.
  double get _collapse {
    if (!_hCtrl.hasClients || !_hCtrl.position.hasPixels) return 0;
    return (_hCtrl.offset / _collapseOver).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Bỏ người xem chung slot: họ mang y hệt số liệu của người khác nên để lại
    // sẽ thành một cột ma và làm mọi hàng "hoà nhau" một cách giả tạo.
    final players = record.realAll;
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
          // IntrinsicHeight để cột nhãn (stretch) biết chiều cao của bảng.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pinnedLabels(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _hCtrl,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cột nhãn GHIM ngoài vùng cuộn.
  ///
  /// Dồn xuống ĐÁY: phần trống phía trên tự khớp chiều cao header, khỏi phải
  /// đo header rồi chừa chỗ bằng con số cứng — header cao thấp tuỳ tên người
  /// chơi dài ngắn và có ai ngồi chung slot hay không.
  Widget _pinnedLabels() {
    // AnimatedBuilder: mỗi khung hình cuộn chỉ vẽ lại CỘT NHÃN, không đụng tới
    // bảng số bên cạnh.
    return AnimatedBuilder(
      animation: _hCtrl,
      builder: (context, _) {
        final t = _collapse;
        // Chữ mờ đi nhanh hơn cột co lại, để không bị bóp méo lúc gần hết chỗ.
        final textOpacity = (1 - t * 1.6).clamp(0.0, 1.0);
        return SizedBox(
          width: _labelW + (_labelIconW - _labelW) * t,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < _metrics.length; i++)
                Container(
                  height: _rowH,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color:
                        i.isEven ? Colors.white.withValues(alpha: 0.025) : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRect(
                    child: Row(
                      children: [
                        Text(_metrics[i].icon,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        // Expanded: chữ nhận đúng phần còn thừa, hết chỗ thì
                        // rộng 0 chứ không đẩy tràn ra ngoài.
                        Expanded(
                          child: Opacity(
                            opacity: textOpacity,
                            child: Text(
                              _metrics[i].label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _isViewer(PlayerStat p) => p.uuid == record.viewerUuid;
  bool _inRed(PlayerStat p) => record.red.any((x) => x.uuid == p.uuid);

  /// Avatar của một slot: thường 1 người, nhưng nếu có người ngồi chung thì
  /// xếp cạnh nhau và thu nhỏ lại. Người ngoài team (không có trong roster)
  /// hiện chữ cái đầu theo tên lấy từ dữ liệu trận.
  ///
  /// Ô có chiều cao cố định theo bán kính lớn nhất để cột có khung và cột
  /// không khung căn thẳng hàng (nếu không, tâm avatar lệch nhau vài pixel).
  Widget _avatarOf(PlayerStat p, List<PlayerStat> sharers) {
    final people = [p, ...sharers];
    final radius = people.length > 1 ? 11.0 : 15.0;
    return SizedBox(
      height: MemberAvatar.maxOuterSize(15),
      child: Center(
        // FittedBox: dữ liệu thật chỉ thấy tối đa 2 người/slot, nhưng đông hơn
        // thì phải thu nhỏ chứ không được tràn ra ngoài cột.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final x in people)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: MemberAvatar(
                    name: roster[x.uuid]?.name ?? x.label,
                    avatarUrl: roster[x.uuid]?.avatarUrl ?? '',
                    radius: radius,
                    vipFrameUrl: roster[x.uuid]?.vipFrameUrl ?? '',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header của bảng: mỗi cột là một SLOT trong game (người ngồi chung slot
  /// hiện thêm tên/avatar ở cùng cột chứ không tách ra).
  ///
  /// Dựng theo TỪNG HÀNG NGANG chứ không phải Row-của-Column: trước đây cột
  /// nào tên dài hơn hoặc có thêm người chung slot thì avatar, chấm màu, tên
  /// và gạch đội của cột đó lệch hẳn so với cột bên cạnh. Cắt theo hàng thì
  /// chiều cao mỗi hàng lấy theo ô cao nhất, nên các cột luôn thẳng nhau.
  Widget _headerRow(List<PlayerStat> players) {
    final sharersOf = <String, List<PlayerStat>>{
      for (final p in players)
        p.uuid: record.slotSharers[p.uuid] ?? const <PlayerStat>[],
    };

    Widget band(
      Widget Function(PlayerStat p, List<PlayerStat> sharers) build, {
      bool first = false,
      bool last = false,
    }) {
      // IntrinsicHeight + stretch: ô thấp vẫn kéo dài hết chiều cao hàng, nếu
      // không thì nền vàng của cột người đang xem bị đứt quãng giữa các hàng.
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in players)
              Container(
                width: _colW,
                padding: EdgeInsets.fromLTRB(4, first ? 6 : 4, 4, last ? 6 : 0),
                decoration: BoxDecoration(
                  color: _isViewer(p)
                      ? AppColors.gold.withValues(alpha: 0.10)
                      : null,
                  borderRadius: first
                      ? const BorderRadius.vertical(top: Radius.circular(8))
                      : null,
                ),
                child: build(p, sharersOf[p.uuid]!),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Avatar + khung VIP (nếu là thành viên team).
        band((p, s) => _avatarOf(p, s), first: true),
        band((p, s) => Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: slotColor(p.color),
                  shape: BoxShape.circle,
                ),
              ),
            )),
        band((p, s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isViewer(p) ? AppColors.gold : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (final x in s)
                  Text(
                    '+ ${x.label}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isViewer(x) ? AppColors.gold : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            )),
        band((p, s) => Text(
              s.isEmpty
                  ? civName(p.empiresType)
                  : '${civName(p.empiresType)} · chung slot',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            )),
        // Gạch màu đội (Đỏ/Xanh).
        band(
          (p, s) => Center(
            child: Container(
              height: 3,
              width: 40,
              decoration: BoxDecoration(
                color: _inRed(p) ? _redTeam : _blueTeam,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          last: true,
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
    final ranked = m.time
        ? [
            for (final v in values)
              if (v > 0) v
          ]
        : values;
    final maxV = ranked.fold(0, (a, b) => a > b ? a : b);
    final minV = ranked.isEmpty ? 0 : ranked.reduce((a, b) => a < b ? a : b);
    final best = m.lowerBetter ? minV : maxV;
    // Bằng nhau hết thì không tô sáng ai. Riêng mốc thời gian: chỉ coi là bằng
    // nhau khi MỌI người đều đạt mốc — lên được đời mà người khác chưa lên tới
    // vẫn đáng tô sáng. Không ai đạt -> cả hàng là "—", không tô ô nào.
    final allEqual =
        ranked.isEmpty || (maxV == minV && ranked.length == values.length);

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
          // Hàng có chiều cao cố định, nên số dài phải THU NHỎ chứ không được
          // xuống dòng (xuống dòng là tràn ra ngoài hàng).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              m.time ? (v > 0 ? matchClock(v) : '—') : '$v${m.suffix}',
              maxLines: 1,
              style: TextStyle(
                color: isBest ? AppColors.win : Colors.white70,
                fontSize: 13,
                fontWeight: isBest ? FontWeight.w900 : FontWeight.w500,
              ),
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

    // Nhãn không còn ở đây: nó nằm trong cột ghim ngoài vùng cuộn. Chiều cao
    // phải đúng _rowH để hai bên thẳng hàng nhau.
    return SizedBox(
      height: _rowH,
      child: Container(
        decoration: BoxDecoration(
          color: striped ? Colors.white.withValues(alpha: 0.025) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
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
      ),
    );
  }
}
