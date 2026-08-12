import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/message_view.dart';
import '../../../core/widgets/selector_chip.dart';
import '../../tournament/pages/tournaments_page.dart';
import '../models/leaderboard.dart';
import '../services/leaderboard_service.dart';
import '../widgets/elo_method_sheet.dart';
import '../widgets/member_card.dart';

// Các chế độ xem: nhãn hiển thị + key trong dữ liệu.
const List<({String key, String label})> _views = [
  (key: kTotalKey, label: 'Tổng'),
  (key: '1v1', label: '1v1'),
  (key: '2v2', label: '2v2'),
  (key: '3v3', label: '3v3'),
  (key: '4v4', label: '4v4'),
];

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key, this.service});

  final LeaderboardService? service;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late final LeaderboardService _svc;
  late Future<Leaderboard> _future;
  String _view = kTotalKey;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? const LeaderboardService();
    _future = _svc.fetch();
  }

  void _reload() => setState(() => _future = _svc.fetch());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _reload,
        tooltip: 'Làm mới',
        child: const Icon(Icons.refresh),
      ),
      body: SafeArea(
        child: FutureBuilder<Leaderboard>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return MessageView(
                icon: Icons.error_outline,
                text: 'Lỗi tải dữ liệu:\n${snap.error}',
              );
            }
            final board = snap.data;
            if (board == null || board.members.isEmpty) {
              return const MessageView(
                icon: Icons.hourglass_empty,
                text:
                    'Chưa có dữ liệu.\nChạy "node scripts/compute.mjs" hoặc chờ cập nhật theo lịch.',
              );
            }
            return _Content(
              board: board,
              view: _view,
              onViewChanged: (v) => setState(() => _view = v),
            );
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.board,
    required this.view,
    required this.onViewChanged,
  });

  final Leaderboard board;
  final String view;
  final ValueChanged<String> onViewChanged;

  @override
  Widget build(BuildContext context) {
    // Người CÓ chơi trong 6 tháng (lastPlayed > 0) mới được xếp hạng.
    // Sắp theo ELO của chế độ đang xem; ai chưa có trận ở chế độ này thì
    // xuống cuối (ELO 1000 xuất phát không phải thành tích).
    final active = board.members
        .where((m) => m.lastPlayed > 0)
        .map((m) => (member: m, stat: m.statFor(view)))
        .toList()
      ..sort((a, b) {
        if (a.stat.isRated != b.stat.isRated) return a.stat.isRated ? -1 : 1;
        final d = b.stat.elo - a.stat.elo;
        if (d != 0) return d;
        return b.stat.wins - a.stat.wins;
      });
    // Người 6 tháng không có trận -> tách xuống cuối.
    final inactive = board.members.where((m) => m.lastPlayed <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final teamUuids = board.members.map((m) => m.userUuid).toSet();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _Header(board: board),
            const SizedBox(height: 14),
            // Hàng nút chức năng — nằm trong luồng layout, không đè lên tiêu đề.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TournamentsPage(roster: board.members),
                    ),
                  ),
                  icon: const Text('🏆', style: TextStyle(fontSize: 16)),
                  label: const Text('Giải đấu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => showEloMethodSheet(context),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Cách tính ELO'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ViewSelector(view: view, onChanged: onViewChanged),
            const SizedBox(height: 20),
            for (var i = 0; i < active.length; i++)
              MemberCard(
                member: active[i].member,
                // Chưa có trận ở chế độ này -> không đánh số hạng.
                rank: active[i].stat.isRated ? i + 1 : 0,
                stat: active[i].stat,
                accent: active[i].stat.isRated
                    ? _rankColor(i + 1)
                    : AppColors.muted,
                sinceEpoch: board.startEpoch,
                teamUuids: teamUuids,
              ),
            if (inactive.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '💤 Không hoạt động (>6 tháng không chơi)',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 12),
              for (final m in inactive)
                Opacity(
                  opacity: 0.55,
                  child: MemberCard(
                    member: m,
                    rank: 0, // không xếp hạng
                    stat: m.statFor(view),
                    accent: AppColors.inactive,
                    sinceEpoch: board.startEpoch,
                    teamUuids: teamUuids,
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                view == kTotalKey
                    ? '${board.internalMatches} trận nội bộ được tính'
                    : 'ELO riêng thể loại $view',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Màu theo thứ hạng: top 1 vàng, 2 bạc, 3 đồng, còn lại xám.
Color _rankColor(int rank) {
  switch (rank) {
    case 1:
      return AppColors.gold;
    case 2:
      return AppColors.silver;
    case 3:
      return AppColors.bronze;
    default:
      return AppColors.muted;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.board});

  final Leaderboard board;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Column(
      children: [
        const Text(
          '🏆  BẢNG XẾP HẠNG ELO',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tính ELO từ ${dateFmt.format(board.startDateVN)}',
          style: const TextStyle(
              color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'Cập nhật: ${fmt.format(board.updatedAtVN)} (giờ VN)',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.view, required this.onChanged});

  final String view;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in _views)
          SelectorChip(
            label: v.label,
            selected: v.key == view,
            onTap: () => onChanged(v.key),
          ),
      ],
    );
  }
}
