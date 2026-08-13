import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../match_history/pages/user_history_page.dart';
import '../models/leaderboard.dart';

const Map<int, String> _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

/// Thẻ 1 thành viên trên bảng xếp hạng. Bấm vào mở lịch sử trận.
class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    required this.rank, // 1-based; 0 = không xếp hạng (ngưng hoạt động)
    required this.stat,
    required this.accent,
    required this.sinceEpoch,
    required this.teamUuids,
    this.animateMedal = false,
  });

  final Member member;
  final int rank;
  final ModeStat stat;
  final Color accent;
  final int sinceEpoch;
  final Set<String> teamUuids;

  /// Huy chương đung đưa tắt dần khi vào trang (chỉ dùng cho top 3).
  final bool animateMedal;

  bool get _isTop3 => rank >= 1 && rank <= 3;

  @override
  Widget build(BuildContext context) {
    // Style TĨNH (không animate) để cuộn thật mượt trên web.
    final Widget card = _isTop3
        ? Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [accent.withValues(alpha: 0.30), AppColors.surface],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.6),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.32), blurRadius: 12),
              ],
            ),
            child: _row(context, big: true),
          )
        : Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: _row(context, big: false),
          );

    // RepaintBoundary: cô lập vẽ từng thẻ -> cuộn không repaint cả list.
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserHistoryPage(
              member: member,
              sinceEpoch: sinceEpoch,
              teamUuids: teamUuids,
            ),
          ),
        ),
        child: card,
      ),
    );
  }

  Widget _row(BuildContext context, {required bool big}) {
    final m = member;
    final s = stat;
    final avatar =
        MemberAvatar(name: m.name, avatarUrl: m.avatarUrl, radius: big ? 24 : 22);

    return Row(
      children: [
        SizedBox(
          width: big ? 34 : 28,
          child: _isTop3
              ? (animateMedal
                  ? _FloatingMedal(medal: _medals[rank]!)
                  : Text(_medals[rank]!,
                      style: const TextStyle(fontSize: 24),
                      textAlign: TextAlign.center))
              : Text(
                  rank > 0 ? '#$rank' : '—',
                  style: TextStyle(
                      color: accent, fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(width: 6),
        // Vòng phát sáng quanh avatar cho top 3.
        if (big)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
            child: avatar,
          )
        else
          avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.name,
                style: TextStyle(
                  color: big ? accent : Colors.white,
                  fontSize: big ? 17 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.games == 0
                    ? 'chưa có trận'
                    : '${s.wins}T-${s.losses}B · ${s.games} trận · '
                        'tỉ lệ ${(s.winRate * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (s.games > 0) ...[
                const SizedBox(height: 5),
                _winRateBar(s.winRate),
              ],
              if (m.lastPlayedVN != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Chơi gần nhất: ${DateFormat('dd/MM/yyyy').format(m.lastPlayedVN!)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              // Chưa có trận -> không có ELO để khoe.
              s.isRated ? '${s.elo}' : '—',
              style: TextStyle(
                color: !s.isRated
                    ? Colors.white38
                    // Xanh = trên mốc xuất phát 1000, đỏ = dưới.
                    : (s.elo >= kEloBase ? AppColors.win : AppColors.loss),
                fontSize: big ? 26 : 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              s.isProvisional ? 'ELO tạm' : 'ELO',
              style: TextStyle(
                color: s.isProvisional ? AppColors.gold : Colors.white38,
                fontSize: 10,
                fontWeight:
                    s.isProvisional ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Thanh tỉ lệ thắng mỏng: phần thắng màu xanh, phần thua màu nền.
  Widget _winRateBar(double winRate) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        width: 140,
        child: Row(
          children: [
            Expanded(
              flex: (winRate * 100).round().clamp(0, 100),
              child: Container(color: AppColors.win.withValues(alpha: 0.8)),
            ),
            Expanded(
              flex: 100 - (winRate * 100).round().clamp(0, 100),
              child: Container(color: Colors.white12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Huy chương đung đưa như treo trên dây, tắt dần rồi ĐỨNG YÊN hẳn.
///
/// Dùng phép XOAY thay vì tịnh tiến: tịnh tiến biên độ nhỏ khiến glyph
/// "hít" vào lưới pixel, nhìn thành nhảy từng nấc; xoay thì mỗi frame
/// glyph được resample lại nên chuyển động mượt. RepaintBoundary cô lập
/// vùng vẽ ~34px; đung đưa xong widget trở về Text tĩnh 100%.
class _FloatingMedal extends StatefulWidget {
  const _FloatingMedal({required this.medal});

  final String medal;

  @override
  State<_FloatingMedal> createState() => _FloatingMedalState();
}

class _FloatingMedalState extends State<_FloatingMedal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool _done = false;

  static const _text =
      TextStyle(fontSize: 24); // kèm textAlign center ở dưới

  @override
  void initState() {
    super.initState();
    _c.forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _done = true); // về tĩnh hoàn toàn
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Con lắc tắt dần: 3 nhịp, biên độ ~16° giảm dần về đúng 0 ở cuối.
  double _angle(double t) =>
      0.28 * (1 - t) * (1 - t) * math.sin(2 * math.pi * 3 * t);

  @override
  Widget build(BuildContext context) {
    final medal =
        Text(widget.medal, style: _text, textAlign: TextAlign.center);
    if (_done) return medal;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.rotate(
          angle: _angle(_c.value),
          alignment: Alignment.topCenter, // xoay quanh "dây treo"
          child: child,
        ),
        child: medal,
      ),
    );
  }
}
