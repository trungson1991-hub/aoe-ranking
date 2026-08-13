import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/message_view.dart';
import '../../../core/widgets/selector_chip.dart';
import '../../leaderboard/models/leaderboard.dart';
import '../../leaderboard/services/leaderboard_service.dart';
import '../models/match_record.dart';
import 'match_detail_page.dart';

// Các bộ lọc thể loại: nhãn + kích thước (null = Tất cả).
const List<({String label, int? size})> _filters = [
  (label: 'Tất cả', size: null),
  (label: '1v1', size: 1),
  (label: '2v2', size: 2),
  (label: '3v3', size: 3),
  (label: '4v4', size: 4),
];

class UserHistoryPage extends StatefulWidget {
  const UserHistoryPage({
    super.key,
    required this.member,
    required this.sinceEpoch,
    required this.teamUuids,
    this.service = const LeaderboardService(),
  });

  final Member member;
  final int sinceEpoch;
  final Set<String> teamUuids;
  final LeaderboardService service;

  @override
  State<UserHistoryPage> createState() => _UserHistoryPageState();
}

class _UserHistoryPageState extends State<UserHistoryPage> {
  late final Future<List<MatchRecord>> _future;
  int? _filterSize; // null = tất cả

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchUserHistory(
      widget.member.userUuid,
      sinceEpoch: widget.sinceEpoch,
      teamUuids: widget.teamUuids,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            MemberAvatar(name: m.name, avatarUrl: m.avatarUrl, radius: 16),
            const SizedBox(width: 10),
            Flexible(
              child: Text(m.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<MatchRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return MessageView(text: 'Lỗi tải lịch sử:\n${snap.error}');
          }
          final all = snap.data ?? const [];
          final matches = _filterSize == null
              ? all
              : all.where((e) => e.symmetricSize == _filterSize).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  _filterBar(all),
                  Expanded(
                    child: matches.isEmpty
                        ? const MessageView(
                            text: 'Không có trận nào ở thể loại này.')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            // Dựng sẵn 2 màn hình tile phía trước để cuộn
                            // không giật; RepaintBoundary cô lập vẽ từng tile.
                            scrollCacheExtent:
                                const ScrollCacheExtent.viewport(2),
                            // +1: thẻ tổng quan ở đầu danh sách.
                            itemCount: matches.length + 1,
                            itemBuilder: (_, i) => i == 0
                                ? _SummaryCard(matches: matches)
                                : RepaintBoundary(
                                    child: _MatchTile(rec: matches[i - 1])),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterBar(List<MatchRecord> all) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in _filters)
            SelectorChip(
              dense: true,
              label: f.size == null
                  ? '${f.label} (${all.length})'
                  : '${f.label} (${all.where((e) => e.symmetricSize == f.size).length})',
              selected: _filterSize == f.size,
              onTap: () => setState(() => _filterSize = f.size),
            ),
        ],
      ),
    );
  }
}

/// Thẻ tổng quan cho danh sách trận đang lọc: thắng/thua, tỉ lệ,
/// phong độ 10 trận gần nhất và chỉ số trung bình.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.matches});

  final List<MatchRecord> matches;

  @override
  Widget build(BuildContext context) {
    final wins = matches.where((m) => m.win).length;
    final losses = matches.length - wins;
    final winRate = matches.isEmpty ? 0.0 : wins / matches.length;

    var kills = 0;
    var deaths = 0;
    for (final m in matches) {
      kills += m.viewer?.kills ?? 0;
      deaths += m.viewer?.losses ?? 0;
    }
    final avgK = matches.isEmpty ? 0 : (kills / matches.length).round();
    final avgD = matches.isEmpty ? 0 : (deaths / matches.length).round();

    // matches sắp mới nhất trước; hiển thị MỚI NHẤT bên trái, cũ dần về phải.
    final recent = matches.take(10).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$wins',
                  style: const TextStyle(
                      color: AppColors.win,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const Text(' thắng   ',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              Text('$losses',
                  style: const TextStyle(
                      color: AppColors.loss,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const Text(' thua',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const Spacer(),
              Text('${(winRate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const Text(' tỉ lệ thắng',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          // Thanh tỉ lệ thắng.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (winRate * 100).round().clamp(0, 100),
                    child: Container(color: AppColors.win),
                  ),
                  Expanded(
                    flex: 100 - (winRate * 100).round().clamp(0, 100),
                    child: Container(color: AppColors.loss.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PHONG ĐỘ GẦN ĐÂY',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('mới nhất',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 10)),
                      const SizedBox(width: 6),
                      for (final m in recent) _formDot(m.win),
                      const Text('→ cũ',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('TRUNG BÌNH / TRẬN',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text('⚔️ $avgK giết  ·  💀 $avgD mất',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formDot(bool win) {
    final c = win ? AppColors.win : AppColors.loss;
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(win ? 'T' : 'B',
          style: TextStyle(
              color: c, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.rec});

  final MatchRecord rec;

  @override
  Widget build(BuildContext context) {
    final win = rec.win;
    final resultColor = win ? AppColors.win : AppColors.loss;
    final opp = rec.opponentNames.isEmpty ? '-' : rec.opponentNames.join(', ');
    final mates = rec.teammateNames;
    final v = rec.viewer;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchDetailPage(record: rec)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: resultColor.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            // Dải màu kết quả bên trái — lướt nhanh vẫn thấy chuỗi thắng/thua.
            Container(
              width: 4,
              height: 78,
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Badge kết quả.
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(win ? 'W' : 'L',
                  style: TextStyle(
                      color: resultColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(rec.modeLabel,
                              style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(rec.dateVN),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                              text: 'vs ',
                              style: TextStyle(color: Colors.white38)),
                          TextSpan(
                              text: opp,
                              style:
                                  const TextStyle(color: Colors.white)),
                          if (mates.isNotEmpty) ...[
                            const TextSpan(
                                text: '  ·  cùng ',
                                style: TextStyle(color: Colors.white38)),
                            TextSpan(
                                text: mates.join(', '),
                                style: const TextStyle(
                                    color: Colors.white70)),
                          ],
                        ],
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⚔️ ${v?.kills ?? 0}   💀 ${v?.losses ?? 0}   '
                      '🪙 ${v?.gold ?? 0}   🗺️ ${v?.exploration ?? 0}%',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
